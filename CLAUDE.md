# Homelab — Claude Context

This file gives Claude enough context to work in this repo without a full scan each session.

---

## Repository layout

```
Homelab/
├── kubernetes/
│   ├── clusters/          # Cluster bootstrap, FluxCD sync definitions, Terraform (CNI, Vault, Cloudflare)
│   ├── infrastructure/    # Shared infra components — base/ + overlays/{cluster}/
│   └── apps/              # User-facing apps — base/ + overlays/{cluster}/
├── proxmox-nodes/
│   ├── terraform/         # Proxmox VMs (OPNsense gateway, storage VM)
│   └── ansible/           # OPNsense and node configuration playbooks
└── docs/
    ├── NETWORK.md          # VLAN layout, firewall rules, BGP
    └── DEVICES.md          # All static IPs and hostnames
```

---

## Cluster topology

One bare-metal **Talos Linux** cluster managed by FluxCD.

### workload-prd
| Node | IP | Role |
|------|----|------|
| controlplane-1 | 10.0.4.3 | control-plane |
| controlplane-2 | 10.0.4.5 | control-plane |
| controlplane-3 | 10.0.4.6 | control-plane (offline, coming back) |
| worker-1 | 10.0.4.4 | worker + **AMD 780M GPU** |

- VLAN 4 — `10.0.4.0/24`, gateway `10.0.4.1` (OPNsense)
- Hosts: all user-facing workloads, LLM stack, observability, infrastructure (Vault on TrueNAS)
- BGP pool: `10.0.4.50–10.0.4.99`, peer OPNsense (ASN 65551 ↔ 65001)
- `worker-1` is the GPU node — LLM workloads pinned there via `nodeSelector: kubernetes.io/hostname: worker-1`

### VLAN map
| VLAN | Subnet | Purpose |
|------|--------|---------|
| 2 | 10.0.2.0/24 | Deprecated — pending removal |
| 3 | 10.0.3.0/24 | Storage (TrueNAS 10.0.3.3 — NAS + Vault + Zot + RustFS) |
| 4 | 10.0.4.0/24 | Workload cluster |
| 5 | 10.0.5.0/24 | Physical workload devices |
| 6 | 10.0.6.0/24 | Private wireless |
| 7 | 10.0.7.0/24 | Guest wireless |

---

## FluxCD GitOps structure

```
GitRepository: homelab (github.com/yuriy-kovalchuk/Homelab, branch: main)
│
├── Kustomization: flux-system   → ./kubernetes/clusters/{cluster}/flux-system
├── Kustomization: infrastructure → ./kubernetes/infrastructure/overlays/{cluster}
├── Kustomization: apps           → ./kubernetes/apps/overlays/{cluster}
└── Kustomization: apps-llm       → ./kubernetes/apps/llama-cpp/overlays/workload-prd
    (workload-prd only — separate to avoid LLM memory usage blocking other apps)
```

Reconciliation order: `flux-system` → `infrastructure` → `apps` → `apps-llm`

Key sync files:
- `kubernetes/clusters/workload-prd/flux-system/` — GitRepository + all Kustomizations
- `kubernetes/infrastructure/overlays/workload-prd/kustomization.yaml` — ordered infra resource list
- `kubernetes/apps/overlays/workload-prd/kustomization.yaml` — app resource list

---

## Infrastructure components

All follow `base/ + overlays/{cluster}/` pattern. HelmRepositories live in `flux-system` namespace.

