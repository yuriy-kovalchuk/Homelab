# TODO — next big steps

## 0. Implement the backup strategy

Full design in [`docs/BACKUPS.md`](docs/BACKUPS.md) — follow its "Implementation order" checklist (offsite bucket → Vault snapshots → TrueNAS snapshot/sync tasks → CNPG Barman → Longhorn backups → PBS → etcd → Velero → drills).

## 1. Migrate Forgejo from TrueNAS to the cluster

Currently a TrueNAS docker app (`proxmox-nodes/terraform/_modules/truenas-apps/app-forgejo.tf`, `codeberg.org/forgejo/forgejo:15`) behind the TrueNAS-local Traefik. The cluster gateway already has `https-forgejo` and `ssh-forgejo` (TCP 22) listeners pointing at a `forgejo` namespace, and the admin credentials are already in Vault (`kubernetes/forgejo/admin`) — the cluster side is half-prepared.

- [ ] Create `kubernetes/apps/forgejo/` (base + overlay) using the Forgejo helm chart
- [ ] Database: CNPG cluster (`pg-cluster-forgejo`) instead of embedded SQLite — reuse the immich pattern (ExternalSecret basic-auth, operator egress policy in `cloudnative-pg/base/network-policy.yaml`)
- [ ] Storage: `truenas-iscsi` PVC for repos (size after checking the current `/mnt/tank/forgejo` usage)
- [ ] Wire the existing `ssh-forgejo` TCP listener to the Forgejo SSH service (TCPRoute)
- [ ] Migrate data: `forgejo dump` on TrueNAS → restore in-cluster; verify repos, users, webhooks
- [ ] Cut over DNS, then remove `app-forgejo.tf`, the `forgejo` dataset in `truenas-setup`, and (if Forgejo was its last user) the TrueNAS Traefik app
- [ ] ⚠️ Same data-loss caveat as immich/opencloud: `terraform state rm` or migrate before `apply` destroys the dataset

## 2. Remove unused VLANs and simplify the network

- [ ] **VLAN 2 removal blocker:** `yk-dns-manager` talks to the OPNsense API at `https://10.0.2.1/api` (`kubernetes/platform/yk-dns-manager/base/helm-release.yaml`). Repoint it to `10.0.4.1` (VLAN 4 firewall already allows 443 to the gateway) and verify DNS records still reconcile **before** touching VLAN 2
- [ ] Audit for other `10.0.2.x` references (ansible inventories, OPNsense config, switch port config)
- [ ] Remove VLAN 2: OPNsense interface + firewall rules (ansible), switch tagging, DHCP
- [ ] Reassess VLAN 5/6/7 — are three separate wireless/device segments still earning their firewall-rule upkeep?
- [ ] Update `docs/NETWORK.md` and `docs/DEVICES.md` (also add `node-3`, currently undocumented)

## 3. Install Authentik (SSO / auth provider)

Groundwork already exists: `cloudnative-pg/base/network-policy.yaml` still carries an `allow-egress-to-authentik` rule for a `pg-cluster-authentik` in namespace `authentik` — a previous attempt's leftover that matches the target design.

**Layer placement: `platform`** — it needs storage (longhorn/democratic-csi), gateway, cert-manager, and external-secrets, all available by then; and its consumers (grafana in observability, forgejo/immich/open-webui in apps/llm) are all downstream of platform, so OIDC integration never points "up" the dependency chain.

