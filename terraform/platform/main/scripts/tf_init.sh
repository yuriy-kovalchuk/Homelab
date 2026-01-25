terraform -chdir=.. init  \
  -backend-config="endpoint=$TF_VAR_s3_endpoint" \
  -backend-config="access_key=$TF_VAR_s3_access_key" \
  -backend-config="secret_key=$TF_VAR_s3_secret_key"
