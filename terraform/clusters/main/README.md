# Talos Kubernetes Cluster - Main

Terraform configuration for provisioning and managing the main Talos Linux Kubernetes cluster.

## Overview

This Terraform module:
- Generates Talos machine secrets
- Creates machine configurations with custom patches
- Applies configurations to control plane nodes
- Bootstraps the Kubernetes cluster
- Outputs kubeconfig and talosconfig

## Usage

### Initial Deployment

```bash
# Initialize Terraform
./scripts/tf_init.sh

# Review the plan
./scripts/tf_plan.sh

# Apply the configuration
./scripts/tf_apply.sh
```

### Get Cluster Credentials

```bash
# Get kubeconfig
terraform output -raw kubeconfig_raw > ~/.kube/main-cluster.yaml

# Get talosconfig
terraform output -raw talos_config > ~/.talos/config
```

## Upgrading Talos

**Important:** Terraform cannot perform in-place Talos upgrades. Use the provided upgrade script or `talosctl` directly.

### Using the Upgrade Script

```bash
# Upgrade all nodes to a new version
./scripts/upgrade_talos.sh -v v1.12.0 --all

# Upgrade a specific node
./scripts/upgrade_talos.sh -v v1.12.0 -n 10.0.2.20

# Dry run (see what would happen)
./scripts/upgrade_talos.sh -v v1.12.0 --all --dry-run
```

### Manual Upgrade with talosctl

```bash
# 1. Get the schematic ID (includes your extensions)
terraform output talos_schematic_id

# 2. Upgrade each control plane node (one at a time)
talosctl upgrade \
  --nodes <node-ip> \
  --image factory.talos.dev/installer/<SCHEMATIC_ID>:v1.12.0 \
  --preserve

# 3. Wait for node to be healthy before upgrading the next one
talosctl health --nodes <node-ip>
```

### After Upgrade

Update `variables.tf` to match the new version:

```hcl
variable "talos_version" {
  default = "v1.12.0"  # Update to your new version
}
```

This keeps Terraform state in sync and ensures any new nodes use the correct version.

## Upgrading Kubernetes

Kubernetes upgrades are also done via `talosctl`:

```bash
# Upgrade Kubernetes to a new version
talosctl upgrade-k8s --to 1.32.0
```

## Configuration

### Harbor Registry Mirror

To use Harbor as an upstream registry mirror (proxy cache), enable it in your tfvars:

```hcl
registry_mirrors_enabled = true
harbor_hostname          = "harbor.yuriy-lab.cloud"
```

This configures Talos to pull images through Harbor for:
- `docker.io` → `harbor.yuriy-lab.cloud/dockerhub`
- `ghcr.io` → `harbor.yuriy-lab.cloud/ghcr`
- `gcr.io` → `harbor.yuriy-lab.cloud/gcr`
- `registry.k8s.io` → `harbor.yuriy-lab.cloud/k8s`
- `quay.io` → `harbor.yuriy-lab.cloud/quay`
- `public.ecr.aws` → `harbor.yuriy-lab.cloud/ecr-public`
- `mcr.microsoft.com` → `harbor.yuriy-lab.cloud/mcr`

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `control_plane_nodes` | List of control plane nodes | Required |
| `cluster_name` | Name of the Talos cluster | `talos-prd-cluster` |
| `gateway` | Default gateway IP | Required |
| `talos_version` | Talos Linux version | `v1.11.5` |
| `cni_name` | CNI plugin | `none` |
| `extensions` | Talos extensions to include | `[iscsi-tools, util-linux-tools]` |
| `allow_scheduling_on_control_planes` | Allow workloads on control planes | `true` |
| `registry_mirrors_enabled` | Enable Harbor as upstream registry mirror | `false` |
| `harbor_hostname` | Harbor registry hostname | `harbor.yuriy-lab.cloud` |

### Node Configuration

Nodes are defined in `vars/terraform.tfvars`:

```hcl
control_plane_nodes = [
  {
    ip        = "10.0.2.20"
    hostname  = "cp-1"
    interface = "ens18"
    disk      = "/dev/sda"  # Optional
    wipe      = true        # Optional
  },
]
```

## File Structure

```
.
├── backend.tf                      # S3 backend configuration
├── extensions.tf                   # Talos extensions/schematic
├── locals.tf                       # Local variables
├── outputs.tf                      # Terraform outputs
├── provider.tf                     # Provider configuration
├── talos_bootstrap.tf              # Bootstrap resources
├── talos_conf.tf                   # Machine secrets and config
├── talos_machines.tf               # Machine configuration apply
├── variables.tf                    # Input variables
├── machine_config_patches/
│   ├── controlplane.tftpl          # Control plane config template
│   └── schematic.tftpl             # Extensions schematic template
├── scripts/
│   ├── tf_init.sh
│   ├── tf_plan.sh
│   ├── tf_apply.sh
│   └── upgrade_talos.sh            # Talos upgrade helper
└── vars/
    └── terraform.tfvars            # Variable values
```

## Outputs

| Output | Description |
|--------|-------------|
| `kubeconfig_raw` | Kubeconfig for kubectl access |
| `talos_config` | Talosconfig for talosctl access |
| `talos_schematic_id` | Schematic ID for upgrades |
| `control_plane_ips` | List of control plane IPs |
| `talos_version` | Current configured Talos version |
