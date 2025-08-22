# Ansible (Proxmox automation)

This folder contains Ansible playbooks and roles to automate common Proxmox tasks used by this Homelab:
- Download a cloud‑init base image to a Proxmox node
- Create a reusable Proxmox VM template from that image
- Create one or more VMs from the template and finalize their configuration (disk size, cloud‑init, network, SSH keys)

These playbooks are also wired to Devbox scripts so you can run them with `devbox run` commands (see below).

## Folder structure

- playbook/
  - download_base_image_playbook.yaml — downloads the cloud‑init image on the Proxmox host via SSH
  - create_proxmox_template_playbook.yaml — creates a template using the Proxmox API
  - create_proxmox_vm_playbook.yaml — clones VMs from the template and finalizes config
  - inventory/hosts.ini — Ansible inventory with your Proxmox host(s)
  - vars/main.yaml — shared variables for the playbooks (many sourced from environment variables)
  - roles/
    - download_base_image/
      - tasks/download_base_image.yaml — uses `get_url` on the remote Proxmox host
    - create_proxmox_template/
      - tasks/create_proxmox_template.yaml — uses `community.general.proxmox_kvm` to build a template
    - create_proxmox_vm/
      - tasks/create_vm.yaml — clones VMs from the template and records their VMIDs
      - tasks/increase_disk_size.yaml — resizes VM disk(s) with `community.general.proxmox_disk`
      - tasks/finalize_vm.yaml — sets CPU, memory, tags, cloud‑init, SSH keys, ipconfig, network

## Prerequisites

- Access to your Proxmox environment (API and, for image download, SSH to the node)
- Ansible installed. If you use Devbox, `ansible` and required Python packages (proxmoxer/requests/urllib3) are provided.
- Ansible collection `community.general` (Devbox shell includes it via Ansible Galaxy caching; otherwise install: `ansible-galaxy collection install community.general`).
- Environment variables exported for credentials and targets (see Variables below).

Tip: Enter the Devbox shell to have all tools and dependencies available:
- devbox shell

## Variables and environment

Common variables live in `playbook/vars/main.yaml`. Many are populated via environment variables using Ansible’s `lookup('env', ...)`.

- Proxmox API/auth:
  - REMOTE_HOST → api_host
  - PROXMOX_USER → api_user (e.g., root@pam or api@pve)
  - REMOTE_PASSWORD → api_password
  - PROXMOX_NODE_TARGET → node_target (e.g., pve or the node name)
  - PROXMOX_STORAGE_TARGET → storage_target (e.g., local-lvm, local, or a ZFS pool)

- Cloud‑init base image:
  - image_url (default: Ubuntu 24.04 Noble cloud‑init image)
  - image_dest (default: /var/lib/vz/template/iso)
  - image_name (default: noble-server-cloudimg-amd64.img)

- Template defaults:
  - template_name (default: noble-ubuntu-cloudinit-template)
  - image_ostype (default: l26)

- VM matrix (used by create_proxmox_vm role):
  - machines: list of VMs to create. Example entries (see vars/main.yaml):
    - name: node1
    - size: 20G (final disk size)
    - tags: ["k3s"]
    - cores: 2
    - memory: 4098
    - ci_user: from env MASTER1_USER
    - ci_password: from env MASTER1_PASSWORD
    - ip_config: "ip=10.0.8.20/24,gw=10.0.8.1" (cloud‑init ipconfig0)
    - vmbr: "virtio,bridge=vmbr8" (network model/bridge)

Export the necessary environment variables before running (Devbox’s init_hook can source `.env`):
- export REMOTE_HOST=...
- export PROXMOX_USER=...
- export REMOTE_PASSWORD=...
- export PROXMOX_NODE_TARGET=...
- export PROXMOX_STORAGE_TARGET=...
- export MASTER1_USER=...
- export MASTER1_PASSWORD=...

## Inventory

`playbook/inventory/hosts.ini` defines a group `proxmox_nodes` used for the download action:

[proxmox_nodes]
node1-api.yuriy-lab.cloud ansible_ssh_private_key_file=/Users/yuriy/.ssh/id_rsa ansible_user=root

- The download playbook runs against these hosts with `become: yes` to place the image at `image_dest`.
- Template/VM creation playbooks run on `localhost` and talk to the Proxmox API directly.

## What each playbook does

1) download_base_image_playbook.yaml
- Hosts: proxmox_nodes (remote execution with sudo)
- Role: download_base_image
- Task: Uses `ansible.builtin.get_url` to download `image_url` to `image_dest/image_name` on the remote Proxmox node. `force: false` prevents re‑download if the file already exists.

2) create_proxmox_template_playbook.yaml
- Hosts: localhost (API only)
- Role: create_proxmox_template
- Tasks: Creates a VM template (vmid 50000 by default) using `community.general.proxmox_kvm` with:
  - EFI disk on `storage_target`, Seabios VGA serial console
  - scsi0 importing the downloaded `image_name`
  - a cloud‑init drive (`ide2: <storage>:cloudinit`)
  - virtio NIC on bridge `vmbr8` (adjust if needed)
  - `template: true` marks it as a template

3) create_proxmox_vm_playbook.yaml
- Hosts: localhost (API only)
- Role: create_proxmox_vm
- Tasks sequence:
  - create_vm.yaml: clones each entry in `machines` from `template_name` and builds a `vm_map` of names → VMIDs (using the results of the clone task).
  - increase_disk_size.yaml: resizes `scsi0` to the requested `size` for each VM using `community.general.proxmox_disk`.
  - finalize_vm.yaml: applies CPU, memory, tags, cloud‑init user/password, SSH public key (from `~/.ssh/id_rsa.pub` if present), ipconfig0, and NIC settings; sets `agent=1` and `update: true`.

## Running the playbooks

Direct commands (from repository root):
- Download base image to Proxmox node:
  - ansible-playbook -i ansible/playbook/inventory/hosts.ini ansible/playbook/download_base_image_playbook.yaml
- Create the template via API:
  - ansible-playbook ansible/playbook/create_proxmox_template_playbook.yaml
- Create VMs from the template:
  - ansible-playbook ansible/playbook/create_proxmox_vm_playbook.yaml

Via Devbox (preferred, ensures dependencies are present):
- devbox run prx_download_base_image
- devbox run prx_create_vm_template
- devbox run prx_create_vm

## Customization tips

- Networking: The template creation uses `vmbr8` and virtio NIC by default; change `net0`/bridge values in template and finalize steps to match your Proxmox setup.
- Storage: Set `PROXMOX_STORAGE_TARGET` to your storage pool (e.g., local, local-lvm, zfs‑pool).
- Image: Update `image_url`, `image_name`, and `image_dest` if you want a different OS or path.
- VM specs: Adjust `machines` (cores/memory/size/ip_config/tags) in `vars/main.yaml` or override via extra vars.

## Troubleshooting

- Authentication errors: verify `REMOTE_HOST`, `PROXMOX_USER`, and `REMOTE_PASSWORD` env vars; ensure the user has API permissions.
- Collection/module not found: install `community.general` collection (`ansible-galaxy collection install community.general`).
- Download failures: confirm inventory SSH access to the Proxmox node and that `image_dest` exists and is writable.
- Wrong bridge/storage names: ensure `vmbr*` and storage names match your Proxmox configuration.
- Resizing disks: `proxmox_disk` expects the correct disk name (scsi0 here) and will only grow disks.

## Related

- Devbox scripts that call these playbooks: `devbox_scripts/download_cloud_init.sh`, `create_vm_template.sh`, `create_vm_from_template.sh`
- k3s install afterward: see `k3s/README.md` and scripts under `k3s/`
