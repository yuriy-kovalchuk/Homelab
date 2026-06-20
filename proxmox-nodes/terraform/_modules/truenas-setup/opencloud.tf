resource "truenas_dataset" "opencloud" {
  pool  = var.truenas_pool_name
  path  = "opencloud"
  quota = "429496729600" # 400GB
  uid   = 1000
  gid   = 1000
  mode  = "750"
}
