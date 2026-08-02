# Cloudflare Tunnel — Terraform

Manages the Cloudflare Tunnel for public-facing workload apps.
Traffic flows: `Internet → Cloudflare edge → cloudflared pod → app Service (ClusterIP) → app`.

> **Why not a Cilium Gateway?** cloudflared is an in-cluster pod. When an
> in-cluster pod connects to a Cilium Gateway's own LoadBalancer VIP, the
> request hair-pins: Envoy resolves its upstream back to the VIP (classified
> `reserved:world`) instead of the backend pods, and the L7 request is dropped
> (`403 Access denied`). North-south (LAN) traffic is unaffected because the LB
> DNATs to a real pod first. So cloudflared connects **straight to each app's
> in-cluster Service** instead of through a gateway.

## Creating the API token

Go to **dash.cloudflare.com → My Profile → API Tokens → Create Token → Create Custom Token**.

### Required permissions

| Resource | Permission |
|---|---|
| Account → Cloudflare Tunnel | Edit |
| Account → Access: Apps and Policies | Edit |
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

1. Add an `ingress_rule` to `cloudflare_tunnel_config` and a `cloudflare_record` in `main.tf`,
   pointing `service` at the app's in-cluster Service DNS:
   ```hcl
   ingress_rule {
     hostname = "myapp.yuriykovalchuk.dev"
     service  = "http://myapp.myapp.svc.cluster.local"   # <svc>.<namespace>.svc.cluster.local
   }
   ```
   ```hcl
   resource "cloudflare_record" "myapp" {
     zone_id = var.cloudflare_zone_id_yuriykovalchuk_dev
     name    = "myapp"
     type    = "CNAME"
     value   = "${cloudflare_tunnel.homelab.id}.cfargotunnel.com"
     proxied = true
   }
   ```
2. Add an egress rule to the cloudflared CiliumNetworkPolicy
   (`kubernetes/platform/cloudflared/base/network-policy.yaml`) allowing cloudflared
   to reach the app's pods on the Service's `targetPort`.
3. Run `terraform apply`.
