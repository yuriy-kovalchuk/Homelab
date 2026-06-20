# TrueNAS Configuration

Terraform module that configures TrueNAS SCALE at `10.0.3.3` using the [bmanojlovic/truenas](https://registry.terraform.io/providers/bmanojlovic/truenas/latest) provider.

## Prerequisites

- TrueNAS SCALE 25.10.1+ installed and reachable at `10.0.3.3`
- Devbox shell active

## 1. Create an API key

In the TrueNAS web UI:

1. Click the user menu (top-right) → **API Keys**
2. Click **Add** and give it a name (e.g. `terraform`)
3. Copy the key — it is shown only once

## 2. Find the disk name

In the TrueNAS web UI go to **Storage → Disks** and note the device name of the
passthrough disk (e.g. `nvme0n1`). This is the disk that will become the pool —
do not use the boot disk (`sda`).

## 3. Configure

Fill in the values in `terraform/prd/.env.example` → `.env` at repo root:
- `TRUENAS_TOKEN` — API key from step 1
- `TRUENAS_POOL_DISKS` — disk name from step 2 (e.g. `'["nvme0n1"]'`)
- `TRUENAS_NAS_USERNAME` — username for the NAS SMB user
- `TRUENAS_NAS_USER_PASSWORD` — password for the NAS SMB user

## 4. Apply

```bash
cd proxmox-nodes/terraform/prd/storage/truenas-setup
terragrunt plan
terragrunt apply
```

> **Note:** A single-disk stripe has no redundancy. Back up important data.

## 5. Enable services (one-time, manual)

The `bmanojlovic/truenas` provider does not have an idempotent resource for enabling
services, so this is done once in the TrueNAS UI for each protocol:

**NFS:** Services → find **NFS** → toggle **on** → gear icon → check **Start Automatically** → Save

**SMB:** Services → find **SMB** → toggle **on** → gear icon → check **Start Automatically** → Save

Services only need to be enabled once; Terraform manages the share configuration.

## What this module manages

| Resource | Name | Details |
|----------|------|---------|
| TrueNAS user | `$TRUENAS_NAS_USERNAME` | SMB-enabled local user for share access |
| ZFS pool | `tank` | Single-disk stripe on the passthrough NVMe |
| Dataset | `tank/nfs-general` | General-purpose NFS dataset, 100 GiB quota |
| NFS share | `/mnt/tank/nfs-general` | Read/write, access controlled by OPNsense firewall |
| Dataset | `tank/smb-general` | General-purpose SMB dataset, 100 GiB quota |
| SMB share | `smb://10.0.3.3/general` | Browsable, access controlled by OPNsense firewall |

### NFS share

**macOS:**
```bash
sudo mkdir -p /mnt/nas
sudo mount -t nfs -o resvport,nfsvers=3 10.0.3.3:/mnt/tank/nfs-general /mnt/nas
```

**Linux:**
```bash
sudo mkdir -p /mnt/nas
sudo mount -t nfs -o nfsvers=3 10.0.3.3:/mnt/tank/nfs-general /mnt/nas
```

**Verify exports:**
```bash
showmount -e 10.0.3.3
```

### SMB share

Share name: `general`. Credentials: `TRUENAS_NAS_USERNAME` / `TRUENAS_NAS_USER_PASSWORD`.

**macOS** — Finder → Go → Connect to Server:
```
smb://<username>@10.0.3.3/general
```

**Linux:**
```bash
sudo mkdir -p /mnt/smb
sudo mount -t cifs //10.0.3.3/general /mnt/smb \
  -o username=<username>,password=<password>,uid=$(id -u),gid=$(id -g)
```
