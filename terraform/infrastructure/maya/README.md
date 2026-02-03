# Maya Proxmox Infrastructure

Terraform configuration to manage virtual machines and infrastructure on the Maya Proxmox node.

## Overview

This module provisions and configures:
- **TrueNAS Scale VM** - Network storage with NVMe passthrough
- **Management Talos VM** - Single-node Kubernetes cluster for infrastructure services
- **ACME Certificates** - Automated SSL certificates via Let's Encrypt and Cloudflare DNS

## Virtual Machines

### TrueNAS Scale

| Property | Value |
|----------|-------|
| **VM ID** | 1000 |
| **CPU** | 2 cores (host type) |
| **RAM** | 8 GB |
| **Boot Disk** | 32 GB (local-lvm) |
| **Storage** | NVMe passthrough (PCIe 0000:03:00.0) |
| **MAC Address** | BC:24:11:19:5C:66 |
| **BIOS** | OVMF (UEFI) |

### Management Talos

| Property | Value |
|----------|-------|
| **VM ID** | 1100 |
| **Name** | management-talos-01 |
| **CPU** | 2 cores (host type) |
| **RAM** | 6 GB |
| **Disk** | 40 GB SSD (local-lvm) |
| **Talos Version** | 1.12.1 |
| **MAC Address** | BC:24:11:1A:26:95 |
| **BIOS** | OVMF (UEFI) |

## Prerequisites

1. Proxmox VE running on Maya node
2. TrueNAS ISO uploaded to local datastore as `trueNAS.iso`
3. NVMe device available for passthrough (0000:03:00.0)
4. Environment variables configured in `.env`

## Environment Variables

Add these to your `.env` file:

```bash
# ACME/Cloudflare
TF_VAR_acme_email="your-email@example.com"
TF_VAR_acme_cf_account_id="cloudflare-account-id"
TF_VAR_acme_cf_token="cloudflare-api-token"
```

## Usage

```bash
cd terraform/infrastructure/maya
tf_init
tf_plan
tf_apply
```

## ACME Certificate

The module configures automatic SSL certificate provisioning for the Proxmox web UI:

- **Domain**: maya.yuriy-lab.cloud
- **Provider**: Let's Encrypt (production)
- **Validation**: Cloudflare DNS-01 challenge

## Files

| File | Description |
|------|-------------|
| `backend.tf` | S3/MinIO state backend |
| `provider.tf` | Proxmox provider configuration |
| `variables.tf` | Input variables (Proxmox, VM specs, ACME) |
| `vm_truenas.tf` | TrueNAS Scale VM resource |
| `vm_talos.tf` | Management Talos VM resource |
| `acme.tf` | ACME account, DNS plugin, and certificate |
| `oidc.tf` | OIDC configuration (planned) |
| `outputs.tf` | Terraform outputs |

## Lifecycle Management

Both VMs use lifecycle rules to prevent Terraform from overwriting changes made by:
- Guest agents modifying descriptions
- Manual start/stop operations
- Network configuration changes

This ensures stability when VMs are managed both by Terraform and manually.

## First-Time Setup

### TrueNAS Installation

1. Set `cdrom.enabled = true` in `vm_truenas.tf`
2. Apply Terraform to create the VM
3. Access Proxmox console and install TrueNAS from ISO
4. Set `cdrom.enabled = false` and reapply

### Talos Configuration

After the VM is created:

1. Apply `terraform/clusters/management` to configure Talos
2. Bootstrap the Kubernetes cluster
3. Extract kubeconfig for cluster access

## Related

- [Management Cluster](../../clusters/management/README.md) - Talos cluster configuration
- [Platform Management](../../platform/management/README.md) - Kubernetes platform services
