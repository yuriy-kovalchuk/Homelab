# Homelab

GitOps monorepo for my homelab: a bare-metal [Talos Linux](https://www.talos.dev) Kubernetes cluster reconciled by [FluxCD](https://fluxcd.io), plus the Proxmox/OPNsense layer underneath it, managed with Terraform and Ansible.

## Repository layout

```
Homelab/
├── kubernetes/
│   ├── clusters/        # Cluster bootstrap: Talos/CNI Terraform + FluxCD sync definitions
│   ├── core/            # CRDs and foundations: cert-manager, external-secrets, Kyverno
│   ├── platform/        # Cluster platform: Cilium (BGP, Gateway, Hubble), storage, KubeVirt, policies
│   ├── observability/   # Grafana LGTM stack: Loki, Mimir, Tempo, Alloy collectors
│   ├── llm/             # LLM inference: llama.cpp (Vulkan + CUDA) and Open WebUI
│   ├── apps/            # User-facing apps: Immich, OpenCloud, Homepage, Forgejo-adjacent tooling
│   └── vms/             # KubeVirt virtual machines
├── proxmox-nodes/
│   ├── terraform/       # Proxmox VMs (OPNsense gateway, storage VM, TrueNAS apps)
│   └── ansible/         # OPNsense and Proxmox node configuration
└── docs/
    ├── NETWORK.md       # VLAN layout, firewall rules, BGP
    ├── DEVICES.md       # All static IPs and hostnames
    ├── BACKUPS.md       # Full backup strategy (3-2-1, per-layer tooling)
    └── DISASTER_RECOVERY.md  # Restore runbooks, boot order, offline material
```

## Cluster

One Talos cluster (`workload-prd`) on VLAN 4 (`10.0.4.0/24`): three control-plane nodes and a GPU worker (AMD Radeon 780M, used by llama.cpp via Vulkan and Immich ML via ROCm). Load balancer IPs (`10.0.4.50–99`) are announced to OPNsense over BGP by Cilium.

Storage comes from three sources:

- **Longhorn** - replicated block storage on the nodes' local disks
- **democratic-csi** - dynamic NFS (`truenas-nfs`) and iSCSI (`truenas-iscsi`) volumes on the TrueNAS box (`10.0.3.3`, VLAN 3)
- **local-path** - node-local scratch

## GitOps flow

FluxCD watches this repo (`main`) and reconciles Kustomizations in dependency order:

```
flux-system (self)
└── core                 # CRDs, cert-manager, external-secrets, Kyverno
    └── platform         # Cilium config, gateway, storage, policies, operators
        ├── apps         # User-facing applications
        ├── observability
        ├── llm-policies → llm
        └── vms
```

Every component follows the same `base/ + overlays/{cluster}/` kustomize pattern. To add an app: create `kubernetes/apps/{name}/base` + `overlays/workload-prd`, register it in `kubernetes/apps/overlays/workload-prd/kustomization.yaml`, and add an HTTPS listener to the gateway patch (below).

## Conventions

- **Ingress** -  Cilium Gateway API. One `Gateway` (`internal`, `kube-system`) with a listener per hostname (`https-{app}`), defined in `kubernetes/platform/gateway/overlays/workload-prd/gateway-patch.yaml`. Apps attach an `HTTPRoute` with a matching `sectionName`. TLS certs are issued by cert-manager (Let's Encrypt DNS-01 via Cloudflare); DNS records on OPNsense are managed by `yk-dns-manager`. Domain: `yuriykovalchuk.dev`.
- **Secrets** - nothing sensitive in Git. Vault (on TrueNAS) → External Secrets Operator (`ClusterSecretStore` `default-store`, KV path prefix `kubernetes/`) → Kubernetes Secrets.
- **Network policy** - every namespace ships `CiliumNetworkPolicy` in its base; DNS egress is allowed cluster-wide, everything else is explicit.
- **Policy enforcement** - Kyverno validates pod security (non-root, seccomp, no privilege escalation); workloads that need exemptions declare a namespaced `PolicyException`.

## Observability

Alloy collectors (k8s-monitoring chart) ship metrics, logs, and traces to Mimir, Loki, and Tempo respectively — all backed by S3 on the storage VLAN with Grafana on top (dashboards provisioned from ConfigMaps).

## Working on this repo

Tooling is pinned with [devbox](https://www.jetify.com/devbox): `devbox shell` provides `kubectl`, `talosctl`, `flux`, `cilium`, `helm`, `terraform`/`terragrunt`, and helper functions from `devbox_scripts/`.

Validate manifests before pushing:

```sh
kubectl kustomize kubernetes/apps/overlays/workload-prd
```

See `docs/NETWORK.md` for the VLAN/firewall design and `docs/DEVICES.md` for the device inventory. `CLAUDE.md` carries the detailed AI-assistant context for this repo.
