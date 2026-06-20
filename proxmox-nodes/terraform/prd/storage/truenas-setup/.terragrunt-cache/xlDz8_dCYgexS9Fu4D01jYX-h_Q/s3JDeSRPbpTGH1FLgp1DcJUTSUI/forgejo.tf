resource "truenas_dataset" "forgejo" {
  pool  = var.truenas_pool_name
  path  = "forgejo"
  quota = "32212254720" # 30GB
}
