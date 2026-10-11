output "management_url" {
  description = "Web UI address for normal use"
  value       = "https://${split("/", var.mgmt_address)[0]}:8006"
}

output "breakglass_url" {
  description = "Web UI address over the break-glass cable"
  value       = "https://${split("/", var.breakglass_address)[0]}:8006"
}
