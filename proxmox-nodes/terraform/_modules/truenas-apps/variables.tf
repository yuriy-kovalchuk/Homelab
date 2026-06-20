variable "truenas_host" {
  description = "TrueNAS host IP or hostname"
  type        = string
  default     = "10.0.3.3"
}

variable "truenas_token" {
  description = "TrueNAS API token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "truenas_ssh_private_key" {
  description = "SSH private key content for TrueNAS root access"
  type        = string
  sensitive   = true
}

variable "truenas_ssh_host_fingerprint" {
  description = "SHA256 host key fingerprint — get via: ssh-keyscan 10.0.3.3 2>/dev/null | ssh-keygen -lf -"
  type        = string
}

variable "truenas_cf_email" {
  description = "Email for Let's Encrypt ACME registration"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions for yuriykovalchuk.dev (used by Traefik for ACME DNS-01 challenge)"
  type        = string
  sensitive   = true
}

variable "rustfs_access_key" {
  description = "RustFS S3 admin access key"
  type        = string
  sensitive   = true
}

variable "rustfs_secret_key" {
  description = "RustFS S3 admin secret key"
  type        = string
  sensitive   = true
}

variable "immich_db_password" {
  description = "PostgreSQL password for Immich database"
  type        = string
  sensitive   = true
}

variable "opencloud_admin_password" {
  description = "Initial admin password for OpenCloud"
  type        = string
  sensitive   = true
}
