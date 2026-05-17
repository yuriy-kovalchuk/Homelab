# Terraform State Migration

Plan for migrating all Terraform modules from local state to RustFS S3 backend running on the docker-vm (`10.0.3.4:9000`).

Each module is migrated **one at a time** — create the `backend.tf`, run `tf_init`, verify, then commit. This keeps each migration as a discrete, reviewable git commit.

All modules share a single bucket `terraform-prd` (production environment). State files are organized by node/cluster under subfolders matching the repo layout.

## Prerequisites

- RustFS running on docker-vm (deployed via `compose/rustfs/`)
- `RUSTFS_ACCESS_KEY` and `RUSTFS_SECRET_KEY` from `compose/rustfs/.env`
- Global `.env` at the repo root configured (see below)

## 1. Configure global .env

Add to the global `.env` at the repo root:

```bash
TF_VAR_s3_endpoint="http://10.0.3.4:9000"
TF_VAR_s3_access_key="<RUSTFS_ACCESS_KEY>"
TF_VAR_s3_secret_key="<RUSTFS_SECRET_KEY>"
```

These are picked up automatically by `tf_init` in the devbox shell.

## 2. Create the bucket

Open the RustFS console at **http://10.0.3.4:9001** and log in with the credentials from `compose/rustfs/.env`.

Create a single bucket named **`terraform-prd`**.

> **CLI alternative** — add `minio-client` to `devbox.json`, then:
> ```bash
> mc alias set rustfs http://10.0.3.4:9000 $TF_VAR_s3_access_key $TF_VAR_s3_secret_key
> mc mb rustfs/terraform-prd
> mc ls rustfs
> ```

## 3. State file layout

All state files live inside `terraform-prd`, organized by the node or cluster where the Terraform runs:

```
terraform-prd/
  proxmox-nodes/
    gateway/
      opnsense.tfstate
    storage/
      truenas-install.tfstate
      truenas-setup.tfstate
      docker-vm.tfstate
  management-cluster/
    talos.tfstate
    cni.tfstate
    fluxcd.tfstate
```

## 4. Migrate one module at a time

For each module in the checklist below:

### Step 1 — Add or fix backend.tf

If the module already has a `backend.tf`, open it and remove any lines referencing
`var.s3_endpoint`, `var.s3_access_key`, or `var.s3_secret_key`. Terraform forbids
variable interpolation in backend blocks. Endpoint and credentials are provided
automatically via `AWS_ENDPOINT_URL_S3`, `AWS_ACCESS_KEY_ID`, and
`AWS_SECRET_ACCESS_KEY`, which the devbox shell exports from `TF_VAR_s3_*` on startup.
They apply to every Terraform command — init, plan, and apply.

If the module has no `backend.tf`, create one using the template below, substituting the
correct key from the layout in section 3.

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-prd"
    key    = "<node-path>/<module>.tfstate"
    region = "eu-south-1"

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
```

### Step 2 — Migrate state

```bash
cd <module-directory>
tf_init -migrate-state   # answer "yes" when prompted to copy existing state
```

### Step 3 — Verify

```bash
tf_plan   # must show: No changes
```

### Step 4 — Commit

```bash
git add backend.tf
git commit -m "chore: migrate <module> state to RustFS S3"
```

## Module checklist

| Module | Path | S3 key | Status |
|--------|------|--------|--------|
| OPNsense | `proxmox-nodes/gateway/terraform/opnsense/` | `proxmox-nodes/gateway/opnsense.tfstate` | ☐ |
| TrueNAS install | `proxmox-nodes/storage/terraform/truenas-install/` | `proxmox-nodes/storage/truenas-install.tfstate` | ☐ |
| TrueNAS setup | `proxmox-nodes/storage/terraform/truenas-setup/` | `proxmox-nodes/storage/truenas-setup.tfstate` | ☐ |
| Docker VM | `proxmox-nodes/storage/terraform/docker-vm/` | `proxmox-nodes/storage/docker-vm.tfstate` | ☐ |
| Talos | `management-cluster/terraform/00_talos/` | `management-cluster/talos.tfstate` | ☐ |
| CNI | `management-cluster/terraform/01-cni/` | `management-cluster/cni.tfstate` | ☐ |
| FluxCD | `management-cluster/terraform/02-fluxcd/` | `management-cluster/fluxcd.tfstate` | ☐ |

Mark each ☑ once `tf_init` migration completes and `tf_plan` shows no changes.
