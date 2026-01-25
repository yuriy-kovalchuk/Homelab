data "proxmox_virtual_environment_time" "first_node_time" {
  node_name = "maya"
}

output "test" {
  value = data.proxmox_virtual_environment_time.first_node_time
}
