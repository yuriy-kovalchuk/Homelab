# Homelab — Claude Context

This file gives Claude enough context to work in this repo without a full scan each session.

---

## Repository layout

```
Homelab/
├── kubernetes/
│   ├── clusters/          # Cluster bootstrap: FluxCD sync definitions + Terraform (CNI, Vault secrets, Cloudflare)
│   ├── core/              # CRDs + foundations: cert-manager, external-secrets, Kyverno
│   ├── platform/          # Cluster platform: Cilium (BGP/Gateway/Hubble), storage, KubeVirt, policies, operators
│   ├── observability/     # Grafana LGTM stack: Loki, Mimir, Tempo, k8s-monitoring (Alloy), Grafana
│   ├── llm/               # LLM inference: llama-cpp (Vulkan), llama-cpp-cuda, Open WebUI
│   ├── apps/              # User-facing apps — base/ + overlays/{cluster}/
│   └── vms/               # KubeVirt VMs (ubuntu-test)
├── proxmox-nodes/
│   ├── terraform/         # Proxmox VMs (OPNsense gateway, storage node), TrueNAS datasets + apps
│   └── ansible/           # OPNsense and node configuration playbooks
├── docs/
│   ├── NETWORK.md          # VLAN layout, firewall rules, BGP
│   ├── DEVICES.md          # All static IPs and hostnames
│   └── L7.md               # L7/proxy notes
└── devbox.json             # Pinned tooling (kubectl, talosctl, flux, terraform…); .env sourced on shell init
```

---

## Cluster topology

One bare-metal **Talos Linux** cluster (`workload-prd`) managed by FluxCD.

| Node | IP | Role |
|------|----|------|
| controlplane-1 | 10.0.4.3 | control-plane |
| controlplane-2 | 10.0.4.5 | control-plane |
| controlplane-3 | 10.0.4.6 | control-plane (offline, coming back) |
| worker-1 | 10.0.4.4 | worker + GPUs (see below) |

- VLAN 4 — `10.0.4.0/24`, gateway `10.0.4.1` (OPNsense)
- BGP: Cilium localASN **65002** ↔ OPNsense peerASN **65551** at `10.0.4.1`; LB pool `10.0.4.50–10.0.4.99` (`internal` Gateway is pinned to `10.0.4.50`)

### GPU nodes
- The GPU node is labeled **`ai-node: oculink`** and tainted `workload=gpu:NoSchedule` — GPU workloads need both the nodeSelector and the toleration (see `kubernetes/llm/llama-cpp/overlays/workload-prd/gpu-patch.yaml`).
- It has **two AMD GPUs**: an oculink-attached **AMD AI Pro R9700** (used by llama-cpp via Vulkan) and the **Radeon 780M iGPU** (reserved for Immich ML/transcoding via ROCm/VAAPI). Both appear under `/dev/dri` — pods must pin a device (`HIP_VISIBLE_DEVICES` for ROCm).
- `llama-cpp-cuda` pins to `kubernetes.io/hostname: node-3` with a `nvidia` RuntimeClass (NVIDIA node, not listed in DEVICES.md).

### VLAN map
| VLAN | Subnet | Purpose |
|------|--------|---------|
| 2 | 10.0.2.0/24 | Deprecated — pending removal |
| 3 | 10.0.3.0/24 | Storage — TrueNAS `10.0.3.3` (NFS/SMB + apps: Vault, Zot, RustFS, Forgejo, Dockhand, Traefik) |
| 4 | 10.0.4.0/24 | Workload cluster |
| 5 | 10.0.5.0/24 | Physical workload devices |
| 6 | 10.0.6.0/24 | Private wireless |
| 7 | 10.0.7.0/24 | Guest wireless |

---

## FluxCD GitOps structure

Flux is installed by Terraform (`kubernetes/clusters/workload-prd/terraform/fluxcd`) via **flux-operator** + a `FluxInstance`. Sync definitions live in `kubernetes/clusters/workload-prd/flux-system/` — one file per Kustomization:

```
GitRepository: homelab (branch: main)
│
├── flux-system      → ./kubernetes/clusters/workload-prd/flux-system (self)
└── core             → ./kubernetes/core/overlays/workload-prd
    └── platform     → ./kubernetes/platform/overlays/workload-prd   (dependsOn: core)
        ├── apps           → ./kubernetes/apps/overlays/workload-prd          (wait: true, timeout 5m)
        ├── observability  → ./kubernetes/observability/overlays/workload-prd
        ├── llm-policies   → ./kubernetes/llm/policies/workload-prd
        │   └── llm        → ./kubernetes/llm/overlays/workload-prd           (wait: false)
        └── vm-ubuntu-test → ./kubernetes/vms/ubuntu-test
```

