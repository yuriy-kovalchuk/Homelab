include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Depends on the harbor app in truenas-apps being up and serving — this stack
# talks to Harbor's REST API, not to TrueNAS.
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = merge(include.root.locals.s3, {
    key = "proxmox-nodes/storage/harbor-config.tfstate"
  })
}

terraform {
  source = "../../../_modules/harbor-config"
}

inputs = {
  harbor_url      = "https://harbor.yuriykovalchuk.dev"
  harbor_username = "admin"
  harbor_password = get_env("HARBOR_ADMIN_PASSWORD")
}
