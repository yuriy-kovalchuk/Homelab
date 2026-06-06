resource "vault_kv_secret_v2" "tempo_s3" {
  mount               = "kubernetes"
  name                = "tempo/s3"
  delete_all_versions = true

  data_json = jsonencode({
    access_key = var.tempo_s3_access_key
    secret_key = var.tempo_s3_secret_key
  })
}
