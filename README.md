# Homelab

This repository contains automation, manifests, and application code used to build and operate a Kubernetes-based homelab on Proxmox. Scripts and helper commands are designed to be executed via Devbox.

Important: Devbox is required to run most scripts and to ensure the correct toolchain (Ansible, kubectl, Helm, kubeseal, gum, etc.). The Devbox shell automatically exports variables from your local .env.

- Install Devbox: https://www.jetify.com/docs/devbox/installing_devbox/
- Enter the environment: devbox shell
- Run helper scripts: devbox run <script-name> (see devbox_scripts/README.md)

## Repository map

Each top-level area has its own README with details. Start here:

- Kubernetes apps (Argo CD-managed): [kubernetes/apps/README.md](kubernetes/apps/README.md)
  - Helm charts/manifests plus Argo CD Application definitions for cluster apps.
- Cluster setup tooling: kubernetes/setup/
  - Contains tooling and IaC to stand up/operate the cluster (e.g., Talos Terraform under kubernetes/setup/talos/). See READMEs inside subfolders when present.
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


## Environment configuration (.env)

Place a .env file at the repository root to configure credentials and parameters used by Ansible, k3s installer, and setup scripts. The Devbox shell will export these on entry.

| Variable | Purpose | Used by | Example |
|---|---|---|---|
| TF_VAR_s3_access_key | Terraform S3 backend access key | Talos Terraform init scripts | terraform-prd |
| TF_VAR_s3_secret_key | Terraform S3 backend secret key | Talos Terraform init scripts | terraform-prd |
| TF_VAR_s3_endpoint | S3-compatible endpoint URL for Terraform backend | Talos Terraform init scripts | http://10.0.10.10:9000 |
| OPNSENSE_URI | Base URL to OPNsense API | ingress-hostname-exporter app/chart | https://10.0.8.254 |
| OPNSENSE_KEY | OPNsense API key | ingress-hostname-exporter app/chart | ******** |
| OPNSENSE_SECRET | OPNsense API secret | ingress-hostname-exporter app/chart | ******** |
| OPNSENSE_SKIP_TLS_VERIFY | Skip TLS verification (self-signed certs) | ingress-hostname-exporter app/chart | true |

Notes:
- Only include what you actually use. Treat secrets carefully; do not commit .env.
- Some scripts allow overriding via direct flags or variables; see each folder’s README.

## Typical flow

1) Provision or prepare your Kubernetes nodes/cluster using the tooling under kubernetes/setup/ (see subfolder READMEs when present).
2) Bootstrap cluster essentials (CNI, GitOps such as Argo CD) as defined by your chosen setup under kubernetes/setup/.
3) Manage and deploy applications via Argo CD using definitions in kubernetes/apps/.
4) Build and publish images for any custom services under applications/ and update corresponding charts/manifests in kubernetes/apps/.

For details and troubleshooting, follow the linked READMEs above.
