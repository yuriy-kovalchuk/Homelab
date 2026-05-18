output "vm_id" {
  description = "OPNsense VM ID"
  value       = proxmox_virtual_environment_vm.opnsense.vm_id
}

output "next_steps" {
  description = "Manual steps after apply"
  value       = "Open Proxmox console for VM ${var.vm_id} and complete the OPNsense installer. WAN = vtnet0 (${var.wan_bridge}), LAN = vtnet1 (${proxmox_network_linux_bridge.lan.name}). After install, detach the CDROM and reboot."
}
