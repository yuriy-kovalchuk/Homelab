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

variable "tempo_s3_access_key" {
  type      = string
  sensitive = true
}

variable "tempo_s3_secret_key" {
  type      = string
  sensitive = true
}
