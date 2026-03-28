# Configuration

This document describes the environment configuration required to run the homelab tooling.

## Environment File (.env)

Place a `.env` file at the repository root to configure credentials and parameters. The Devbox shell automatically exports these variables on entry (via `devbox.json` init_hook).

> **Security:** Never commit `.env` to version control. Treat all secrets carefully.

## Required Variables

### Terraform S3 Backend

These variables configure the S3-compatible backend for Terraform state storage.

| Variable | Purpose | Example |
|----------|---------|---------|
| `TF_VAR_s3_access_key` | S3 backend access key | `terraform-prd` |
| `TF_VAR_s3_secret_key` | S3 backend secret key | `********` |
| `TF_VAR_s3_endpoint` | S3-compatible endpoint URL | `http://10.0.10.40:9000` |

**Used by:** All Terraform modules (`terraform/clusters/`, `terraform/infrastructure/`, `terraform/apps/`, `terraform/platform/`)

### OPNsense API

These variables configure access to the OPNsense firewall API.

| Variable | Purpose | Example |
|----------|---------|---------|
| `OPNSENSE_URI` | Base URL to OPNsense API | `https://10.0.10.254` |
| `OPNSENSE_KEY` | OPNsense API key | `********` |
| `OPNSENSE_SECRET` | OPNsense API secret | `********` |
| `OPNSENSE_SKIP_TLS_VERIFY` | Skip TLS verification (self-signed certs) | `true` |

**Used by:** dns-sync application

### Vault Secrets Management

These variables configure secrets stored in HashiCorp Vault via `terraform/apps/vault`.

| Variable | Purpose |
|----------|---------|
| `TF_VAR_vault_token` | Vault API token |
| `TF_VAR_cloudflare_token` | Cloudflare API token for cert-manager |
| `TF_VAR_authentik_pg_user` | Authentik PostgreSQL username |
| `TF_VAR_authentik_pg_password` | Authentik PostgreSQL password |
| `TF_VAR_authentik_admin_password` | Authentik admin password |
| `TF_VAR_grafana_admin_user` | Grafana admin username |
| `TF_VAR_grafana_admin_password` | Grafana admin password |
| `TF_VAR_grafana_client_id` | Grafana OIDC client ID |
| `TF_VAR_grafana_client_secret` | Grafana OIDC client secret |
| `TF_VAR_rustfs_*` | RustFS access keys and credentials |
| `TF_VAR_mimir_*` | Mimir S3 credentials (RustFS backend) |
| `TF_VAR_opnsense_secret` | OPNsense API secret |
| `TF_VAR_truenas_api_key` | TrueNAS API key |

**Used by:** `terraform/apps/vault`

### Authentik OIDC

These variables configure OAuth2 providers in Authentik via `terraform/apps/authentik`.

| Variable | Purpose |
|----------|---------|
| `TF_VAR_authentik_token` | Authentik API token |
| `TF_VAR_proxmox_provider_client_secret` | Proxmox OIDC client secret |
| `TF_VAR_argocd_provider_client_secret` | ArgoCD OIDC client secret |
| `TF_VAR_vault_provider_client_secret` | Vault OIDC client secret |
| `TF_VAR_grafana_provider_client_secret` | Grafana OIDC client secret |

**Used by:** `terraform/apps/authentik`

### Maya Infrastructure (ACME)

These variables configure ACME certificates on the Maya Proxmox node.

| Variable | Purpose |
|----------|---------|
| `TF_VAR_acme_email` | Email for Let's Encrypt account |
| `TF_VAR_acme_cf_account_id` | Cloudflare account ID |
| `TF_VAR_acme_cf_token` | Cloudflare API token for DNS validation |

**Used by:** `terraform/infrastructure/maya`

### Release Automation

These variables are required to push Helm charts to the Harbor OCI registry using the `Makefile`.

| Variable | Purpose | Example |
|----------|---------|---------|
| `HARBOR_USER` | Harbor registry username (e.g., admin) | `admin` |
| `HARBOR_PASSWORD` | Harbor registry password | `********` |

**Used by:** `Makefile` (run `make login` first)

## Example .env File

```bash
# Terraform S3 Backend (RustFS)
TF_VAR_s3_access_key=admin
TF_VAR_s3_secret_key=your-secret-key-here
TF_VAR_s3_endpoint=http://10.0.10.40:9000

# Proxmox API (Firewall Node)
FIREWALL_USER=root@pam
FIREWALL_PASSWORD=your-password

# OPNsense API
OPNSENSE_URI=https://10.0.10.254
OPNSENSE_KEY=your-api-key
OPNSENSE_SECRET=your-api-secret
OPNSENSE_SKIP_TLS_VERIFY=true

# Vault (for terraform/apps/vault)
TF_VAR_vault_token=hvs.xxxxx

# Authentik (for terraform/apps/authentik)
TF_VAR_authentik_token=your-authentik-api-token
TF_VAR_proxmox_provider_client_secret=xxx
TF_VAR_argocd_provider_client_secret=xxx
TF_VAR_vault_provider_client_secret=xxx
TF_VAR_grafana_provider_client_secret=xxx

# Maya ACME (for terraform/infrastructure/maya)
TF_VAR_acme_email=your-email@example.com
TF_VAR_acme_cf_account_id=cloudflare-account-id
TF_VAR_acme_cf_token=cloudflare-api-token
```

## Notes

- Only include variables you actually use
- Quote values containing spaces
- Some scripts allow overriding via direct flags; see each folder's README

---

## Related Documentation

- [Architecture Overview](architecture.md)
- [Infrastructure](infrastructure.md)
