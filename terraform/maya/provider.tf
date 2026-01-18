terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.93.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://10.0.2.2:8006/"
  insecure = true
}
