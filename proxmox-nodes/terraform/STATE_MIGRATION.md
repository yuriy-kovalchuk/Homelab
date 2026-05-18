# Terraform State Migration

Guide for migrating Terraform modules from local state to the RustFS S3 backend running on docker-vm (`10.0.3.4:9000`).

Modules managed by Terragrunt have their backend generated automatically — no manual `backend.tf` needed. Modules still using plain Terraform need the manual step.

## Prerequisites

- RustFS running on docker-vm (deployed via `ansible/files/compose/rustfs/`)
- Devbox shell active (auto-exports `AWS_*` vars from `.env`)

## 1. Configure .env

Add to `.env` at repo root (see `terraform/prd/.env.example`):

```bash
export TF_VAR_s3_endpoint="http://10.0.3.4:9000"
export TF_VAR_s3_access_key="<access-key>"
export TF_VAR_s3_secret_key="<secret-key>"
```

The devbox shell re-exports these as `AWS_ENDPOINT_URL_S3`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY` automatically, so every `terraform` and `terragrunt` command picks them up.

## 2. Create the bucket

Open the RustFS console at **http://10.0.3.4:9001** and create a bucket named **`terraform-prd`**.

CLI alternative:
```bash
mc alias set rustfs http://10.0.3.4:9000 $TF_VAR_s3_access_key $TF_VAR_s3_secret_key
mc mb rustfs/terraform-prd
mc ls rustfs
```

## 3. State file layout

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

## 4. Migrate a Terragrunt module

Terragrunt generates `backend.tf` automatically on first run. To migrate from local state:

```bash
cd proxmox-nodes/terraform/prd/<node>/<module>
terragrunt init -migrate-state   # answer "yes" to copy local state to S3
terragrunt plan                   # must show: No changes
```

## 5. Migrate a plain Terraform module

For modules not yet using Terragrunt, add a `backend.tf` manually:

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

> Do not use variable interpolation in backend blocks — Terraform forbids it.
> Credentials come from the environment variables exported by devbox.

Then migrate:
```bash
terraform init -migrate-state
terraform plan   # must show: No changes
```

## Module checklist

| Module | Path | S3 key | Status |
|--------|------|--------|--------|
| OPNsense | `terraform/prd/gateway/` | `proxmox-nodes/gateway/opnsense.tfstate` | ✅ |
| TrueNAS install | `terraform/prd/storage/truenas-install/` | `proxmox-nodes/storage/truenas-install.tfstate` | ✅ |
| TrueNAS setup | `terraform/prd/storage/truenas-setup/` | `proxmox-nodes/storage/truenas-setup.tfstate` | ✅ |
| Docker VM | `terraform/prd/storage/docker-vm/` | `proxmox-nodes/storage/docker-vm.tfstate` | ✅ |
| Talos | `management-cluster/terraform/00_talos/` | `management-cluster/talos.tfstate` | ☐ |
| CNI | `management-cluster/terraform/01-cni/` | `management-cluster/cni.tfstate` | ☐ |
| FluxCD | `management-cluster/terraform/02-fluxcd/` | `management-cluster/fluxcd.tfstate` | ☐ |