- [ ] **Prerequisite: move `cloudnative-pg` from `apps` → `platform`** (it's an operator, it belongs there anyway), ordered before authentik in the platform kustomization. Today the CNPG operator lives in the apps layer — Authentik-in-platform needing a CNPG `Cluster` would be a cross-layer cycle. Moving immich's DB dependency down a layer is harmless (apps already depends on platform)
- [ ] Add `kubernetes/platform/authentik/`: helm chart + CNPG `Cluster` `pg-cluster-authentik` (the egress policy is already waiting) + built-in/valkey Redis + ExternalSecret (secret key, bootstrap admin) + `https-authentik` listener + HTTPRoute
- [ ] Vault secrets via `clusters/workload-prd/terraform/vault/authentik.tf`
- [ ] Integrate downstream apps as OIDC clients: grafana, forgejo (after migration), immich (supports OIDC), open-webui, opencloud (swap its built-in IDP for external OIDC)
- [ ] Decide the story for UIs with no native auth (longhorn, hubble, kyverno-reporter, flux-operator UI, goldilocks): oauth2-proxy/forward-auth in front — Cilium Gateway has no native forward-auth, so this is per-app proxy or an Envoy ext_authz experiment
- [ ] **Avoid circular auth dependencies:** never put authentik in the login path of the things it depends on — Vault (its secrets source), Flux, or the gateway route serving authentik itself. Keep break-glass local admins (grafana admin secret, Vault root/userpass) so an authentik outage can't lock you out of the tools needed to fix authentik
- [ ] Add `pg-cluster-authentik` to the CNPG Barman schedules (`docs/BACKUPS.md`)

## 4. Complete network policy review

Audit every `CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy` in the cluster against the stated conventions (CLAUDE.md) and against real traffic. Known findings to start from (see also suggestions.md #7 and #12):

- [ ] **Inventory:** list all policies (`grep -rl "kind: Cilium.*NetworkPolicy" kubernetes/`) + what each namespace actually allows; flag namespaces with *no* policy at all
- [ ] **Fix known convention violations:** `cloudnative-pg/base` combines `kube-apiserver`+`remote-node`+`host` in one rule with only 6443 (convention: split rules, both 6443 and 443)
- [ ] **Remove stale rules:** `allow-egress-to-authentik` in `cnpg-system` (dead until TODO #3 lands — or keep, documented, as the authentik landing zone)
- [ ] **Tighten the broad ones:**
  - `allow-gateway-frontend` admits all of `10.0.5.0/24` to every gateway listener — consider splitting admin UIs (longhorn, hubble, flux UI, goldilocks, kyverno-reporter) from family-facing apps (separate gateway or `fromCIDR` narrowing) until Authentik forward-auth exists
  - `cloudflared` egress `toEntities: ingress` port 80 lets the tunnel reach *every* hostname on the gateway — decide whether public apps should instead each get an explicit `toEndpoints` rule (pattern already started for whoami/yk-portfolio) and drop the gateway rule
  - review every `toEntities: world` egress (immich server/ml, flux, cert-manager…) — port-scoped is good, but check none can be `toFQDNs` instead (Cilium DNS-aware policies are already enabled via the cluster-wide DNS rule)
- [ ] **Verify with Hubble, not by reading:** run each app through its real flows and check `hubble observe --verdict DROPPED` for both false-denies and rules that never match (candidates for removal)
- [ ] **Document the verified end state** in CLAUDE.md conventions + a short `docs/NETWORK-POLICIES.md` inventory table (namespace → allowed ingress/egress → why)

## 6. Split Alertmanager Slack notifications by component/channel

Alert rules now exist (`kubernetes/observability/alerting-rules/base/`: `node-not-ready.yaml`, `node-resources.yaml`, `workload-health.yaml`, `storage.yaml`, `certificates.yaml`, `database.yaml`, `gitops.yaml`, `watchdog.yaml`) and every alert already carries a `component` label (`node`, `workload`, `storage`, `certificates`, `database`, `gitops`, `alerting`) plus `severity` (`critical`/`warning`/`none`). Alertmanager currently has a single catch-all route → one Slack receiver → `#alerts`, fed by one webhook URL (`alertmanager-slack-webhook` Vault secret → `config.global.slack_api_url` in `kubernetes/observability/alertmanager/overlays/workload-prd/helm-release-patch.yaml`).

**Decision made:** route by `component` label, one Slack channel per component (7 channels), not a severity-based split and not logical groupings.

**Blocker to resolve before implementing:** Alertmanager's built-in Slack receiver only POSTs to a single webhook-bound channel — Slack no longer honors a payload-level `channel` override for App-based Incoming Webhooks, so one webhook URL can't fan out to multiple channels. Two options were discussed, needs a decision to resume:

- [ ] **Option A — native, 7 webhook URLs (recommended, no new infra):** Create 7 Slack Incoming Webhook URLs (same Slack App → "Incoming Webhooks" → "Add New Webhook to Workspace", once per channel). Store all 7 in Vault (extend `clusters/workload-prd/terraform/vault/` the same way the current single webhook is provisioned), expose via ExternalSecret, add 7 `slack_configs` receivers + 7 child `route` blocks matching `component` in `kubernetes/observability/alertmanager/overlays/workload-prd/helm-release-patch.yaml`.
- [ ] **Option B — Slack bot token + relay service:** One bot token (`chat:write` scope, or `chat:write.public`) can post to any channel via `chat.postMessage`, but Alertmanager can't call that API natively — requires a new lightweight Deployment between Alertmanager (`webhook_configs`) and Slack's Web API to translate. More moving parts, one credential instead of seven.
- [ ] Decide whether `Watchdog` (component: `alerting`, fires continuously, `repeat_interval: 3h`) gets its own channel or should be muted/routed elsewhere once the split lands — it's a heartbeat, not actionable.
- [ ] Once the approach is chosen: wire receivers/routes, verify each component's alerts land in the right channel (test by temporarily lowering a `for:` duration or forcing a condition).

## 5. Cleanup follow-ups (small, do alongside)

- [ ] Drop stale gateway listeners: `https-uptime-kuma` (app removed), `https-forgejo`/`ssh-forgejo` stay but only until step 1 lands
- [ ] Remove or deploy the unwired components: `platform/harbor`, `platform/yk-talos-manager`, `core/local-path-provisioner`
- [ ] Remove orphaned variables `immich_db_password` / `opencloud_admin_password` from `truenas-apps/variables.tf`
- [ ] Verify the immich ML `HIP_VISIBLE_DEVICES` placeholder against `rocminfo` on the GPU node
- [ ] Bring `controlplane-3` back online (etcd is running 2/3 — one failure from quorum loss)
