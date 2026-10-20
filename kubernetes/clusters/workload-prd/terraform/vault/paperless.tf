resource "vault_kv_secret_v2" "paperless_config" {
  mount               = "kubernetes"
  name                = "paperless/config"
  delete_all_versions = true

  data_json = jsonencode({
    secret_key     = var.paperless_secret_key
    admin_user     = var.paperless_admin_user
    admin_password = var.paperless_admin_password
    admin_mail     = var.paperless_admin_mail
  })
}

resource "vault_kv_secret_v2" "paperless_db" {
  mount               = "kubernetes"
  name                = "paperless/db"
  delete_all_versions = true

  data_json = jsonencode({
    password = var.paperless_db_password
  })
}
