# Workload Cluster — `workload-prd`

Bare-metal Talos Linux cluster running on VLAN 4 (`10.0.4.0/24`). Hosts user-facing
workloads. Consumes shared infrastructure services (Vault, Harbor) from the
`management-prd` cluster on VLAN 2. Managed entirely by FluxCD after bootstrap.

## Nodes

| Hostname        | IP       | Role          | Interface | Disk          |
|-----------------|----------|---------------|-----------|---------------|
| controlplane-1  | 10.0.4.3 | control-plane | enp1s0    | /dev/nvme0n1  |
| workload-1      | 10.0.4.4 | worker        | enp2s0    | /dev/nvme0n1  |

## FluxCD layer order

Layers are enabled one at a time in `flux-system/kustomization.yaml`. Verify each
layer is healthy before uncommenting the next.

```
core → platform → observability
              ↘ apps
              ↘ llm
```

---

## Prerequisites

- Devbox shell active (`devbox shell` at repo root)
- Kubeconfig for this cluster at `~/.kube/workload`
- Management cluster running and healthy (Vault + Harbor reachable)
- Vault root token available (`VAULT_ADDR=https://vault.mgmt.yuriy-lab.cloud`)

---

## 1. Reserve static IPs in Kea

Add DHCP reservations in OPNsense so nodes always receive their assigned IPs:

**OPNsense → Services → Kea DHCP → DHCPv4 → Reservations**

| Hostname       | MAC              | IP       | Description              |
|----------------|------------------|----------|--------------------------|
| controlplane-1 | `<mac>`          | 10.0.4.3 | workload-prd control-plane |
| workload-1     | `<mac>`          | 10.0.4.4 | workload-prd worker        |

Find the MAC address from OPNsense DHCP leases after first network boot, or from
the BIOS/UEFI network settings.

---

## 2. Provision Talos nodes

Node imaging is handled by `yk-talos-manager` running on the management cluster.
Apply the TalosCluster and TalosNode CRs from the management cluster:

```bash
kubectl --kubeconfig ~/.kube/mgmt apply \
  -f kubernetes/platform/yk-talos-manager-prd-workload/overlays/management-prd/
```

Wait for yk-talos-manager to complete provisioning before proceeding.

Verify nodes are reachable:

```bash
kubectl --kubeconfig ~/.kube/workload get nodes
```

Nodes will show `NotReady` until Cilium is installed.

---

## 3. Install Cilium CNI

```bash
cd kubernetes/clusters/workload-prd/terraform/cni
tf_init && tf_apply
```

Verify:

```bash
kubectl --kubeconfig ~/.kube/workload get nodes
kubectl --kubeconfig ~/.kube/workload -n kube-system get pods -l app.kubernetes.io/name=cilium
```

All nodes should reach `Ready`.

---

## 4. Install FluxCD

```bash
cd kubernetes/clusters/workload-prd/terraform/fluxcd
tf_init && tf_apply
```

Verify controllers are running:

```bash
kubectl --kubeconfig ~/.kube/workload -n flux-system get pods
```

---

## 5. Bootstrap GitOps sync

```bash
kubectl --kubeconfig ~/.kube/workload \
  apply -k kubernetes/clusters/workload-prd/flux-system/
```

This creates:
- `GitRepository/homelab` — watches the `main` branch
- `Kustomization/flux-system` — self-manages the flux-system directory
- `Kustomization/core` — first layer (only active layer at bootstrap)

Watch reconciliation:

```bash
flux --kubeconfig ~/.kube/workload get kustomizations -w
```

---

## 6. Layer: core

**What deploys:** `gateway-api-crds`, `prometheus-operator-crds`, `cert-manager`,
`external-secrets`, `external-secrets-config` (ClusterSecretStore), `kyverno`,
`cilium-policies`.

### 6a. Configure Vault Kubernetes auth (one-time)

After `external-secrets` is running, set up Vault authentication so the
`ClusterSecretStore` can resolve secrets.

→ See [`core/external-secrets/overlays/workload-prd/README.md`](../../../core/external-secrets/overlays/workload-prd/README.md)

### 6b. Verify core is healthy

```bash
# All HelmReleases ready
kubectl --kubeconfig ~/.kube/workload get helmrelease -A

# ClusterSecretStore connected to Vault
kubectl --kubeconfig ~/.kube/workload get clustersecretstore default-store

# Kyverno generate policy created per-namespace policies
kubectl --kubeconfig ~/.kube/workload get ciliumnetworkpolicies -A
```

Expected:

