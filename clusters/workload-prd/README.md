# Workload Cluster — `workload-prd`

Bare-metal Talos Linux cluster running on VLAN 4 (`10.0.4.0/24`). Hosts user-facing
workloads. Consumes shared infrastructure services (Vault, Harbor, cert-manager) from the
`management-prd` cluster on VLAN 2. Managed entirely by FluxCD after bootstrap.

## Nodes

| Hostname | IP       | Role          |
|----------|----------|---------------|
| node-1   | 10.0.4.2 | control-plane |

## 1. Reserve static IP in Kea

Reservations are managed via Ansible. Run from the gateway ansible directory:

```bash
cd proxmox-nodes/gateway/ansible
ansible-playbook -i inventory/hosts.yml playbooks/opnsense/reservations.yml
```

Reservations configured (all nodes across all VLANs):

| Hostname | IP       | MAC               | Subnet       | Role                      |
|----------|----------|-------------------|--------------|---------------------------|
| mgmt-1   | 10.0.2.2 | fc:3f:db:0f:8e:18 | 10.0.2.0/24  | management control-plane  |
| truenas  | 10.0.3.3 | bc:24:11:19:5c:66 | 10.0.3.0/24  | TrueNAS SCALE VM          |
| node-1   | 10.0.4.2 | 00:e0:4c:68:10:09 | 10.0.4.0/24  | workload control-plane    |
