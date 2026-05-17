resource "truenas_pool_dataset" "nfs_general" {
  name  = "${var.truenas_pool_name}/nfs-general"
  type  = "FILESYSTEM"
  quota = var.nfs_general_quota_bytes
}

resource "null_resource" "nfs_general_setperm" {
  triggers = {
    dataset  = truenas_pool_dataset.nfs_general.id
    username = var.truenas_nas_username
  }

  provisioner "local-exec" {
    environment = {
      TRUENAS_TOKEN = var.truenas_token
    }
    command = <<-EOT
      curl -sf -X POST "http://${var.truenas_host}/api/v2.0/filesystem/setperm" \
        -H "Authorization: Bearer $TRUENAS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"path":"/mnt/${var.truenas_pool_name}/nfs-general","mode":"770","user":"${var.truenas_nas_username}","group":"${var.truenas_nas_username}","options":{"stripacl":true,"recursive":true}}'
    EOT
  }

  depends_on = [truenas_pool_dataset.nfs_general]
}

resource "truenas_sharing_nfs" "general" {
  path       = "/mnt/${var.truenas_pool_name}/nfs-general"
  comment    = "General NFS share — access controlled by firewall"
  mapall_user = var.truenas_nas_username

  depends_on = [null_resource.nfs_general_setperm]
}
