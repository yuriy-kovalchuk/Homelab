resource "vault_kv_secret_v2" "opencloud_admin" {
  mount               = "kubernetes"
  name                = "opencloud/admin"
  delete_all_versions = true

  data_json = jsonencode({
    password = var.opencloud_admin_password
  })
}
