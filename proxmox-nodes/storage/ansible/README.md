# Storage Ansible

Ansible playbooks for configuring VMs on the storage network.

## Prerequisites

- Docker VM provisioned via `../terraform/docker-vm` and reachable at `10.0.3.4`
- Devbox shell active (provides `ansible-playbook`)

## Structure

```
ansible/
├── inventory.yml
├── requirements.yml
├── compose/                  — one subdirectory per service
│   └── <service>/
│       └── docker-compose.yml
└── playbooks/
    ├── site.yml              — runs all playbooks in order
    ├── update.yml            — system update (apt upgrade)
    ├── docker.yml            — Docker install
    └── compose.yml           — deploy all compose services
```

## Setup

```bash
ansible-galaxy collection install -r requirements.yml
```

## Run

```bash
# All at once
ansible-playbook -i inventory.yml playbooks/site.yml

# Individual playbooks
ansible-playbook -i inventory.yml playbooks/update.yml
ansible-playbook -i inventory.yml playbooks/docker.yml
ansible-playbook -i inventory.yml playbooks/compose.yml
```

## Adding a service

Drop a `docker-compose.yml` in `compose/<service>/` and re-run `compose.yml`.
The service will be copied to `/opt/<service>/` on the remote VM and started.
