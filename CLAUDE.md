# Homelab — Claude Context

This file gives Claude enough context to work in this repo without a full scan each session.

---

## Repository layout

```
Homelab/
├── kubernetes/
│   ├── clusters/          # Cluster bootstrap: FluxCD sync definitions + Terraform (CNI, Vault secrets, Cloudflare)
│   ├── namespaces/        # Every Namespace object in the cluster, centralized — base/ only, one file per component
│   ├── network-policies/  # Every CiliumNetworkPolicy/CiliumClusterwideNetworkPolicy, centralized
│   ├── core/               # Engines/CRDs only: cert-manager, external-secrets, Kyverno (no instances of their own CRDs)
│   ├── policies/           # Kyverno PolicyExceptions + mutating/generating ClusterPolicies, centralized
│   ├── secrets/            # ClusterSecretStore + every ExternalSecret, centralized
│   ├── platform/
│   │   ├── infra/          # Blocking platform prerequisites: gateway, storage, cloudnative-pg, kubevirt/cdi…
│   │   └── ops/             # Non-blocking day-2 tooling: trivy, cloudflared, vpa, yk-dns-manager…
│   ├── observability/      # Grafana LGTM stack: Loki, Mimir, Tempo, k8s-monitoring (Alloy), Grafana, Alertmanager
│   │   └── alerting-rules/ # PrometheusRules — own Kustomization, depends on observability being up
│   ├── llm/                # llama-cpp (Vulkan), llama-cpp-cuda (dormant), Open WebUI — wired in via apps, not their own layer
│   ├── apps/               # User-facing apps + forgejo + llama-cpp + open-webui — base/ + overlays/{cluster}/
│   └── vms/                # KubeVirt VMs (ubuntu-test)
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
- `llama-cpp-cuda` pins to `kubernetes.io/hostname: node-3` with a `nvidia` RuntimeClass (NVIDIA node, not listed in DEVICES.md). Currently **dormant/unwired** — see note below.

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
├── flux-system          → ./kubernetes/clusters/workload-prd/flux-system (self)
└── namespaces           → ./kubernetes/namespaces/overlays/workload-prd
    └── network-policies → ./kubernetes/network-policies/overlays/workload-prd     (dependsOn: namespaces)
        └── core         → ./kubernetes/core/overlays/workload-prd                 (dependsOn: namespaces, network-policies)
            ├── policies → ./kubernetes/policies/overlays/workload-prd             (dependsOn: core)
            └── secrets  → ./kubernetes/secrets/overlays/workload-prd              (dependsOn: core)
                └── platform-infra → ./kubernetes/platform/infra/overlays/workload-prd   (dependsOn: policies, secrets)
                    ├── platform-ops    → ./kubernetes/platform/ops/overlays/workload-prd     (dependsOn: platform-infra, wait: false)
                    ├── observability   → ./kubernetes/observability/overlays/workload-prd     (dependsOn: platform-infra)
                    │   └── alerting-rules → ./kubernetes/observability/alerting-rules/overlays/workload-prd  (dependsOn: observability, wait: false)
                    ├── apps            → ./kubernetes/apps/overlays/workload-prd              (dependsOn: policies, platform-infra, wait: false)
                    └── vm-ubuntu-test  → ./kubernetes/vms/ubuntu-test                         (dependsOn: platform-infra, wait: false)
```

Each layer's `overlays/workload-prd/kustomization.yaml` is the ordered list of its components — register new components there.

**Why `network-policies` and `secrets` are split out** (not just folded into `core`/`platform-infra`): a Kustomization that installs a CRD via HelmRelease can never also contain a raw manifest that's an *instance* of that CRD — `kustomize-controller` applies its whole build as one batch with zero visibility into `helm-controller`'s async CRD install, so on a cold reconcile it's a hard, non-self-healing race, not a soft one. `network-policies` is safe to run before `core` because Cilium's CRDs come from Terraform, not from anything Flux installs. `secrets` has to run after `core` because `ExternalSecret`/`ClusterSecretStore` are `external-secrets`' own CRDs. See **Kustomization conventions** below for the general rule.

