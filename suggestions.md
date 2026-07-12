# Suggestions & criticalities

An audit of the repo and overall homelab design (2026-07). Ordered by severity.

## Critical

### 1. No visible backup story
**→ Full strategy now designed in [`docs/BACKUPS.md`](docs/BACKUPS.md)** — the gaps that motivated it:

- **CNPG databases** — `pg-cluster-immich` (and future forgejo) have no `backup:` stanza. CNPG has first-class Barman object storage support; RustFS is already there. A `ScheduledBackup` + WAL archiving to a `cnpg-backups` bucket is ~15 lines per cluster and gives point-in-time recovery.
- **Longhorn volumes** — no recurring snapshot/backup jobs configured; Longhorn can back up to the same S3.
- **Vault** — runs on TrueNAS with no snapshot/raft-backup automation visible. Losing it loses every credential in the lab. A cron'd `vault operator raft snapshot save` (or ZFS snapshot + replication of the dataset) is the minimum.
- **TrueNAS datasets** — democratic-csi parents, immich uploads, forgejo repos: confirm ZFS snapshot tasks + off-box replication exist (not visible from this repo). A NAS-local snapshot doesn't survive the NAS dying.

### 2. etcd quorum fragility
`controlplane-3` has been "offline, coming back" long enough to be in the docs. With 2/3 members, a single node failure freezes the control plane. Either bring it back or scale the cluster definition to a size that reflects reality.

### 3. Storage circular dependency worth mapping
The cluster's secrets (Vault), registry (Zot), object storage (RustFS), and half the PVCs (democratic-csi) all live on **one TrueNAS VM on one storage node**. If it dies: no secrets, no image pulls (for anything pinned to Zot), observability backends down, iSCSI/NFS PVCs gone — and the cluster can't self-heal because recovery tooling depends on the same box. Worth writing a short disaster-recovery runbook: what's the boot order, what needs manual unseal, what can't come back without it. (Related: Terraform state lives in RustFS *on* the infrastructure Terraform manages.)

## Important

### 4. Floating image tags on stateful apps
`immich-server:release`, `opencloud-rolling:latest`, and on TrueNAS `zot:latest` / `dockhand:latest` / `traefik:v3`. For Immich especially this is risky: an unplanned pod restart can pull a new major that runs irreversible DB migrations. Pin digests or exact versions; `yk-update-checker` already exists to surface bumps — lean on it instead of floating tags.

### 5. No CI validation on the repo
Flux applies whatever lands on `main`. A GitHub Actions workflow running `kubectl kustomize` over every overlay + `kubeconform` + `flux-local diff` would catch broken YAML/schema before the cluster sees it. (Bonus: fixing the `cilium-policies` cross-boundary file reference would let plain `kustomize build` pass without load-restrictor workarounds.)

### 6. Alerting gap
Metrics/logs/traces are collected, but nothing in the repo defines alert rules or a notification channel. Mimir's ruler + Alertmanager (or Grafana alerting) with a handful of rules — node down, PVC near full, CNPG unhealthy, cert expiry, Flux reconciliation failed, etcd degraded — plus a push channel (ntfy/Telegram) would close the "it broke on Tuesday, I noticed on Sunday" loop. Uptime-kuma was removed; nothing replaced it.

### 7. Policy conventions drift
The stated CNP convention (split `kube-apiserver` vs `remote-node`/`host`, allow both 6443+443) isn't followed by `cloudnative-pg/base/network-policy.yaml` (single combined rule, 6443 only — the operator likely works only because of where it's scheduled). Also `PolicyException`s are broad namespace-wide carve-outs; the immich one exempts 17 policies for the whole namespace when only 2 pods need privileged. Kyverno exceptions support matching on pod names/labels — worth tightening the GPU ones.

### 8. `apps` Flux Kustomization: one blast radius
Everything user-facing is in a single Kustomization with `wait: true, timeout: 5m`. One app stuck Pending (image pull, PVC bind) marks the whole layer failed and blocks pruning/health of the rest. The `llm` layer already solved this by being separate with `wait: false`. Consider per-app Kustomizations (or at least `wait: false` + health checks on the few that matter) — heavy apps like Immich will trip the 5m timeout routinely.

## Nice to have

### 9. Renovate instead of manual bumps
The commit history is a stream of hand-made `chore: bump X` commits. Renovate (self-hosted or via Forgejo once migrated) automates chart/image PRs — pairs well with pinned tags from #4 and CI from #5.

### 10. Secrets hygiene
All `TF_VAR_*` secrets sit in a plaintext `.env` on the workstation, and `vault_kv_secret_v2` values are also persisted in the Terraform state on RustFS. Consider sops+age for the env file, and treat the state bucket as secret-grade (it effectively is).

### 11. GPU access is broader than needed
Immich/llama-cpp pods are `privileged: true` with raw `/dev/dri` hostPath. A device-plugin approach (e.g. generic `/dev/dri` device plugin, or AMD's) would let pods request `amd.com/gpu`-style resources unprivileged. Not urgent — it's a homelab — but it would shrink the PolicyException lists from #7.

### 12. External exposure review
`cloudflared` tunnels into the cluster and the gateway allows LAN VLANs broadly. Worth an explicit inventory: which hostnames are reachable from the internet through the tunnel, and do any (Grafana, Longhorn UI, Hubble, flux-operator UI) lack SSO/authn? An oauth2-proxy or Authentik in front of admin UIs would help — notably there are leftovers of an Authentik CNPG setup (`allow-egress-to-authentik` policy) suggesting this was planned. **→ Now planned as TODO.md #3 (Authentik in the platform layer).**

### 13. Docs freshness automation
CLAUDE.md/DEVICES.md drifted badly until this audit (wrong domain, wrong ASN, missing node-3). A quarterly "docs audit" checklist item — or a CI job that greps docs for hostnames/IPs and diffs against the tree — keeps the context docs trustworthy.
