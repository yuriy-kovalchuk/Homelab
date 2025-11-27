variable "s3_access_key" {
  description = "Access key for S3/MinIO backend"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "Secret key for S3/MinIO backend"
  type        = string
  sensitive   = true
}

variable "s3_endpoint" {
  description = "Endpoint for S3/MinIO backend"
  type        = string
  sensitive   = true
}

variable "cilium_version" {
  default = ""
  type = string
}

variable "argocd_version" {
  default = ""
  type = string
}

variable "metrics_server_version" {
  default = ""
}