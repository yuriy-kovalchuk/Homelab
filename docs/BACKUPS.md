# Backup Strategy

Full-homelab backup design. Goal: **3-2-1** — three copies, two different systems, one offsite — with restore paths that don't depend on the thing being restored.

---

## Principles

1. **Git is the config backup.** Everything declarative (k8s manifests, terraform, ansible) is rebuildable from this repo. Backups only need to cover *state*: databases, volumes, secrets, snapshots of things Git can't express.
2. **Tier the data.** Irreplaceable data gets offsite copies and tested restores; disposable data gets nothing. Don't pay B2 egress for Mimir blocks.
3. **App-consistent > crash-consistent.** Databases get dumped/WAL-archived by their own tooling (CNPG Barman, `vault operator raft snapshot`), not just snapshotted underneath.
4. **The backup path must not depend on the failure domain.** Today Vault, Zot, RustFS, and half the PVCs live on one TrueNAS VM — its backups cannot land only on itself.
5. **A backup that hasn't been restored is a hope, not a backup.** Scheduled restore drills, alerts on failure, dead-man switch on silence.

## Data inventory & tiers

| Tier | Data | Where it lives | RPO target |
|------|------|----------------|------------|
| **T1 — irreplaceable** | Immich photo library | TrueNAS (`truenas-nfs` PVC dataset) | 24h |
| | Forgejo repos (post-migration) | TrueNAS iSCSI PVC / dataset | 24h |
| | CNPG databases (immich, future forgejo/authentik) | Longhorn / truenas-iscsi PVs | ~5 min (WAL) |
| | Vault data (all lab credentials) | TrueNAS `vault` dataset | 24h |
| | OpenCloud user files | TrueNAS iSCSI PVC | 24h |
| **T2 — painful to rebuild** | OPNsense config, TrueNAS config, Talos machine secrets, Terraform state, PBS/host configs | various | on change / 24h |
| | VM disks (OPNsense, TrueNAS VM itself) | Proxmox local storage | weekly |
| **T3 — disposable** | Observability data (Mimir/Loki/Tempo buckets), Zot registry cache, GGUF models, ML model cache, Longhorn scratch | RustFS / PVCs | none — re-pullable |

---

## Layer 1 — Proxmox: Proxmox Backup Server (PBS)

The state-of-the-art tool for this layer. Incremental forever, dedup, zstd, encryption, scheduled verify + prune.

- **Host PBS off the failure domain:** a PBS VM on `gateway-pve` with its datastore on a disk that is *not* the storage node (USB/SATA disk on the gateway node is fine for a homelab), or a small dedicated box. Do **not** put the only PBS datastore on TrueNAS — it must survive the storage node dying.
- Back up **all VMs** from both nodes: OPNsense VM, TrueNAS VM (root disk only — exclude the `tank` data disks from the job; the data is covered by ZFS replication below), any future VMs.
- Schedule: weekly full-VM backups (T2), `verify` job weekly, prune policy `keep-daily=7, keep-weekly=4, keep-monthly=6`.
- **PBS remote sync** to the offsite target (see Layer 6) or `proxmox-backup-client` push to a cloud datastore.
- Proxmox host configs (`/etc/pve`, network, storage.cfg) are small — add a `vzdump` host-config cron or manage them via the existing ansible so they're re-applyable.

**OPNsense (belt and braces, VM backup already covers it):** enable the built-in config auto-backup — the `os-git-backup` plugin commits `config.xml` to a private Git repo on every change. Config-on-change beats weekly VM images for firewall rules.

## Layer 2 — TrueNAS: ZFS snapshots + replication + cloud sync

TrueNAS data (docker app volumes, democratic-csi parent datasets, immich uploads) is all ZFS — use ZFS-native tooling:

- **Periodic snapshot tasks** on `tank`: hourly (keep 24) + daily (keep 14) on T1 datasets; daily (keep 7) elsewhere. Snapshots give instant local restore and protect against oops-deletion — but they are copy #1, same box.
- **Replication task (`zfs send`)** of T1 datasets to a second ZFS target — options in order of preference: a disk shelf/second pool on `gateway-pve`, a cheap second-hand mini-NAS, or zfs.rent-style hosted ZFS. This is copy #2, different hardware, and it's block-level incremental (cheap).
- **Cloud sync task** (TrueNAS built-in, rclone under the hood) for T1 datasets → offsite bucket (Layer 6), encrypted at rest with rclone crypt. Daily.
- **TrueNAS config export**: enable the automatic config backup (System → General → Save Config) or a cron uploading it to the offsite bucket — this file recreates users, shares, iSCSI targets, and app definitions.

**Docker apps on TrueNAS** — volumes are datasets (covered above), but two need app-consistent handling:

- **Vault (the crown jewel):** ZFS snapshot alone risks an inconsistent barrier. Add a nightly cron (TrueNAS or a k8s CronJob hitting the API): `vault operator raft snapshot save` → push the snapshot file to the offsite bucket. Keep the **unseal key + root token recovery material offline** (printed / password manager), because restoring Vault is step zero of every other restore.
- **Forgejo (until migrated):** nightly `forgejo dump` into its dataset before the snapshot window, so the snapshot always contains a consistent dump.

## Layer 3 — Kubernetes

Four distinct mechanisms, each the state-of-the-art for its slice:

### 3a. etcd / Talos
- Nightly `talosctl etcd snapshot` from a CronJob or a cron on the workstation → upload to the offsite bucket. This is the "restore the control plane without re-bootstrapping" path.
- **Talos machine secrets** (`secrets.yaml` / talosconfig, currently only in Terraform state?) — export and store offline + offsite. Without them, disaster recovery means rebuilding the cluster identity from scratch.

