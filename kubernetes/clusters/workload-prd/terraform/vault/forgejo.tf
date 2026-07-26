resource "vault_kv_secret_v2" "forgejo_admin" {
  mount               = "kubernetes"
  name                = "forgejo/admin"
  delete_all_versions = true

  data_json = jsonencode({
    username = var.forgejo_admin_username
    password = var.forgejo_admin_password
    email    = var.forgejo_admin_email
  })
}

resource "vault_kv_secret_v2" "forgejo_db" {
  mount               = "kubernetes"
  name                = "forgejo/db"
  delete_all_versions = true

  data_json = jsonencode({
    password = var.forgejo_db_password
  })
}
