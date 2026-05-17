# Terraform shell functions for devbox
# These run in your current directory (unlike devbox scripts)

# Expose S3 backend credentials as standard AWS env vars so the Terraform S3
# backend picks them up automatically for init, plan, and apply.
export AWS_ACCESS_KEY_ID="${TF_VAR_s3_access_key}"
export AWS_SECRET_ACCESS_KEY="${TF_VAR_s3_secret_key}"
export AWS_ENDPOINT_URL_S3="${TF_VAR_s3_endpoint}"

# Helper to find tfvars file
_tf_var_file() {
  if [[ -f "vars/terraform.tfvars" ]]; then
    echo "-var-file=vars/terraform.tfvars"
  elif [[ -f "terraform.tfvars" ]]; then
    echo "-var-file=terraform.tfvars"
  fi
}

tf_init() {
  terraform init "$@"
}

tf_init_local() {
  terraform init
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

