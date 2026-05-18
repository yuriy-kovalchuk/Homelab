# Gateway Node

Infrastructure for the `gateway` Proxmox node (`192.168.0.254`). This node runs OPNsense as the main firewall/router for the homelab network.

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
