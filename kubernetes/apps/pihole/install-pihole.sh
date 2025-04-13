#!/bin/bash

# Variables
export PIHOLE_WEB_PASSWORD="password"
export PIHOLE_FIRST_IP="10.0.8.153"
export PIHOLE_SECOND_IP="10.0.8.154"
export PIHOLE_LB="10.0.8.152"


install_pihole() {

    kubectl apply -f manifest/v5/namespace.yaml --wait
    envsubst < manifest/v5/statefulset.yaml | kubectl apply -f - --wait
    kubectl apply -f manifest/v5/headless-svc.yaml --wait
    envsubst < manifest/v5/svc.yaml | kubectl apply -f - --wait
    kubectl apply -f manifest/v5/ingress.yaml --wait

}

install_pihole
