# Devbox Scripts

This folder contains helper scripts that are meant to be run via Devbox. Each script is exposed as a `devbox run` command configured in `devbox.json`.

Quick start:
- Install Devbox and enter the shell: `devbox shell`
- List scripts below and invoke them using `devbox run <script-name>`

The Devbox shell `init_hook` (see `devbox.json`) does the following:
- `chmod +x devbox_scripts/*` to ensure scripts are executable
- `export $(cat .env | xargs)` to export environment variables from `.env` (optional)

Note: You can also run these scripts directly with Bash, but using `devbox run` ensures all required tools are available in the environment.

## Commands mapping (from devbox.json)

- `devbox run prx_download_base_image` → `./devbox_scripts/download_cloud_init.sh`
- `devbox run prx_create_vm_template` → `./devbox_scripts/create_vm_template.sh`
- `devbox run prx_create_vm` → `./devbox_scripts/create_vm_from_template.sh`
- `devbox run argo_new_app [args...]` → `./devbox_scripts/new_app.sh [args...]`
- `devbox run k_ss_create <name> <key> <value> <namespace>` → `./devbox_scripts/create_sealed_secret.sh <name> <key> <value> <namespace>`

## Script details

### 1) download_cloud_init.sh
Downloads the required cloud-init base image to a Proxmox server using Ansible.

- Runs: `ansible-playbook -i ansible/playbook/inventory/hosts.ini ansible/playbook/download_base_image_playbook.yaml`
- Prerequisites:
  - Proxmox inventory set in `ansible/playbook/inventory/hosts.ini`
  - Ansible variables (if any) in `ansible/playbook/vars/main.yaml`
- Usage:
  - Via Devbox: `devbox run prx_download_base_image`
  - Direct: `bash devbox_scripts/download_cloud_init.sh`

### 2) create_vm_template.sh
Creates a Proxmox VM template using Ansible.

- Runs: `ansible-playbook ansible/playbook/create_proxmox_template_playbook.yaml`
- Prerequisites:
  - Proxmox connection details in Ansible inventory/vars
- Usage:
  - Via Devbox: `devbox run prx_create_vm_template`
  - Direct: `bash devbox_scripts/create_vm_template.sh`

### 3) create_vm_from_template.sh
Creates VMs based on an existing Proxmox template using Ansible.

- Runs: `ansible-playbook ansible/playbook/create_proxmox_vm_playbook.yaml`
- Prerequisites:
  - A prepared template (see the previous step)
  - Inventory and variables configured for target VMs
- Usage:
  - Via Devbox: `devbox run prx_create_vm`
  - Direct: `bash devbox_scripts/create_vm_from_template.sh`

### 4) new_app.sh
Scaffolds a new Kubernetes app folder from `kubernetes/apps/_template`.

- Features:
  - Copies `_template` to `kubernetes/apps/<app-name>`
  - Renames `TEMPLATE-app.yaml` to `<app-name>-app.yaml`
  - Replaces placeholders `__APP_NAME__` and `__NAMESPACE__`
  - Optional: removes `manifest/templates` with `--no-templates`
  - Optional: overrides `.spec.source.repoURL` with `--repo-url <url>`
- Requirements in Devbox: `sed`, `kubectl` not required for scaffolding, only filesystem tools (provided by shell)
- Usage:
  - Via Devbox:
    - `devbox run argo_new_app <app-name>`
    - Options:
      - `--namespace <ns>` (default: same as app name)
      - `--no-templates`
      - `--repo-url <url>`
      - `--dry-run`
    - Examples:
      - `devbox run argo_new_app myapp`
      - `devbox run argo_new_app myapp --namespace myns --no-templates`
      - `devbox run argo_new_app myapp --repo-url "https://github.com/you/Homelab.git"`
  - Direct:
    - `bash devbox_scripts/new_app.sh <app-name> [options]`

### 5) create_sealed_secret.sh
Creates a SealedSecret manifest (sealed_secret.yaml) from given inputs using `kubectl` and `kubeseal`.

- Arguments: `<secret-name> <secret-key> <secret-value> <namespace>`
- Behavior:
  - Prompts for confirmation
  - Runs `kubectl create secret ... --dry-run=client -o yaml | kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets --scope strict -o yaml > sealed_secret.yaml`
- Prerequisites:
  - Access to a cluster with the Sealed Secrets controller installed
  - `kubectl` and `kubeseal` available (provided by Devbox)
- Usage:
  - Via Devbox: `devbox run k_ss_create rancher-bootstrap bootstrapPassword 'mySecret123' cattle-system`
  - Direct: `bash devbox_scripts/create_sealed_secret.sh rancher-bootstrap bootstrapPassword 'mySecret123' cattle-system`

## Notes
- All commands are configured in `devbox.json` under `shell.scripts`.
- Enter `devbox shell` to ensure all required tools (ansible, kubectl, helm, kubeseal, gum, etc.) are available.
- The shell exports variables from `.env` on entry; keep secrets safe and consider your workflow before committing `.env`.
