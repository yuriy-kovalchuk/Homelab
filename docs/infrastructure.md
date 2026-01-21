# Infrastructure

This document describes the infrastructure components of the homelab.

## Firewall Node

The firewall node is the entry point to the network and runs Proxmox VE.

### Services Running on Firewall Node

| Service | Description | Status |
|---------|-------------|--------|
| **OPNsense** | Primary firewall/router, handles all network traffic | Production |
| **HashiCorp Vault** | Centralized secrets management | Production |
| **Nginx Proxy Manager** | Reverse proxy for services outside Kubernetes | Production |
| **MinIO** | S3-compatible storage for Terraform state and backups | Production |
| **Pulse** | Monitoring and heartbeat service | Production |

### Configuration Status

> **Manual Configuration:** This node was set up manually due to bootstrap dependencies (chicken-egg problem). Bringing this under IaC management is a planned improvement.

---

## Main Kubernetes Cluster

The production Kubernetes cluster runs on Talos Linux across 3 baremetal nodes.

### Cluster Specifications

| Property | Value |
|----------|-------|
| **Node Count** | 3 |
| **Operating System** | Talos Linux |
| **Deployment** | Baremetal |
| **CNI** | Cilium |
| **Ingress Controller** | Envoy Gateway |
| **GitOps** | Argo CD |

### Terraform Configuration

The cluster is managed via Terraform located in `terraform/kubernetes/`:

```
terraform/kubernetes/
├── talos_machines.tf    # Node machine definitions
├── talos_bootstrap.tf   # Cluster bootstrap config
├── talos_conf.tf        # Talos OS configuration
├── extensions.tf        # System extensions
├── variables.tf         # Cluster variables
├── provider.tf          # Provider configuration
└── backend.tf           # State management (S3)
```

### Storage Classes

| Storage Class | Backend | Use Case |
|---------------|---------|----------|
| `longhorn` | Longhorn | Replicated block storage |
| `democratic-csi-iscsi` | TrueNAS (iSCSI) | High-performance block storage |
| `democratic-csi-nfs` | TrueNAS (NFS) | Shared filesystem storage |

---

## Maya Node

"Maya" is a Proxmox host that runs both TrueNAS Scale and the management Kubernetes cluster.

### Virtual Machines

#### TrueNAS Scale VM

| Property | Value |
|----------|-------|
| **VM ID** | 1000 |
| **CPU** | 2 cores |
| **RAM** | 8 GB |
| **Boot Disk** | 32 GB |
| **Storage** | NVMe passthrough (PCIe 0000:03:00.0) |
| **MAC Address** | BC:24:11:19:5C:66 |

#### Management Talos VM

| Property | Value |
|----------|-------|
| **VM ID** | 1100 |
| **Name** | management-talos-01 |
| **CPU** | 2 cores |
| **RAM** | 4 GB |
| **Disk** | 40 GB SSD (local-lvm) |
| **Talos Version** | v1.12.1 |
| **MAC Address** | BC:24:11:1A:26:95 |

### Terraform Configuration

Maya infrastructure is managed via Terraform in `terraform/maya/`:

```
terraform/maya/
├── provider.tf      # Proxmox provider (https://10.0.2.2:8006/)
├── vm_talos.tf      # Management Talos VM
├── vm_truenas.tf    # TrueNAS Scale VM
├── talos_conf.tf    # Talos cluster config
├── acme.tf          # ACME/Cloudflare cert automation
├── variables.tf     # Sensitive variables
├── backend.tf       # S3 backend configuration
└── outputs.tf       # Terraform outputs
```

### Management Cluster Purpose

The management Kubernetes cluster hosts infrastructure tools that support the main cluster:

- **Harbor Registry** - Container image mirror/registry for the main cluster
- Additional management tools (work in progress)

---

## Providers Used

| Provider | Version | Purpose |
|----------|---------|---------|
| `bpg/proxmox` | v0.93.0 | Proxmox VM management |
| `siderolabs/talos` | v0.9.0 - v0.10.0 | Talos Linux configuration |

---

## Related Documentation

- [Architecture Overview](architecture.md)
- [Applications](apps.md)
- [Hardware](hardware.md)
- [Network Topology](network.md)
