resource "truenas_user" "nas" {
  username          = var.truenas_nas_username
  full_name         = "NAS share user"
  password          = var.truenas_nas_user_password
  smb               = true
  group_create      = true
  password_disabled = false
  random_password   = false
}
