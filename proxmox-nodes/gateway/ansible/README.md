# OPNsense Ansible Configuration

Configures OPNsense after the VM is running. Uses the OPNsense HTTP API via the `oxlorg.opnsense` collection — no SSH required.

## Structure

```
ansible/
├── inventory/
│   ├── hosts.yml                  # host definitions
│   └── group_vars/
│       └── opnsense.yml           # OPNsense API connection vars
├── playbooks/
│   └── opnsense/
│       ├── site.yml               # runs all playbooks in order
│       ├── vlans.yml              # VLAN sub-interfaces (vtnet1.2–vtnet1.7)
│       ├── interfaces.yml         # prints manual checklist (no API available)
│       ├── dhcp.yml               # DHCP server per VLAN
│       ├── nat.yml                # outbound NAT masquerade for all VLANs  ⚠️ requires manual step
│       ├── firewall.yml           # firewall rules (see NETWORK.md)
│       ├── dns.yml                # Unbound DoT (1.1.1.1 over TLS) + per-VLAN port-53 redirect
│       ├── proxmox.yml            # Proxmox management access + WAN block
│       └── temp_ap_setup.yml      # temporary: phys-workload → guest-wifi for AP setup
├── requirements.yml               # collection dependencies
├── .env.example
└── .gitignore
```

> **interfaces.yml requires one manual step** before it can run: after `vlans.yml`
> creates the VLAN devices, go to OPNsense GUI → Interfaces → Assignments and add
> vtnet1.2 through vtnet1.7 in order. OPNsense assigns them as opt1–opt6.

## Prerequisites

**1. OPNsense must be running** and reachable at the configured host (see `terraform/opnsense/README.md` for setup).

**2. Generate an API key** in OPNsense:
- System → Access → Users → edit `root` → API Keys → Add
- Save the key and secret — they are only shown once

**3. Create a Python venv and install dependencies:**

The `oxlorg.opnsense` collection requires `httpx`. Use a venv to keep this
isolated from the system Python:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install ansible httpx
ansible-galaxy collection install -r requirements.yml
```

The `.venv` directory is gitignored. You need to activate it each session:
```bash
source .venv/bin/activate
```

## Configuration

```bash
cp .env.example .env
```

Fill in:
- `OPNSENSE_HOST` — OPNsense URL (e.g. `https://192.168.0.200`)
- `OPNSENSE_API_KEY` — from step 2 above
- `OPNSENSE_API_SECRET` — from step 2 above

The devbox shell auto-sources `.env` on entry.

## Usage

OPNsense has no REST API for interface assignment (open issue since 2024), so the
full run requires one manual GUI step between `vlans.yml` and `interfaces.yml`.

**Step 1 — Create VLAN devices:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/vlans.yml
```

**Step 2 — Assign and configure interfaces in the GUI (manual, one-time):**

OPNsense does not expose interface assignment or IP configuration via REST API
(open issues since 2024). These steps must be done in the GUI.

*2a. Assign VLAN devices:*

1. Go to **Interfaces → Assignments**
2. Use the **"New interface"** dropdown at the bottom to add each device in order:

   | Device    | Description  |
   |-----------|--------------|
   | vtnet1.2  | K8sMgmt      |
   | vtnet1.3  | Storage      |
   | vtnet1.4  | K8sWorkload  |
   | vtnet1.5  | PhysWorkload |
   | vtnet1.6  | PrivateWifi  |
   | vtnet1.7  | GuestWifi    |

3. Click **Save** — OPNsense assigns them as `opt1` through `opt6` in order

*2b. Clear the IP from the LAN trunk:*

1. Go to **Interfaces → [LAN]**
2. Set **IPv4 Configuration Type** → `None`
3. Click **Save** → **Apply changes**

*2c. Set gateway IPs on each VLAN interface:*

For each interface below: **Interfaces → [Name] → check Enable → IPv4 Configuration
Type: Static → enter IP → Save → Apply changes**

| Interface      | IPv4 Address |
|----------------|--------------|
| [K8sMgmt]      | 10.0.2.1/24  |
| [Storage]      | 10.0.3.1/24  |
| [K8sWorkload]  | 10.0.4.1/24  |
| [PhysWorkload] | 10.0.5.1/24  |
| [PrivateWifi]  | 10.0.6.1/24  |
| [GuestWifi]    | 10.0.7.1/24  |

You can run `interfaces.yml` to print this checklist in the terminal:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/interfaces.yml
```

