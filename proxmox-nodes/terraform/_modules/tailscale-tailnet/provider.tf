terraform {
  required_version = ">= 1.5.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}

# Authenticates with the scoped OAuth client from the tailscale-bootstrap unit:
# TAILSCALE_OAUTH_CLIENT_ID / TAILSCALE_OAUTH_CLIENT_SECRET in .env.
# On a brand-new tailnet, apply this unit once with TAILSCALE_API_KEY first
# (the policy must define the router tag before the client can be created).
provider "tailscale" {
  tailnet = "-" # the tailnet the credential belongs to
}
