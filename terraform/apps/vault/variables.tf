# Vault Connection
variable "vault_address" {
  type    = string
  default = "https://vault-intra.yuriy-lab.cloud"
}

variable "vault_token" {
  type      = string
  sensitive = true
}

# S3 Backend
variable "s3_endpoint" {
  type = string
}

variable "s3_access_key" {
  type      = string
  sensitive = true
}

variable "s3_secret_key" {
  type      = string
  sensitive = true
}

# ============================================================================
# Secrets - prd
# ============================================================================

variable "cloudflare_token" {
  type      = string
  sensitive = true
}

# ============================================================================
# Secrets - prd/authentik
# ============================================================================

variable "authentik_pg_user" {
  type      = string
  sensitive = true
}

variable "authentik_pg_password" {
  type      = string
  sensitive = true
}

variable "authentik_admin_password" {
  type      = string
  sensitive = true
}

# ============================================================================
# Secrets - prd/grafana
# ============================================================================

variable "grafana_admin_user" {
  type      = string
  sensitive = true
}

variable "grafana_admin_password" {
  type      = string
  sensitive = true
}

variable "grafana_client_id" {
  type      = string
  sensitive = true
}

variable "grafana_client_secret" {
  type      = string
  sensitive = true
}

# ============================================================================
# Secrets - prd/minio
# ============================================================================

variable "minio_s3_access_key" {
  type      = string
  sensitive = true
}

variable "minio_s3_secret_key" {
  type      = string
  sensitive = true
}

variable "minio_root_user" {
  type      = string
  sensitive = true
}

variable "minio_root_password" {
  type      = string
  sensitive = true
}

# ============================================================================
# Secrets - prd/mimir
# ============================================================================

variable "mimir_access_key" {
  type      = string
  sensitive = true
}

variable "mimir_secret_key" {
  type      = string
  sensitive = true
}

# ============================================================================
# Secrets - prd/opnsense
# ============================================================================

variable "opnsense_secret" {
  type      = string
  sensitive = true
}

# ============================================================================
# Secrets - prd/democratic-csi
# ============================================================================

variable "truenas_api_key" {
  type      = string
  sensitive = true
}
