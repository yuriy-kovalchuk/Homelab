# Bootstrap: Vault Kubernetes auth

The `ClusterSecretStore` authenticates against Vault using the ESO controller's
Kubernetes service account. Vault exchanges the service account token for a
short-lived Vault token automatically — no manual secret rotation needed.

## One-time Vault setup

### 1. Configure the Kubernetes auth method

Kubernetes auth was already enabled (`vault auth enable kubernetes`). Configure
it with the workload cluster's API endpoint and CA cert.

**workload-prd cluster:**
```bash
kubectl config view --minify --raw \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > /tmp/k8s-ca.crt

kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'
```

**management-prd cluster:**
```bash
CA=$(cat /tmp/k8s-ca.crt)

kubectl exec -n vault vault-0 -- \
  vault write auth/kubernetes/config \
    kubernetes_host="https://<workload-cluster-api>:6443" \
    kubernetes_ca_cert="$CA"
```

### 2. Create the read policy

**management-prd cluster:**
```bash
kubectl exec -n vault vault-0 -- sh -c 'vault policy write eso-reader - <<EOF
path "kubernetes/data/*" {
  capabilities = ["read"]
}
path "kubernetes/metadata/*" {
  capabilities = ["read", "list"]
}
EOF'
```

### 3. Create the role

**management-prd cluster:**
```bash
kubectl exec -n vault vault-0 -- \
  vault write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=eso-reader \
    ttl=1h
```

### 4. Verify the store is ready

**workload-prd cluster:**
```bash
kubectl get clustersecretstore default-store
```

Expected output:

```
NAME            AGE   STATUS   READY
default-store   1m    Valid    True
```

## Notes

- The `external-secrets` service account is created by the Helm chart — no manual
  secret creation is required.
- Tokens are 1h TTL and renewed automatically by ESO.
- The Vault auth mount path (`kubernetes`) must match `mountPath` in the
  `ClusterSecretStore` spec.
