terraform {
  required_version = ">= 1.5.0"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.29"
    }
  }
}

# Apply only with TAILSCALE_API_KEY set: a full-access API access token from
# console.tailscale.com → Settings → Keys, 1-day expiry, revoked afterwards.
# Unset TAILSCALE_OAUTH_CLIENT_* for this unit (they conflict with api_key).
provider "tailscale" {
  tailnet = "-" # the tailnet the credential belongs to
}
