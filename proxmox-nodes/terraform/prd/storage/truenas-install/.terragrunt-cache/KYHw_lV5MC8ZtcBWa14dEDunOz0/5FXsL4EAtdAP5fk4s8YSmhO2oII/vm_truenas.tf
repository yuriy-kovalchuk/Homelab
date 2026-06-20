resource "proxmox_virtual_environment_vm" "truenas" {
  name            = "truenas-scale"
  description     = "TrueNAS SCALE — managed by Terraform"
  tags            = ["terraform", "truenas"]
  node_name       = var.proxmox_node_name
  vm_id           = var.vm_id
  stop_on_destroy = true
  started         = true

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores = var.vm_cores
    type  = "host"
  }

  memory {
    dedicated = var.vm_memory
    floating  = var.vm_memory
  }

  efi_disk {
    datastore_id = var.proxmox_vm_datastore
    file_format  = "raw"
  }

  disk {
    datastore_id = var.proxmox_vm_datastore
    interface    = "scsi0"
    size         = var.vm_disk_size
    file_format  = "raw"
  }

  cdrom {
    file_id   = data.proxmox_virtual_environment_file.truenas_iso.id
    interface = "ide2"
  }

  boot_order = ["ide2", "scsi0"]

  network_device {
    bridge      = var.proxmox_network_bridge
    model       = "virtio"
    mac_address = "BC:24:11:19:5C:66"
  }

  vga {
    type   = "vmware"
    memory = 16
  }

  # PCIe passthrough — storage controller
  # ⚠️  Requires IOMMU enabled on the host. See README.md.
  hostpci {
    device = "hostpci0"
    id     = var.pcie_controller
    pcie   = true
    rombar = true
  }
}
