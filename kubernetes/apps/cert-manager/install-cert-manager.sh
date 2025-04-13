#!/bin/bash

# Variables
CERT_MANAGER_VERSION="v1.17.1"      # Adjust version as needed

install_cert_manager() {
    #    - **Zone > DNS > Edit**
    #    - **Zone > Zone > Read**
    YOUR_CLOUDFLARE_API_TOKEN=$(gum input --cursor.foreground "#FF0" \
        --prompt.foreground "#0FF" \
        --placeholder "Your Cloudflare token:" \
        --prompt "* " \
        --width 80)

    helm repo add jetstack https://charts.jetstack.io
    helm repo update

    helm upgrade --install cert-manager jetstack/cert-manager \
      --version $CERT_MANAGER_VERSION \
      --namespace cert-manager \
      --create-namespace \
      --set installCRDs=true

    kubectl delete secret cloudflare-api-token-secret -n cert-manager
    kubectl create secret generic cloudflare-api-token-secret \
      --namespace cert-manager \
      --from-literal=api-token=$YOUR_CLOUDFLARE_API_TOKEN

    kubectl apply -f templates/cert-manager-cluster-issuer.yaml
    kubectl patch ingressclass nginx -p '{"metadata":{"annotations":{"cert-manager.io/cluster-issuer":"letsencrypt-dns"}}}'
}

install_cert_manager

