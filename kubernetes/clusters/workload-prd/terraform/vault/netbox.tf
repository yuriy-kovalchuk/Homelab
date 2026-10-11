resource "vault_kv_secret_v2" "netbox_config" {
  mount               = "kubernetes"
  name                = "netbox/config"
  delete_all_versions = true

  data_json = jsonencode({
    secret_key       = var.netbox_secret_key
    api_token_pepper = var.netbox_api_token_pepper
  })
}

resource "vault_kv_secret_v2" "netbox_superuser" {
  mount               = "kubernetes"
  name                = "netbox/superuser"
  delete_all_versions = true

  data_json = jsonencode({
    username  = var.netbox_superuser_username
    password  = var.netbox_superuser_password
    email     = var.netbox_superuser_email
    api_token = var.netbox_superuser_api_token
  })
}

resource "vault_kv_secret_v2" "netbox_db" {
  mount               = "kubernetes"
  name                = "netbox/db"
  delete_all_versions = true

  data_json = jsonencode({
    password = var.netbox_db_password
  })
}