`platform-infra`/`platform-ops` split the same way for a different reason: `platform-infra` holds only what `apps`/`observability`/etc. actually need to function (gateway, storage, cloudnative-pg, kubevirt/cdi); `platform-ops` holds day-2 tooling nothing downstream depends on (trivy, cloudflared, vpa…). A broken `platform-ops` component can't block anything else from reconciling.

Other Terraform under `kubernetes/clusters/workload-prd/terraform/`: `cni` (Cilium install), `cloudflare` (DNS zone), `vault` (writes app secrets into Vault KV — see Secrets).

---

## Components by layer

HelmRepositories live next to each component (`base/helm-repository.yaml`, namespace `flux-system`).

### namespaces
One `Namespace` manifest per live component across every layer below, flat in `kubernetes/namespaces/base/`, named `{layer}-{component}.yaml` (e.g. `apps-immich.yaml`, `platform-longhorn.yaml`). No per-component `namespace.yaml` exists anymore.

### network-policies
Every `CiliumNetworkPolicy`/`CiliumClusterwideNetworkPolicy` in the cluster, flat in `kubernetes/network-policies/base/`, same `{layer}-{component}.yaml` naming, plus a `cluster-wide/` subfolder for the genuinely cluster-scoped rules (`allow-dns`, `allow-kube-system`, `allow-health-probes`, `allow-flux-system`, `allow-alloy-metrics-scraping`, `allow-gateway-frontend`). `cloudnative-pg`'s rule is a single label-selector policy matching any `cnpg.io/cluster` endpoint — adding a new Postgres-backed app never requires touching this file.

### core
| Component | Chart | Version | Purpose |
|-----------|-------|---------|---------|
| gateway-api-crds | — | — | Gateway API CRDs |
| prometheus-operator-crds | prometheus-operator-crds | 30.0.1 | ServiceMonitor/PodMonitor CRDs |
| cert-manager | cert-manager | 1.21.0 | TLS via Let's Encrypt + Cloudflare DNS-01 (chart + engine only — its `ExternalSecret` lives in `secrets/`) |
| external-secrets | external-secrets | 2.7.0 | Vault → K8s Secrets (chart + engine only — `ClusterSecretStore` lives in `secrets/`) |
| kyverno | kyverno | 3.8.2 | Policy engine (+ kyverno-policies baseline chart) |

### policies
| Component | Kind | Purpose |
|-----------|------|---------|
| `policies/base/exceptions/` | `PolicyException` | One file per component that needs a policy exemption, `{layer}-{component}.yaml` |
| `policies/base/kyverno/` | `ClusterPolicy` / `MutatingPolicy` | `mutate-goldilocks-label`, `mutate-beyla-instrument-label`, `generate-same-namespace` (auto-generates a default same-namespace `CiliumNetworkPolicy` for every new Namespace) |

### secrets
| Component | Kind | Purpose |
|-----------|------|---------|
| `secrets/base/cluster-secret-store.yaml` | `ClusterSecretStore` | `default-store` — Vault Kubernetes-auth connection |
| `secrets/base/*.yaml` | `ExternalSecret` | One file per component consuming a Vault-sourced secret (cert-manager, democratic-csi-nfs/iscsi, cloudflared, yk-dns-manager, loki, mimir, tempo, grafana, alertmanager, immich, opencloud, forgejo ×2, vm-ubuntu-test) |

### platform-infra
| Component | Chart/Type | Version | Purpose |
|-----------|-----------|---------|---------|
| gateway | manifests | — | Cilium `Gateway` `internal` (kube-system) + all HTTPS listeners |
| cluster-issuer | manifests | — | `letsencrypt-dns` ClusterIssuer (Cloudflare) |
| bgp | manifests | — | Cilium BGP peer config + LB IP pool |
| longhorn | longhorn | 1.12.0 | HA block storage (`longhorn` StorageClass) |
| democratic-csi-nfs | democratic-csi | 0.15.1 | `truenas-nfs` StorageClass (RWX, TrueNAS) |
| democratic-csi-iscsi | democratic-csi | 0.15.1 | `truenas-iscsi` StorageClass (RWO block, TrueNAS) |
| cloudnative-pg | cloudnative-pg | 0.29.0 | CNPG operator (`cnpg-system`) — per-app Postgres clusters |
| kubevirt / cdi | operator manifests | — | VMs on k8s + disk image import |
| metrics-server | metrics-server | 3.x | HPA/VPA metrics |

