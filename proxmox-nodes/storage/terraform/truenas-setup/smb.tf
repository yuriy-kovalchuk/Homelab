resource "truenas_pool_dataset" "smb_general" {
  name  = "${var.truenas_pool_name}/smb-general"
  type  = "FILESYSTEM"
  quota = var.smb_general_quota_bytes
}

resource "null_resource" "smb_general_setperm" {
  triggers = {
    dataset  = truenas_pool_dataset.smb_general.id
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
        -d '{"path":"/mnt/${var.truenas_pool_name}/smb-general","mode":"770","user":"${var.truenas_nas_username}","group":"${var.truenas_nas_username}","options":{"stripacl":true,"recursive":true}}'
    EOT
  }

  depends_on = [truenas_pool_dataset.smb_general, truenas_user.nas]
}

resource "truenas_sharing_smb" "general" {
  path      = "/mnt/${var.truenas_pool_name}/smb-general"
  name      = "general"
  comment   = "General SMB share — access controlled by firewall"
  browsable = true
  enabled   = true

  depends_on = [null_resource.smb_general_setperm]
}
