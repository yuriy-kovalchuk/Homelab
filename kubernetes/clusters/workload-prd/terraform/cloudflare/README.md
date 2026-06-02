# Cloudflare Tunnel — Terraform

Manages the Cloudflare Tunnel for public-facing workload apps.
Traffic flows: `Internet → Cloudflare edge → cloudflared pod → public gateway (10.0.4.51) → app`.

## Creating the API token

Go to **dash.cloudflare.com → My Profile → API Tokens → Create Token → Create Custom Token**.

### Required permissions

| Resource | Permission |
|---|---|
| Account → Cloudflare Tunnel | Edit |
| Zone → DNS (`yuriykovalchuk.dev`) | Edit |

### Scoping

- **Account resources**: Include → your account
- **Zone resources**: Include → Specific zone → `yuriykovalchuk.dev`

Click **Continue to summary → Create Token**. Copy the token — it is shown only once.

## Environment variables

```bash
export TF_VAR_cloudflare_api_token="<token>"
export TF_VAR_cloudflare_account_id="<account-id>"                      # dash.cloudflare.com → right sidebar
export TF_VAR_cloudflare_zone_id_yuriykovalchuk_dev="<zone-id>"          # dash.cloudflare.com → yuriykovalchuk.dev → Overview → right sidebar
export VAULT_TOKEN="<vault-token>"
```

## Apply

```bash
cd kubernetes/clusters/workload-prd/terraform/cloudflare
terraform init
terraform plan
terraform apply
```

The tunnel token is stored automatically in Vault at `kubernetes/cloudflared/tunnel`.
ESO picks it up and creates the `cloudflared-token` secret in the `cloudflared` namespace.

## Adding a new public app

1. Add an `ingress_rule` to `cloudflare_tunnel_config` in `main.tf`:
   ```hcl
   ingress_rule {
     hostname = "myapp.yuriy-lab.cloud"
     service  = "http://10.0.4.51"
   }
   ```
2. Create an `HTTPRoute` in the app's overlay pointing to the `public` gateway in `public-gateway` namespace.
3. Run `terraform apply`.
