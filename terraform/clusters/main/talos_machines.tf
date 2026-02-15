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
        gateway                            = var.gateway
        cni_name                           = var.cni_name
        allow_scheduling_on_control_planes = var.allow_scheduling_on_control_planes
        registry_mirrors_enabled           = var.registry_mirrors_enabled
        harbor_hostname                    = var.harbor_hostname
      }),
    ],
    # GPU passthrough patch (only for nodes with gpu_passthrough enabled)
    each.value.gpu_passthrough != null && each.value.gpu_passthrough.enabled ? [
      templatefile("${path.module}/machine_config_patches/gpu_passthrough.tftpl", {
        pci_devices = each.value.gpu_passthrough.pci_devices
        node_labels = each.value.gpu_passthrough.node_labels != null ? each.value.gpu_passthrough.node_labels : {}
      }),
    ] : []
  )
}
