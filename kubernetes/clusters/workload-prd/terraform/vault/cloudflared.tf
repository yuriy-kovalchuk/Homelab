resource "vault_kv_secret_v2" "cloudflared_tunnel" {
  mount               = "kubernetes"
  name                = "cloudflared/tunnel"
  delete_all_versions = true

  data_json = jsonencode({
    token = var.cloudflared_tunnel_token
  })
}
