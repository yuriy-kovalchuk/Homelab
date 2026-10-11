# Cluster `workload-prd`

Bare-metal Talos Linux cluster on the k8s-workload VLAN. Three control planes
(valefor, ifrit, shiva) and two workers that are not always on (ixion,
bahamut). After bootstrap, Flux manages everything from this repo.

Hardware, IPs and MACs: [docs/DEVICES.md](../../../docs/DEVICES.md).
Network, API VIP and BGP: [docs/NETWORK.md](../../../docs/NETWORK.md).
Layers and components: [README.md](../../../README.md).

## This folder

| Path | Contents |
|------|----------|
| `flux-system/` | `gotk-sync.yaml` (GitRepository `homelab` on `main`) and one Flux Kustomization per layer, ordered by `dependsOn` |
| `terraform/cni/` | Cilium install (Helm) |
| `terraform/fluxcd/` | flux-operator + `FluxInstance` |
| `terraform/vault/` | Writes every app secret into Vault (KV v2 mount `kubernetes`), one `.tf` per app |
| `terraform/cloudflare/` | Cloudflare DNS records |

Terraform runs inside `devbox shell`, which loads `.env` and provides
`tf_init` / `tf_plan` / `tf_apply`. Kubeconfig path: `~/.kube/workload`
(see the `terraform.tfvars` files).

## Bootstrap from scratch

### 1. Network

On OPNsense (Ansible in `proxmox-nodes/ansible/playbooks/opnsense/`):

- `reservations.yml` — a Kea reservation for every node.
- `k8s_api_lb.yml` — Kubernetes API VIP (HAProxy). The VIP must exist before
  the nodes are configured, because their config points at it.
- `bgp.yml` — a BGP neighbor for every node.

### 2. Talos nodes

Node configs are kept out of Git (`.playground/talos/`, `~/.talos/`).
Generate them with `talosctl gen config`, with these settings for every node:

- `cluster.controlPlane.endpoint`: the API VIP, `https://<vip>:6443`.
- `cluster.apiServer.certSANs`: the VIP.
- A `HostnameConfig` document with the lowercase node name.
- `machine.install.image`: the node's factory installer, with the schematic
  from DEVICES.md (iscsi-tools and util-linux-tools everywhere, plus amdgpu
  and amd-ucode on AMD GPU nodes).
- `machine.nodeAnnotations`: `node.longhorn.io/default-node-tags`:
  `'["system"]'` on control planes, `'["gpu"]'` on bahamut.
- Workers: labels and taints (bahamut: `ai-node: oculink`,
  `workload=gpu:NoSchedule`). Talos cannot add taints to a worker after it
  has registered, so set them with `kubectl` if the node already exists.

Boot each node into maintenance mode, then:

```bash
talosctl apply-config --insecure -n <node-ip> -f <node>.yaml
talosctl -e <first-cp> -n <first-cp> bootstrap          # first control plane only
talosctl -e <first-cp> -n <first-cp> kubeconfig ~/.kube/workload
```

Nodes stay `NotReady` until Cilium is installed.

### 3. Cilium

```bash
cd kubernetes/clusters/workload-prd/terraform/cni && tf_init && tf_apply
```

### 4. Vault secrets

Vault runs on TrueNAS. Write the app secrets (values come from `TF_VAR_*` in
`.env`):

```bash
cd kubernetes/clusters/workload-prd/terraform/vault && tf_init && tf_apply
```

### 5. Flux

```bash
cd kubernetes/clusters/workload-prd/terraform/fluxcd && tf_init && tf_apply
kubectl --kubeconfig ~/.kube/workload apply -k kubernetes/clusters/workload-prd/flux-system/
flux --kubeconfig ~/.kube/workload get kustomizations -w
```

All layers are listed in `flux-system/kustomization.yaml`; `dependsOn`
brings them up in order. Nothing needs enabling by hand.

### 6. Vault Kubernetes auth (one time)

Once `external-secrets` is running, configure Vault to trust its
ServiceAccount tokens, with `kubernetes_host` set to the API VIP:
[`core/external-secrets/overlays/workload-prd/README.md`](../../core/external-secrets/overlays/workload-prd/README.md).
Until then the `secrets` layer, and everything after it, waits.

### 7. Cloudflare DNS

```bash
cd kubernetes/clusters/workload-prd/terraform/cloudflare && tf_init && tf_apply
```

### 8. Check

```bash
flux --kubeconfig ~/.kube/workload get kustomizations
kubectl --kubeconfig ~/.kube/workload get clustersecretstore default-store
kubectl --kubeconfig ~/.kube/workload get externalsecrets -A
kubectl --kubeconfig ~/.kube/workload get helmreleases -A
kubectl --kubeconfig ~/.kube/workload -n longhorn-system get lease longhorn-global-manager
```

## Secrets

Every secret comes from Vault through an ExternalSecret in
`kubernetes/secrets/base/`: cert-manager (Cloudflare token), democratic-csi
(nfs, iscsi), cloudflared, yk-dns-manager (OPNsense API key), Loki, Mimir,
Tempo, Grafana, Alertmanager, Immich, OpenCloud, Forgejo, forgejo-runner,
and the ubuntu-test VM. Nothing is created by hand in the cluster.
