terraform {
  required_providers {
    talos = {
      source = "siderolabs/talos"
    }
  }
}

locals {
  first_control_plane = var.control_plane_nodes[0].ip

  node_extensions = {
    for node in var.control_plane_nodes : node.hostname => {
      extensions        = node.extensions != null ? node.extensions : var.extensions
      extra_kernel_args = node.extra_kernel_args != null ? node.extra_kernel_args : var.extra_kernel_args
    }
  }
  unique_extension_sets = distinct([for node in local.node_extensions : node.extensions])
}

data "talos_image_factory_extensions_versions" "this" {
  for_each      = { for idx, exts in local.unique_extension_sets : join(",", exts) => exts }
  talos_version = var.talos_version
  filters       = { names = each.value }
}

resource "talos_image_factory_schematic" "nodes" {
  for_each = local.node_extensions
  schematic = templatefile("${path.module}/machine_config_patches/schematic.tftpl", {
    extensions        = data.talos_image_factory_extensions_versions.this[join(",", each.value.extensions)].extensions_info.*.name
    extra_kernel_args = each.value.extra_kernel_args
  })
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "this" {
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${local.first_control_plane}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  kubernetes_version = var.kubernetes_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [local.first_control_plane]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each = { for node in var.control_plane_nodes : node.ip => node }

  depends_on = [talos_image_factory_schematic.nodes]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = each.value.ip

  config_patches = concat(
    [
      templatefile("${path.module}/machine_config_patches/controlplane.tftpl", {
        install_image                      = "${var.image_registry}/${talos_image_factory_schematic.nodes[each.value.hostname].id}:${var.talos_version}"
        install_disk                       = each.value.disk != null ? each.value.disk : ""
        install_wipe                       = each.value.wipe != null ? each.value.wipe : false
        hostname                           = each.value.hostname
        interface                          = each.value.interface
        ip_address                         = each.value.ip
        gateway                            = each.value.gateway
        cni_name                           = var.cni_name
        allow_scheduling_on_control_planes = var.allow_scheduling_on_control_planes
        registry_mirrors                   = var.registry_mirrors
      }),
    ],
    each.value.gpu_passthrough != null && each.value.gpu_passthrough.enabled ? [
      templatefile("${path.module}/machine_config_patches/gpu_passthrough.tftpl", {
        pci_devices    = each.value.gpu_passthrough.pci_devices
        kernel_args    = each.value.gpu_passthrough.kernel_args
        kernel_modules = each.value.gpu_passthrough.kernel_modules
      }),
    ] : [],
    length(each.value.node_labels) > 0 ? [
      templatefile("${path.module}/machine_config_patches/node_labels.tftpl", {
        node_labels = each.value.node_labels
      }),
    ] : []
  )
}

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
