resource "vault_kv_secret_v2" "loki_s3" {
  mount               = "kubernetes"
  name                = "loki/s3"
  delete_all_versions = true

  data_json = jsonencode({
    access_key = var.rustfs_access_key
    secret_key = var.rustfs_secret_key
  })
}

resource "vault_kv_secret_v2" "mimir_s3" {
  mount               = "kubernetes"
  name                = "mimir/s3"
  delete_all_versions = true

  data_json = jsonencode({
    access_key = var.rustfs_access_key
    secret_key = var.rustfs_secret_key
  })
}

resource "vault_kv_secret_v2" "tempo_s3" {
  mount               = "kubernetes"
  name                = "tempo/s3"
  delete_all_versions = true

  data_json = jsonencode({
    access_key = var.rustfs_access_key
    secret_key = var.rustfs_secret_key
  })
}

resource "vault_kv_secret_v2" "grafana_admin" {
  mount               = "kubernetes"
  name                = "grafana/admin"
  delete_all_versions = true

  data_json = jsonencode({
    username = var.grafana_admin_username
    password = var.grafana_admin_password
  })
}

resource "vault_kv_secret_v2" "alertmanager_slack" {
  mount               = "kubernetes"
  name                = "alertmanager/slack"
  delete_all_versions = true

  data_json = jsonencode({
    webhook_url = var.alertmanager_slack_webhook_url
  })
}
