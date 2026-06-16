resource "vault_kv_secret_v2" "cert_manager_cloudflare" {
  mount               = "kubernetes"
  name                = "cert-manager/cloudflare"
  delete_all_versions = true

  data_json = jsonencode({
    api-token = var.cloudflare_api_token
  })
}
