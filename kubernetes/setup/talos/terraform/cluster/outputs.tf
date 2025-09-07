output "kubeconfig_raw" {
  value     = talos_cluster_kubeconfig.first_cp.kubeconfig_raw
  sensitive = true
  description = "Raw kubeconfig from the first control plane node"
}

output "talos_config" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}