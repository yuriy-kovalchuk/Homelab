resource "truenas_dataset" "kubernetes" {
  pool = var.truenas_pool_name
  path = "kubernetes"
}

resource "truenas_dataset" "kubernetes_nfs" {
  pool  = var.truenas_pool_name
  path  = "kubernetes/nfs"
  quota = "107374182400" # 100GB

  depends_on = [truenas_dataset.kubernetes]
}

resource "truenas_dataset" "kubernetes_iscsi" {
  pool  = var.truenas_pool_name
  path  = "kubernetes/iscsi"
  quota = "407374182400"

  depends_on = [truenas_dataset.kubernetes]
}

resource "truenas_dataset" "kubernetes_nfs_snapshots" {
  pool = var.truenas_pool_name
  path = "kubernetes/nfs-snapshots"

  depends_on = [truenas_dataset.kubernetes]
}

resource "truenas_dataset" "kubernetes_iscsi_snapshots" {
  pool = var.truenas_pool_name
  path = "kubernetes/iscsi-snapshots"

  depends_on = [truenas_dataset.kubernetes]
}
