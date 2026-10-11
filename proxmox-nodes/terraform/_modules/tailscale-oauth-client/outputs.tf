output "oauth_client_id" {
  description = "TAILSCALE_OAUTH_CLIENT_ID for later applies"
  value       = tailscale_oauth_client.terraform.id
  sensitive   = true
}

output "oauth_client_secret" {
  description = "TAILSCALE_OAUTH_CLIENT_SECRET for later applies"
  value       = tailscale_oauth_client.terraform.key
  sensitive   = true
}
