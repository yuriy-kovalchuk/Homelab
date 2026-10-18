# Devices

Every device in the homelab: hardware, addresses and MACs. Topology and VLAN
policy are in [NETWORK.md](NETWORK.md). Update this file whenever a device or
reservation changes; static leases are defined in
`proxmox-nodes/ansible/playbooks/opnsense/reservations.yml`.

## Hardware

### Network

| Device | Model | Notes |
|--------|-------|-------|
| Managed switch | UniFi USW-Flex-2.5G-8 | 8 × 2.5 GbE; managed from the UniFi controller |
| Control-plane switch | MERCUSYS MS105GS-M2 | Unmanaged, 5 × 2.5 GbE; behind switch port 4 |
| Access point | TP-Link TL-WA1201 | AC1200 dual-band; one SSID on the trusted network. MAC b0:19:21:de:28:ee |

### Proxmox hosts

| Host | Hardware | Role |
|------|----------|------|
| gateway | Topton mini-PC, Intel N150, 16 GB DDR5, 128 GB NVMe, 4 NICs | Runs the OPNsense and Tailscale VMs. `nic0` → ISP router (`vmbr0`, OPNsense WAN, no host address); `nic3` → switch port 1 (`vmbr1`, VLAN trunk); `nic1` = break-glass port (`vmbr9`); `nic2` spare. Management on `vmbr1.5` (trusted VLAN). Host networking: `proxmox-nodes/terraform/prd/gateway/network` |
| storage | Beelink ME Mini NAS, Intel N150 (Twin Lake), 16 GB LPDDR5-4800 | Runs the TrueNAS VM with its storage controller passed through. Switch port 2 |

### Virtual machines

| VM | Host | VM ID | Resources | Defined in |
|----|------|-------|-----------|------------|
| opnsense | gateway | 1001 | 2 vCPU, 8 GB RAM, 32 GB disk; vtnet0 on `vmbr0`, vtnet1 on `vmbr1` | `proxmox-nodes/terraform/prd/gateway` |
| truenas | storage | 1000 | 3 vCPU, 12 GB RAM, 32 GB boot disk, PCIe storage controller passthrough; on `vmbr0` | `proxmox-nodes/terraform/prd/storage/truenas-install` |
| tailscale | gateway | 1010 | 1 vCPU, 1 GB RAM, 8 GB disk, Ubuntu 24.04; `eth0` on `vmbr1` tag 6 (VLAN 6 only); no guest agent, no passthrough | `proxmox-nodes/terraform/prd/gateway/tailscale` (OS config: `playbooks/tailscale.yml`) |

TrueNAS apps (`proxmox-nodes/terraform/_modules/truenas-apps`): Vault,
Harbor, RustFS (S3), Traefik, Dockhand.

### Kubernetes nodes (Talos, cluster `workload-prd`)

All run Talos v1.14.4 with Kubernetes v1.37.1.

| Node | Role | Hardware | CPU | RAM | Disk | NIC |
|------|------|----------|-----|-----|------|-----|
| valefor | control plane | HP EliteDesk 800 G2 DM 65W | Intel i5-6400T, 4C/4T | 16 GB DDR4-2133 | Kingston SV300 120 GB SATA | Intel I219-LM 1 GbE (`eno1`) |
| ifrit | control plane | HP ProDesk 600 G3 DM | Intel i5-6500T, 4C/4T | 32 GB DDR4-2133 | Essencore 256 GB SATA | Realtek RTL8125 2.5 GbE (`enp1s0`); onboard I219-LM unused |
| shiva | control plane | HP EliteDesk 800 G3 DM 65W | Intel i5-6500, 4C/4T | 16 GB DDR4-2133 | MicroFrom 256 GB SATA | Intel I219-LM 1 GbE (`eno1`) |
| ixion | worker | Beelink SER5 Max | AMD Ryzen 7 6800H, 8C/16T | 32 GB | **None** — the 128 GB OSC NVMe (SM2263XT) failed; replacement pending | `eno1` |
| bahamut | worker | Minisforum AI series mini-PC (firmware vendor "Micro Computer (HK) Tech Limited") | AMD Ryzen 7 255, 8C/16T | 64 GB DDR5-5600 | Crucial P310 1 TB NVMe | Realtek RTL8125 2.5 GbE (`enp4s0`); MediaTek MT7925 WiFi unused |
| yojimbo | worker | Desktop, Pegatron mainboard | Intel i7-7700K, 4C/8T | 16 GB (2 × 8 GB Micron) | Samsung MZ7LN256 256 GB SATA (`wwid naa.5002538d41a3f834`) | Realtek RTL8111/8168 1 GbE (`enp4s0`); Intel AC 3168 WiFi unused |