**Step 3 — Configure DHCP:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/dhcp.yml
```

**Step 4 — Enable NAT (one GUI step + Ansible):**

Before running `nat.yml`, switch the outbound NAT mode to **Hybrid** in the GUI —
otherwise OPNsense ignores manually added rules:

1. Go to **Firewall → NAT → Outbound**
2. Set **Mode** to `Hybrid outbound NAT rule generation`
3. Click **Save**

Then run:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/nat.yml
```

**Step 5 — Configure firewall rules:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/firewall.yml
```

**Step 6 — Configure DNS:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/dns.yml
```

> **Requires step 5 first.** `dns.yml` references the `HOMELAB_ALL` alias created by
> `firewall.yml`. Running it before step 5 will fail with an alias validation error.

Configures three things automatically:

- **Cloudflare DoT upstreams** — Unbound forwards all queries to `1.1.1.1` / `1.0.0.1`
  over TLS port 853, verified against `cloudflare-dns.com`.
- **Per-VLAN destination NAT rules** — transparent DNS redirect on opt1–opt6. Any port
  53 traffic destined for a non-homelab IP is silently rewritten to `127.0.0.1:53`
  (Unbound). Clients with hardcoded external DNS (e.g. `8.8.8.8`) are redirected without
  reconfiguration. Uses the OPNsense 26.x `firewall/d_nat` API.
- **WAN egress block** — blocks TCP/UDP port 53 outbound on WAN. Safety net: redirected
  traffic never reaches WAN, so this rule only fires if a d_nat rule is missing.

A client querying `8.8.8.8:53` is silently rewritten by pf to `127.0.0.1:53` (Unbound).
Unbound queries `1.1.1.1:853` over TLS, gets the answer, and the client receives it as
if `8.8.8.8` had responded.

After this step, verify pf is still enabled:
```
pfctl -s info | head -3
```
If it shows `Status: Disabled`, run:
```
pfctl -e && pfctl -f /tmp/rules.debug
```
OPNsense's reload mechanism calls `pfctl -d` internally to swap rulesets; if rule
generation fails for any reason, pf stays disabled and all NAT and firewall rules
stop applying.

**Re-enable pf after initial setup:**

During initial setup before the switch and Ansible rules were in place, pf was
disabled (`pfctl -d`) to allow GUI access from the WAN-side home network without
a pass rule. Once `firewall.yml` has been applied (which adds the WAN management
rule), pf must be re-enabled:

```
pfctl -e && pfctl -f /tmp/rules.debug
```

This is a one-time step after the first successful Ansible run.

**Step 7 — Configure Proxmox access:**
```bash
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/proxmox.yml
```

Adds a `PROXMOX` alias (`192.168.0.254`) and a `PROXMOX_PORTS` alias (`22`, `8006`), then:

- Blocks TCP 22 + 8006 inbound on WAN — prevents internet-routed access to Proxmox.
- phys-workload can already reach Proxmox via the existing internet rule (192.168.0.254 is
  outside `HOMELAB_ALL`); no additional allow rule is needed.

> **Note:** Proxmox and OPNsense WAN share the same L2 home network (192.168.0.x). Traffic
> from a home-network device directly to Proxmox bypasses OPNsense and cannot be blocked
> here. Full isolation requires moving Proxmox's management interface to a dedicated VLAN.

## One-off tasks

**Temporary phys-workload → guest-wifi access (AP setup):**

The permanent firewall rules block phys-workload from reaching the guest-wifi VLAN.
To temporarily lift that block while configuring a WiFi access point:

```bash
# Open
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/temp_ap_setup.yml

# Close when done
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/temp_ap_setup.yml -e "state=absent"
```

## Network Design

See [`NETWORK.md`](../../../NETWORK.md) for the full VLAN layout and firewall rules that these playbooks implement.
