# OPNsense Ansible Configuration

Configures OPNsense after the VM is running. Uses the OPNsense HTTP API via the `oxlorg.opnsense` collection — no SSH required.

## Structure

```
playbooks/opnsense/
├── site.yml               # runs all playbooks in order
├── vlans.yml              # VLAN sub-interfaces (vtnet1.2–vtnet1.7)
├── interfaces.yml         # prints manual checklist (no API available)
├── dhcp.yml               # DHCP server per VLAN
├── reservations.yml       # static DHCP reservations for all nodes
├── nat.yml                # outbound NAT masquerade  ⚠️ requires manual step
├── firewall.yml           # firewall rules (see NETWORK.md)
├── dns.yml                # Unbound DoT + per-VLAN port-53 redirect
├── proxmox.yml            # Proxmox management access + WAN block
├── bgp.yml                # FRR BGP peering with Cilium (management cluster)
└── temp_ap_setup.yml      # temporary: phys-workload → guest-wifi for AP setup
```

> **interfaces.yml requires one manual step** before it can run: after `vlans.yml`
> creates the VLAN devices, go to OPNsense GUI → Interfaces → Assignments and add
> vtnet1.2 through vtnet1.7 in order. OPNsense assigns them as opt1–opt6.

## Prerequisites

**1. OPNsense must be running** — see `terraform/_modules/opnsense/README.md`.

**2. Generate an API key** in OPNsense:
- System → Access → Users → edit `root` → API Keys → Add
- Save the key and secret — they are only shown once

**3. Create a Python venv and install dependencies:**

```bash
cd proxmox-nodes/ansible
python3 -m venv .venv
source .venv/bin/activate
pip install ansible httpx
ansible-galaxy collection install -r requirements.yml
```

Activate on each new session:
```bash
source proxmox-nodes/ansible/.venv/bin/activate
```

## Configuration

Fill in `OPNSENSE_HOST`, `OPNSENSE_API_KEY`, `OPNSENSE_API_SECRET` in `.env` at repo root (see `terraform/prd/.env.example`).

## Usage

Run all commands from `proxmox-nodes/ansible/`:

**Step 1 — Create VLAN devices:**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/vlans.yml
```

**Step 2 — Assign and configure interfaces in the GUI (manual, one-time):**

*2a. Assign VLAN devices:*

1. Go to **Interfaces → Assignments**
2. Add each device in order:

   | Device    | Description  |
   |-----------|--------------|
   | vtnet1.2  | K8sMgmt      |
   | vtnet1.3  | Storage      |
   | vtnet1.4  | K8sWorkload  |
   | vtnet1.5  | PhysWorkload |
   | vtnet1.6  | PrivateWifi  |
   | vtnet1.7  | GuestWifi    |

3. Click **Save** — OPNsense assigns them as `opt1` through `opt6`

*2b. Clear the IP from the LAN trunk:*
1. Go to **Interfaces → [LAN]**
2. Set **IPv4 Configuration Type** → `None` → Save → Apply changes

*2c. Set gateway IPs on each VLAN interface:*

| Interface      | IPv4 Address |
|----------------|--------------|
| [K8sMgmt]      | 10.0.2.1/24  |
| [Storage]      | 10.0.3.1/24  |
| [K8sWorkload]  | 10.0.4.1/24  |
| [PhysWorkload] | 10.0.5.1/24  |
| [PrivateWifi]  | 10.0.6.1/24  |
| [GuestWifi]    | 10.0.7.1/24  |

Print this checklist in the terminal:
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/interfaces.yml
```

**Step 3 — DHCP:**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/dhcp.yml
```

**Step 4 — DHCP reservations:**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/reservations.yml
```

| Hostname | IP       | MAC               |
|----------|----------|-------------------|
| mgmt-1   | 10.0.2.2 | fc:3f:db:0f:8e:18 |
| truenas  | 10.0.3.3 | bc:24:11:19:5c:66 |
| node-1   | 10.0.4.2 | 00:e0:4c:68:10:09 |

**Step 5 — NAT (one GUI step first):**

1. Go to **Firewall → NAT → Outbound** → set mode to `Hybrid` → Save

```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/nat.yml
```

**Step 6 — Firewall rules:**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/firewall.yml
```

**Step 7 — DNS:**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/dns.yml
```

> Requires step 6 first — `dns.yml` references the `HOMELAB_ALL` alias from `firewall.yml`.

Configures Cloudflare DoT upstreams (`1.1.1.1`/`1.0.0.1` over TLS 853), per-VLAN transparent DNS redirect (port 53 → Unbound), and WAN egress block on port 53.

**Step 8 — Proxmox access:**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/proxmox.yml
```

**Step 9 — BGP (Cilium peering):**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/bgp.yml
```

| Side     | ASN   | IP       |
|----------|-------|----------|
| OPNsense | 65551 | 10.0.2.1 |
| mgmt-1   | 65001 | 10.0.2.2 |

**Or run everything at once:**
```bash
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/site.yml
```

## One-off tasks

**Temporary phys-workload → guest-wifi access (AP setup):**
```bash
# Open
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/temp_ap_setup.yml

# Close when done
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/temp_ap_setup.yml -e "state=absent"
```

## Network Design

See [`NETWORK.md`](../../../NETWORK.md) for the full VLAN layout and firewall rules.
