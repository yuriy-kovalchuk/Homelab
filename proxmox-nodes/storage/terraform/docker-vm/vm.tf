resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  node_name    = var.storage_proxmox_node_name
  datastore_id = var.storage_proxmox_iso_datastore
  file_name    = "ubuntu-24.04-cloud-amd64.img"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

resource "proxmox_virtual_environment_vm" "docker_vm" {
  name            = "docker-vm"
  description     = "Ubuntu 24.04 VM with Docker — managed by Terraform"
  tags            = ["terraform", "docker", "ubuntu"]
  node_name       = var.storage_proxmox_node_name
  vm_id           = var.docker_vm_id
  started         = true
  stop_on_destroy = true

  agent {
    enabled = false
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = var.storage_proxmox_vm_datastore
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
    interface    = "scsi0"
    size         = 10
    file_format  = "raw"
    discard      = "on"
  }

  network_device {
    bridge = var.storage_proxmox_network_bridge
    model  = "virtio"
  }

  initialization {
    datastore_id = var.storage_proxmox_vm_datastore

    ip_config {
      ipv4 {
        address = "${var.docker_vm_ip}/24"
        gateway = "10.0.3.1"
      }
    }

    dns {
      servers = ["10.0.3.1"]
    }

    user_account {
      username = "ubuntu"
      keys     = [file(var.docker_vm_ssh_key_path)]
    }
  }
}
