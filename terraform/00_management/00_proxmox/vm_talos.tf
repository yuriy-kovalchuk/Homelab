resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.proxmox_iso_datastore
  node_name    = var.proxmox_node_name

  # Talos Linux ISO (Metal - AMD64)
  url       = "https://factory.talos.dev/image/${var.talos_image_schematic_id}/v${var.talos_version}/nocloud-amd64.iso"
  file_name = "talos-v${var.talos_version}-amd64.iso"
}


resource "proxmox_virtual_environment_vm" "talos_vm" {
  name        = var.talos_vm_name
  description = var.talos_vm_description
  node_name   = var.proxmox_node_name
  vm_id       = var.talos_vm_id

  cpu {
    cores = var.talos_vm_cpu_cores
    type  = "host" # Recommended for Talos performance
  }

  memory {
    dedicated = var.talos_vm_memory
  }

  # Talos runs best with modern UEFI
  bios = "ovmf"

  machine = "q35"

  # Talos doesn't use a traditional 'installer' once set up,
  # but you start by booting the Talos ISO.
  cdrom {
    enabled   = true
    file_id   = proxmox_virtual_environment_download_file.talos_iso.id
    interface = "ide2"
  }

  efi_disk {
    datastore_id = var.proxmox_vm_datastore
    file_format  = "raw"
  }

  # Main OS disk
  disk {
    datastore_id = var.proxmox_vm_datastore
    interface    = "scsi0"
    size         = var.talos_vm_disk_size
    file_format  = "raw"
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge      = var.proxmox_network_bridge
    model       = "virtio"
    mac_address = var.talos_vm_mac_address
  }

  operating_system {
    type = "l26" # Linux 2.6+ kernel
  }


  # Ensure the disk is the first boot priority after installation
  boot_order = ["scsi0", "ide2"]

  started = true

  # LIFECYCLE: This is the most important part for stability
  lifecycle {
    ignore_changes = [
      # Ignore network changes that Talos handles internally
      network_device,
      # Ignore the manual start/stop state if you manage it via talosctl
      started,
      # Ignore the description if it gets modified by the Guest Agent
      description,
      initialization,
    ]
  }
}
