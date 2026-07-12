# Disaster Recovery

Companion to [BACKUPS.md](BACKUPS.md). That doc is about *making* copies; this one is the runbook for *using* them. Written to be followed at 2am by someone stressed — keep steps literal.

---

## Assumed survivors

Every scenario below assumes only these exist. If a scenario has more survivors, skip steps.

1. **This Git repo** (GitHub, mirrored to Forgejo post-migration)
2. **The offsite bucket** (B2) — Vault raft snapshots, TrueNAS cloud-synced datasets, PBS sync, CNPG/Longhorn/Velero buckets, Terraform state copies, etcd snapshots, TrueNAS + OPNsense config exports
3. **Offline recovery material** (printed / password manager — see appendix): Vault unseal key + root token, B2 credentials + rclone crypt keys, Talos machine secrets, PBS encryption key
4. A workstation with this repo cloned and `devbox shell` working

## Golden rules

- **Restore order is the dependency order.** Network → hypervisor → storage → secrets → cluster → apps. Skipping ahead wastes time (everything downstream crash-loops until its dependency is up).
- **Vault is step zero of anything involving the cluster.** ExternalSecrets, cert-manager, S3 credentials, DB passwords — all dead until Vault is unsealed.
- **Don't terraform against a half-restored world.** Terraform state describes the *old* world; reconcile state (import/`state rm`) before `apply`, or you'll destroy the things you just restored.
- **Internal DNS may lie during recovery.** `*.yuriykovalchuk.dev` internal records live on OPNsense; if OPNsense or the cluster is down, use raw IPs (`docs/DEVICES.md`).

## Dependency map

```
OPNsense (VLANs, DNS, DHCP, BGP)
└── Proxmox nodes (gateway-pve, storage)
    └── TrueNAS VM  ── zpool tank
        ├── Vault  ←──────────────┐  (unseal is MANUAL, every restart)
        ├── RustFS (S3)           │
        ├── Zot (registry)        │
        └── NFS/iSCSI (CSI PVs)   │
            └── Talos cluster     │
                └── Flux → external-secrets ──┘
                    └── core → platform (CSI, gateway) → apps / observability / llm
```

---

## Scenario playbooks (most likely → worst)

### S1 — Deleted/broken app, namespace, or manifest
Flux is the recovery tool. `flux reconcile kustomization <layer> --with-source` re-applies Git. If PV data was lost too: restore the PVC via Velero (`velero restore create --from-backup <daily> --include-namespaces <ns>`) or the Longhorn UI (restore volume from backup, recreate PVC pointing at it), *then* let Flux recreate the workload.

### S2 — Database corruption / bad migration (CNPG)
Point-in-time recovery, declaratively: create a **new** `Cluster` manifest with `bootstrap.recovery` from the Barman object store, `recoveryTarget.targetTime` just before the incident. Verify data in the new cluster, repoint the app's `DB_HOSTNAME`, retire the old cluster. Never restore over the running cluster.

### S3 — Single Talos node dies
Control-plane (while ≥2 CPs remain) or worker: replace hardware, boot Talos installer, apply the machine config (`talosctl apply-config`), let it rejoin. Longhorn rebuilds replicas automatically; check `kubectl -n longhorn-system get volumes` for degraded volumes before declaring done. If it was the GPU node: workloads with `ai-node: oculink` selector stay Pending until the label/taint are reapplied.

### S4 — etcd quorum lost (2 of 3 CPs dead)
`talosctl etcd snapshot` backups exist for this. Recover the surviving node into a single-member cluster (`talosctl bootstrap --recover-from=<snapshot>`), verify the API answers, then re-add members. Flux state, being in Git, needs nothing — it reconverges.

### S5 — OPNsense / gateway node loss
The lab is offline (no routing, no DNS, no DHCP) but data is safe.
1. Restore the OPNsense VM from PBS onto any Proxmox node (or reinstall OPNsense and import the latest `config.xml` from the os-git-backup repo — faster than a full VM restore).
2. Verify per-VLAN gateways answer, DNS resolves, BGP session with the cluster re-establishes (`cilium bgp peers`).
3. Everything else self-heals; no cluster action needed.

### S6 — TrueNAS / storage node loss (the big one)
Cluster degrades immediately: ESO can't refresh, iSCSI/NFS PVs detach, RustFS-backed observability stops. Order:
1. **Hardware/hypervisor:** restore Proxmox storage node; restore TrueNAS VM root disk from PBS.
2. **Pool:** if the `tank` disks survived → `zpool import tank` and skip to 4. If not → recreate the pool.
3. **Data:** restore T1 datasets — from ZFS replication target if it exists (fast, block-level), else from the offsite bucket (`rclone sync` back; hours, not minutes).
4. **TrueNAS config:** import the config export (recreates shares, iSCSI targets, users, apps).
5. **Vault:** start the app, then `vault operator raft snapshot restore` (if dataset was lost) and **unseal manually** with the printed key. Verify: `vault kv get kubernetes/cloudflared/tunnel`.
6. **RustFS + Zot:** start; observability buckets may be gone (T3 — accept the gap).
7. **Cluster reconvergence:** ESO refreshes secrets, CSI reattaches PVs, pods unstick. Force it: `flux reconcile kustomization core platform apps`. Check CNPG clusters last — if their PVs were lost, S2 recovery per database.

### S7 — Total cluster loss (all Talos nodes)
Storage/TrueNAS intact, cluster gone:
1. Reinstall Talos on all nodes with the saved machine secrets (identity preserved → certs/kubeconfig/talosconfig still valid).
2. Either restore the etcd snapshot (S4 — brings back everything instantly) **or** clean re-bootstrap: terraform `cni` + `fluxcd`, then Flux rebuilds every layer from Git in dependency order.
3. On clean rebuild: PVs are the manual part. Longhorn volumes → restore from backup target before apps start claiming PVCs; CNPG → `bootstrap.recovery` (S2); democratic-csi PVs → data still on TrueNAS, but dynamic PVs need re-binding — restore via Velero, or static-PV the old datasets/zvols.
4. Expect first reconcile flaps (CRD ordering, image pulls) — Flux retries through them.

### S8 — Total site loss (fire/theft)
Everything from survivors 1–3: new hardware → S5 (network) → S6 (storage, data from offsite only) → S7 (cluster, clean rebuild path). Terraform state: download the offsite state copy, point backends at it *before* any `terraform` command. Budget: days. The quarterly drills are what make this scenario survivable rather than theoretical.

---

## Verification

- Each playbook above maps to a quarterly drill in BACKUPS.md — after every drill, fix what surprised you *in this file*.
- After any real recovery: `flux get kustomizations` all Ready, `hubble observe --verdict DROPPED` clean, CNPG clusters healthy, one photo uploads to Immich, one secret round-trips through ESO.

## Appendix — offline recovery material (keep printed + in password manager)

| Item | Needed for |
|------|-----------|
| Vault unseal key + root token | S6 step 5 — and therefore everything |
| B2 account + bucket credentials | reaching the offsite copies at all |
| rclone crypt / PBS encryption keys | decrypting them |
| Talos machine secrets (`secrets.yaml`) | S7 without rebuilding cluster identity |
| TrueNAS root password + config export location | S6 step 4 |
| Cloudflare account creds (+ API token) | external DNS/tunnel if the dashboard must be touched |
| This file, printed | the 2am case where nothing resolves |
