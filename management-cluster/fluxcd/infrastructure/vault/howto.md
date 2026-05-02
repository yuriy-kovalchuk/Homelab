# Vault Manual Commands

## Setup Unseal Key Secret

For gitops, convert the secret to SealedSecret:
```bash
kubeseal --format yaml --namespace vault < secret-unseal-key.yaml > sealed-secret.yaml
```

Then update the base64 value with your actual unseal key.

## Initialize Vault (first time only)
```bash
kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1
```

## Get Unseal Key
```bash
kubectl get secret -n vault vault-unseal-key -o jsonpath='{.data.unseal-key}' | base64 -d
```

## Manual Unseal (if needed)
```bash
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key>
```

## Check Vault Status
```bash
kubectl exec -n vault vault-0 -- vault status
```

## Update Unseal Key
If you need to rotate the unseal key:
1. Update the secret: `kubectl edit secret -n vault vault-unseal-key`
2. Restart Vault pods: `kubectl rollout restart statefulset -n vault vault`