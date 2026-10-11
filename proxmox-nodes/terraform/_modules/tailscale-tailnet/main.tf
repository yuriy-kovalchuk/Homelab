# Whole tailnet policy: tags, route auto-approval, grants.
resource "tailscale_acl" "policy" {
  acl                        = file("${path.module}/policy.hujson")
  overwrite_existing_content = true
}

# yuriykovalchuk.dev resolves through the lab's Unbound, so internal hostnames
# point at the Gateway exactly as on the home network.
resource "tailscale_dns_split_nameservers" "lab" {
  domain      = var.split_dns_domain
  nameservers = var.split_dns_nameservers
}

resource "tailscale_tailnet_settings" "this" {
  devices_approval_on        = true # new devices need an admin's approval
  devices_auto_updates_on    = true
  devices_key_duration_days  = 180
  users_approval_on          = true
  acls_externally_managed_on = true # console shows the policy is managed elsewhere
  acls_external_link         = var.policy_repo_url
}

# One-time login key for the subnet router (playbooks/tailscale.yml).
# Tagged, so the router never expires and belongs to no user; pre-approved so
# it joins without a manual click. Only used on first login — once the router
# is up, an expired key does not matter.
resource "tailscale_tailnet_key" "router" {
  description         = "homelab-router subnet router VM"
  reusable            = false
  ephemeral           = false
  preauthorized       = true
  tags                = [var.router_tag]
  expiry              = 86400 # 1 day
  recreate_if_invalid = "always"

  depends_on = [tailscale_acl.policy] # the tag must exist in the policy first
}
