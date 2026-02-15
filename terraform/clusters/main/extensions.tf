# Get extension versions for each unique set of extensions
locals {
  # Create a map of node configs with their extensions
  node_extensions = {
    for node in var.control_plane_nodes : node.hostname => {
      extensions        = node.extensions != null ? node.extensions : var.extensions
      extra_kernel_args = node.extra_kernel_args != null ? node.extra_kernel_args : var.extra_kernel_args
    }
  }

  # Get unique extension sets to minimize API calls
  unique_extension_sets = distinct([for node in local.node_extensions : node.extensions])
}

# Fetch extension versions for each unique extension set
data "talos_image_factory_extensions_versions" "this" {
  for_each      = { for idx, exts in local.unique_extension_sets : join(",", exts) => exts }
  talos_version = var.talos_version
  filters       = { names = each.value }
}

# Create a schematic for each node
resource "talos_image_factory_schematic" "nodes" {
  for_each = local.node_extensions

  schematic = templatefile("${path.module}/machine_config_patches/schematic.tftpl", {
    extensions        = data.talos_image_factory_extensions_versions.this[join(",", each.value.extensions)].extensions_info.*.name
    extra_kernel_args = each.value.extra_kernel_args
  })
}
