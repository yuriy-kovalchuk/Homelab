# Authentik OIDC Configuration

Terraform configuration to manage OAuth2/OIDC providers and applications in Authentik.

## Overview

This module configures Single Sign-On (SSO) for homelab services using Authentik as the identity provider. It creates OAuth2 providers, applications, groups, and a forward-auth proxy outpost.

## Configured Applications

| Application | Type | Redirect URLs |
|-------------|------|---------------|
| **Proxmox** | OAuth2 | firewall.yuriy-lab.cloud:8006, maya.yuriy-lab.cloud:8006 |
| **ArgoCD** | OAuth2 | argocd.yuriy-lab.cloud/api/dex/callback |
| **Vault** | OAuth2 | vault.yuriy-lab.cloud/ui/vault/auth/oidc/oidc/callback |
| **Grafana** | OAuth2 | grafana.yuriy-lab.cloud/login/generic_oauth |
| **Proxy** | Forward Auth | authentik.yuriy-lab.cloud (domain-wide) |

## Groups

| Group | Purpose |
|-------|---------|
| ArgoCD Admins | Administrative access to ArgoCD |
| Grafana Admins | Administrative access to Grafana |
| Grafana Editors | Editor access to Grafana |
| Grafana Viewers | Read-only access to Grafana |

## Proxy Outpost

The module configures a forward-auth proxy outpost for protecting services that don't support native OIDC:

- **Mode**: Forward Domain
- **Cookie Domain**: yuriy-lab.cloud
- **External Host**: https://authentik.yuriy-lab.cloud

This enables SSO for applications like Longhorn UI via the Authentik proxy.

## Prerequisites

1. Authentik running on the main Kubernetes cluster
2. Authentik API token with administrative access
3. Environment variables configured in `.env`

## Environment Variables

Add these to your `.env` file:

```bash
# Authentik API
TF_VAR_authentik_token="your-authentik-api-token"

# OAuth2 Client Secrets
TF_VAR_proxmox_provider_client_secret="xxx"
TF_VAR_argocd_provider_client_secret="xxx"
TF_VAR_vault_provider_client_secret="xxx"
TF_VAR_grafana_provider_client_secret="xxx"
TF_VAR_rancher_provider_client_secret="xxx"
```

## Usage

```bash
cd terraform/apps/authentik
tf_init
tf_plan
tf_apply
```

## Adding a New Application

1. Add a new OAuth2 provider resource in `main.tf`:
```hcl
resource "authentik_provider_oauth2" "myapp_provider" {
  name               = "myapp"
  client_id          = "generated-client-id"
  client_secret      = var.myapp_provider_client_secret
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  property_mappings  = data.authentik_property_mapping_provider_scope.test.ids
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://myapp.yuriy-lab.cloud/callback",
    }
  ]
}

resource "authentik_application" "myapp_application" {
  name              = "myapp"
  slug              = "myapp"
  protocol_provider = authentik_provider_oauth2.myapp_provider.id
}
```

2. Add the client secret variable to `variables.tf`
3. Add the secret to your `.env` file
4. Apply the changes

## Files

| File | Description |
|------|-------------|
| `backend.tf` | S3/MinIO state backend |
| `provider.tf` | Authentik provider configuration |
| `variables.tf` | Client secrets and API token variables |
| `data.tf` | Data sources for flows, scopes, and users |
| `main.tf` | OAuth2 providers and applications |
| `outpost.tf` | Proxy outpost for forward-auth |

## Notes

- Client IDs are hardcoded to ensure consistency across applies
- Client secrets are passed via environment variables for security
- The default admin user is `yuriy` (referenced in `data.tf`)
- OIDC configuration in Proxmox (`oidc.tf`) is pending provider support

## Related

- [Vault Secrets](../vault/README.md) - Secrets management including Authentik credentials
- [Apps Documentation](../../../docs/apps.md) - Authentik application deployment
