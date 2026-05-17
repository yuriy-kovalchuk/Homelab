terraform {
  required_version = ">= 1.5.0"

  required_providers {
    truenas = {
      source  = "bmanojlovic/truenas"
      version = "~> 0.0.35"
    }
  }
}

provider "truenas" {
  host  = var.truenas_host
  token = var.truenas_token
}