```
NAME            AGE   STATUS   READY
default-store   Xm    Valid    True
```

---

## 7. Layer: platform

**What deploys:** `gateway`, `cluster-issuer`, `bgp`, `hubble`, `cilium-observability`,
`longhorn`, `metrics-server`, `forgejo`, `flux-system` (HelmRepo), `kyverno-reporter`,
`vpa`, `yk-dns-manager`, `trivy`, `trivy-converter`.

### 7a. Pre-create secrets

These are not managed by ExternalSecrets — create them before enabling the layer:

```bash
# cert-manager — Cloudflare API token for DNS-01 challenges
kubectl --kubeconfig ~/.kube/workload create namespace cert-manager
kubectl --kubeconfig ~/.kube/workload create secret generic cloudflare-api-token-secret \
  --namespace cert-manager \
  --from-literal=api-token=<cloudflare-api-token>
```

Token permissions required: `Zone:Read`, `DNS:Edit`.
Create at **Cloudflare Dashboard → My Profile → API Tokens → Create Token**.

```bash
# yk-dns-manager — OPNsense API credentials
kubectl --kubeconfig ~/.kube/workload create namespace yk-dns-manager
kubectl --kubeconfig ~/.kube/workload create secret generic dns-provider-credentials \
  --namespace yk-dns-manager \
  --from-literal=OPNSENSE_API_KEY=<api-key> \
  --from-literal=OPNSENSE_API_SECRET=<api-secret>
```

Generate the OPNsense key at **System → Access → Users → root → API Keys → Add**.

### 7b. Enable platform layer

Uncomment `platform.yaml` in `flux-system/kustomization.yaml`, commit and push.

### 7c. Verify platform is healthy

```bash
flux --kubeconfig ~/.kube/workload get kustomization platform
kubectl --kubeconfig ~/.kube/workload get helmrelease -A
kubectl --kubeconfig ~/.kube/workload get clusterissuer
```

---

## 8. Layer: observability

**What deploys:** `loki`, `mimir`, `tempo`, `k8s-monitoring`, `grafana`.

### 8a. Populate Vault with S3 credentials

Observability components pull S3 credentials via ExternalSecrets. Populate Vault
using the workload-prd Vault terraform:

```bash
cd kubernetes/clusters/workload-prd/terraform/vault
tf_init && tf_apply
```

Verify the ExternalSecrets resolve after the layer deploys:

```bash
kubectl --kubeconfig ~/.kube/workload get externalsecrets -A
```

### 8b. Enable observability layer

Uncomment `observability.yaml` in `flux-system/kustomization.yaml`, commit and push.

### 8c. Verify

```bash
flux --kubeconfig ~/.kube/workload get kustomization observability
kubectl --kubeconfig ~/.kube/workload get helmrelease -n loki
kubectl --kubeconfig ~/.kube/workload get helmrelease -n mimir
kubectl --kubeconfig ~/.kube/workload get helmrelease -n tempo
```

---

## 9. Layers: apps + llm

### 9a. Enable apps and llm

Uncomment `apps.yaml` and `llm.yaml` in `flux-system/kustomization.yaml`, commit and push.

### 9b. Verify

```bash
flux --kubeconfig ~/.kube/workload get kustomizations
kubectl --kubeconfig ~/.kube/workload get helmrelease -A
```

---

## Cloudflare DNS records

DNS records for all exposed services are managed via Terraform. Apply at any point
after FluxCD is running — records must exist before cert-manager issues certificates:

```bash
cd kubernetes/clusters/workload-prd/terraform/cloudflare
tf_init && tf_apply
```

---

## Secrets reference

| Secret | Namespace | How created | When needed |
|--------|-----------|-------------|-------------|
| `cloudflare-api-token-secret` | `cert-manager` | Manual (step 7a) | Before platform |
| `dns-provider-credentials` | `yk-dns-manager` | Manual (step 7a) | Before platform |
| `loki-s3-secret` | `loki` | ExternalSecret → Vault | Before observability |
| `mimir-credentials` | `mimir` | ExternalSecret → Vault | Before observability |
| `tempo-s3-secret` | `tempo` | ExternalSecret → Vault | Before observability |

---

## Network

| Host           | IP       | VLAN               |
|----------------|----------|--------------------|
| controlplane-1 | 10.0.4.3 | k8s-workload (VLAN 4) |
| workload-1     | 10.0.4.4 | k8s-workload (VLAN 4) |

See [`docs/NETWORK.md`](../../../docs/NETWORK.md) for the full VLAN layout and firewall rules.
