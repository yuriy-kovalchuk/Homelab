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

variable "forgejo_runner_uuid" {
  description = "UUID for the forgejo-runner Actions runner connection (from Forgejo admin UI: /admin/actions/runners)"
  type        = string
  sensitive   = true
}

variable "forgejo_runner_token" {
  description = "Token for the forgejo-runner Actions runner connection (from Forgejo admin UI: /admin/actions/runners)"
  type        = string
  sensitive   = true
}

variable "forgejo_runner_talos_uuid" {
  description = "UUID for the forgejo-runner-talos Actions runner connection (from Forgejo admin UI: /admin/actions/runners)"
  type        = string
  sensitive   = true
}

variable "forgejo_runner_talos_token" {
  description = "Token for the forgejo-runner-talos Actions runner connection (from Forgejo admin UI: /admin/actions/runners)"
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


variable "netbox_secret_key" {
  description = "NetBox SECRET_KEY (50+ random characters)"
  type        = string
  sensitive   = true
}

variable "netbox_api_token_pepper" {
  description = "NetBox API token pepper (50+ random characters)"
  type        = string
  sensitive   = true
}

variable "netbox_superuser_username" {
  description = "NetBox superuser name"
  type        = string
  default     = "admin"
}

variable "netbox_superuser_password" {
  description = "NetBox superuser password"
  type        = string
  sensitive   = true
}

variable "netbox_superuser_email" {
  description = "NetBox superuser email"
  type        = string
}

variable "netbox_superuser_api_token" {
  description = "NetBox superuser API token (40 hex characters)"
  type        = string
  sensitive   = true
}

variable "netbox_db_password" {
  description = "Password for the netbox CNPG database user"
  type        = string
  sensitive   = true
}

variable "paperless_secret_key" {
  description = "Paperless-ngx PAPERLESS_SECRET_KEY (50+ random characters)"
  type        = string
  sensitive   = true
}

variable "paperless_admin_user" {
  description = "Paperless-ngx superuser name (created on first start only)"
  type        = string
  default     = "admin"
}

variable "paperless_admin_password" {
  description = "Paperless-ngx superuser password (created on first start only)"
  type        = string
  sensitive   = true
}

variable "paperless_admin_mail" {
  description = "Paperless-ngx superuser email"
  type        = string
}

variable "paperless_db_password" {
  description = "Password for the paperless CNPG database user"
  type        = string
  sensitive   = true
}