GPUs (claimed through Kubernetes DRA by PCI device ID):

| Node | GPU | PCI ID | Used by |
|------|-----|--------|---------|
| bahamut | AMD Radeon AI PRO R9700 (Navi 48, gfx1201), on OCuLink | `0x7551` | llama-cpp, llama-cpp-rocm, strata, sd-server |
| bahamut | Radeon 780M iGPU (HawkPoint, gfx1103) | `0x1900` | llama-cpp-igpu |
| ixion | Radeon 680M iGPU (Rembrandt, gfx1035) | `0x1681` | Immich (server + machine learning) |
| yojimbo | NVIDIA GeForce GTX 1070 (Pascal GP104), HDMI audio `0x10f0` | `0x1b81` | llama-cpp-cuda (NVIDIA DRA driver); VMs via VFIO passthrough planned |

Talos image schematics (factory.talos.dev):

| Nodes | Schematic | Extensions |
|-------|-----------|------------|
| valefor, ifrit, shiva | `613e1592…` | iscsi-tools, util-linux-tools |
| bahamut, ixion | `65cf8364…` | amd-ucode, amdgpu, iscsi-tools, util-linux-tools |
| yojimbo | `c9d4b52a…` | intel-ucode, nonfree-kmod-nvidia-lts (580, the last branch with Pascal), nvidia-container-toolkit-lts, iscsi-tools, util-linux-tools; kernel args `intel_iommu=on iommu=pt` |

Node labels and taints:

- Control planes carry the Longhorn node tag `system`. Data that must stay
  available lives only on them, since the workers are not always powered on.
- bahamut: label `ai-node: oculink`, taint `workload=gpu:NoSchedule`, Longhorn
  tag `gpu`. Only GPU workloads (and forgejo-runner, which builds there)
  tolerate it.
- yojimbo: labels `machineSize: medium`, `gpu-vendor: nvidia`, taint
  `workload=gpu:NoSchedule` (set with kubectl: Talos cannot taint a worker),
  Longhorn node and disk tag `vms` (10 GiB reserved): only the `longhorn-vms`
  StorageClass places volumes there. Managed by Omni (config patch
  `10-bee448ac-…`), joined 2026-10-18.

## Addresses

### Home LAN — `192.168.0.0/24` (ISP side, not managed here)

| IP | Device | Notes |
|----|--------|-------|
| 192.168.0.1 | ISP router | Internet gateway |
| 192.168.0.253 | OPNsense WAN (vtnet0) | Read from OPNsense on 2026-10-11 (earlier docs said `.110`; firewall rule `wan-01` still targets `.110`) |
| — | gateway Proxmox | **No address on the home LAN** since the lockdown (2026-10-11). `192.168.0.254` is only used during a rebuild (`lockdown = false`) |

### VLAN 3 — storage — `10.0.3.0/24`

| IP | Device | MAC | Notes |
|----|--------|-----|-------|
| 10.0.3.1 | OPNsense (opt2) | — | Gateway, DNS, NTP |
| 10.0.3.2 | storage Proxmox | — | Static on the host; web UI on 8006 |
| 10.0.3.3 | truenas | bc:24:11:19:5c:66 | Kea reservation; must stay static (democratic-csi and Vault depend on it) |
| 10.0.3.100–200 | DHCP pool | | |

### VLAN 4 — k8s-workload — `10.0.4.0/24`

Address plan: `.1` gateway · `.2–.9` control planes only · `.10` Kubernetes
API VIP · `.11+` workers · `.50–.99` Cilium LoadBalancer pool · `.100–.200`
DHCP pool.

