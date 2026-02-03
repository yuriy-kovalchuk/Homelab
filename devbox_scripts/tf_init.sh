#!/bin/bash
set -euo pipefail

# Terraform init with S3 backend configuration
# Usage: cd terraform/clusters/main && devbox run tf_init

if [[ ! -f "main.tf" ]] && [[ ! -f "versions.tf" ]]; then
    echo "Error: No terraform files found in current directory"
    echo "Usage: cd <terraform-dir> && devbox run tf_init"
    exit 1
fi

terraform init \
  -backend-config="endpoint=$TF_VAR_s3_endpoint" \
  -backend-config="access_key=$TF_VAR_s3_access_key" \
  -backend-config="secret_key=$TF_VAR_s3_secret_key"
