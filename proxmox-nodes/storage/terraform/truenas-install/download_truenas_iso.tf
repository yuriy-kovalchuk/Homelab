data "proxmox_virtual_environment_file" "truenas_iso" {
  content_type = "iso"
  datastore_id = var.storage_proxmox_iso_datastore
  file_name    = "truenas-scale-25.10.2.1.iso"
  node_name    = var.storage_proxmox_node_name
}
