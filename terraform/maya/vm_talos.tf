resource "proxmox_virtual_environment_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "maya"

  # Talos Linux ISO (Metal - AMD64)
  # You can update the version number in the URL as needed
  url       = "https://factory.talos.dev/image/70d243b7e2cbe699e4db5e73356a2add6b4bb8e34eadba9db22c823110e79099/v1.12.1/nocloud-amd64.iso"
  file_name = "talos-v1.12.1-amd64.iso"

}


resource "proxmox_virtual_environment_vm" "talos_vm" {
  name        = "management-talos-01"
  description = "Talos Linux node managed by Terraform"
  node_name   = "maya"
  vm_id       = 1100

  cpu {
    cores = 2
    type  = "host" # Recommended for Talos performance
  }

  memory {
    dedicated = 4096 # Talos is lightweight; 4GB is plenty for most roles
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
    datastore_id = "local-lvm"
    file_format  = "raw"
  }

  # Main OS disk
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 40
    file_format  = "raw"
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
    mac_address = "BC:24:11:1A:26:95"
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