Each layer's `overlays/workload-prd/kustomization.yaml` is the ordered list of its components — register new components there.

Other Terraform under `kubernetes/clusters/workload-prd/terraform/`: `cni` (Cilium install), `cloudflare` (DNS zone), `vault` (writes app secrets into Vault KV — see Secrets).

---

## Components by layer

HelmRepositories live next to each component (`base/helm-repository.yaml`, namespace `flux-system`).

### core
| Component | Chart | Version | Purpose |
|-----------|-------|---------|---------|
| gateway-api-crds | — | — | Gateway API CRDs |
| prometheus-operator-crds | prometheus-operator-crds | 30.0.1 | ServiceMonitor/PodMonitor CRDs |
| cert-manager | cert-manager | 1.21.0 | TLS via Let's Encrypt + Cloudflare DNS-01 |
| external-secrets | external-secrets | 2.7.0 | Vault → K8s Secrets |
| kyverno | kyverno | 3.8.2 | Policy engine (+ kyverno-policies) |

### platform
| Component | Chart/Type | Version | Purpose |
|-----------|-----------|---------|---------|
| cilium-policies | manifests | — | Cluster-wide CiliumNetworkPolicies (DNS allowed cluster-wide, alloy scraping, flux egress, gateway frontend) |
| gpu-tools | DaemonSet | — | GPU node debug/tools pod (ubuntu) |
| kyverno-config | manifests | — | Mutations (goldilocks/beyla labels) + shared PolicyExceptions |
| external-secrets-config | manifests | — | ClusterSecretStore `default-store` |
| gateway | manifests | — | Cilium `Gateway` `internal` (kube-system) + all HTTPS listeners |
| cluster-issuer | manifests | — | `letsencrypt-dns` ClusterIssuer (Cloudflare) |
| bgp | manifests | — | Cilium BGP peer config + LB IP pool |
| hubble | httproute | — | Hubble UI exposure |
| cilium-observability | manifests | — | Cilium Envoy stats + PodMonitor |
| longhorn | longhorn | 1.12.0 | HA block storage (`longhorn` StorageClass) |
| democratic-csi-nfs | democratic-csi | 0.15.1 | `truenas-nfs` StorageClass (RWX, TrueNAS) |
| democratic-csi-iscsi | democratic-csi | 0.15.1 | `truenas-iscsi` StorageClass (RWO block, TrueNAS) |
| kubevirt / cdi | operator manifests | — | VMs on k8s + disk image import |
| metrics-server | metrics-server | 3.x | HPA/VPA metrics |
| flux-system | httproute | — | flux-operator UI at fluxcd.* |
| kyverno-reporter | policy-reporter | 3.8.1 | Policy reporting UI |
| vpa | vpa + goldilocks | — | Vertical pod autoscaler + recommendations |
| yk-dns-manager | custom (OCIRepository) | — | DNS records on OPNsense |
| trivy | trivy-operator | 0.34.0 | Vulnerability scanning |
| trivy-converter | trivy-operator-polr-adapter | 0.11.5 | Trivy reports → PolicyReports |
| forgejo | forgejo-helm (OCI) | 17.1.3 | Git server, `git.` hostname + SSH (port 22 via TCPRoute), CNPG `pg-cluster-forgejo`, `truenas-iscsi` PVC for repo data |

Present in tree but **not wired into any overlay** (do not assume deployed): `core/local-path-provisioner`, `platform/harbor`, `platform/yk-talos-manager`.

### observability
| Component | Chart | Version | Notes |
|-----------|-------|---------|-------|
| loki | loki | 7.0.0 | S3 backend |
| mimir | mimir-distributed | 6.1.0 | S3 backend |
| tempo | tempo-distributed | 2.23.4 | S3 backend |
| k8s-monitoring | k8s-monitoring | 4.2.1 | Alloy collectors (metrics/logs/traces) |
| grafana | grafana | 10.5.15 | Dashboards |

### llm
| Component | Notes |
|-----------|-------|
| llama-cpp | `ghcr.io/ggml-org/llama.cpp:server-vulkan-*` router mode, R9700 via `ai-node: oculink`, models PVC `longhorn` 200Gi RWX |
| llama-cpp-cuda | `server-cuda` image, `node-3`, `nvidia` RuntimeClass, `cuda.` hostname |
| open-webui | chart 15.2.0, `chat.` hostname, talks to llama-cpp `:8080` |

PolicyExceptions for llm live in `kubernetes/llm/llama-cpp/base/policy-exception.yaml`, applied by the separate `llm-policies` Kustomization (so the LLM stack can be pruned without losing policy state).

