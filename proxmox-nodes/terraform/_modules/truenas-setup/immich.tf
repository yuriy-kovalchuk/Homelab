resource "truenas_dataset" "immich" {
  pool  = var.truenas_pool_name
  path  = "immich"
  quota = "107374182400" # 100GB
}
