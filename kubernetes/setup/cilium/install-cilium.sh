#!/bin/bash

# Variables
CILIUM_VERSION="1.16.7"         # Adjust version as needed
MAIN_MASTER_NODE="10.0.8.20"
# Cilium IP Configuration
export POOL_NAME="master-pool"
export START_IP="10.0.8.100"
export STOP_IP="10.0.8.200"
export MAIN_MASTER_NODE=$MAIN_MASTER_NODE

install_cilium() {

    helm repo add cilium https://helm.cilium.io/
    helm repo update

    helm upgrade --install cilium cilium/cilium \
        --version $CILIUM_VERSION \
        --namespace kube-system \
        -f values/cilium-config.yaml \
        --set k8sServiceHost=$MAIN_MASTER_NODE \
        --wait

    envsubst < templates/cilium-ip-pool-template.yaml | kubectl apply -f -
    kubectl apply -f templates/cilium-announcements-template.yaml

}

install_cilium
