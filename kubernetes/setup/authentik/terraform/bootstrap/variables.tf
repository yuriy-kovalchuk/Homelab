variable "authentik_token" {
  description = "Authentik API token"
  type        = string
  sensitive   = true
}

variable "proxmox_provider_client_secret" {
  description = "Client secret for proxmox provider"
  type        = string
  sensitive   = true
}

variable "argocd_provider_client_secret" {
  description = "Client secret for argocd provider"
  type        = string
  sensitive   = true
}

variable "vault_provider_client_secret" {
  description = "Client secret for vault provider"
  type        = string
  sensitive   = true
}