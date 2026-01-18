data "proxmox_virtual_environment_file" "truenas_iso" {
  node_name    = "maya"
  datastore_id = "local"
  content_type = "iso"
  file_name    = "trueNAS.iso"
}
resource "proxmox_virtual_environment_vm" "truenas_vm" {
  name        = "truenas-scale"
  description = "TrueNAS managed by Terraform"
  node_name   = "maya"
  vm_id       = 1000
  started     = true
  cpu {
    cores = 2
    type  = "host" 
  }

  memory {
    dedicated = 8192
  }

  # Required for modern TrueNAS SCALE installations
  bios = "ovmf"


  efi_disk {
    datastore_id = "local-lvm" # Storage for EFI vars
    file_format  = "raw"
  }

  # The Boot ISO
  cdrom {
    enabled  = false # set to true during the first run 
    file_id  = data.proxmox_virtual_environment_file.truenas_iso.id
    interface = "ide2"
  }

  # OS Boot Drive
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    file_format  = "raw"
  }
# Ensure the machine type is q35 for better PCIe support
  machine = "q35"

  hostpci {
    # The PCI ID of your NVMe (e.g., 0000:01:00.0)
    device = "hostpci0"
    id   = "0000:03:00.0" 
    pcie = true
    rombar = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
    mac_address = "BC:24:11:19:5C:66" # reserve a lease in opnsense
  }

  operating_system {
    type = "l26" # Linux 2.6+ kernel
  }

  # Set boot order to ensure ISO boots first for installation
  # boot_order = ["ide2", "scsi0"]
  boot_order = ["scsi0"]




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
