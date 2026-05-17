terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.100"
    }
  }
}

provider "proxmox" {
  endpoint = var.storage_proxmox_endpoint
  username = var.storage_proxmox_username
  password = var.storage_proxmox_password
  insecure = true
}
