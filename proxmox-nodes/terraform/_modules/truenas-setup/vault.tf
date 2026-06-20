resource "truenas_dataset" "vault" {
  pool  = var.truenas_pool_name
  path  = "vault"
  quota = "10737418240" # 10GB
  uid   = 100
  gid   = 1000
  mode  = "750"
}
