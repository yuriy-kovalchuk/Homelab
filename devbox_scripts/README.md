# Devbox Scripts

This folder contains helper scripts that are meant to be run via Devbox. Each script is exposed as a `devbox run` command configured in `devbox.json`.

Quick start:
- Install Devbox and enter the shell: `devbox shell`
- List scripts below and invoke them using `devbox run <script-name>`

The Devbox shell `init_hook` (see `devbox.json`) does the following:
- `chmod +x devbox_scripts/*` to ensure scripts are executable
- `export $(cat .env | xargs)` to export environment variables from `.env`
- `source devbox_scripts/tf_functions.sh` to load Terraform helper functions

## Terraform Functions

These are shell functions loaded into your devbox shell. Run them directly (not via `devbox run`):

| Function | Description |
|----------|-------------|
| `tf_init` | Initialize terraform with S3 backend credentials |
| `tf_plan` | Run terraform plan (auto-detects tfvars) |
| `tf_apply` | Run terraform apply (auto-detects tfvars) |
| `tf_output [name]` | Print terraform outputs (auto-detects common outputs) |
| `upgrade_talos` | Upgrade Talos nodes (run from clusters/main) |

**Usage:**
```bash
cd terraform/clusters/main
tf_init
tf_plan
tf_apply
```

The functions auto-detect `vars/terraform.tfvars` or `terraform.tfvars` and pass them to terraform.

## Devbox Run Commands

These are configured in `devbox.json` under `shell.scripts`:

| Command | Script |
|---------|--------|
| `devbox run k_argo_app` | `./devbox_scripts/new_app.sh` |
| `devbox run k_ss_create` | `./devbox_scripts/create_sealed_secret.sh` |
| `devbox run k-token` | Get Headlamp admin token |

## Script Details

### new_app.sh

Scaffolds a new Kubernetes app folder from `kubernetes/apps/_template`.

**Usage:**
```bash
devbox run k_argo_app <app-name> [options]
```

**Options:**
- `--namespace <ns>` - Override namespace (default: same as app name)
- `--no-templates` - Remove manifest/templates folder
- `--repo-url <url>` - Override `.spec.source.repoURL`
- `--dry-run` - Show what would be done

**Examples:**
```bash
devbox run k_argo_app myapp
devbox run k_argo_app myapp --namespace myns --no-templates
```

### create_sealed_secret.sh

Creates a SealedSecret manifest from given inputs using `kubectl` and `kubeseal`. Outputs to stdout.

**Usage:**
```bash
devbox run k_ss_create <secret-name> <secret-key> <secret-value> <namespace>
```

**Examples:**
```bash
# Output to file
devbox run k_ss_create vault-token token "hvs.xxx" external-secrets > sealed-secret.yaml

# Apply directly
devbox run k_ss_create vault-token token "hvs.xxx" external-secrets | kubectl apply -f -
```

**Prerequisites:**
- Access to a cluster with Sealed Secrets controller installed
- `kubectl` and `kubeseal` available (provided by Devbox)

## Notes

- Enter `devbox shell` to ensure required tools (kubectl, helm, kubeseal, terraform, talosctl, etc.) are available
- The shell exports variables from `.env` on entry; keep secrets safe and don't commit `.env`
- Terraform functions require `TF_VAR_s3_*` environment variables for backend initialization
