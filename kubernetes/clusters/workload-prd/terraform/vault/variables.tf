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

