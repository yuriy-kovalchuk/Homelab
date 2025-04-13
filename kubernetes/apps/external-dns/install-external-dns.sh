#!/bin/bash

# Variables
EXT_DNS_VERSION="8.0.1"        # Adjust version as needed
export PIHOLE_WEB_PASSWORD="password"


install_ext_dns() {

    helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
    helm repo update

    helm upgrade --install external-dns-0 external-dns/external-dns \
        --namespace pihole \
        --create-namespace \
        --version 1.16.1 \
        --set extraArgs[0]=--pihole-server=http://10.0.8.153 \
        --set extraArgs[1]=--pihole-password=password \
        -f values/values.yaml \
        --wait

    helm upgrade --install external-dns-1 external-dns/external-dns \
        --namespace pihole \
        --create-namespace \
        --version 1.16.1 \
        --set extraArgs[0]=--pihole-server=http://10.0.8.154 \
        --set extraArgs[1]=--pihole-password=password \
        --set serviceAccount.create=false \
        -f values/values.yaml \
        --wait

}

install_ext_dns
