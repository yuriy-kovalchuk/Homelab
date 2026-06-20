resource "truenas_dataset" "zot" {
  pool  = var.truenas_pool_name
  path  = "zot"
  quota = "107374182400" # 100GB
}
