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
| `TF_VAR_s3_endpoint` | S3-compatible endpoint URL | `http://10.0.10.10:9000` |

**Used by:** Talos Terraform init scripts (`terraform/kubernetes/`, `terraform/maya/`)

### OPNsense API

These variables configure access to the OPNsense firewall API.

| Variable | Purpose | Example |
|----------|---------|---------|
| `OPNSENSE_URI` | Base URL to OPNsense API | `https://10.0.8.254` |
| `OPNSENSE_KEY` | OPNsense API key | `********` |
| `OPNSENSE_SECRET` | OPNsense API secret | `********` |
| `OPNSENSE_SKIP_TLS_VERIFY` | Skip TLS verification (self-signed certs) | `true` |

**Used by:** dns-sync application

## Example .env File

```bash
# Terraform S3 Backend (MinIO)
TF_VAR_s3_access_key=terraform-prd
TF_VAR_s3_secret_key=your-secret-key-here
TF_VAR_s3_endpoint=http://10.0.10.10:9000

# OPNsense API
OPNSENSE_URI=https://10.0.8.254
OPNSENSE_KEY=your-api-key
OPNSENSE_SECRET=your-api-secret
OPNSENSE_SKIP_TLS_VERIFY=true
```

## Notes

- Only include variables you actually use
- Quote values containing spaces
- Some scripts allow overriding via direct flags; see each folder's README

---

## Related Documentation

- [Architecture Overview](architecture.md)
- [Infrastructure](infrastructure.md)
