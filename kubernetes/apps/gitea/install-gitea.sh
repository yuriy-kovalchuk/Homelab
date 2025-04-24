#!/bin/bash

# Variables
GITEA_VERSION="v11.0.1"      # Adjust version as needed

install_gitea() {

    helm repo add gitea-charts https://dl.gitea.com/charts/
    helm repo update

    helm upgrade --install gitea gitea-charts/gitea \
        --version $GITEA_VERSION \
        --create-namespace \
        --namespace gitea \
        -f values/values.yaml \
        --wait

    kubectl apply -f templates/ingress.yaml


}

install_gitea