| Component | Namespace | Chart | Version | Repo | Purpose |
|-----------|-----------|-------|---------|------|---------|
| cert-manager | cert-manager | cert-manager | — | jetstack | TLS via Let's Encrypt + Cloudflare DNS |
| external-secrets | external-secrets | external-secrets | 2.5.0 | external-secrets | Syncs Vault secrets → K8s Secrets |
| vault | vault | vault | 0.32.0 | hashicorp | Secrets backend |
| harbor | harbor | harbor | 1.x | harbor | Private container registry |
| longhorn | longhorn-system | longhorn | 1.11.2 | longhorn | HA block storage |
| gateway-api-crds | — | — | — | — | Gateway API CRD installation |
| gateway | kube-system | — | — | — | Cilium Gateway, HTTPS ingress |
| metrics-server | kube-system | metrics-server | — | — | K8s HPA/VPA metrics |
| kyverno | kyverno | kyverno | 3.8.1 | kyverno | Policy engine |
| kyverno-reporter | kyverno-reporter | policy-reporter | — | kyverno | Policy reporting UI |
| prometheus-operator-crds | — | prometheus-operator-crds | 29.x | prometheus-community | CRDs for ServiceMonitor etc. |
| k8s-monitoring | k8s-monitoring | k8s-monitoring | 4.1.3 | grafana | Alloy collectors (metrics + logs + traces) |
| mimir | mimir | mimir-distributed | 6.0.6 | grafana | Metrics long-term storage (S3 backend) |
| loki | loki | loki | 7.0.0 | grafana | Log aggregation (S3 backend) |
| tempo | tempo | tempo-distributed | 2.23.4 | grafana-community | Distributed tracing (S3 backend) |
| grafana | grafana | grafana | 10.5.15 | grafana | Dashboards |
| trivy | trivy | trivy-operator | 0.32.1 | aqua | Container vulnerability scanning |
| trivy-converter | trivy-converter | trivy-operator-polr-adapter | 0.11.3 | fjogeleit | Converts Trivy reports → PolicyReports |
| vpa | vpa | vpa + goldilocks | — | fairwinds | Vertical pod autoscaler + recommendations |
| forgejo | forgejo | forgejo | — | forgejo | Self-hosted Git |
| bgp | — | — | — | — | Cilium BGP peer config + LB IP pool |
| cilium-policies | — | — | — | — | Cluster-wide CiliumNetworkPolicies |
| cilium-observability | — | — | — | — | Cilium Envoy stats + PodMonitor |
| hubble | kube-system | — | — | — | Cilium Hubble network UI |
| yk-dns-manager | yk-dns-manager | yk-dns-manager | — | custom | DNS record management on OPNsense |
| yk-talos-manager | yk-talos-manager | yk-talos-manager | — | custom | Talos machine lifecycle controller |

---

## Applications (workload-prd only)

| App | Namespace | Purpose |
|-----|-----------|---------|
| llama-cpp | llm | LLM inference server — llama.cpp router mode, Vulkan GPU, AMD 780M on worker-1 |
| open-webui | open-webui | Chat UI — connects to `llama-cpp.llm.svc.cluster.local:8080/v1` |
| homepage | homepage | Dashboard landing page |
| cloudflared | cloudflared | Cloudflare Tunnel agent |
| uptime-kuma | uptime-kuma | Service availability monitoring |
| yk-portfolio | yk-portfolio | Personal portfolio (static site) |
| httpbin | httpbin | HTTP echo/testing service |
| whoami | whoami | Simple identity service |
| clean-pods | clean-pods | CronJob — cleans failed pods + completed jobs |
| s3 | s3 | ExternalEndpoint → MinIO at 10.0.3.4:9000 (API) and :9001 (console) |
| truenas | truenas | ExternalEndpoint → TrueNAS at 10.0.3.3:80 |
| opnsense | opnsense | ExternalEndpoint → OPNsense at 10.0.4.1:443 |
| cloudnative-pg | cloudnative-pg | PostgreSQL operator (STANDBY — pending monitoring stack readiness) |

---

## Networking conventions

**Domain:** `yuriy-lab.cloud` (Cloudflare DNS, cert-manager DNS-01 challenge)

**Gateway pattern:**
- GatewayClass: `cilium`
- Gateway name: `internal` in namespace `kube-system`
- One HTTPS listener per hostname, named `https-{app-name}` — must match HTTPRoute `sectionName`
- Cert refs live in the app namespace
- Config: `kubernetes/infrastructure/gateway/overlays/workload-prd/gateway-patch.yaml`

**HTTPRoute pattern:**
```yaml
parentRefs:
  - name: internal
    namespace: kube-system
    sectionName: https-{app-name}   # must match gateway listener name
hostnames:
  - {app-name}.yuriy-lab.cloud
```

**CiliumNetworkPolicy conventions:**
- Policies are namespace-scoped, placed in `base/network-policy.yaml` of each component
- Always split `kube-apiserver` and `remote-node/host` into separate egress rules, each allowing **both port 6443 and 443** (in-cluster pods use `10.96.0.1:443` via the kubernetes service, not 6443 directly)
- Common entities: `kube-apiserver`, `cluster`, `ingress`, `world`, `remote-node`, `host`
- S3 egress uses `toCIDR: 10.0.3.4/32` port 9000
- Never use a single rule combining `kube-apiserver` + `remote-node` + `host` — split them

