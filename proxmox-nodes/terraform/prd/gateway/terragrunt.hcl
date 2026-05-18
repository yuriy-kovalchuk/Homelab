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
    key = "proxmox-nodes/gateway/opnsense.tfstate"
  })
}

terraform {
  source = "../../_modules/opnsense"
}

inputs = {
  proxmox_endpoint     = get_env("GATEWAY_PROXMOX_ENDPOINT")
  proxmox_password     = get_env("GATEWAY_PROXMOX_PASSWORD")
  proxmox_node_name    = "gateway"
  proxmox_vm_datastore = "local-lvm"
  vm_id                = 1001
  vm_name              = "opnsense"
  vm_memory            = 8196
  vm_cores             = 2
  vm_disk_size         = 32
  wan_bridge           = "vmbr0"
  lan_bridge           = "vmbr1"
  lan_bridge_port      = "nic3"
  opnsense_iso_file_id = "local:iso/OPNsense-26.1.6-dvd-amd64.iso"
}
