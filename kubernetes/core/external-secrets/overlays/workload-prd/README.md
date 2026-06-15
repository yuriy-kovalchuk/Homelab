# Bootstrap: Vault Kubernetes auth

The `ClusterSecretStore` authenticates against Vault using the ESO controller's
Kubernetes service account. Vault exchanges the service account token for a
short-lived Vault token automatically — no manual secret rotation needed.

## One-time Vault setup

### 1. Get the token reviewer token

The `vault-reviewer` ServiceAccount, Secret, and ClusterRoleBinding are managed
by Flux via `vault-reviewer.yaml`. Once Flux reconciles, extract the token:

**workload-prd cluster:**
```bash
kubectl get secret vault-reviewer-token -n external-secrets \
  -o jsonpath='{.data.token}' | base64 -d
```

### 2. Configure the Kubernetes auth method

**management-prd cluster:**
```bash
# Enable the Kubernetes auth method if not already enabled
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

CA=$(kubectl --kubeconfig ~/.kube/workload config view --minify --raw \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)

kubectl exec -n vault vault-0 -- \
  vault write auth/kubernetes/config \
    kubernetes_host="https://10.0.4.3:6443" \
    kubernetes_ca_cert="$CA" \
    token_reviewer_jwt="<token-from-step-1>"
```

### 3. Create the read policy

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

### 4. Create the role

**management-prd cluster:**
```bash
kubectl exec -n vault vault-0 -- \
  vault write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=eso-reader \
    ttl=1h
```

### 5. Verify the store is ready

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
- The `vault-reviewer` ServiceAccount, Secret, and ClusterRoleBinding are managed
  by Flux. Only the Vault config update (`token_reviewer_jwt`) is manual.
- Tokens issued to ESO are 1h TTL and renewed automatically.
- The Vault auth mount path (`kubernetes`) must match `mountPath` in the
  `ClusterSecretStore` spec.
- **Mount conflict warning:** Both clusters share a single Vault instance with one
  `auth/kubernetes` mount. If ESO is ever added to the management-prd cluster,
  configuring its Kubernetes auth at the same mount will overwrite the workload-prd
  config. At that point, use separate mount paths (e.g. `kubernetes-workload-prd`
  and `kubernetes-mgmt-prd`) and update the `ClusterSecretStore` `mountPath` fields
  accordingly.
