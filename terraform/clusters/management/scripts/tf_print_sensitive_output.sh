terraform -chdir=.. output -raw talosconfig
echo "--------"
terraform -chdir=.. output -raw kubeconfig
