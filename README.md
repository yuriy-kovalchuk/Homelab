# Homelab

This repository contains Infrastructure as Code, Kubernetes manifests, and automation for a production-grade homelab environment.

## Architecture Overview

The homelab consists of three main components:

| Component | Description |
|-----------|-------------|
| **Main Kubernetes Cluster** | 3-node Talos Linux cluster on baremetal running 33+ applications via Argo CD |
| **Firewall Node** | Proxmox host running OPNsense, Vault, Nginx Proxy Manager, MinIO |
| **Maya Node** | Proxmox host running TrueNAS Scale (storage) and a management Kubernetes cluster |

For detailed documentation, see the [docs/](docs/) folder:
- [Architecture](docs/architecture.md) - High-level architecture and technology stack
- [Infrastructure](docs/infrastructure.md) - Detailed infrastructure components
- [Applications](docs/apps.md) - All 33 Kubernetes applications
- [Hardware](docs/hardware.md) - Hardware specifications (TODO)
- [Network](docs/network.md) - Network topology (TODO)
- [Configuration](docs/configuration.md) - Environment variables and .env setup

## Quick Start

Devbox is required to run scripts and ensure the correct toolchain.

```bash
# Install Devbox: https://www.jetify.com/docs/devbox/installing_devbox/
devbox shell           # Enter the environment
devbox run <script>    # Run helper scripts
```

## Repository Map

Each top-level area has its own README with details. Start here:

- Kubernetes apps (Argo CD-managed): [docs/apps.md](docs/apps.md)
  - Helm charts (OCI) for cluster applications.
- Management Layer: [kubernetes/management/](kubernetes/management/)
  - App of Apps pattern (Root App) for managing cluster deployments.
- Cluster setup tooling: kubernetes/setup/
  - Contains tooling and IaC to stand up/operate the cluster (e.g., Talos Terraform under kubernetes/setup/talos/). See READMEs inside subfolders when present.
- Ad‑hoc Kubernetes tests: [kubernetes/test/README.md](kubernetes/test/README.md)
  - Scratch area for quick manifest experiments (not managed by Argo CD).
- Custom applications source: [applications/README.md](applications/README.md)
  - Source code and Dockerfiles for custom services running in the cluster.
- Firewall Bootstrap: [bootstrap/firewall/](bootstrap/firewall/)
  - Native scripts for provisioning the firewall node and management VMs.
- Devbox scripts: [devbox_scripts/README.md](devbox_scripts/README.md)
  - All helper scripts are exposed as devbox run commands (configured in devbox.json).

## Typical Flow

1) Provision or prepare your Kubernetes nodes/cluster using the tooling under kubernetes/setup/ (see subfolder READMEs when present).
2) Bootstrap cluster essentials (CNI, GitOps such as Argo CD) as defined by your chosen setup under kubernetes/setup/.
3) Manage and deploy applications via Argo CD using definitions in kubernetes/apps/.
4) Build and publish images for any custom services under applications/ and update corresponding charts/manifests in kubernetes/apps/.

For details and troubleshooting, follow the linked READMEs above.
