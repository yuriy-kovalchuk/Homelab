resource "authentik_service_connection_kubernetes" "local" {
  name  = "local"
  local = true
}

resource "authentik_outpost" "proxy_outpost" {
  name = "proxy"
  service_connection = authentik_service_connection_kubernetes.local.id
  protocol_providers = [
    authentik_provider_proxy.proxy_provider.id
  ]
}

