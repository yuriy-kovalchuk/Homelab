# Homelab

This repository contains automation, manifests, and application code used to build and operate a Kubernetes-based homelab on Proxmox. Scripts and helper commands are designed to be executed via Devbox.

Important: Devbox is required to run most scripts and to ensure the correct toolchain (Ansible, kubectl, Helm, kubeseal, gum, etc.). The Devbox shell automatically exports variables from your local .env.

- Install Devbox: https://www.jetify.com/docs/devbox/installing_devbox/
- Enter the environment: devbox shell
- Run helper scripts: devbox run <script-name> (see devbox_scripts/README.md)

## Repository map

Each top-level area has its own README with details. Start here:

- Ansible (Proxmox automation): [ansible/README.md](ansible/README.md)
  - Automates Proxmox tasks: download cloud‑init image, create a VM template, and clone VMs.
- k3s installer and helpers: [k3s/README.md](k3s/README.md)
  - Installs a k3s cluster on Proxmox VMs (single master, master+workers, or HA) and prepares for Cilium.
- Kubernetes setup bootstrap: [kubernetes/setup/README.md](kubernetes/setup/README.md)
  - Bootstraps a fresh cluster with Cilium (CNI) and Argo CD. Note: kubernetes/setup/longhorn is out of scope here.
- Kubernetes apps (Argo CD-managed): [kubernetes/apps/README.md](kubernetes/apps/README.md)
  - Helm charts/manifests plus Argo CD Application definitions for cluster apps.
- Ad‑hoc Kubernetes tests: [kubernetes/test/README.md](kubernetes/test/README.md)
  - Scratch area for quick manifest experiments (not managed by Argo CD).
- Custom applications source: [applications/README.md](applications/README.md)
  - Source code and Dockerfiles for custom services running in the cluster.
- Devbox scripts: [devbox_scripts/README.md](devbox_scripts/README.md)
  - All helper scripts are exposed as devbox run commands (configured in devbox.json).

## Devbox environment

- Install Devbox: https://www.jetify.com/docs/devbox/installing_devbox/
- From the repository root, start the environment: `devbox shell`
- Run helper scripts: `devbox run <script-name>` (see the full mapping in [devbox_scripts/README.md](devbox_scripts/README.md))
- The Devbox shell auto-exports variables from your local `.env` (see `devbox.json` init_hook). Avoid committing `.env` and quote values containing spaces.

Common examples:
- Proxmox image download: `devbox run prx_download_base_image`
- Proxmox template creation: `devbox run prx_create_vm_template`
- Create VMs from template: `devbox run prx_create_vm`
- Scaffold a new app: `devbox run argo_new_app myapp --namespace myns`
- Create a SealedSecret: `devbox run k_ss_create <name> <key> <value> <namespace>`

## Environment configuration (.env)

Place a .env file at the repository root to configure credentials and parameters used by Ansible, k3s installer, and setup scripts. The Devbox shell will export these on entry.

| Variable | Purpose | Used by | Example |
|---|---|---|---|
| REMOTE_HOST | Proxmox API host (FQDN/IP) | Ansible | 192.168.0.2 |
| REMOTE_USER | Proxmox SSH/API user (if used in your workflow) | Local/Ansible context | root |
| REMOTE_PASSWORD | Proxmox API password/token | Ansible | ******** |
| PROXMOX_USER | Proxmox API user | Ansible | root@pam |
| PROXMOX_NODE_TARGET | Proxmox node name | Ansible | node1 |
| PROXMOX_STORAGE_TARGET | Proxmox storage pool | Ansible | local-lvm |
| MASTER1_USER | Cloud‑init VM user for template/VMs | Ansible | master |
| MASTER1_PASSWORD | Cloud‑init VM password | Ansible | ******** |
| K3S_VAR_CLUSTER_TOKEN | Shared k3s cluster token | k3s/install-k3s-v3.sh | YOUR_CLUSTER_TOKEN |

Notes:
- Only include what you actually use. Treat secrets carefully; do not commit .env.
- Some scripts allow overriding via direct flags or variables; see each folder’s README.

## Typical flow

1) Provision Proxmox VMs (optionally using the Ansible playbooks via devbox run).
2) Install k3s onto those nodes (see k3s/README.md).
3) Bootstrap the cluster networking and GitOps: install Cilium and Argo CD (see kubernetes/setup/README.md).
4) Let Argo CD manage apps in kubernetes/apps, and build/publish images for custom apps in applications/.

For details and troubleshooting, follow the linked READMEs above.
