# TrueNAS VM

Terraform module that provisions the TrueNAS SCALE VM on the storage Proxmox node (`storage`, `10.0.3.2`). Creates the VM with PCIe passthrough for the storage controller and configures a Let's Encrypt certificate on the Proxmox node via Cloudflare DNS.

## Prerequisites

- Proxmox installed and reachable at `10.0.3.2` (storage VLAN, `10.0.3.0/24`)
- IOMMU enabled on the host (required for PCIe passthrough — see step 1)
- PCIe storage controller address known (see step 1)
- Devbox shell active

## 1. Verify IOMMU and PCIe passthrough

SSH into the Proxmox node and confirm IOMMU is active:

```bash
dmesg | grep -e DMAR -e IOMMU | head -5
```

If nothing appears, enable it in `/etc/default/grub`:

```
# Intel CPU
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# AMD CPU
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

Then:
```bash
update-grub && reboot
```

Find the PCIe address of the storage controller to pass through:

```bash
lspci -nn | grep -i -e sata -e nvme -e storage
```

Note the address (e.g. `04:00.0`) — you will need it in the next step.

## 2. Configure

```bash
cp .env.example .env
```

Fill in `.env`:
- `TF_VAR_storage_proxmox_endpoint` — `https://10.0.3.2:8006/`
- `TF_VAR_storage_proxmox_password` — Proxmox root password
- `TF_VAR_storage_pcie_controller` — PCIe address from step 1 (e.g. `0000:04:00.0`)
- `TF_VAR_storage_acme_domain` — domain for the Proxmox certificate (e.g. `storage.yuriy-lab.cloud`)

The ACME credentials (`TF_VAR_acme_email`, `TF_VAR_acme_cf_account_id`, `TF_VAR_acme_cf_token`)
are shared with other modules — set them once in the global `.env` at the repo root.

## 3. Download the TrueNAS ISO

SSH into the storage Proxmox node and download the ISO directly:

```bash
wget -O /var/lib/vz/template/iso/truenas-scale-25.10.2.1.iso \
  "https://download.truenas.com/TrueNAS-SCALE-Goldeye/25.10.2.1/TrueNAS-SCALE-25.10.2.1.iso?download=1"
```

## 4. Apply

From the devbox shell (`devbox shell` at repo root):

```bash
source .env
tf_init_local
tf_plan
tf_apply
```

This:
- Creates the TrueNAS VM (ID 1000) on `vmbr0` with PCIe passthrough for the storage controller
- Configures the ACME account + Cloudflare DNS plugin on the Proxmox node
- Issues a Let's Encrypt certificate for `$TF_VAR_acme_domain`

## 5. Install TrueNAS SCALE

Open the Proxmox web UI → VM 1000 → Console. Once the ISO boots:

1. Select **Install/Upgrade**
2. Select the boot disk — choose `sda` (the 32 GB virtio disk, **not** the passthrough controller disks)
3. Confirm to erase and install
4. Set the admin password when prompted
5. Reboot when installation completes

> After reboot, detach the CDROM in Proxmox to prevent booting from ISO again:
> VM → Hardware → CD/DVD Drive → select `Do not use any media`

## 6. Reserve static IP in Kea

Before starting the VM, add a DHCP reservation in OPNsense so TrueNAS always boots with `10.0.3.3`:

1. Open the OPNsense web UI → **Services → Kea DHCP → DHCPv4 → Reservations**
2. Click **+** and fill in:
   - Subnet: `10.0.3.0/24`
   - MAC address: `BC:24:11:19:5C:66`
   - IP address: `10.0.3.3`
   - Description: `TrueNAS SCALE VM`
3. Click **Save** and **Apply**

TrueNAS will be reachable at `https://10.0.3.3` after first boot.

## 7. Verify passthrough disks

In the TrueNAS web UI, go to **Storage → Disks** and confirm the physical disks from the
passthrough controller are visible. These are the disks used for storage pools — do not
confuse them with `sda` (the VM boot disk).

## 8. Next steps

- Create storage pools in TrueNAS (**Storage → Create Pool**)
- Configure NFS shares for k8s-mgmt and k8s-workload VLANs
- Configure SMB shares if needed for phys-workload and private-wifi VLANs

See [`NETWORK.md`](../../../NETWORK.md) for which VLANs have access to the storage network.
