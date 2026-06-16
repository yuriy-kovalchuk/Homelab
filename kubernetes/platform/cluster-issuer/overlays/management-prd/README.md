# Cluster Issuer — Bootstrap Secret

The `ClusterIssuer` uses Cloudflare DNS-01 challenge for Let's Encrypt. Before Flux can reconcile the platform layer, the Cloudflare API token secret must exist in the `cert-manager` namespace.

## 1. Create a Cloudflare API Token

In the [Cloudflare dashboard](https://dash.cloudflare.com/profile/api-tokens):

1. Click **Create Token** → **Create Custom Token**
2. Set permissions:
   - **Zone / Zone / Read**
   - **Zone / DNS / Edit**
3. Under **Zone Resources**, select: **Include → Specific zone → yuriykovalchuk.dev** (covers `*.mgmt.yuriykovalchuk.dev`)
4. Click **Continue to summary** → **Create Token**
5. Copy the token — it is only shown once

## 2. Create the Secret

```bash
kubectl create secret generic cloudflare-api-token-secret \
  --namespace cert-manager \
  --from-literal=api-token=<YOUR_TOKEN>
```

Verify:

```bash
kubectl get secret cloudflare-api-token-secret -n cert-manager
```

Once the secret exists, uncomment `platform.yaml` in
`kubernetes/clusters/management-prd/flux-system/kustomization.yaml` to enable the platform layer.
