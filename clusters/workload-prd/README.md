# Workload Cluster — `workload-prd`

Bare-metal Talos Linux cluster running on VLAN 4 (`10.0.4.0/24`). Hosts user-facing
workloads. Consumes shared infrastructure services (Vault, Harbor, cert-manager) from the
`management-prd` cluster on VLAN 2. Managed entirely by FluxCD after bootstrap.

## Nodes

| Hostname | IP       | Role          |
|----------|----------|---------------|
| node-1   | 10.0.4.2 | control-plane |
| node-2   | 10.0.4.3 | control-plane |

## 1. Reserve static IP in Kea

Managed via Ansible — see [`proxmox-nodes/gateway/ansible/README.md`](../../proxmox-nodes/gateway/ansible/README.md) step 4 for the full reservations table and run command.
