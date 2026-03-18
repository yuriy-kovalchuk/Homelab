# Talos Kubernetes Cluster - Management

Terraform configuration to provision and manage the management Talos Kubernetes cluster running on the Maya Proxmox node.

## Overview

This module configures a single-node Talos Kubernetes cluster used for management infrastructure services like Harbor registry. The cluster runs as a VM on the Maya Proxmox host.

## Cluster Specifications

| Property | Value |
|----------|-------|
| **Cluster Name** | management-talos |
| **Endpoint IP** | 10.0.2.10 |
| **Talos Version** | 1.12.1 |
| **Kubernetes Version** | 1.34.0 |
| **Control Plane Scheduling** | Enabled (single-node) |

## Prerequisites

1. Management Talos VM provisioned via `terraform/infrastructure/maya`
2. VM booted with Talos ISO and accessible at the endpoint IP
3. S3 backend credentials configured in `.env`

## Usage

```bash
cd terraform/clusters/management
tf_init
tf_plan
tf_apply
```

## Outputs

After applying, extract the kubeconfig and talosconfig:

```bash
# Get kubeconfig
tf_output kubeconfig > ~/.kube/management-talos.yaml

# Get talosconfig
tf_output talosconfig > ~/.talos/management-talos.yaml
```

## Configuration

The cluster configuration is applied via machine config patches in `machine_config_patches/controlplane.tftpl`. Key settings include:

- Static IP configuration (no DHCP)
- DNS server configuration
- Install disk and image settings
- Control plane scheduling enabled for workloads

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `talos_cluster_name` | management-talos | Cluster name |
| `talos_cluster_endpoint_ip` | 10.0.2.10 | Cluster API endpoint IP |
| `talos_version` | 1.12.1 | Talos Linux version |
| `kubernetes_version` | 1.34.0 | Kubernetes version |
| `talos_install_disk` | /dev/sda | Disk for Talos installation |
| `talos_dns` | 10.0.2.254 | DNS server |
| `talos_network_gateway` | 10.0.2.254 | Network gateway |

## Files

| File | Description |
|------|-------------|
| `backend.tf` | S3/MinIO state backend |
| `provider.tf` | Talos provider configuration |
| `variables.tf` | Input variables with defaults |
| `talos_conf.tf` | Cluster secrets, config, and bootstrap |
| `outputs.tf` | Kubeconfig and talosconfig outputs |
| `machine_config_patches/` | Talos machine configuration templates |

## Upgrading Talos

To upgrade the cluster:

1. Update `talos_version` and `talos_image_schematic_id` variables
2. Run `tf_plan` to preview changes
3. Run `tf_apply` to apply the new configuration
4. Use `talosctl upgrade` if needed for the actual OS upgrade

## Related

- [Maya Infrastructure](../../infrastructure/maya/README.md) - VM provisioning
- [Main Cluster](../main/README.md) - Production cluster
