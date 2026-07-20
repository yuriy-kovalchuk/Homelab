resource "vault_kv_secret_v2" "immich_db" {
  mount               = "kubernetes"
  name                = "immich/db"
  delete_all_versions = true

  data_json = jsonencode({
    password = var.immich_db_password
  })
}
