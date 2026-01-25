resource "talos_machine_configuration_apply" "control_plane" {
  for_each = { for node in var.control_plane_nodes : node.ip => node }

  depends_on = [talos_image_factory_schematic.this]

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this.machine_configuration
  node                        = each.value.ip

  config_patches = [
    yamlencode({
      machine = {

        install = merge(
          {
            image = "${var.image_registry}/${talos_image_factory_schematic.this.id}:${var.talos_version}"
          },
            each.value.disk != null ? { disk = each.value.disk } : {},
            each.value.wipe != null ? { wipe = each.value.wipe } : {}
        )
        network = {
          hostname   = each.value.hostname
          interfaces = [
            {
              interface = each.value.interface
              dhcp      = false
              addresses = ["${each.value.ip}/24"]
              routes = [
                { network = "0.0.0.0/0", gateway = var.gateway, metric = 1024 }
              ]
              mtu = 1500
            }
          ]
          nameservers = [var.gateway]
        }
      }
      cluster = {
        network = { cni = { name = var.cni_name } }
        proxy   = { disabled = true }
        allowSchedulingOnControlPlanes = true
      }
    })
  ]
}
