resource "truenas_dataset" "opencloud" {
  pool  = var.truenas_pool_name
  path  = "opencloud"
  quota = "429496729600" # 400GB
}
