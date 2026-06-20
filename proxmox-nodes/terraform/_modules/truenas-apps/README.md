# truenas-apps

Manages custom Docker Compose apps on TrueNAS 25.x via the `deevus/truenas` Terraform provider (SSH transport).

## Prerequisites

### 1. Move TrueNAS UI off ports 80/443

Traefik owns ports 80/443. Move the TrueNAS web UI first:

**TrueNAS UI → System → General → GUI Settings**
- HTTPS Port: `8443`
- HTTP Port: `8080`
- Save — the UI will restart on the new ports

After this, TrueNAS UI is at `https://10.0.3.3:8443`.

### 2. Generate the SSH key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/truenas -C "terraform@truenas" -N ""
```

### 3. Add the public key to TrueNAS

**TrueNAS UI → Credentials → Users → root → Edit**

Paste the contents of `~/.ssh/truenas.pub` into **Authorized Keys** and save.

### 4. Enable SSH service

**TrueNAS UI → System → Services → SSH** — enable and set to start automatically.

### 5. Test the connection

```bash
ssh -i ~/.ssh/truenas root@10.0.3.3
```

### 6. Get the host key fingerprint

```bash
ssh-keyscan 10.0.3.3 2>/dev/null | ssh-keygen -lf -
# Use the ECDSA (SHA256:D2I...) line
```

## Running

```bash
export TRUENAS_SSH_PRIVATE_KEY="$(cat ~/.ssh/truenas)"
export TRUENAS_SSH_HOST_FINGERPRINT="SHA256:xxxx"
# TF_VAR_cloudflare_api_token must already be set (shared with cert-manager)

terragrunt plan
terragrunt apply
```

After apply, the Traefik dashboard is available at `https://traefik.yuriykovalchuk.dev`.

## Adding more apps

Every new Docker Compose app that should be routed through Traefik needs to:

1. Join the shared `traefik_proxy` Docker network:
   ```yaml
   networks:
     proxy:
       name: traefik_proxy
       external: true
   ```

2. Add Traefik labels to the service:
   ```yaml
   labels:
     - traefik.enable=true
     - traefik.http.routers.myapp.rule=Host(`myapp.yuriykovalchuk.dev`)
     - traefik.http.routers.myapp.entrypoints=websecure
     - traefik.http.routers.myapp.tls.certresolver=letsencrypt
   ```

## Vault — manual unseal after restart

Vault uses Shamir seal (default). After every TrueNAS reboot or container restart, Vault starts sealed and must be manually unsealed before any secrets can be served.

```bash
ssh root@10.0.3.3
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 ix-vault-vault-1 vault operator unseal <key>
```

Single key is sufficient (threshold = 1 for a homelab single-node setup). The unseal key and root token were generated during `vault operator init`. Auto-unseal would require an external KMS — not currently set up.

## Vault — Kubernetes auth setup

Vault authenticates External Secrets Operator (ESO) in the workload cluster via the Kubernetes auth method. This was configured manually (not via Terraform — auth config rarely changes).

**Auth flow:** ESO presents its SA token → Vault calls the K8s TokenReview API to verify it → Vault issues a short-lived Vault token.

**Requirements:**
- OPNsense firewall rule: VLAN 3 (storage, 10.0.3.0/24) → VLAN 4 (k8s-workload) port 6443 — Vault must reach the K8s API to run TokenReview. This rule is in `firewall.yml` as `opt2-15`.
- `vault-reviewer` ServiceAccount in the `external-secrets` namespace with `system:auth-delegator` ClusterRoleBinding.
- Static token for `vault-reviewer` stored as a Secret (named `vault-reviewer-token`).

**Reconfiguring after CA cert rotation:** If the workload cluster CA cert is rotated, update Vault:

```bash
# Get new CA cert
kubectl --kubeconfig ~/.kube/workload get configmap kube-root-ca.crt -n kube-system -o jsonpath='{.data.ca\.crt}' > /tmp/k8s-ca.crt

# Get vault-reviewer token
kubectl --kubeconfig ~/.kube/workload get secret vault-reviewer-token -n external-secrets \
  -o jsonpath='{.data.token}' | base64 -d > /tmp/reviewer-jwt.txt

# Copy into Vault container and update config
scp /tmp/k8s-ca.crt root@10.0.3.3:/tmp/k8s-ca.crt
ssh root@10.0.3.3 "
  docker cp /tmp/k8s-ca.crt ix-vault-vault-1:/tmp/k8s-ca.crt
  docker cp /tmp/reviewer-jwt.txt ix-vault-vault-1:/tmp/reviewer-jwt.txt
  docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=<root-token> ix-vault-vault-1 \
    sh -c 'vault write auth/kubernetes/config \
      kubernetes_host=https://10.0.4.3:6443 \
      kubernetes_ca_cert=@/tmp/k8s-ca.crt \
      token_reviewer_jwt=\$(cat /tmp/reviewer-jwt.txt) \
      disable_iss_validation=true'
"
```

## Proxying TrueNAS UI through Traefik

Once TrueNAS UI is on port 8443, add this service to `apps.tf` to route `truenas.yuriykovalchuk.dev` through Traefik with a proper TLS cert:

```hcl
resource "truenas_app" "truenas_proxy" {
  name       = "truenas-proxy"
  custom_app = true

  compose_config = <<-EOT
    services:
      proxy:
        image: traefik:v3
        restart: unless-stopped
        networks:
          - proxy
        labels:
          - traefik.enable=true
          - traefik.http.routers.truenas.rule=Host(`truenas.yuriykovalchuk.dev`)
          - traefik.http.routers.truenas.entrypoints=websecure
          - traefik.http.routers.truenas.tls.certresolver=letsencrypt
          - traefik.http.services.truenas.loadbalancer.server.url=https://10.0.3.3:8443
          - traefik.http.services.truenas.loadbalancer.server.tls.insecureskipverify=true

    networks:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
```
