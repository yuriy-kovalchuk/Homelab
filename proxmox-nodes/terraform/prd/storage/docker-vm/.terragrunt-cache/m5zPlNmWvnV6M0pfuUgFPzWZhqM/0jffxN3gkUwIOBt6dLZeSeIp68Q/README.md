# Docker VM

Terraform module that provisions an Ubuntu 24.04 VM with Docker on the storage Proxmox node (`10.0.3.4`). Docker workloads (Garage S3, Portainer, nginx-proxy-manager) are deployed via Ansible — see `ansible/playbooks/docker_vm.yml`.

## Prerequisites

- Devbox shell active

## 1. Generate SSH key

Generate a dedicated key for homelab VMs if you don't have one yet:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -C "homelab" -N ""
```

## 2. Configure

Fill in the values in `terraform/prd/.env.example` → `.env` at repo root:
- `STORAGE_PROXMOX_PASSWORD` — Proxmox root password
- `DOCKER_VM_SSH_KEY_PATH` — path to the public key generated in step 1 (default: `~/.ssh/homelab_ed25519.pub`)

## 3. Apply

```bash
cd proxmox-nodes/terraform/prd/storage/docker-vm
terragrunt plan
terragrunt apply
```

The VM boots with Ubuntu 24.04 and a static IP of `10.0.3.4`. Docker is installed via Ansible after provisioning.

## 4. Deploy services

```bash
cd proxmox-nodes/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventories/prd/storage playbooks/docker_vm.yml
```

## Network

| VM         | IP       | VLAN           |
|------------|----------|----------------|
| docker-vm  | 10.0.3.4 | storage (opt2) |

Accessible from: k8s-mgmt, k8s-workload, phys-workload.

See [`NETWORK.md`](../../../../NETWORK.md) for the full VLAN layout and firewall rules.
