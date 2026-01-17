# -------------------- proxmox ---------------------------
resource "authentik_provider_oauth2" "proxmox_provider" {
  name               = "proxmox"
  client_id          = "C34Fn2M8NqU9hyfb2ykZYpSQ1zgb4oIcYFz0lLT7"
  client_secret      = var.proxmox_provider_client_secret
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  sub_mode           = "user_email"
  property_mappings  = data.authentik_property_mapping_provider_scope.test.ids
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://firewall.yuriy-lab.cloud:8006",
    },
    {
      matching_mode = "strict",
      url           = "https://maya.yuriy-lab.cloud:8006",
    }
  ]
}

resource "authentik_application" "proxmox_application" {
  name              = "proxmox"
  slug              = "proxmox"
  protocol_provider = authentik_provider_oauth2.proxmox_provider.id
}
# -------------------- proxmox ---------------------------

# -------------------- argocd ---------------------------
resource "authentik_provider_oauth2" "argocd_provider" {
  name               = "argocd"
  client_id          = "egOBpvoCLsDQLt0JDFlnM5G4xYVjUdQSvatFqog8"
  client_secret      = var.argocd_provider_client_secret
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  property_mappings  = data.authentik_property_mapping_provider_scope.test.ids
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://argocd.yuriy-lab.cloud/api/dex/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://localhost:8085/auth/callback",
    }
  ]
}

resource "authentik_application" "argocd_application" {
  name              = "argocd"
  slug              = "argocd"
  protocol_provider = authentik_provider_oauth2.argocd_provider.id
}


resource "authentik_group" "argo_admins_group" {
  name  = "ArgoCD Admins"
  users = [data.authentik_user.akadmin.id]
}
# -------------------- argocd ---------------------------

# -------------------- longhorn ---------------------------
resource "authentik_provider_proxy" "proxy_provider" {
  mode               = "forward_domain"
  name               = "proxy"
  external_host      = "https://authentik.yuriy-lab.cloud"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  cookie_domain      = "yuriy-lab.cloud"
}

resource "authentik_application" "proxy_application" {
  name              = "proxy"
  slug              = "proxy"
  protocol_provider = authentik_provider_proxy.proxy_provider.id
}
# -------------------- longhorn ---------------------------

# -------------------- vault ---------------------------
resource "authentik_provider_oauth2" "vault_provider" {
  name               = "vault"
  client_id          = "wF45S2bPDJg7M5XEFXRNcMOrtCmKKFE5iu4Gdh3U"
  client_secret      = var.vault_provider_client_secret
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  property_mappings  = data.authentik_property_mapping_provider_scope.profile.ids
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://vault.yuriy-lab.cloud/ui/vault/auth/oidc/oidc/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://vault.yuriy-lab.cloud/oidc/callback",
    },
    {
      matching_mode = "strict",
      url           = "http://localhost:8250/oidc/callback.",
    }
  ]
}

resource "authentik_application" "vault_application" {
  name              = "vault"
  slug              = "vault"
  protocol_provider = authentik_provider_oauth2.vault_provider.id
}
# -------------------- vault ---------------------------


# -------------------- grafana ---------------------------
resource "authentik_provider_oauth2" "grafana_provider" {
  name               = "grafana"
  client_id          = "ljuHKQWUPCdi2ElfXLUqFqvDrM9w2oa97mY7vRe4"
  client_secret      = var.grafana_provider_client_secret
  authorization_flow = data.authentik_flow.default-provider-authorization-implicit-consent.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://grafana.yuriy-lab.cloud/login/generic_oauth",
    }
  ]

  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
  ]
}

resource "authentik_application" "grafana_application" {
  name              = "grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana_provider.id
}

resource "authentik_group" "grafana_admins" {
  name  = "Grafana Admins"
  users = [data.authentik_user.akadmin.id]
}

resource "authentik_group" "grafana_editors" {
  name = "Grafana Editors"
}

resource "authentik_group" "grafana_viewers" {
  name = "Grafana Viewers"
}
# -------------------- grafana ---------------------------




