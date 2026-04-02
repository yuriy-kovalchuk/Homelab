resource "proxmox_virtual_environment_vm" "truenas_vm" {
  name        = "truenas-scale"
  description = "TrueNAS managed by Terraform"
  node_name   = "gaia"
  vm_id       = 1000
  started     = true
  cpu {
    cores = 2
    type  = "host"
  }

  boot_order = ["ide2", "scsi0"]

  vga {
    type   = "vmware"
    memory = 16
  }

  memory {
    dedicated = 8192
    floating  = 8192
  }

  bios = "ovmf"

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
  }


  cdrom {
    #file_id   = "none"
    file_id   = proxmox_download_file.download_truenas_iso.id
    interface = "ide2"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    file_format  = "raw"
  }
  machine = "q35"


  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:19:5C:66" # reserve a lease in opnsense
  }

  # -------- DANGER ZONE ------------
  hostpci {
    device = "hostpci0"
    id     = "0000:04:00.0"
    pcie   = true
    rombar = true
  }

}
