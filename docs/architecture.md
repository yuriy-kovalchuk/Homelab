# Homelab Architecture

This document provides a high-level overview of the homelab architecture.

## Overview

The homelab consists of three main components:

```
                                    +------------------+
                                    |    Internet      |
                                    +--------+---------+
                                             |
                                    +--------v---------+
                                    |     Firewall     |
                                    |   (OPNsense)     |
                                    |   on Proxmox     |
                                    +--------+---------+
                                             |
                    +------------------------+------------------------+
                    |                        |                        |
           +--------v---------+    +---------v--------+    +---------v--------+
           |   Main Cluster   |    |      Maya        |    |  (Future Nodes)  |
           |  (3x Talos K8s)  |    |    (Proxmox)     |    |                  |
           |    Baremetal     |    | TrueNAS + Mgmt   |    |                  |
           +------------------+    +------------------+    +------------------+
```

## Components

### 1. Firewall Node (Entry Point)

The firewall node runs **Proxmox** and serves as the network entry point. It hosts several critical services:

| Service | Purpose |
|---------|---------|
| **OPNsense** | Primary firewall and router |
| **HashiCorp Vault** | Secrets management |
| **Nginx Proxy Manager** | Reverse proxy for external services |
| **MinIO** | S3-compatible object storage (Terraform state, backups) |
| **Pulse** | Monitoring/heartbeat service |

> **Note:** This node was configured manually due to the chicken-egg problem with Infrastructure as Code. Future work will address bringing this under Terraform management.

### 2. Main Kubernetes Cluster (Production)

The core of the homelab is a **3-node Kubernetes cluster** running on:
- **OS:** Talos Linux
- **Hardware:** Baremetal servers
- **GitOps:** Argo CD for application deployment

This cluster runs all production workloads. See [apps.md](apps.md) for the full list of deployed applications.

### 3. Maya Node (Management & Storage)

"Maya" is a Proxmox host running:
- **TrueNAS Scale** - Primary storage backend (NFS, iSCSI)
- **Management Kubernetes Cluster** - Runs supporting infrastructure like Harbor registry

Infrastructure code for Maya is located in `terraform/maya/`.

## GitOps Workflow

```
+-------------+     git push      +------------+     push      +------------------+
|  Developer  | ----------------> |   GitHub   | -----------> |      Harbor      |
+-------------+                   +------------+              | (OCI Registry)   |
                                                              +--------+---------+
                                                                       |
                                                              +--------v---------+
                                                              |    Argo CD       |
                                                              +--------+---------+
                                                                       |
                                                              +--------v---------+
                                                              |   Kubernetes     |
                                                              |    Cluster       |
                                                              +------------------+
```

1. Changes are made to Kubernetes manifests and Helm charts in this repository.
2. Pushing to GitHub (or manual release) triggers a build/push of the Helm chart to the **Harbor OCI Registry**.
3. Argo CD is configured to track specific versions of these charts in Harbor.
4. Argo CD pulls the OCI artifact and applies changes to the cluster.

## Technology Stack

| Layer | Technology |
|-------|------------|
| **Virtualization** | Proxmox VE |
| **Container OS** | Talos Linux |
| **Container Runtime** | containerd |
| **Orchestration** | Kubernetes |
| **CNI** | Cilium |
| **Ingress** | Envoy Gateway |
| **GitOps** | Argo CD |
| **IaC** | Terraform |
| **Storage** | Longhorn, TrueNAS (NFS/iSCSI) |
| **Secrets** | Sealed Secrets, External Secrets |
| **Monitoring** | Grafana, Loki, Mimir |
| **Identity** | Authentik (OIDC) |

## Related Documentation

- [Infrastructure Details](infrastructure.md)
- [Applications](apps.md)
- [Hardware](hardware.md)
- [Network Topology](network.md)