### platform-ops
| Component | Chart/Type | Version | Purpose |
|-----------|-----------|---------|---------|
| gpu-tools | DaemonSet | — | GPU node debug/tools pod (ubuntu) |
| hubble | httproute | — | Hubble UI exposure |
| cilium-observability | manifests | — | Cilium Envoy stats + PodMonitor |
| flux-system | httproute | — | flux-operator UI at fluxcd.* |
| kyverno-reporter | policy-reporter | 3.8.1 | Policy reporting UI |
| vpa | vpa + goldilocks | — | Vertical pod autoscaler + recommendations |
| yk-dns-manager | custom (OCIRepository) | — | DNS records on OPNsense |
| cloudflared | deployment | — | Cloudflare Tunnel agent |
| trivy | trivy-operator | 0.34.0 | Vulnerability scanning |
| trivy-converter | trivy-operator-polr-adapter | 0.11.5 | Trivy reports → PolicyReports |
| clean-pods | CronJob | — | Cluster-wide cleanup of Failed pods + stale completed pods |

Present in tree but **not wired into any overlay** (do not assume deployed): `core/local-path-provisioner`, `platform/harbor`, `platform/yk-talos-manager`, `llm/llama-cpp-cuda`.

### observability
| Component | Chart | Version | Notes |
|-----------|-------|---------|-------|
| loki | loki | 7.0.0 | S3 backend |
| mimir | mimir-distributed | 6.1.0 | S3 backend, ruler enabled |
| tempo | tempo-distributed | 2.23.4 | S3 backend |
| k8s-monitoring | k8s-monitoring | 4.2.1 | Alloy collectors (metrics/logs/traces) |
| grafana | grafana | 10.5.15 | Dashboards; explicit HelmRelease `dependsOn`: loki, mimir, tempo, alertmanager |
| alertmanager | alertmanager | 1.41.0 | Slack routing via `ExternalSecret` (`secrets/base/observability-alertmanager.yaml`) |

