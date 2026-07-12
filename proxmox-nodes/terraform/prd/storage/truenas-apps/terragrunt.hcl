include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Note: this stack manages the RustFS app hosting this same S3 backend, so
# an apply that restarts RustFS fails its final state save. Recovery:
#   terragrunt state push errored.tfstate && rm errored.tfstate
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = merge(include.root.locals.s3, {
    key = "proxmox-nodes/storage/truenas-apps.tfstate"
  })
}

terraform {
  source = "../../../_modules/truenas-apps"
}

inputs = {
  truenas_host                 = "10.0.3.3"
  truenas_token                = get_env("TRUENAS_TOKEN")
  truenas_ssh_private_key      = get_env("TRUENAS_SSH_PRIVATE_KEY")
  truenas_ssh_host_fingerprint = get_env("TRUENAS_SSH_HOST_FINGERPRINT")
  truenas_cf_email             = get_env("TRUENAS_CF_EMAIL")
  cloudflare_api_token         = get_env("TF_VAR_cloudflare_api_token")
  rustfs_access_key            = get_env("RUSTFS_ACCESS_KEY")
  rustfs_secret_key            = get_env("RUSTFS_SECRET_KEY")
  immich_db_password           = get_env("IMMICH_DB_PASSWORD")
  opencloud_admin_password     = get_env("OPENCLOUD_ADMIN_PASSWORD")
}
