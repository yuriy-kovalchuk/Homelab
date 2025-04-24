#!/bin/bash

# Variables
ARGOCD_VERSION="7.8.28"      # Adjust version as needed

install_argo() {

    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo update

    helm upgrade --install argo-cd argo/argo-cd \
        --version ARGOCD_VERSION \
        --create-namespace \
        --namespace argo-cd \
        -f values/values.yaml \
        --wait

    pwd=$(kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    echo "default password: $pwd"

    kubectl apply -f templates/ingress.yaml


}

install_argo

