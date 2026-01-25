resource "talos_machine_secrets" "this" {}


data "talos_machine_configuration" "this" {
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${local.first_control_plane}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}


data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [local.first_control_plane]
}


