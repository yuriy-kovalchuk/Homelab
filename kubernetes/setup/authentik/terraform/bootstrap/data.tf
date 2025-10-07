data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

# Get default invalidation flow
data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_property_mapping_provider_scope" "test" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}

data "authentik_property_mapping_provider_scope" "profile" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-profile"
  ]
}

# To get the name of a user by username
data "authentik_user" "akadmin" {
  username = "yuriy"
}
