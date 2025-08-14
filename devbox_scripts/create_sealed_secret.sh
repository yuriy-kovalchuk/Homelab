#!/usr/bin/env bash

set -euo pipefail

# --- Functions ---
usage() {
  echo "Usage: $0 <secret-name> <secret-key> <secret-value> <namespace>"
  echo
  echo "Arguments:"
  echo "  secret-name   Name of the Kubernetes Secret to create"
  echo "  secret-key    Key inside the Secret"
  echo "  secret-value  Value for the Secret key"
  echo "  namespace     Kubernetes namespace for the Secret"
  echo
  echo "Example:"
  echo "  $0 rancher-bootstrap bootstrapPassword 'mySecret123' cattle-system"
  exit 1
}

check_bin() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: Required tool '$1' not found in PATH."
    exit 1
  fi
}

# --- Argument validation ---
if [[ $# -ne 4 ]]; then
  usage
fi

SECRET_NAME="$1"
SECRET_KEY="$2"
SECRET_VALUE="$3"
NAMESPACE="$4"

# --- Check dependencies ---
check_bin kubectl
check_bin kubeseal

# --- Summary ---
echo "--------------------------------------------"
echo " SealedSecret creation script"
echo "--------------------------------------------"
echo "Secret Name:      $SECRET_NAME"
echo "Secret Key:       $SECRET_KEY"
echo "Namespace:        $NAMESPACE"
echo "kubeseal Scope:   strict"
echo "--------------------------------------------"
read -p "Proceed with creation? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# --- Create sealed secret ---
echo -n "$SECRET_VALUE" | kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --dry-run=client --from-file="$SECRET_KEY"=/dev/stdin -o yaml | \
  kubeseal \
    --controller-namespace sealed-secrets \
    --controller-name sealed-secrets \
    --scope strict \
    -o yaml > sealed_secret.yaml

echo "SealedSecret manifest created: sealed_secret.yaml"
echo "To apply it: kubectl apply -f sealed_secret.yaml"