---

## Secrets management

**Flow:** Vault (management cluster) → ExternalSecret → K8s Secret (workload cluster)

- Vault: `vault` namespace, management cluster, standalone mode, Longhorn PVC
- ExternalSecrets: `external-secrets` namespace, ClusterSecretStore `default-store`
- Vault address: `https://vault.mgmt.yuriy-lab.cloud` (or `http://vault.vault.svc.cluster.local:8200` in-cluster)
- Auth: Kubernetes service account `external-secrets`
- Secrets path prefix: `kubernetes/`

**Secrets NOT in Git (must be created manually before bootstrap):**
- `cloudflare-api-token-secret` in `cert-manager` — Cloudflare API token for DNS-01
- `dns-provider-credentials` in `yk-dns-manager` — OPNsense API key + secret
- Vault unseal key — created after `vault operator init`

---

## Observability stack

**Architecture:** Alloy collectors → Mimir (metrics) + Loki (logs) + Tempo (traces) → Grafana

**S3 storage:** all three backends use `10.0.3.4:9000`, credentials from Vault via ExternalSecret

| Component | Service URL (in-cluster) | Port |
|-----------|--------------------------|------|
| Mimir query | `mimir-query-frontend.mimir.svc.cluster.local` | 8080 |
| Mimir ingest | `mimir-distributor.mimir.svc.cluster.local` | 8080 |
| Loki | `loki-gateway.loki.svc.cluster.local` | 8080 |
| Tempo query | `tempo-query-frontend.tempo.svc.cluster.local` | 3100 |
| Tempo ingest | `tempo-distributor.tempo.svc.cluster.local` | 4317 (gRPC) / 4318 (HTTP) |

**Grafana datasources** (configured in `grafana/overlays/workload-prd/helm-release-patch.yaml`):
- Mimir — uid: `mimir-metrics`, default datasource
- Loki — uid: `loki-datasource`, has `derivedFields` linking traceID → Tempo
- Tempo — uid: `tempo-datasource`, linked to Mimir (service map) and Loki (log correlation)

**Dashboards:** loaded via ConfigMap + sidecar, `grafana_dashboard: "1"` label, target dir annotation per category (Kubernetes, Infrastructure, Security, Networking, Storage, Loki Dashboards, Mimir Dashboards, Tempo Dashboards)

**k8s-monitoring destinations** (in `k8s-monitoring/overlays/workload-prd/helm-release-patch.yaml`):
```yaml
destinations:
  loki:   type: loki,       url: http://loki-gateway.loki...
  mimir:  type: prometheus, url: http://mimir-distributor.mimir...:8080/api/v1/push
  tempo:  type: otlp,       url: http://tempo-distributor.tempo...:4317, protocol: grpc
```

---

## LLM stack

**llama.cpp** runs in router mode — no `--model` flag, serves all GGUF files from the models PVC.

**Key files:**
- `kubernetes/apps/llama-cpp/base/deployment.yaml` — base Deployment (CPU, no GPU)
- `kubernetes/apps/llama-cpp/overlays/workload-prd/gpu-patch.yaml` — hardware-only patch (worker-1, privileged, `/dev/dri`, `/sys/bus/pci`)
- `kubernetes/apps/llama-cpp/base/models-preset-configmap.yaml` — `presets.ini` ConfigMap
- `kubernetes/apps/llama-cpp/base/model-download-*.yaml` — one Job per model

**Server args (base):**
```
--host 0.0.0.0 --port 8080
--models-dir /models
--models-preset /config/presets.ini
--models-max 1
```

**GPU patch adds:** `nodeSelector: worker-1`, `securityContext: privileged + runAsUser: 0`, `volumes: dev-dri + sys-bus-pci`

**presets.ini structure:**
```ini
[*]                      ; global defaults
n-gpu-layers = -1

[ModelFilenameWithoutDotGguf]
c = 262144               ; context size
flash-attn = auto
cache-type-k = q8_0
spec-type = draft-mtp    ; MTP speculative decoding (Qwen models only)
load-on-startup = true/false
```

