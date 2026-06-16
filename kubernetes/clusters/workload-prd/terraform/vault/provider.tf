terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider "vault" {
  address = "https://vault.mgmt.yuriykovalchuk.dev"
  # Token sourced from VAULT_TOKEN environment variable
}
