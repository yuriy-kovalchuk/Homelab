# Docker VM

Terraform module that provisions an Ubuntu 24.04 VM with Docker on the storage Proxmox
node (`10.0.3.4`). Docker workloads (e.g. Garage S3) are deployed via Ansible — see
`../../ansible/`.

## Prerequisites

- Devbox shell active

## 1. Generate SSH key

Generate a dedicated key for homelab VMs if you don't have one yet:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab_ed25519 -C "homelab" -N ""
```

## 2. Configure

```bash
cp .env.example .env
```

Fill in `.env`:
- `TF_VAR_storage_proxmox_password` — Proxmox root password
- `TF_VAR_docker_vm_ssh_key_path` — path to the public key generated in step 1 (default: `~/.ssh/homelab_ed25519.pub`)

## 3. Apply

From the devbox shell (`devbox shell` at repo root):

```bash
source .env
tf_init_local
tf_plan
tf_apply
```

The VM boots with Ubuntu 24.04 and a static IP of `10.0.3.4`. Docker is installed via
Ansible after provisioning — see `../../ansible/README.md`.

## Network

| VM         | IP       | VLAN           |
|------------|----------|----------------|
| docker-vm  | 10.0.3.4 | storage (opt2) |

Accessible from: k8s-mgmt, k8s-workload, phys-workload.
