terraform {
  required_version = ">= 1.5.0"

  required_providers {
    truenas = {
      source  = "deevus/truenas"
      version = "~> 0.16"
    }
  }
}

provider "truenas" {
  host        = var.truenas_host
  auth_method = "ssh"

  ssh {
    user                 = "root"
    private_key          = var.truenas_ssh_private_key
    host_key_fingerprint = var.truenas_ssh_host_fingerprint
  }
}
