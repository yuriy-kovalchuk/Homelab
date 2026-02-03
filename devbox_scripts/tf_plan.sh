#!/bin/bash
set -euo pipefail

# Terraform plan
# Usage: cd terraform/clusters/main && devbox run tf_plan

if [[ ! -f "main.tf" ]] && [[ ! -f "versions.tf" ]]; then
    echo "Error: No terraform files found in current directory"
    echo "Usage: cd <terraform-dir> && devbox run tf_plan"
    exit 1
fi

terraform plan "$@"
