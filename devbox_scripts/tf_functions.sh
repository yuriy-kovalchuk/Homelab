# Terraform shell functions for devbox
# These run in your current directory (unlike devbox scripts)

# Helper to find tfvars file
_tf_var_file() {
  if [[ -f "vars/terraform.tfvars" ]]; then
    echo "-var-file=vars/terraform.tfvars"
  elif [[ -f "terraform.tfvars" ]]; then
    echo "-var-file=terraform.tfvars"
  fi
}

tf_init() {
  terraform init \
    -backend-config="endpoint=$TF_VAR_s3_endpoint" \
    -backend-config="access_key=$TF_VAR_s3_access_key" \
    -backend-config="secret_key=$TF_VAR_s3_secret_key"
}

tf_plan() {
  terraform plan $(_tf_var_file) "$@"
}

tf_apply() {
  terraform apply $(_tf_var_file) "$@"
}

tf_output() {
  if [[ $# -gt 0 ]]; then
    terraform output -raw "$1"
  else
    # Auto-detect common outputs
    local found=false

    if terraform output -raw kubeconfig_raw 2>/dev/null; then
      echo ""
      found=true
    elif terraform output -raw kubeconfig 2>/dev/null; then
      echo ""
      found=true
    fi

    if terraform output -raw talos_config 2>/dev/null; then
      echo ""
      found=true
    fi

    if [[ "$found" == "false" ]]; then
      echo "Available outputs:"
      terraform output
    fi
  fi
}

upgrade_talos() {
  "$DEVBOX_PROJECT_ROOT/devbox_scripts/upgrade_talos.sh" "$@"
}