### apps (workload-prd)
| App | Namespace | Purpose |
|-----|-----------|---------|
| clean-pods | clean-pods | CronJob — cleans failed pods + completed jobs |
| httpbin | httpbin | httpbingo echo service |
| whoami | whoami | Identity echo service |
| yk-portfolio | yk-portfolio | Personal portfolio (`portfolio.` hostname) |
| yk-update-checker | yk-update-checker | Dependency update dashboard (`yk-updates.` hostname) |
| cloudflared | cloudflared | Cloudflare Tunnel agent |
| homepage | homepage | Dashboard landing page |
| cloudnative-pg | cnpg-system | CNPG operator (chart 0.29.0) — per-app Postgres clusters |
| immich | immich | Photos — server + ML (ROCm on 780M) + Valkey + CNPG `pg-cluster-immich` (VectorChord image) |
| opencloud | opencloud | File cloud (OpenCloud/oCIS fork), single pod, `truenas-iscsi` PVC |

Note: the gateway patch still carries a listener for `uptime-kuma`, which has been removed as a cluster app.

Note: `forgejo` (platform layer, `git.yuriykovalchuk.dev`) and the TrueNAS Docker `forgejo` app (`forgejo.yuriykovalchuk.dev`) both currently exist — the k8s one is a fresh instance with no data migrated yet. Different hostnames, so no DNS conflict; decide later whether/how to consolidate.

---

## Networking conventions

**Domain:** `yuriykovalchuk.dev` (Cloudflare DNS, cert-manager DNS-01; internal records via yk-dns-manager on OPNsense)

**Gateway pattern:**
- GatewayClass `cilium`; Gateway `internal` in `kube-system`, address `10.0.4.50`
- One HTTPS listener per hostname, named `https-{app}` — must match HTTPRoute `sectionName`
- Listener cert secret `{app}-gw-tls`; `allowedRoutes` restricted to the app namespace by selector
- All listeners: `kubernetes/platform/gateway/overlays/workload-prd/gateway-patch.yaml`

