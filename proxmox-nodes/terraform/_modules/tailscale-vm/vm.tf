resource "proxmox_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  node_name    = var.proxmox_node_name
  datastore_id = var.proxmox_iso_datastore
  file_name    = "ubuntu-24.04-cloud-amd64.img"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

# Tailscale subnet router. Its only NIC is an access port on the remote-access
# VLAN of vmbr1, so it reaches the rest of the lab only through OPNsense.
resource "proxmox_virtual_environment_vm" "tailscale" {
  name            = "tailscale"
  description     = "Tailscale subnet router (remote access) — managed by Terraform"
  tags            = ["terraform", "tailscale", "ubuntu"]
  node_name       = var.proxmox_node_name
  vm_id           = var.vm_id
  started         = true
  on_boot         = true
  stop_on_destroy = true

  # No guest agent and no passthrough: minimal surface between guest and host
  agent {
    enabled = false
  }

  cpu {
    cores = 1
    type  = "host"
  }

  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = var.proxmox_vm_datastore
    file_id      = proxmox_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 8
    file_format  = "raw"
    discard      = "on"
  }

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.vlan_id
    model   = "virtio"
  }

  initialization {
    datastore_id = var.proxmox_vm_datastore

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/24"
        gateway = var.vm_gateway
      }
    }

    dns {
      servers = [var.vm_gateway]
    }

    user_account {
      username = "ubuntu"
      keys     = [file(var.vm_ssh_key_path)]
    }
  }
}
