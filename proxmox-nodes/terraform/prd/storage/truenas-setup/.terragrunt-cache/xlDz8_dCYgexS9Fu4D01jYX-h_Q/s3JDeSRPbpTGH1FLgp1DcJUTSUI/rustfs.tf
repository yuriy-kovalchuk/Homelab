resource "truenas_dataset" "rustfs" {
  pool  = var.truenas_pool_name
  path  = "rustfs"
  uid   = 10001
  gid   = 10001
  mode  = "750"
  quota = "107374182400" # 100GB
}