**HTTPRoute pattern** (file `http-route.yaml` in the app's overlay):
```yaml
parentRefs:
  - name: internal
    namespace: kube-system
    sectionName: https-{app-name}   # must match gateway listener name
hostnames:
  - {app-name}.yuriykovalchuk.dev
```

**CiliumNetworkPolicy conventions:**
- Namespace-scoped, in `base/network-policy.yaml` of each component
- DNS egress to CoreDNS is allowed cluster-wide (`cilium-policies`) — don't re-add it
- Split `kube-apiserver` and `remote-node`/`host` into separate egress rules, each allowing **both 6443 and 443** (in-cluster pods reach the API via `10.96.0.1:443`)
- Common entities: `kube-apiserver`, `cluster`, `ingress`, `world`, `remote-node`, `host`
- Ingress from the gateway = `fromEntities: [cluster, ingress]`
- CNPG clusters additionally need: ingress 8000 from the operator (`cnpg-system`), and a matching `allow-egress-to-{app}` policy appended in `kubernetes/apps/cloudnative-pg/base/network-policy.yaml`

---

## Secrets management

**Flow:** Terraform → Vault KV → ExternalSecret → K8s Secret

- **Vault runs on TrueNAS** (`hashicorp/vault` app, VLAN 3), reachable at `https://vault.yuriykovalchuk.dev`
- KV v2 mount `kubernetes`; ESO `ClusterSecretStore` `default-store` (Kubernetes auth, SA `external-secrets`)
- Secret *values* are supplied as `TF_VAR_*` env vars (untracked `.env`, sourced by devbox) and written to Vault by `kubernetes/clusters/workload-prd/terraform/vault/` — one `.tf` file per app
- Apps consume them via `ExternalSecret` in their base (e.g. `cert-manager/cloudflare`, `cloudflared/tunnel`, `immich/db`, `opencloud/admin`)
- For Helm values, use `valuesFrom` on the HelmRelease (see loki/tempo overlays) with `targetPath` into the chart values

**Manual bootstrap steps (not in Git/Terraform):** Vault init/unseal on TrueNAS; `.env` with `TF_VAR_*` values (incl. `TF_VAR_s3_*` for the Terraform S3 state backend).

---

## Observability stack

**Architecture:** Alloy collectors → Mimir (metrics) + Loki (logs) + Tempo (traces) → Grafana

**Object storage:** RustFS (S3-compatible, TrueNAS app) at `s3.yuriykovalchuk.dev:443`; credentials from Vault via ExternalSecret

| Component | Service URL (in-cluster) | Port |
|-----------|--------------------------|------|
| Mimir query | `mimir-query-frontend.mimir.svc.cluster.local` | 8080 |
| Mimir ingest | `mimir-distributor.mimir.svc.cluster.local` | 8080 |
| Loki | `loki-gateway.loki.svc.cluster.local` | 80 |
| Tempo query | `tempo-query-frontend.tempo.svc.cluster.local` | 3100 |
| Tempo ingest | `tempo-distributor.tempo.svc.cluster.local` | 4317 (gRPC) / 4318 (HTTP) |

**Grafana datasources** (`observability/grafana/overlays/workload-prd/helm-release-patch.yaml`): Mimir `mimir-metrics` (default), Loki `loki-datasource` (derivedFields → Tempo), Tempo `tempo-datasource` (linked to Mimir + Loki).

**Dashboards:** ConfigMap + sidecar, label `grafana_dashboard: "1"`, target folder via annotation.

---

## LLM stack

**llama.cpp** runs in router mode — no `--model` flag; serves all GGUF files on the models PVC (`--models-dir /models --models-preset /config/presets.ini --models-max 1`).

**Key files:**
- `kubernetes/llm/llama-cpp/base/deployment.yaml` — base Deployment (no GPU)
- `kubernetes/llm/llama-cpp/overlays/workload-prd/gpu-patch.yaml` — hardware patch (`ai-node: oculink`, toleration, privileged, `/dev/dri`, `/sys/bus/pci`)
- `kubernetes/llm/llama-cpp/base/models-preset-configmap.yaml` — `presets.ini` (one `[section]` per model filename, global `[*]` defaults, `n-gpu-layers = -1`)
- `kubernetes/llm/llama-cpp/base/model-download-*.yaml` — one download Job per model

**Models** (section name = filename without `.gguf`; all `load-on-startup = false`):
Qwen3.6-35B-A3B-UD-Q4_K_M · Qwen3.6-27B-UD-Q6_K_XL · Qwen3.6-27B-Q4_K_M (all with built-in MTP speculative decoding, `spec-type = draft-mtp`) · gemma-4-12b-it-Q4_K_M · gemma-4-12B-it-qat-UD-Q4_K_XL (MTP via separate draft file) · gemma-4-26B-A4B-it-UD-Q4_K_M · Bonsai-8B

**Adding a new model:** copy a `model-download-*.yaml` Job (change URL + filename), add it to `base/kustomization.yaml`, add a `[ModelName]` section to the presets ConfigMap.

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
│   ├── external-secret.yaml    # if secrets needed
│   └── policy-exception.yaml   # Kyverno PolicyException (if needed)
└── overlays/workload-prd/
    ├── kustomization.yaml       # resources: ../../base + patches
    ├── http-route.yaml          # if exposed via gateway
    └── helm-release-patch.yaml  # strategic merge patch — values + valuesFrom
```

**Kyverno PolicyException pattern** (namespace-scoped; list only the ValidatingPolicies actually violated — privileged/hostPath workloads like immich and llm need the full baseline list, root-only workloads just `require-run-as-nonroot`, `require-run-as-non-root-user`, `disallow-privilege-escalation`, `restrict-seccomp-strict`):
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

---

## Key files quick reference

| File | What it controls |
|------|-----------------|
| `kubernetes/clusters/workload-prd/flux-system/` | All Flux Kustomizations + dependency order |
| `kubernetes/{core,platform,observability,llm,apps}/overlays/workload-prd/kustomization.yaml` | Component list per layer |
| `kubernetes/platform/gateway/overlays/workload-prd/gateway-patch.yaml` | All HTTPS listeners and hostnames |
| `kubernetes/platform/external-secrets-config/base/cluster-secret-store.yaml` | Vault connection for ESO |
| `kubernetes/clusters/workload-prd/terraform/vault/` | App secrets written into Vault |
| `kubernetes/observability/k8s-monitoring/overlays/workload-prd/helm-release-patch.yaml` | Alloy collector config, destinations |
| `kubernetes/llm/llama-cpp/base/models-preset-configmap.yaml` | Per-model inference parameters |
| `kubernetes/apps/immich/overlays/workload-prd/gpu-patch-*.yaml` | Immich GPU access (780M, ROCm/VAAPI, `HIP_VISIBLE_DEVICES`) |
| `proxmox-nodes/terraform/_modules/truenas-apps/` | Docker apps on TrueNAS (Vault, Zot, RustFS, Forgejo, Dockhand, Traefik) |
| `proxmox-nodes/terraform/_modules/truenas-setup/` | TrueNAS datasets (incl. democratic-csi parents) |
| `docs/NETWORK.md` | VLAN layout, BGP, firewall rules |
| `docs/DEVICES.md` | All device IPs |
