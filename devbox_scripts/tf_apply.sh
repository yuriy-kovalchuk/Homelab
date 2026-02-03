#!/bin/bash
set -euo pipefail

# Terraform apply
# Usage: cd terraform/clusters/main && devbox run tf_apply

if [[ ! -f "main.tf" ]] && [[ ! -f "versions.tf" ]]; then
    echo "Error: No terraform files found in current directory"
    echo "Usage: cd <terraform-dir> && devbox run tf_apply"
    exit 1
fi

terraform apply "$@"
