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
    key = "proxmox-nodes/tailscale-bootstrap.tfstate"
  })
}

terraform {
  source = "../../_modules/tailscale-oauth-client"
}
