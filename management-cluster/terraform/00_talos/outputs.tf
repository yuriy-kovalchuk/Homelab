output "kubeconfig_raw" {
  value       = module.talos_cluster.kubeconfig_raw
  sensitive   = true
  description = "Raw kubeconfig from the first control plane node"
}

output "talos_config" {
  value     = module.talos_cluster.talos_config
  sensitive = true
}

output "talos_schematic_ids" {
  value       = module.talos_cluster.talos_schematic_ids
  description = "Talos image schematic IDs per node (used for upgrades with extensions)"
}

output "control_plane_ips" {
  value       = module.talos_cluster.control_plane_ips
  description = "List of control plane node IPs"
}

output "talos_version" {
  value       = module.talos_cluster.talos_version
  description = "Current Talos version configured in Terraform"
}
