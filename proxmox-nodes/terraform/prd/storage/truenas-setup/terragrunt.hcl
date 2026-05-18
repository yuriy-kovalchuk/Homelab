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
  truenas_host              = "10.0.3.3"
  truenas_token             = get_env("TRUENAS_TOKEN")
  truenas_pool_name         = "tank"
  truenas_pool_disks        = ["nvme0n1"]
  truenas_nas_username      = get_env("TRUENAS_NAS_USERNAME")
  truenas_nas_user_password = get_env("TRUENAS_NAS_USER_PASSWORD")
  nfs_general_quota_bytes   = 107374182400 # 100 GiB
  smb_general_quota_bytes   = 107374182400 # 100 GiB
}
