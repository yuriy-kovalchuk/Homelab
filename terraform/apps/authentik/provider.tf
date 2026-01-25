terraform {
  required_providers {
    authentik = {
      source = "goauthentik/authentik"
      version = "2025.8.1"
    }
  }
}

provider "authentik" {
  url   = "https://authentik.yuriy-lab.cloud"
  token = var.authentik_token
}
