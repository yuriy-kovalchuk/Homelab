terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.100.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://10.0.2.50:8006/"
  insecure = true
}
