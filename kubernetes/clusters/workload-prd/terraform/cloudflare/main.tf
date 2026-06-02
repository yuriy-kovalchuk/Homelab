resource "cloudflare_tunnel" "homelab" {
  account_id = var.cloudflare_account_id
  name       = "homelab-workload-prd"
  secret     = random_id.tunnel_secret.b64_std
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_tunnel_config" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.homelab.id

  config {
    ingress_rule {
      hostname = "whoami.yuriykovalchuk.dev"
      service  = "http://10.0.4.51"
    }

    # Default catch-all — required by Cloudflare
    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "whoami" {
  zone_id = var.cloudflare_zone_id_yuriykovalchuk_dev
  name    = "whoami"
  type    = "CNAME"
  value   = "${cloudflare_tunnel.homelab.id}.cfargotunnel.com"
  proxied = true
}

resource "vault_kv_secret_v2" "cloudflared_tunnel" {
  mount               = "kubernetes"
  name                = "cloudflared/tunnel"
  delete_all_versions = true
  data_json = jsonencode({
    token     = cloudflare_tunnel.homelab.tunnel_token
    tunnel_id = cloudflare_tunnel.homelab.id
  })
}
