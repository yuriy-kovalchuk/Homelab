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
    key = "proxmox-nodes/storage/truenas-setup.tfstate"
  })
}

terraform {
  source = "../../../_modules/truenas-setup"
}

inputs = {
  truenas_host                 = "10.0.3.3"
  truenas_pool_name            = "tank"
  truenas_ssh_private_key      = get_env("TRUENAS_SSH_PRIVATE_KEY")
  truenas_ssh_host_fingerprint = get_env("TRUENAS_SSH_HOST_FINGERPRINT")
}
