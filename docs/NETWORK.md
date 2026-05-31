# Network Architecture

## Overview

- **Supernet:** `10.0.0.0/16` — all homelab traffic
- **Router/Firewall:** OPNsense VM on Proxmox gateway node
- **Switching:** Managed switch connected to `vmbr1` (VLAN-aware bridge on Proxmox)
- **Uplink:** OPNsense WAN → `vmbr0` → home router → internet

OPNsense owns all VLAN routing. The managed switch does VLAN tagging per port. `vmbr1` carries all VLANs as a trunk to OPNsense. VLAN tag matches the third octet directly (10.0.2.x → VLAN 2, 10.0.3.x → VLAN 3, etc.). VLAN 1 is reserved by 802.1Q and not used.

## VLANs

| VLAN | Subnet       | Purpose                        | Gateway    |
|------|--------------|--------------------------------|------------|
| 2    | 10.0.2.0/24  | Management k8s cluster         | 10.0.2.1   |
| 3    | 10.0.3.0/24  | Storage                        | 10.0.3.1   |
| 4    | 10.0.4.0/24  | Main k8s workload cluster      | 10.0.4.1   |
| 5    | 10.0.5.0/24  | Physical workload              | 10.0.5.1   |
| 6    | 10.0.6.0/24  | Private wireless               | 10.0.6.1   |
| 7    | 10.0.7.0/24  | Guest wireless                 | 10.0.7.1   |

> **Note on VLAN 2:** This is not a traditional management VLAN. It hosts the management k8s cluster which runs shared infrastructure services (Vault, Harbor, etc.) consumed by other VLANs. Its services must be reachable from VLAN 4, 5, and 6.

## Firewall Rules

### Management k8s — VLAN 2

| Direction | Target              | Notes                                    |
|-----------|---------------------|------------------------------------------|
| OUT       | 10.0.2.1 :53        | DNS to gateway                           |
| OUT       | 10.0.2.1 :123       | NTP to gateway                           |
| OUT       | 10.0.2.1 :443       | HTTPS API to gateway                     |
| OUT       | 10.0.2.1 :179       | BGP to gateway                           |
| OUT       | VLAN 3 (full)       | Full storage access                      |
| OUT       | VLAN 4 :6443+50000  | Kubernetes + Talos API (yk-talos-manager)|
| OUT       | Internet            |                                          |
| IN        | VLAN 4              | Vault, Harbor and other shared services  |
| IN        | VLAN 5              | Vault, Harbor and other shared services  |
| IN        | VLAN 6              | Vault, Harbor and other shared services  |

### Storage — VLAN 3

| Direction | Target          | Notes                              |
|-----------|-----------------|------------------------------------|
| OUT       | Internet        | Updates only (port 80/443)         |
| IN        | VLAN 2          | Full access                        |
| IN        | VLAN 4          | Full access                        |
| IN        | VLAN 5          | Full access                        |
| IN        | VLAN 6          | NFS only (port 2049)               |

### Main k8s workload — VLAN 4

| Direction | Target            | Notes                              |
|-----------|-------------------|------------------------------------|
| OUT       | 10.0.4.1 :53      | DNS to gateway                     |
| OUT       | 10.0.4.1 :123     | NTP to gateway                     |
| OUT       | 10.0.4.1 :443     | HTTPS API to gateway               |
| OUT       | 10.0.4.1 :179     | BGP to gateway                     |
| OUT       | VLAN 3 (full)     | Storage access                     |
| OUT       | VLAN 2 :443+8200  | Vault + Harbor only                |
| OUT       | Internet          |                                    |
| IN        | VLAN 2            | Management access                  |
| IN        | VLAN 5            |                                    |
| IN        | VLAN 6            |                                    |

### Physical workload — VLAN 5

| Direction | Target          | Notes                              |
|-----------|-----------------|------------------------------------|
| OUT       | Full access     | All VLANs except VLAN 7 + internet |
| IN        | VLAN 2          |                                    |
| IN        | VLAN 4          |                                    |
| IN        | VLAN 6          |                                    |

### Private wireless — VLAN 6

| Direction | Target          | Notes                              |
|-----------|-----------------|------------------------------------|
| OUT       | VLAN 2          | Shared services access             |
| OUT       | VLAN 3          | NFS shares (port 2049)             |
| OUT       | Internet        |                                    |
| IN        | —               | Not a server VLAN                  |

### Guest wireless — VLAN 7

| Direction | Target          | Notes                              |
|-----------|-----------------|------------------------------------|
| OUT       | Internet        | Hard isolated — no intra access    |
| IN        | —               | Nobody                             |

## Physical Topology

```
Internet
   │
Home Router (192.168.0.1)
   │
Proxmox (192.168.0.254) ── vmbr0 (WAN uplink)
   │
OPNsense VM (vtnet0=WAN, vtnet1=LAN trunk)
   │
vmbr1 (VLAN-aware trunk)
   │
Managed Switch
   ├── Port 1 : Trunk — Proxmox uplink (all VLANs tagged)
   ├── Port 2 : VLAN 2  — management k8s nodes / Proxmox hosts (future)
   ├── Port 3 : VLAN 3  — storage nodes (TrueNAS, NAS)
   ├── Port 4 : VLAN 4  — main k8s workload nodes
   ├── Port 5 : VLAN 5  — physical workload devices
   ├── Port 6 : VLAN 6  — private access point
   └── Port 7 : VLAN 7  — guest access point
```

## Key Design Decisions

