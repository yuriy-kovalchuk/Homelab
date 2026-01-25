terraform -chdir=.. output -raw kubeconfig_raw
echo "------------"
terraform -chdir=.. output -raw talos_config
