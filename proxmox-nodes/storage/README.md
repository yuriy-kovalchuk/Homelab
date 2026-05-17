# Storage Node

Infrastructure for the `storage` Proxmox node (`10.0.3.2`). This node runs TrueNAS SCALE as a VM with PCIe-passthrough storage controller for NAS duties across the homelab.

## Structure

```
storage/
└── terraform/
    ├── truenas-install/   # Proxmox VM, PCIe passthrough, ACME cert
    ├── truenas-setup/     # TrueNAS pool, datasets, NFS/SMB shares
    └── docker-vm/         # Ubuntu 24.04 VM with Docker (runs Garage S3, etc.)
```

## Terraform

Apply in order:

```bash
# 1. Provision the TrueNAS VM on Proxmox
cd terraform/truenas-install
cp .env.example .env && source .env
tf_init_local && tf_apply

# 2. Provision the Docker VM
cd ../docker-vm
cp .env.example .env && source .env
tf_init_local && tf_apply
# Then deploy services via Ansible — see ansible/README.md

# 3. Configure TrueNAS (after install and IP reservation)
cd ../truenas-setup
cp .env.example .env && source .env
tf_init_local && tf_apply
```

See each module's `README.md` for the full setup guide.

## Network

| Service  | IP         | VLAN           |
|----------|------------|----------------|
| Proxmox  | 10.0.3.2   | storage (opt2) |
| TrueNAS  | 10.0.3.3   | storage (opt2) |

See [`NETWORK.md`](../../NETWORK.md) for the full VLAN layout and firewall rules.
