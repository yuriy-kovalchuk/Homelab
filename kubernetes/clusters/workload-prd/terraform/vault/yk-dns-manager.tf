resource "vault_kv_secret_v2" "yk_dns_manager_opnsense" {
  mount               = "kubernetes"
  name                = "yk-dns-manager/opnsense"
  delete_all_versions = true

  data_json = jsonencode({
    OPNSENSE_API_KEY    = var.opnsense_api_key
    OPNSENSE_API_SECRET = var.opnsense_api_secret
  })
}
