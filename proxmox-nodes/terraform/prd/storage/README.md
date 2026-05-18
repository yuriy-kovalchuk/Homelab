# Storage Node

Infrastructure for the `storage` Proxmox node (`10.0.3.2`). This node runs TrueNAS SCALE as a VM with PCIe-passthrough storage controller, and a Docker VM for containerised services.

## Terraform

Apply in order:

```bash
cd proxmox-nodes/terraform/prd/storage

# 1. Provision the TrueNAS VM on Proxmox
cd truenas-install && terragrunt apply && cd ..

# 2. Provision the Docker VM
cd docker-vm && terragrunt apply && cd ..

# 3. Configure TrueNAS (after install and IP reservation)
cd truenas-setup && terragrunt apply && cd ..
```

See each module's README in `terraform/_modules/` for the full setup guide.

## Ansible

Deploy Docker services to the Docker VM:

```bash
cd proxmox-nodes/ansible
ansible-playbook -i inventories/prd/storage playbooks/docker_vm.yml
```

See `ansible/README.md` for details.

## Network

| Service   | IP       | VLAN           |
|-----------|----------|----------------|
| Proxmox   | 10.0.3.2 | storage (opt2) |
| TrueNAS   | 10.0.3.3 | storage (opt2) |
| docker-vm | 10.0.3.4 | storage (opt2) |

See [`NETWORK.md`](../../../../NETWORK.md) for the full VLAN layout and firewall rules.
