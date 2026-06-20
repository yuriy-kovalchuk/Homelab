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

variable "cloudflare_api_token" {
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

