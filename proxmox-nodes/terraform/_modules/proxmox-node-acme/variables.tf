variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
  sensitive   = true
}

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node_name" {
  description = "Name of the Proxmox node"
  type        = string
}

variable "acme_email" {
  description = "ACME email for the Let's Encrypt account"
  type        = string
  sensitive   = true
}

variable "acme_cf_account_id" {
  description = "Cloudflare account ID for DNS challenge"
  type        = string
  sensitive   = true
}

variable "acme_cf_token" {
  description = "Cloudflare API token for DNS challenge"
  type        = string
  sensitive   = true
}

variable "acme_domain" {
  description = "Domain for the Proxmox node certificate (e.g. firewall.yuriy-lab.cloud)"
  type        = string
}
