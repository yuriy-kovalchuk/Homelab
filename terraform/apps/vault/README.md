# Vault Secrets Management

Terraform configuration to manage secrets in HashiCorp Vault on the management cluster.

## Overview

This module creates KV secrets in Vault that are consumed by Kubernetes ExternalSecrets on the main cluster.

## Vault Structure

| Path | Keys | Used By |
|------|------|---------|
| `kubernetes/prd` | cloudflare-token | cert-manager |
| `kubernetes/prd/authentik` | pg_user, pg_password, auth_admin_password | authentik |
| `kubernetes/prd/democratic-csi` | iscsi_config, nfs_config | democratic-csi |
| `kubernetes/prd/grafana` | admin-user, admin-password, client_id, client_secret | grafana |
| `kubernetes/prd/minio` | S3_ACCESS_KEY, S3_SECRET_KEY, rootUser, rootPassword | minio, loki |
| `kubernetes/prd/mimir` | access_key_id, secret_access_key | mimir |
| `kubernetes/prd/opnsense` | secret | dns-sync |

## Prerequisites

1. Vault running on management cluster
2. Vault token with write access to `kubernetes/*` path
3. Environment variables configured in `.env`

## Environment Variables

Add these to your `.env` file:

```bash
# Vault connection
TF_VAR_vault_token="hvs.xxxxx"

# Secrets
TF_VAR_cloudflare_token="xxx"
TF_VAR_authentik_pg_user="authentik"
TF_VAR_authentik_pg_password="xxx"
TF_VAR_authentik_admin_password="xxx"
TF_VAR_grafana_admin_user="admin"
TF_VAR_grafana_admin_password="xxx"
TF_VAR_grafana_client_id="xxx"
TF_VAR_grafana_client_secret="xxx"
TF_VAR_minio_s3_access_key="xxx"
TF_VAR_minio_s3_secret_key="xxx"
TF_VAR_minio_root_user="xxx"
TF_VAR_minio_root_password="xxx"
TF_VAR_mimir_access_key="xxx"
TF_VAR_mimir_secret_key="xxx"
TF_VAR_opnsense_secret="xxx"
TF_VAR_truenas_api_key="xxx"
```

## Usage

```bash
cd terraform/apps/vault
tf_init
tf_plan
tf_apply
```

## Getting the Vault Token

Get the root token from the management cluster:

```bash
kubectl get secret vault-unseal-keys -n vault-system \
  -o jsonpath='{.data.vault-root}' \
  --kubeconfig=~/.kube/management-talos.yaml | base64 -d
```

## Files

| File | Description |
|------|-------------|
| `backend.tf` | S3/MinIO state backend |
| `provider.tf` | Vault provider configuration |
| `variables.tf` | Input variables (secrets from env) |
| `mounts.tf` | KV secret engine mount |
| `main.tf` | Secret resources |
