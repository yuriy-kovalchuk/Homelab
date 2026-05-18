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
    key = "proxmox-nodes/storage/docker-vm.tfstate"
  })
}

terraform {
  source = "../../../_modules/docker-vm"
}

inputs = {
  proxmox_endpoint       = get_env("STORAGE_PROXMOX_ENDPOINT")
  proxmox_password       = get_env("STORAGE_PROXMOX_PASSWORD")
  proxmox_node_name      = "storage"
  proxmox_iso_datastore  = "local"
  proxmox_vm_datastore   = "local-lvm"
  proxmox_network_bridge = "vmbr0"
  vm_id                  = 200
  vm_ip                  = "10.0.3.4"
  vm_ssh_key_path        = "~/.ssh/homelab_ed25519.pub"
}
