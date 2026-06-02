variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type      = string
  sensitive = true
}

variable "cloudflare_zone_id_yuriykovalchuk_dev" {
  description = "Zone ID for yuriykovalchuk.dev — dash.cloudflare.com → select zone → Overview → right sidebar"
  type        = string
  sensitive   = true
}
