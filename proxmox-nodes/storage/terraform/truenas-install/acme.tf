resource "proxmox_virtual_environment_acme_account" "prod" {
  name      = "production"
  contact   = var.acme_email
  directory = "https://acme-v02.api.letsencrypt.org/directory"
  tos       = "https://letsencrypt.org/documents/LE-SA-v1.3-September-21-2022.pdf"
}

resource "proxmox_virtual_environment_acme_dns_plugin" "cloudflare" {
  plugin = "cf-dns"
  api    = "cf"

  data = {
    CF_Token      = var.acme_cf_token
    CF_Account_ID = var.acme_cf_account_id
  }
}

resource "proxmox_virtual_environment_acme_certificate" "prod" {
  node_name = var.storage_proxmox_node_name
  account   = proxmox_virtual_environment_acme_account.prod.name
  force     = false

  domains = [
    {
      domain = var.storage_acme_domain
      plugin = proxmox_virtual_environment_acme_dns_plugin.cloudflare.plugin
    }
  ]

  depends_on = [
    proxmox_virtual_environment_acme_account.prod,
    proxmox_virtual_environment_acme_dns_plugin.cloudflare,
  ]
}
