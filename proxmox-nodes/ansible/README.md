# Ansible

Configures all homelab nodes after they are provisioned by Terraform.

## Structure

```
ansible/
├── ansible.cfg
├── requirements.yml              # all collections
├── inventories/
│   └── prd/
│       ├── gateway/              # OPNsense host + group_vars
│       └── storage/              # docker-vm host
├── roles/
│   ├── system_update/            # apt upgrade
│   ├── docker_install/           # docker.io + docker-compose-v2
│   └── compose_deploy/           # copy and start compose services
├── playbooks/
│   ├── docker_vm.yml             # full storage VM setup (calls roles above)
│   └── opnsense/                 # OPNsense configuration playbooks
│       ├── site.yml              # runs all in order
│       └── ...
└── files/
    └── compose/                  # docker-compose files deployed to docker-vm
        ├── nginx-proxy-manager/
        ├── portainer/
        └── rustfs/
```

## Setup (one-time)

```bash
cd proxmox-nodes/ansible
```

For the OPNsense playbooks (require `httpx`):
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install ansible httpx
ansible-galaxy collection install -r requirements.yml
```

## Run

All commands from `proxmox-nodes/ansible/`:

```bash
# Storage — docker VM (update, install docker, deploy compose services)
ansible-playbook -i inventories/prd/storage playbooks/docker_vm.yml

# Gateway — OPNsense full run
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/site.yml

# Gateway — individual playbook
ansible-playbook -i inventories/prd/gateway playbooks/opnsense/firewall.yml
```

## Adding a compose service

Drop a `docker-compose.yaml` in `files/compose/<service>/` and re-run:
```bash
ansible-playbook -i inventories/prd/storage playbooks/docker_vm.yml
```

The service is copied to `/opt/<service>/` on the VM and started automatically.

## Adding a dev environment

Add `inventories/dev/storage/hosts.yml` with the dev VM IP. Run with:
```bash
ansible-playbook -i inventories/dev/storage playbooks/docker_vm.yml
```

No playbook or role changes required.

## OPNsense setup guide

See `playbooks/opnsense/README.md` for the full step-by-step OPNsense configuration guide including manual GUI steps.
