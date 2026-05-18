locals {
  s3 = {
    bucket   = "terraform-prd"
    region   = "eu-south-1"
    endpoint = get_env("TF_VAR_s3_endpoint")

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