**Models (filename = INI section name):**
| File | Size | Notes |
|------|------|-------|
| Qwen3.6-35B-A3B-UD-Q4_K_M.gguf | ~22 GB | Primary — MoE 3B active, ~25 tok/s, MTP, load-on-startup=false |
| Qwen3.6-27B-Q4_K_M.gguf | 17.1 GB | Dense 27B, MTP, ~6–8 tok/s with MTP |
| gemma-4-12b-it-Q4_K_M.gguf | 7.12 GB | Gemma 4 12B |
| gemma-4-26B-A4B-it-UD-Q4_K_M.gguf | 16.9 GB | Gemma 4 MoE 4B active |

**GPU hardware:** AMD Radeon 780M (iGPU, Vulkan backend, ~50–60 GB/s shared memory bandwidth)

**Adding a new model:**
1. Create `base/model-download-{name}.yaml` (copy existing job, change URL + filename)
2. Add to `base/kustomization.yaml` resources
3. Add `[ModelName]` section to `models-preset-configmap.yaml`

---

## Kustomization conventions

**Base/overlay structure:**
```
component/
├── base/
│   ├── kustomization.yaml      # lists all resources
│   ├── namespace.yaml
│   ├── helm-repository.yaml    # HelmRepository (namespace: flux-system)
│   ├── helm-release.yaml       # chart ref + interval/timeout/remediation
│   ├── network-policy.yaml     # CiliumNetworkPolicies
│   └── policy-exception.yaml   # Kyverno PolicyException (if needed)
└── overlays/workload-prd/
    ├── kustomization.yaml       # resources: ../../base + patches
    └── helm-release-patch.yaml  # strategic merge patch — values + valuesFrom
```

**helm-release-patch.yaml:** strategic merge patch targeting `kind: HelmRelease`. Sets `spec.values` and `spec.valuesFrom` (for secrets). Base has chart version + interval; overlay adds cluster-specific values.

**Kyverno PolicyException pattern:**
```yaml
apiVersion: policies.kyverno.io/v1beta1
kind: PolicyException
metadata:
  name: {component}
  namespace: {namespace}
spec:
  matchConditions:
    - name: exclude-{component}
      expression: "object.metadata.namespace == '{namespace}'"
  policyRefs:
    - kind: ValidatingPolicy
      name: restrict-seccomp-strict
```

**valuesFrom pattern** (for S3 credentials):
```yaml
valuesFrom:
  - kind: Secret
    name: {component}-s3-secret
    valuesKey: S3_ACCESS_KEY
    targetPath: {chart.path.to.access_key}
  - kind: Secret
    name: {component}-s3-secret
    valuesKey: S3_SECRET_KEY
    targetPath: {chart.path.to.secret_key}
```

---

## Key files quick reference

| File | What it controls |
|------|-----------------|
| `kubernetes/infrastructure/overlays/workload-prd/kustomization.yaml` | Ordered list of all infrastructure components |
| `kubernetes/infrastructure/gateway/overlays/workload-prd/gateway-patch.yaml` | All HTTPS listeners and hostnames |
| `kubernetes/infrastructure/grafana/overlays/workload-prd/helm-release-patch.yaml` | Grafana datasources + admin secret |
| `kubernetes/infrastructure/k8s-monitoring/overlays/workload-prd/helm-release-patch.yaml` | Alloy collector config, destinations |
| `kubernetes/infrastructure/mimir/overlays/workload-prd/helm-release-patch.yaml` | Mimir S3 config, retention, replicas |
| `kubernetes/infrastructure/loki/overlays/workload-prd/helm-release-patch.yaml` | Loki S3 config, schema |
| `kubernetes/infrastructure/tempo/overlays/workload-prd/helm-release-patch.yaml` | Tempo S3 config, metrics-generator |
| `kubernetes/infrastructure/vault/overlays/management-prd/helm-release-patch.yaml` | Vault storage, HA config |
| `kubernetes/apps/llama-cpp/base/models-preset-configmap.yaml` | Per-model inference parameters |
| `kubernetes/apps/llama-cpp/overlays/workload-prd/gpu-patch.yaml` | GPU hardware access (worker-1) |
| `docs/NETWORK.md` | VLAN layout, BGP, firewall rules |
| `docs/DEVICES.md` | All device IPs |
