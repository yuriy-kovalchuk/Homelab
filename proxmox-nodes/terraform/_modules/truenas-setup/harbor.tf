# Harbor registry. Holds two subdirectories, both created by the goharbor/prepare
# container on first start of the harbor app (see truenas-apps/app-harbor.tf):
#   data/   — registry blobs, postgres, redis, generated secrets
#   config/ — rendered component configs, regenerated on every prepare run
# Left owned by root: prepare runs privileged and chowns the subdirectories
# itself (10000:10000 for Harbor components, 999:999 for postgres and redis).
resource "truenas_dataset" "harbor" {
  pool  = var.truenas_pool_name
  path  = "harbor"
  quota = "107374182400" # 100GB
}
