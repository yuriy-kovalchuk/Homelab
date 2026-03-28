terraform {
  backend "s3" {
    bucket = "terraform"
    key    = "proxmox-maya-prd.tfstate"

    endpoint   = var.s3_endpoint
    access_key = var.s3_access_key
    secret_key = var.s3_secret_key

    region                      = "eu-south-1"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
