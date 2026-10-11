# Gateway Node

Infrastructure for the `gateway` Proxmox node. This node runs OPNsense as the main firewall/router for the homelab network, and the Tailscale subnet router VM.

Management: `https://10.0.5.3:8006` (trusted VLAN), or the break-glass port `nic1` at `https://172.30.0.1:8006` (laptop at `172.30.0.2/24`, direct cable). During a rebuild the installer address `192.168.0.254` on `vmbr0` is used until `network/` is applied with `lockdown = true`.

Units: `.` (OPNsense VM), `network/` (host networking, lockdown switch), `tailscale/` (Tailscale VM), `proxmox-acme/`.

## Terraform

Provisions the OPNsense VM and `vmbr1` LAN bridge on Proxmox:

```bash
cd proxmox-nodes/terraform/prd/gateway
terragrunt plan
terragrunt apply
```

See `terraform/_modules/opnsense/README.md` for the full setup guide including ISO preparation and installation.

## Ansible

Configures OPNsense after it is running (VLANs, DHCP, firewall, DNS, BGP):

```bash
cd proxmox-nodes/ansible
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/site.yml
```

See `ansible/playbooks/opnsense/README.md` for the full step-by-step guide.

## Network Design

See [`NETWORK.md`](../../../../NETWORK.md) for the full VLAN layout and firewall rules.
