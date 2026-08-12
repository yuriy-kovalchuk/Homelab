variable "forgejo_admin_username" {
  type      = string
  sensitive = true
}

variable "forgejo_admin_password" {
  type      = string
  sensitive = true
}

variable "forgejo_admin_email" {
  type      = string
  sensitive = true
}

variable "forgejo_db_password" {
  description = "Password for the forgejo CNPG database user"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflared_tunnel_token" {
  type      = string
  sensitive = true
}

variable "opnsense_api_key" {
  type      = string
  sensitive = true
}

variable "opnsense_api_secret" {
  type      = string
  sensitive = true
}

variable "truenas_token" {
  description = "TrueNAS API token for democratic-csi"
  type        = string
  sensitive   = true
}

variable "kubevirt_ubuntu_test_username" {
  description = "Username for the default user in the ubuntu-test VM"
  type        = string
  sensitive   = true
}

variable "kubevirt_ubuntu_test_passwd" {
  description = "Password for the default user in the ubuntu-test VM"
  type        = string
  sensitive   = true
}

variable "rustfs_access_key" {
  description = "RustFS S3 access key (loki/mimir/tempo object storage)"
  type        = string
  sensitive   = true
}

variable "rustfs_secret_key" {
  description = "RustFS S3 secret key (loki/mimir/tempo object storage)"
  type        = string
  sensitive   = true
}

variable "grafana_admin_username" {
  type      = string
  sensitive = true
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "immich_db_password" {
  description = "Password for the immich CNPG database user"
  type        = string
  sensitive   = true
}

variable "opencloud_admin_password" {
  description = "Initial admin password for OpenCloud"
  type        = string
  sensitive   = true
}

variable "alertmanager_slack_webhook_url" {
  description = "Slack Incoming Webhook URL for Alertmanager notifications"
  type        = string
  sensitive   = true
}

