#!/bin/bash

# Variables
LONGHORN_VERSION="1.8.1"        # Adjust version as needed


install_longhorn() {

    helm repo add longhorn https://charts.longhorn.io
    helm repo update

    helm upgrade --install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace --version $LONGHORN_VERSION --wait

    #kubectl patch svc longhorn-frontend -n longhorn-system -p '{"spec": {"type": "ClusterIP"}}'
    #kubectl patch svc longhorn-frontend -n longhorn-system -p '{"spec": {"type": "LoadBalancer"}}'

}

install_longhorn
