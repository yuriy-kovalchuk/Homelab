output "vm_id" {
  description = "TrueNAS VM ID"
  value       = proxmox_virtual_environment_vm.truenas.vm_id
}

output "next_steps" {
  description = "Manual steps after apply"
  value       = "Open Proxmox console for VM ${var.vm_id} and complete the TrueNAS SCALE installer. Select scsi0 as the boot disk. After install, set static IP 10.0.3.3 in TrueNAS (Network → Interfaces) and detach the CDROM."
}
