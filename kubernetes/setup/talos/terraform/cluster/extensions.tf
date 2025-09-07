data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = { names = var.extensions }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info.*.name
      }
    }
  })
}
