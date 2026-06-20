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
    key = "proxmox-nodes/storage/truenas-install.tfstate"
  })
}

terraform {
  source = "../../../_modules/truenas-install"
}

inputs = {
  proxmox_endpoint       = get_env("STORAGE_PROXMOX_ENDPOINT")
  proxmox_password       = get_env("STORAGE_PROXMOX_PASSWORD")
  proxmox_node_name      = "storage"
  proxmox_iso_datastore  = "local"
  proxmox_vm_datastore   = "local-lvm"
  proxmox_network_bridge = "vmbr0"
  vm_id                  = 1000
  vm_cores               = 3
  vm_memory              = 12000
  vm_disk_size           = 32
  pcie_controller        = get_env("STORAGE_PCIE_CONTROLLER")
  acme_email             = get_env("ACME_EMAIL")
  acme_cf_account_id     = get_env("ACME_CF_ACCOUNT_ID")
  acme_cf_token          = get_env("ACME_CF_TOKEN")
  acme_domain            = get_env("STORAGE_ACME_DOMAIN")
}
