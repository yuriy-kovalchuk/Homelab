#!/bin/bash
set -euo pipefail

# Print terraform sensitive outputs
# Usage: cd terraform/clusters/main && devbox run tf_output [output-name]

if [[ ! -f "main.tf" ]] && [[ ! -f "versions.tf" ]]; then
    echo "Error: No terraform files found in current directory"
    echo "Usage: cd <terraform-dir> && devbox run tf_output [output-name]"
    exit 1
fi

print_output() {
    local name=$1
    local value
    if value=$(terraform output -raw "$name" 2>/dev/null); then
        echo "=== $name ==="
        echo "$value"
        echo ""
        return 0
    fi
    return 1
}

if [[ $# -gt 0 ]]; then
    terraform output -raw "$1"
else
    found=false

    if print_output "kubeconfig_raw"; then
        found=true
    elif print_output "kubeconfig"; then
        found=true
    fi

    if print_output "talos_config"; then
        found=true
    fi

    if [[ "$found" == "false" ]]; then
        echo "No common sensitive outputs found. Available outputs:"
        terraform output
    fi
fi
