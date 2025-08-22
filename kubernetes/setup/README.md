# Kubernetes Setup

This folder contains scripts and manifests to bootstrap a freshly created Kubernetes cluster. It focuses on installing:

- Cilium as the CNI (Container Network Interface)
- Argo CD to manage and continuously reconcile the applications defined under `kubernetes/apps`

## Contents

- `cilium/`
  - `install-cilium.sh` — installs Cilium via Helm
  - `values/cilium-config.yaml` — base configuration for Cilium
  - `templates/cilium-ip-pool-template.yaml` — IPAM pool template applied with environment substitution
  - `templates/cilium-announcements-template.yaml` — L2 announcements template
- `argocd/`
  - `install-argocd.sh` — installs Argo CD via Helm and configures an Ingress
  - `values/values.yaml` — base configuration for Argo CD components
  - `templates/ingress.yaml` — Ingress for Argo CD server

## Prerequisites

- A reachable Kubernetes cluster with admin access via `kubectl`
- `helm` and `kubectl` installed and configured
- DNS and Ingress controller if you want to expose Argo CD via Ingress
  - The provided Ingress expects:
    - Ingress class `nginx`
    - A `ClusterIssuer` named `letsencrypt-dns` (from cert-manager)
- Network ranges appropriate for your environment (see Cilium IP pool below)

## Quick Start

1. Install Cilium (CNI):
   - Review and, if needed, export environment variables used by the IP pool in `cilium/install-cilium.sh`:
     - `POOL_NAME` (default: `master-pool`)
     - `START_IP` (default: `10.0.8.100`)
     - `STOP_IP` (default: `10.0.8.200`)
     - `MAIN_MASTER_NODE` (default in script: `10.0.8.20`)
   - Run:
     ```bash
     cd kubernetes/setup/cilium
     ./install-cilium.sh
     ```

2. Install Argo CD:
   - Review `argocd/values/values.yaml` and `argocd/templates/ingress.yaml` (hostnames, TLS secret, issuer) and adjust to your environment.
   - Run:
     ```bash
     cd ../argocd
     ./install-argocd.sh
     ```
   - Fetch the initial admin password (the script prints it automatically). You can also run:
     ```bash
     kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
     ```
   - Access Argo CD at the host configured in `templates/ingress.yaml` (e.g., `https://argocd.your-domain`)

## How applications are managed

This repository is structured for GitOps with Argo CD. The applications under `kubernetes/apps` contain Helm charts, manifests, and Argo CD application definitions. Once Argo CD is running, you can:

- Point Argo CD to this Git repository and configure Applications or an ApplicationSet to track subpaths under `kubernetes/apps`.
- Alternatively, apply the Argo CD `Application` manifests located within `kubernetes/apps/**` to register apps with the Argo instance.

After configured, Argo CD will continuously reconcile resources defined in `kubernetes/apps` to your cluster state.

## Notes and Tips

- Order of operations: Install Cilium first (as CNI), then Argo CD.
- Ingress and TLS: The provided Argo CD Ingress assumes cert-manager is available with a `ClusterIssuer` named `letsencrypt-dns`. If not yet installed, you can add it later via Argo CD-managed apps.
- Namespaces: Argo CD will be installed into the `argo-cd` namespace (see `values/values.yaml`). Cilium is installed into `kube-system`.
- Waiting for readiness: Both installation scripts use `--wait` to block until resources are ready.