| IP | Device | MAC | Notes |
|----|--------|-----|-------|
| 10.0.4.1 | OPNsense (opt3) | — | Gateway, DNS, NTP, BGP (ASN 65551, router ID) |
| 10.0.4.5 | valefor | fc:3f:db:0f:8e:18 | Control plane |
| 10.0.4.6 | ifrit | 00:e0:4c:68:10:09 | Control plane |
| 10.0.4.7 | shiva | 10:62:e5:17:93:cf | Control plane |
| 10.0.4.10 | Kubernetes API VIP | — | IP alias on OPNsense; HAProxy → control planes :6443 |
| 10.0.4.11 | ixion | 78:55:36:03:b1:e0 | Worker; offline until its disk is replaced (moves to switch port 7) |
| 10.0.4.12 | bahamut | 38:05:25:32:8e:dc | Worker; not always powered on. Static IP in its Talos config as well |
| 10.0.4.13 | yojimbo | 10:05:01:43:06:f7 | Worker, GTX 1070 for VMs. Kea reservation and static IP in its Talos config |
| 10.0.4.50 | `internal` Gateway | — | Cilium Gateway for every HTTPS hostname |
| 10.0.4.51 | `ubuntu-test-rdp` / `ubuntu-test-ssh` | — | RDP (TCP 3389) and SSH (TCP 22) to the ubuntu-test VM on bahamut (shared LB IP); trusted VLAN and Tailscale only |
| 10.0.4.50–99 | Cilium LB pool | | Advertised over BGP (ASN 65002) |
| 10.0.4.100–200 | DHCP pool | | |

All five nodes are BGP neighbors of OPNsense (`bgp.yml`). Free control-plane
addresses: `.2–.4`, `.8`, `.9`.

### VLAN 5 — trusted — `10.0.5.0/24`

| IP | Device | Notes |
|----|--------|-------|
| 10.0.5.1 | OPNsense (opt4) | Gateway, DNS, NTP; the address Ansible uses for the OPNsense API. vtnet1 MAC bc:24:11:a3:2a:24 (seen on switch port 1) |
| 10.0.5.5 | UniFi USW-Flex-2.5G-8 | Switch management (static) |
| 10.0.5.3 | gateway Proxmox (`vmbr1.5`) | Management: web UI `https://10.0.5.3:8006`, SSH. Static on the host; default route via `10.0.5.1`. Reached from trusted at L2 (works with OPNsense down) and from remote-access |
| 10.0.5.2 | TP-Link TL-WA1201 | Static, set on the AP itself (no Kea reservation); web UI at http://10.0.5.2/ |
| 10.0.5.100–200 | DHCP pool | Admin PC (MAC d0:11:e5:81:14:af, switch port 9), WiFi clients |

### VLAN 6 — remote-access — `10.0.6.0/24`

Exists only inside the gateway Proxmox host (`vmbr1`, tag 6); not on the
switch, no DHCP.

| IP | Device | MAC | Notes |
|----|--------|-----|-------|
| 10.0.6.1 | OPNsense (opt1, GUI name "Tailscale") | — | Gateway, DNS (split-DNS resolver for the tailnet), NTP |
| 10.0.6.10 | tailscale VM | bc:24:11:e3:11:6a | Static via cloud-init. Tailnet name `homelab-router`, tag `tag:homelab-router`, tailnet IP `100.67.182.63` |

### Tailnet

| Name | Tailnet IP | Notes |
|------|-----------|-------|
| homelab-router | 100.67.182.63 | Subnet router; advertises `10.0.3.0/24`, `10.0.4.0/24`, `10.0.5.0/24`, `10.0.6.1/32` (auto-approved by the policy) |

Your own devices join with your Apple ID and need approval under Machines in
the Tailscale console. Tailscale addresses are assigned by Tailscale from
`100.64.0.0/10`.

### Break-glass — `172.30.0.0/24` (gateway host only)

A direct-cable emergency path into the gateway Proxmox host that works with
OPNsense, the switch or the VLANs down. Not routed anywhere, no gateway.

| IP | Device | Notes |
|----|--------|-------|
| 172.30.0.1 | gateway Proxmox, port `nic1` (`vmbr9`, MAC 00:d0:b4:04:8c:a2) | Web UI `https://172.30.0.1:8006` |
| 172.30.0.2 | your laptop, set manually | Cable straight into `nic1`; subnet `255.255.255.0`, no router |

