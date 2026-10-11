output "router_auth_key" {
  description = "Auth key for the subnet router's first login"
  value       = tailscale_tailnet_key.router.key
  sensitive   = true
}
