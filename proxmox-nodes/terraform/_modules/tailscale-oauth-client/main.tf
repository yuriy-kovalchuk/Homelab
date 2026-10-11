# The OAuth client the tailscale-tailnet unit authenticates with.
# Kept in its own unit, applied only with a short-lived TAILSCALE_API_KEY:
# the client cannot read itself (that needs oauth_keys:read), so managing it
# with its own credentials would recreate it on every apply.
# Scopes are exactly what tailscale-tailnet manages; auth keys it creates can
# only carry the router tag. Destroying it cuts off that unit, hence prevent_destroy.
resource "tailscale_oauth_client" "terraform" {
  description = "terraform proxmox-nodes tailscale"
  scopes      = ["policy_file", "dns", "auth_keys", "feature_settings"]
  tags        = [var.router_tag]

  lifecycle {
    prevent_destroy = true
  }
}
