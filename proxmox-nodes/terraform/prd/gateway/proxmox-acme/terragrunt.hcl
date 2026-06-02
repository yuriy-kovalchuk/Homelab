include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = merge(include.root.locals.s3, {
    key = "proxmox-nodes/gateway/proxmox-acme.tfstate"
  })
}

terraform {
  source = "../../../_modules/proxmox-node-acme"
}

inputs = {
  proxmox_endpoint  = get_env("GATEWAY_PROXMOX_ENDPOINT")
  proxmox_password  = get_env("GATEWAY_PROXMOX_PASSWORD")
  proxmox_node_name = "gateway"
  acme_email        = get_env("ACME_EMAIL")
  acme_cf_account_id = get_env("ACME_CF_ACCOUNT_ID")
  acme_cf_token     = get_env("ACME_CF_TOKEN")
  acme_domain       = get_env("GATEWAY_ACME_DOMAIN")
}
