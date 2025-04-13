#!/bin/bash

# Variables

INGRESS_NGINX_VERSION="4.12.1" # Adjust version as needed
START_IP="10.0.8.100"

install_ingress() {

    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update

    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --version $INGRESS_NGINX_VERSION \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.loadBalancerIP=$START_IP \
        --wait

}

install_ingress