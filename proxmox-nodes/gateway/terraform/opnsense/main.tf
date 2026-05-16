resource "proxmox_network_linux_bridge" "lan" {
  node_name  = var.proxmox_node_name
  name       = var.lan_bridge
  comment    = "Production LAN 10.0.0.0/16 — VLAN-aware, managed by OPNsense"
  autostart  = true
  vlan_aware = true
  ports      = [var.lan_bridge_port]
}

resource "proxmox_virtual_environment_vm" "opnsense" {
  name            = var.vm_name
  description     = "OPNsense firewall/router — managed by Terraform"
  tags            = ["terraform", "opnsense"]
  node_name       = var.proxmox_node_name
  vm_id           = var.vm_id
  stop_on_destroy = true

  depends_on = [proxmox_network_linux_bridge.lan]

  cpu {
    cores   = var.vm_cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = var.vm_memory
  }

  disk {
    datastore_id = var.proxmox_vm_datastore
    interface    = "virtio0"
    size         = var.vm_disk_size
    file_format  = "raw"
    iothread     = true
    discard      = "on"
  }

  cdrom {
    file_id   = var.opnsense_iso_file_id
    interface = "ide2"
  }

  # WAN — uplink to home router
  network_device {
    bridge   = var.wan_bridge
    model    = "virtio"
    firewall = false
  }

  # LAN — internal homelab network
  network_device {
    bridge   = proxmox_network_linux_bridge.lan.name
    model    = "virtio"
    firewall = false
  }

  operating_system {
    type = "other"
  }

  boot_order = ["ide2", "virtio0"]

  vga {
    type = "std"
  }
}

output "vm_id" {
  description = "OPNsense VM ID"
  value       = proxmox_virtual_environment_vm.opnsense.vm_id
}

output "next_steps" {
  description = "Manual steps after apply"
  value       = "Open Proxmox console for VM ${var.vm_id} and complete the OPNsense installer. WAN = vtnet0 (${var.wan_bridge}), LAN = vtnet1 (${proxmox_network_linux_bridge.lan.name}). After install, detach the CDROM and reboot."
}
