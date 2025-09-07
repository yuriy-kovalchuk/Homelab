resource "talos_machine_bootstrap" "first_cp" {
  depends_on           = [talos_machine_configuration_apply.control_plane]
  node                 = local.first_control_plane
  client_configuration = talos_machine_secrets.this.client_configuration
}

resource "talos_cluster_kubeconfig" "first_cp" {
  depends_on           = [talos_machine_bootstrap.first_cp]
  node                 = local.first_control_plane
  client_configuration = talos_machine_secrets.this.client_configuration
}
