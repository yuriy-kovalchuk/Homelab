locals {
  s3 = {
    bucket     = "terraform-prd"
    region     = "eu-south-1"
    access_key = get_env("TF_VAR_s3_access_key")
    secret_key = get_env("TF_VAR_s3_secret_key")

    endpoints = {
      s3 = get_env("TF_VAR_s3_endpoint")
    }

    insecure                     = true
    skip_credentials_validation  = true
    skip_requesting_account_id   = true
    skip_metadata_api_check      = true
    skip_region_validation       = true
    use_path_style               = true
  }
}
