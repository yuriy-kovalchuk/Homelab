# Bootstrap: Vault token secret

The `ClusterSecretStore` authenticates against Vault using a static token stored
as a Kubernetes secret. This secret must be created manually before Flux reconciles
external-secrets, otherwise the store will stay `NotReady`.

## Steps

1. Generate or retrieve a Vault token with read access to the `kubernetes/` KV path.

2. Create the secret in the cluster:

```bash
kubectl create secret generic vault-token \
  --namespace external-secrets \
  --from-literal=token=<your-vault-token>
```

3. Verify the store becomes ready:

```bash
kubectl get clustersecretstore default-store
```

Expected output:

```
NAME            AGE   STATUS   READY
default-store   1m    Valid    True
```

## Notes

- The namespace must exist before running the command. If Flux hasn't reconciled yet, create it first: `kubectl create namespace external-secrets`.
- The token is not managed by Flux and will not be rotated automatically. Rotate it manually in Vault and re-run the `kubectl create secret` command (delete the old one first).