- **VLAN tag = third octet** — easy to derive any IP from the VLAN ID without looking it up (VLAN 2 = `10.0.2.x`, VLAN 3 = `10.0.3.x`, etc.). VLAN 1 is reserved by 802.1Q.
- **VLAN 2 hosts shared services** — Vault, Harbor and similar tools run here and are consumed by VLAN 4, 5, and 6. Not a traditional management VLAN.
- **Storage never initiates intra-VLAN connections** — only accepts them. Outbound is internet-only for updates.
- **Physical workload has full outbound** — most permissive VLAN, intended for generic workloads that may need broad access.
- **Private wireless is client-only** — no services run here, only outbound to VLAN 2, VLAN 3, and internet.
- **Proxmox hosts land on VLAN 2** — currently on home LAN (`192.168.0.x`), will move to VLAN 2 when internal network is ready (see `FUTURE.md`).

## BGP — Kubernetes LoadBalancer IPs

OPNsense peers with Cilium BGP Control Plane on the management cluster to advertise
LoadBalancer service IPs. IPs are allocated from a pool within VLAN 2 so they are
routable on the same segment without additional static routes.

| Side       | ASN   | IP        | Role                        |
|------------|-------|-----------|-----------------------------|
| OPNsense   | 65551 | 10.0.2.1  | Router, BGP speaker         |
| mgmt-1     | 65001 | 10.0.2.2  | Kubernetes node, BGP peer   |

**LoadBalancer IP pool:** `10.0.2.50–10.0.2.99` (VLAN 2 — K8sMgmt)

Cilium announces allocated IPs via eBGP to OPNsense. OPNsense installs them as
host routes and forwards traffic to the node that holds the service.

Configured via `proxmox-nodes/gateway/ansible/playbooks/opnsense/bgp.yml` (FRR plugin)
and `infrastructure/overlays/management-prd/bgp/` (Cilium side).

## OPNsense Setup

Managed via Ansible — see `proxmox-nodes/gateway/ansible/README.md` for the full
run order. Summary:

1. `vlans.yml` — creates vtnet1.2–vtnet1.7 VLAN sub-interfaces
2. Manual GUI — assign interfaces, set gateway IPs (OPNsense has no API for this)
3. `dhcp.yml` — configures DHCP pools per VLAN
4. `firewall.yml` — applies aliases and rules from the tables above
5. `bgp.yml` — installs FRR plugin and configures BGP peering with the management cluster

## Managed Switch Setup (UniFi)

**1. Create VLAN networks** — Settings → Networks → Create New Network:

| Name | VLAN ID | Type |
|------|---------|-----------|
| k8s-mgmt | 2 | VLAN Only |
| storage | 3 | VLAN Only |
| k8s-workload | 4 | VLAN Only |
| phys-workload | 5 | VLAN Only |
| private-wifi | 6 | VLAN Only |
| guest-wifi | 7 | VLAN Only |

Use **VLAN Only** — OPNsense handles routing and DHCP, not UniFi.

**2. Understand the two port settings**

Each port has two settings:

- **Native VLAN / Network** — the untagged VLAN. Frames leaving this port for the
  native VLAN have their tag stripped, so the device receives plain ethernet and
  doesn't need to understand VLANs. Frames arriving without a tag are assigned to
  this VLAN.
- **Tagged VLAN Management** — additional VLANs that travel across the port with
  their tag intact. Only devices that understand VLAN tags can use these
  (Proxmox, OPNsense, WiFi APs).

**3. Configure ports by type**

*Trunk port* (connects to Proxmox nic3 → `vmbr1`):
- Native VLAN: **None** — no untagged traffic; everything must be tagged so OPNsense knows which VLAN it belongs to
- Tagged VLANs: **Allow All** — all VLANs 2–7 travel tagged; Proxmox/OPNsense sorts them

*Access port* (regular device — server, NAS, desktop):
- Native VLAN: the device's VLAN (e.g. `storage` for a NAS)
- Tagged VLANs: **Block All** — the device sends and receives plain untagged ethernet; the switch handles VLAN assignment invisibly

*Access point port* (WiFi AP with multiple SSIDs):
- Native VLAN: the VLAN used to manage the AP itself (e.g. `k8s-mgmt`)
- Tagged VLANs: **Custom** → select the VLANs matching each SSID (e.g. `private-wifi` + `guest-wifi`); the AP maps each tag to the right SSID

| Port type | Native VLAN | Tagged VLANs |
|-----------|-------------|--------------|
| Trunk to Proxmox | None | Allow All |
| Server / NAS / desktop | that device's VLAN | Block All |
| WiFi AP (multi-SSID) | AP management VLAN | Custom (one per SSID) |

**4. Port-by-port configuration** (UniFi Flex 2.5 — 8 ports + 2 extra)

| Port | Connected to | Native VLAN | Tagged VLANs |
|------|-------------|-------------|--------------|
| 1 | k8s mgmt nodes | `k8s-mgmt` (2) | Block All |
| 2 | Storage / NAS | `storage` (3) | Block All |
| 3 | k8s workload nodes | `k8s-workload` (4) | Block All |
| 4 | Physical workload devices | `phys-workload` (5) | Block All |
| 5 | WiFi AP (private SSID) | `k8s-mgmt` (2) | Custom: `private-wifi` (6) + `guest-wifi` (7) |
| 6 | — | — | — |
| 7 | — | — | — |
| 8 | — | — | — |
| 9 | Proxmox nic3 (trunk) | None | Allow All (2–7) |
| 10 | — | — | — |

> **Port 5 — WiFi AP:** one physical port carries both SSIDs as tagged VLANs.
> The AP maps VLAN 6 → private SSID, VLAN 7 → guest SSID. Native is `k8s-mgmt`
> so the AP itself gets a management IP on VLAN 2. If you use two separate APs,
> dedicate one port per AP: native = that AP's VLAN, tagged = Block All.

**5. Connect the trunk cable** — port 9 → Proxmox physical NIC (nic3)
→ `vmbr1` → OPNsense vtnet1
