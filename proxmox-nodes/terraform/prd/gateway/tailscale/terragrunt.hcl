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
    key = "proxmox-nodes/gateway/tailscale.tfstate"
  })
}

terraform {
  source = "../../../_modules/tailscale-vm"
}

inputs = {
  proxmox_endpoint  = get_env("GATEWAY_PROXMOX_ENDPOINT")
  proxmox_username  = get_env("GATEWAY_PROXMOX_USERNAME", "root@pam")
  proxmox_password  = get_env("GATEWAY_PROXMOX_PASSWORD")
  proxmox_node_name = "gateway"
}