### alerting-rules
`PrometheusRule` objects only, own layer (`dependsOn: observability` — a rule is inert until Mimir's ruler + Alertmanager exist, so it has to come after the stack it alerts on). Currently just `node-health` (`NodeNotReady`). This is where every future alert rule in the cluster lands.

### apps (workload-prd)
| App | Namespace | Purpose |
|-----|-----------|---------|
| httpbin | httpbin | httpbingo echo service |
| whoami | whoami | Identity echo service |
| yk-portfolio | yk-portfolio | Personal portfolio (`portfolio.` hostname) |
| yk-update-checker | yk-update-checker | Dependency update dashboard (`yk-updates.` hostname) |
| homepage | homepage | Dashboard landing page |
| immich | immich | Photos — server + ML (ROCm on 780M) + Valkey + CNPG `pg-cluster-immich` (VectorChord image) |
| opencloud | opencloud | File cloud (OpenCloud/oCIS fork), single pod, `truenas-iscsi` PVC |
| forgejo | forgejo | Git server, `git.` hostname + SSH (port 22 via TCPRoute), CNPG `pg-cluster-forgejo`, `truenas-iscsi` PVC for repo data. Physically lives at `kubernetes/platform/forgejo/` still — only its Flux wiring moved to `apps` |
| llama-cpp | llm | `ghcr.io/ggml-org/llama.cpp:server-vulkan-*` router mode, R9700 via `ai-node: oculink`, models PVC `longhorn` 200Gi RWX. Plain Deployment, not a HelmRelease |
| open-webui | open-webui | chart 15.2.0, `chat.` hostname, talks to llama-cpp `:8080` |

Note: the gateway patch still carries a listener for `uptime-kuma`, which has been removed as a cluster app.

Note: `forgejo` (`git.yuriykovalchuk.dev`) and the TrueNAS Docker `forgejo` app (`forgejo.yuriykovalchuk.dev`) both currently exist — the k8s one is a fresh instance with no data migrated yet. Different hostnames, so no DNS conflict; decide later whether/how to consolidate.

---

## Networking conventions

**Domain:** `yuriykovalchuk.dev` (Cloudflare DNS, cert-manager DNS-01; internal records via yk-dns-manager on OPNsense)

**Gateway pattern:**
- GatewayClass `cilium`; Gateway `internal` in `kube-system`, address `10.0.4.50`
- One HTTPS listener per hostname, named `https-{app}` — must match HTTPRoute `sectionName`
- Listener cert secret `{app}-gw-tls`; `allowedRoutes` restricted to the app namespace by selector
- All listeners: `kubernetes/platform/infra/gateway/overlays/workload-prd/gateway-patch.yaml`

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
- Centralized in `kubernetes/network-policies/base/{layer}-{component}.yaml` — **not** co-located with the component anymore
- DNS egress to CoreDNS is allowed cluster-wide (`network-policies/base/cluster-wide/allow-dns.yaml`) — don't re-add it
- Split `kube-apiserver` and `remote-node`/`host` into separate egress rules, each allowing **both 6443 and 443** (in-cluster pods reach the API via `10.96.0.1:443`)
- Common entities: `kube-apiserver`, `cluster`, `ingress`, `world`, `remote-node`, `host`
- Ingress from the gateway = `fromEntities: [cluster, ingress]`
- CNPG clusters need ingress 8000 from the operator (`cnpg-system`) — already covered generically by `network-policies/base/platform-cloudnative-pg.yaml`'s label-selector rule; **no per-app edit needed**

---

## Secrets management

**Flow:** Terraform → Vault KV → ExternalSecret → K8s Secret

- **Vault runs on TrueNAS** (`hashicorp/vault` Docker app, VLAN 3), reachable at `https://vault.yuriykovalchuk.dev`. It is **not** a Kubernetes workload anywhere — `vault` CLI commands run via `docker exec` on TrueNAS, or remotely with `VAULT_ADDR` set explicitly (defaults to `https://127.0.0.1:8200`, which is wrong almost everywhere; the container's internal listener is plain HTTP, external access is HTTPS via the TrueNAS reverse proxy).
- KV v2 mount `kubernetes`; ESO `ClusterSecretStore` `default-store` (Kubernetes auth, SA `external-secrets`), defined in `kubernetes/secrets/base/cluster-secret-store.yaml`
- Secret *values* are supplied as `TF_VAR_*` env vars (untracked `.env`, sourced by devbox) and written to Vault by `kubernetes/clusters/workload-prd/terraform/vault/` — one `.tf` file per app
- Apps consume them via `ExternalSecret`, centralized in `kubernetes/secrets/base/{layer}-{component}.yaml` (**not** co-located with the component anymore)
- For Helm values, use `valuesFrom` on the HelmRelease (see loki/tempo overlays) with `targetPath` into the chart values

**Vault Kubernetes-auth bootstrap** (the `token_reviewer_jwt` Vault needs to validate ESO's ServiceAccount tokens) is a manual, one-time step documented in `kubernetes/core/external-secrets/overlays/workload-prd/README.md`. It has to be redone any time the `external-secrets` namespace/ServiceAccount gets recreated from scratch (the old reviewer token goes stale, Vault starts rejecting logins with `403 permission denied`).

**Manual bootstrap steps (not in Git/Terraform):** Vault init/unseal on TrueNAS; `.env` with `TF_VAR_*` values (incl. `TF_VAR_s3_*` for the Terraform S3 state backend); the Vault Kubernetes-auth config above.

---

## Observability stack

**Architecture:** Alloy collectors → Mimir (metrics) + Loki (logs) + Tempo (traces) → Grafana, Mimir ruler → Alertmanager (Slack)

**Object storage:** RustFS (S3-compatible, TrueNAS app) at `s3.yuriykovalchuk.dev:443`; credentials from Vault via `ExternalSecret` (`kubernetes/secrets/base/`)

| Component | Service URL (in-cluster) | Port |
|-----------|--------------------------|------|
| Mimir query | `mimir-query-frontend.mimir.svc.cluster.local` | 8080 |
| Mimir ingest | `mimir-distributor.mimir.svc.cluster.local` | 8080 |
| Loki | `loki-gateway.loki.svc.cluster.local` | 80 |
| Tempo query | `tempo-query-frontend.tempo.svc.cluster.local` | 3100 |
| Tempo ingest | `tempo-distributor.tempo.svc.cluster.local` | 4317 (gRPC) / 4318 (HTTP) |
| Alertmanager | `alertmanager.alertmanager.svc.cluster.local` | 9093 |

**Grafana datasources** (`observability/grafana/overlays/workload-prd/helm-release-patch.yaml`): Mimir `mimir-metrics` (default), Loki `loki-datasource` (derivedFields → Tempo), Tempo `tempo-datasource` (linked to Mimir + Loki).

**Dashboards:** ConfigMap + sidecar, label `grafana_dashboard: "1"`, target folder via annotation.

**Alert rules:** `PrometheusRule` objects live in `kubernetes/observability/alerting-rules/base/`, applied by the standalone `alerting-rules` Kustomization (see FluxCD GitOps structure above).

---

## LLM stack

llama-cpp and open-webui are applied via the **`apps`** Kustomization (not a standalone `llm` layer — folded in once namespace/policy bootstrapping was centralized and the special-case pre-staging it existed for became unnecessary). Their files still physically live under `kubernetes/llm/`.

**llama.cpp** runs in router mode — no `--model` flag; serves all GGUF files on the models PVC (`--models-dir /models --models-preset /config/presets.ini --models-max 1`).

**Key files:**
- `kubernetes/llm/llama-cpp/base/deployment.yaml` — base Deployment (no GPU, image: `server-vulkan` floating tag)
- `kubernetes/llm/llama-cpp/overlays/workload-prd/gpu-patch.yaml` — hardware patch (`ai-node: oculink`, toleration, privileged, `/dev/dri`, `/sys/bus/pci`)
- `kubernetes/llm/llama-cpp/base/models-preset-configmap.yaml` — `presets.ini` (one `[section]` per model filename, global `[*]` defaults, `n-gpu-layers = -1`)
- `kubernetes/llm/llama-cpp/base/model-downloader-chart/values.yaml` — model URL list; HelmRelease generates one Job per entry (supports resume via `wget -c`)

**Models** (section name = filename without `.gguf`; all `load-on-startup = false`):
Qwen3.6-35B-A3B-UD-Q4_K_M · Qwen3.6-27B-UD-Q6_K_XL · Qwen3.6-27B-Q4_K_M (all with built-in MTP speculative decoding, `spec-type = draft-mtp`) · gemma-4-12b-it-Q4_K_M · gemma-4-12B-it-qat-UD-Q4_K_XL (MTP via separate draft file) · Bonsai-8B
(gemma-4-26B-A4B-it-UD-Q4_K_M is in values.yaml as a commented-out entry)

**Adding a new model:** add a `- name: <slug>` entry with `urls:` to `model-downloader-chart/values.yaml`, then add a `[ModelName]` section to the presets ConfigMap.

---

## Kustomization conventions

**Base/overlay structure** — component directories no longer carry `namespace.yaml`, `network-policy.yaml`, `external-secret.yaml`, or `policy-exception.yaml`. Those four are centralized (see Components by layer above); a component's own `base/` is just its workload:
```
component/
├── base/
│   ├── kustomization.yaml      # lists all resources
│   ├── helm-repository.yaml    # HelmRepository (namespace: flux-system)
│   └── helm-release.yaml       # chart ref + interval/timeout/remediation
└── overlays/workload-prd/
    ├── kustomization.yaml       # resources: ../../base + patches
    ├── http-route.yaml          # if exposed via gateway
    └── helm-release-patch.yaml  # strategic merge patch — values + valuesFrom
```

**The rule that drives the namespaces/network-policies/policies/secrets split**: a Kustomization that installs a CRD via HelmRelease must never also contain a raw manifest that's an instance of that CRD. `kustomize-controller` applies its whole build as one atomic batch with no visibility into `helm-controller`'s async chart install — mixing the two is a hard, non-self-healing race on any cold reconcile (verified the hard way: it's what caused a full core-namespace outage). The instance's Kustomization needs an explicit `dependsOn` on the installer's Kustomization instead. Exception: a CRD that's a *raw manifest itself* (not Helm-installed) can safely share a Kustomization with its instances — `kustomize-controller` does correctly order CRDs before CRs within one batch; it just can't see through a HelmRelease to what that chart will install.

**Renaming or deleting a Kustomization is destructive by default.** Its finalizer garbage-collects everything it manages when the CR itself goes away — including any object that's already been re-adopted by a differently-named Kustomization if that adoption hasn't landed yet. Any git change that shrinks a Kustomization's resource set, or renames/retires one, needs `spec.prune: false` on the affected Kustomization(s) *before* the change merges (patch it live first, then merge), not after.

**Kyverno PolicyException pattern** (namespace-scoped, in `kubernetes/policies/base/exceptions/{layer}-{component}.yaml`; list only the ValidatingPolicies actually violated — privileged/hostPath workloads like immich and llm need the full baseline list, root-only workloads just `require-run-as-nonroot`, `require-run-as-non-root-user`, `disallow-privilege-escalation`, `restrict-seccomp-strict`):
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
| `kubernetes/namespaces/base/kustomization.yaml` | Every Namespace in the cluster |
| `kubernetes/network-policies/base/kustomization.yaml` | Every CiliumNetworkPolicy/CiliumClusterwideNetworkPolicy |
| `kubernetes/policies/base/kustomization.yaml` | Every PolicyException + Kyverno mutator/generator |
| `kubernetes/secrets/base/kustomization.yaml` | Every ExternalSecret + the ClusterSecretStore |
| `kubernetes/{core,platform/infra,platform/ops,observability,apps}/overlays/workload-prd/kustomization.yaml` | Component list per layer |
| `kubernetes/platform/infra/gateway/overlays/workload-prd/gateway-patch.yaml` | All HTTPS listeners and hostnames |
| `kubernetes/secrets/base/cluster-secret-store.yaml` | Vault connection for ESO |
| `kubernetes/core/external-secrets/overlays/workload-prd/README.md` | Vault Kubernetes-auth bootstrap procedure |
| `kubernetes/clusters/workload-prd/terraform/vault/` | App secrets written into Vault |
| `kubernetes/observability/k8s-monitoring/overlays/workload-prd/helm-release-patch.yaml` | Alloy collector config, destinations |
| `kubernetes/observability/alerting-rules/base/` | Every PrometheusRule in the cluster |
| `kubernetes/llm/llama-cpp/base/models-preset-configmap.yaml` | Per-model inference parameters |
| `kubernetes/apps/immich/overlays/workload-prd/gpu-patch-*.yaml` | Immich GPU access (780M, ROCm/VAAPI, `HIP_VISIBLE_DEVICES`) |
| `proxmox-nodes/terraform/_modules/truenas-apps/` | Docker apps on TrueNAS (Vault, Zot, RustFS, Forgejo, Dockhand, Traefik) |
| `proxmox-nodes/terraform/_modules/truenas-setup/` | TrueNAS datasets (incl. democratic-csi parents) |
| `docs/NETWORK.md` | VLAN layout, BGP, firewall rules |
| `docs/DEVICES.md` | All device IPs |
