terraform {
  required_version = ">= 1.5.0"

  required_providers {
    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.12"
    }
  }
}

provider "harbor" {
  url      = var.harbor_url
  username = var.harbor_username
  password = var.harbor_password

  # The provider defaults this to true. Harbor sits behind Traefik with a real
  # Let's Encrypt certificate, so there is no reason to skip verification.
  insecure = false
}
