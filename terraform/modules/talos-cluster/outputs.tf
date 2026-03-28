output "kubeconfig_raw" {
  value       = talos_cluster_kubeconfig.first_cp.kubeconfig_raw
  sensitive   = true
  description = "Raw kubeconfig from the first control plane node"
}

output "talos_config" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "talos_schematic_ids" {
  value       = { for hostname, schematic in talos_image_factory_schematic.nodes : hostname => schematic.id }
  description = "Talos image schematic IDs per node (used for upgrades with extensions)"
}

output "control_plane_ips" {
  value       = [for node in var.control_plane_nodes : node.ip]
  description = "List of control plane node IPs"
}

output "talos_version" {
  value       = var.talos_version
  description = "Current Talos version configured in Terraform"
}
