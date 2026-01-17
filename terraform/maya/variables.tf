variable "acme_email" {
  description = "ACME email used to create a default account"
  type        = string
  sensitive   = true
}

variable "acme_cf_account_id" {
  type      = string
  sensitive = true
}

variable "acme_cf_token" {
  type      = string
  sensitive = true
}

