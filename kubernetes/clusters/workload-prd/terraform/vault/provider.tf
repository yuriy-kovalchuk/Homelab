terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
  address = "https://vault.mgmt.yuriy-lab.cloud"
  # Token sourced from VAULT_TOKEN environment variable
}