### 3b. CNPG databases — Barman to S3 (native, better than any generic tool)
Per cluster, add to the `Cluster` spec + a `ScheduledBackup`:
```yaml
backup:
  barmanObjectStore:
    destinationPath: s3://cnpg-backups/pg-cluster-immich
    endpointURL: https://s3.yuriykovalchuk.dev
    s3Credentials: { ... from ExternalSecret ... }
  retentionPolicy: "14d"
```
This gives continuous WAL archiving → **point-in-time recovery, ~5 min RPO** for the immich DB. Backups land in RustFS (same box ⚠) — the offsite cloud-sync of the `cnpg-backups` bucket (Layer 6) provides the second copy. `bootstrap.recovery` restores declaratively, in keeping with GitOps.

### 3c. Longhorn volumes — native backup target
Longhorn's built-in backup engine (incremental, dedup'd) beats generic file copy for its own volumes:
- Set the cluster backup target: `s3://longhorn-backups@us-east-1/` → RustFS endpoint, credentials via secret.
- `RecurringJob` CRs (GitOps-managed): daily snapshot + backup on T1 volumes (label-selected), weekly on the rest that matter. Exclude T3 (models PVC — re-downloadable).

### 3d. Velero — cluster state + everything the above misses
GitOps rebuilds manifests, so Velero's role is narrower but still valuable: PV data for apps without a native engine, namespace-scoped restores ("give me yesterday's opencloud namespace"), and CRD-heavy state that's tedious to replay (cert-manager certs avoid re-issuing against LE rate limits).
- Install `velero` (infrastructure component, `velero` namespace) with the AWS plugin → RustFS bucket `velero`.
- Use **CSI snapshot data mover** for `truenas-iscsi`/`truenas-nfs` PVs (democratic-csi supports CSI snapshots) and **kopia file-system backup** as fallback.
- Schedules: daily backup of T1 app namespaces (`immich`, `opencloud`, `forgejo`) excluding PVs already covered by CNPG/Longhorn native engines; weekly full-cluster resource-only backup.

### 3e. democratic-csi PVs
Data physically lives on TrueNAS → already covered by Layer 2 snapshots + replication (crash-consistent). Velero/CSI adds app-consistent copies for T1. Both is fine; document which restore path is primary (ZFS for whole-dataset loss, Velero for single-PVC restore).

## Layer 4 — Terraform state
State (in RustFS `s3` backend) contains **secret values** from `vault_kv_secret_v2`. Include the state bucket in the offsite cloud-sync (encrypted), and enable state locking/versioning if RustFS supports object versioning — otherwise a nightly `rclone copy` with dated paths.

## Layer 5 — Git
GitHub is the primary; after the Forgejo migration, set Forgejo to **mirror** the GitHub repos (or vice versa). Two hosted copies of all config = done.

## Layer 6 — Offsite target

One encrypted cloud bucket ties the whole strategy together. Recommended: **Backblaze B2** (cheapest for this volume, S3-compatible, works with TrueNAS cloud sync, rclone, PBS, Velero) or a **Hetzner Storage Box** (flat fee, borg/rsync/rclone). Estimated T1+T2 footprint: photos (~100 GB) + files (~≤400 GB) + DB/WAL/snapshots (~20 GB) → ~0.5 TB ≈ $3/mo on B2.

Everything that lands offsite is encrypted client-side (rclone crypt / PBS encryption / restic-kopia native).

## Monitoring & verification

- **Alert on failure:** PBS email/webhook notifications; Velero + Longhorn + CNPG all expose Prometheus metrics — add alert rules (`velero_backup_last_successful_timestamp`, `cnpg_collector_last_available_backup_timestamp`, Longhorn backup job failures) once the alerting stack (suggestions.md #6) exists.
- **Dead-man switch:** every backup cron pings a [healthchecks.io](https://healthchecks.io) check (free tier) — silence = alert. This catches the failure mode alerts can't: the scheduler itself dying.
- **Restore drills** (quarterly, rotate through):
  1. Restore a CNPG backup into a scratch `Cluster` and run a query.
  2. Restore one Longhorn volume + one Velero namespace into a scratch namespace.
  3. Boot a PBS-restored OPNsense VM on the spare node (no cables).
  4. Restore the Vault raft snapshot into a dev vault and read one secret.
- **Runbook:** [`DISASTER_RECOVERY.md`](DISASTER_RECOVERY.md) — scenario playbooks (app loss → total site loss), the dependency-ordered boot sequence, and the offline recovery material list. Update it after every drill.

## Implementation order

1. [ ] Offsite bucket (B2) + rclone crypt keys stored offline
2. [ ] Vault raft snapshot cron → offsite (**do this first — everything depends on Vault**)
3. [ ] TrueNAS snapshot tasks + config backup + cloud sync of T1 datasets
4. [ ] CNPG `barmanObjectStore` + `ScheduledBackup` for `pg-cluster-immich`
5. [ ] Longhorn backup target + RecurringJobs
6. [ ] PBS deployment + VM jobs + verify/prune + remote sync
7. [ ] Talos etcd snapshot cron + machine-secrets export offline
8. [ ] Velero + CSI data mover, daily T1 schedules
9. [ ] ZFS replication to second box (when hardware exists)
10. [ ] healthchecks.io pings on every job + alert rules
11. [ ] First restore drill — validate `DISASTER_RECOVERY.md` against reality and fix what surprised you
