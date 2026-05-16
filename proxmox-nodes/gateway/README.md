# Gateway Node

Infrastructure and configuration for the `gateway` Proxmox node. This node runs OPNsense as the main firewall/router for the homelab network.

## Structure

```
gateway/
├── terraform/
│   └── opnsense/   # OPNsense VM + vmbr1 VLAN-aware bridge
└── ansible/        # OPNsense configuration — VLANs, interfaces, DHCP, firewall rules
```

## Terraform

Provisions infrastructure on the Proxmox node. Each module has its own local state and `.env` file.

```bash
cd terraform/opnsense
cp .env.example .env  # fill in your values
tf_init_local
tf_plan
tf_apply
```

See `terraform/opnsense/README.md` for the full setup guide including ISO preparation, installation, and initial GUI access.

## Ansible

Configures OPNsense after it is running. Requires the OPNsense API to be reachable and an API key generated.

```bash
cd ansible
cp .env.example .env  # fill in OPNsense host + API credentials
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/site.yml
```

See `ansible/README.md` for details.

## Network Design

See [`NETWORK.md`](../../NETWORK.md) for the full VLAN layout and firewall rules.
