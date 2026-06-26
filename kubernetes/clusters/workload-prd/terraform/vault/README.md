# Vault Terraform

Writes secrets into Vault KV (`kubernetes/` mount). Consumed by ExternalSecrets in the workload-prd cluster.

## Applying

```bash
export VAULT_TOKEN=<your-token>
export TF_VAR_truenas_token=$TRUENAS_TOKEN
terraform init
terraform apply
```

## Creating a TrueNAS API token for democratic-csi

democratic-csi needs a TrueNAS API token with full admin access to create datasets, NFS shares, and iSCSI targets.

**Via TrueNAS UI:**
1. Log in to TrueNAS at `https://truenas.yuriy-lab.cloud`
2. Go to **Top-right menu → API Keys**
3. Click **Add**, name it `democratic-csi`, no expiry
4. Copy the token — it is only shown once

**Via SSH:**
```bash
ssh root@10.0.3.3
midclt call api_key.create '{"name": "democratic-csi"}'
# Returns: {"id": 1, "name": "democratic-csi", "key": "1-xxxxxx..."}
```

Pass the token as `truenas_api_key` and the username (`root` or the API key owner) as `truenas_api_user` when running `terraform apply`.

> Note: the democratic-csi driver config uses `username` + `password` fields for the TrueNAS REST API.
> TrueNAS accepts an API token in the `password` field when `username` is set to the token owner.
