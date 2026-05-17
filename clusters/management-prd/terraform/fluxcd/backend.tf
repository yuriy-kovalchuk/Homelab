terraform {
  backend "s3" {
    bucket = "terraform-prd"
    key    = "clusters/management-prd/fluxcd.tfstate"

    region                      = "eu-south-1"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
