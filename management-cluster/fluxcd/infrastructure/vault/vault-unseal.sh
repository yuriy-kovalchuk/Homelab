#!/bin/sh
set -e

UNSEAL_KEY="${UNSEAL_KEY}"
VAULT_ADDR="http://localhost:8200"

if [ -z "$UNSEAL_KEY" ]; then
    echo "ERROR: UNSEAL_KEY not set"
    exit 1
fi

echo "Waiting for Vault to be ready..."
until curl -s "$VAULT_ADDR/v1/sys/health" > /dev/null 2>&1; do
    sleep 2
done

echo "Checking Vault seal status..."
seal_status=$(curl -s "$VAULT_ADDR/v1/sys/health" | grep -o '"seal_status":"[^"]*"' | cut -d'"' -f4)

if [ "$seal_status" = "unsealed" ]; then
    echo "Vault is already unsealed"
    exit 0
fi

echo "Unsealing Vault..."
vault operator unseal "$UNSEAL_KEY"

echo "Waiting for Vault to become active..."
until [ "$(curl -s "$VAULT_ADDR/v1/sys/health" | grep -o '"sealed":[^,]*' | cut -d':' -f2 | tr -d ' ')" = "false" ]; do
    sleep 2
done

echo "Vault unsealed successfully"