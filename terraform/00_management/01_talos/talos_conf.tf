resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.talos_cluster_name
  cluster_endpoint   = "https://${var.talos_cluster_endpoint_ip}:${var.talos_cluster_endpoint_port}"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.talos_cluster_endpoint_ip]
}

# Compute install image from factory if not explicitly set
locals {
  talos_install_image = var.talos_install_image != "" ? var.talos_install_image : "factory.talos.dev/installer/${var.talos_image_schematic_id}:v${var.talos_version}"
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = var.talos_cluster_endpoint_ip

  config_patches = [
    templatefile("${path.module}/machine_config_patches/controlplane.tftpl", {
      install_disk                       = var.talos_install_disk
      install_image                      = local.talos_install_image
      dns                                = var.talos_dns
      interface                          = var.talos_network_interface
      ip_address                         = "${var.talos_cluster_endpoint_ip}${var.talos_ip_cidr}"
      network                            = var.talos_network
      network_gateway                    = var.talos_network_gateway
      allow_scheduling_on_control_planes = var.talos_allow_scheduling_on_control_planes
    }),
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.talos_cluster_endpoint_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.talos_cluster_endpoint_ip
}
