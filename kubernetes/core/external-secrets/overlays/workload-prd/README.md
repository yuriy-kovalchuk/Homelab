# Bootstrap: Vault Kubernetes auth

The `ClusterSecretStore` authenticates against Vault using the ESO controller's
Kubernetes service account. Vault exchanges the service account token for a
short-lived Vault token automatically — no manual secret rotation needed.

**Vault runs on TrueNAS** as the `hashicorp/vault` Docker app (VLAN 3) — it is
**not** a Kubernetes workload anywhere, so there's no `kubectl exec` into a
Vault pod. Run the `vault` commands below either via `docker exec` into the
Vault container on TrueNAS, or remotely with `VAULT_ADDR` pointed at it.

**`VAULT_ADDR` gotcha:** the `vault` CLI defaults to `https://127.0.0.1:8200`
if unset, which is wrong almost everywhere here. Inside the Vault container
the listener is plain HTTP:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
```

From anywhere else, use the external HTTPS address instead:

```bash
export VAULT_ADDR=https://vault.yuriykovalchuk.dev
```

Also make sure `VAULT_TOKEN` is set to a token with `sudo` capability on
`auth/kubernetes/config` (the root token, or an equivalent admin policy) —
writing auth-method config is a root-protected Vault endpoint, a plain
read/write policy isn't enough and fails with `403 permission denied`.

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

**On the Vault host (TrueNAS), with `VAULT_ADDR`/`VAULT_TOKEN` set as above:**
```bash
# Enable the Kubernetes auth method if not already enabled
vault auth enable kubernetes

# CA cert comes from the workload-prd cluster, not Vault's own
CA=$(kubectl --kubeconfig ~/.kube/workload config view --minify --raw \
  -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)

vault write auth/kubernetes/config \
  kubernetes_host="https://10.0.4.3:6443" \
  kubernetes_ca_cert="$CA" \
  token_reviewer_jwt="<token-from-step-1>"
```

### 3. Create the read policy

```bash
vault policy write eso-reader - <<EOF
path "kubernetes/data/*" {
  capabilities = ["read"]
}
path "kubernetes/metadata/*" {
  capabilities = ["read", "list"]
}
EOF
```

### 4. Create the role

```bash
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
  `ClusterSecretStore` spec (`kubernetes/secrets/base/cluster-secret-store.yaml`).
- **This step must be redone if `external-secrets`' namespace/ServiceAccount is
  ever deleted and recreated from scratch** (e.g. a full namespace GC event) —
  the reviewer token embedded in Vault's `auth/kubernetes/config` goes stale and
  every login starts failing with `403 permission denied`. Symptom: the
  `ClusterSecretStore` shows `InvalidProviderConfig` / `unable to create client`,
  and `kubectl logs -n external-secrets deploy/external-secrets` shows
  `unable to log in with Kubernetes auth`. Fix: repeat step 1 for a fresh token,
  then step 2 to push it to Vault — steps 3 and 4 don't need to be redone, the
  policy and role are unaffected.
- If Vault is ever also used to authenticate a second Kubernetes cluster, it
  can't share this same `auth/kubernetes` mount — configuring a second
  cluster's Kubernetes auth at the same mount path overwrites this config.
  Use a distinct mount path per cluster (e.g. `kubernetes-workload-prd`) and
  update the `ClusterSecretStore` `mountPath` field accordingly.
