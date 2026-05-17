# Management Cluster — `management-prd`

Bare-metal Talos Linux cluster running on VLAN 2 (`10.0.2.0/24`). Hosts shared infrastructure
services: Vault, Harbor, cert-manager, Longhorn, and DNS/Talos managers. Managed entirely by
FluxCD after bootstrap.

## Structure

```
management-prd/
├── terraform/
│   ├── cni/         # Installs Cilium as the CNI
│   └── fluxcd/      # Installs flux-operator + FluxInstance
├── flux-system/     # FluxCD bootstrap manifests (GitRepository, Kustomizations, infrastructure + apps sync)
└── talos-nodes/     # yk-talos-manager CRs — applied manually, not managed by FluxCD
```

## Nodes

| Hostname | IP        | Role          | Interface | Disk     |
|----------|-----------|---------------|-----------|----------|
| mgmt-1     | 10.0.2.2  | control-plane | eno1      | /dev/sda |

## Terraform apply order

Apply the two steps in sequence — each depends on the previous:

```bash
# From devbox shell (devbox shell at repo root)
source .env

# 1. Install Cilium CNI
cd clusters/management-prd/terraform/cni
tf_init && tf_apply

# 2. Install FluxCD
cd ../fluxcd
tf_init && tf_apply
```

See each section below for prerequisites before running each step.

---

## Prerequisites

- Devbox shell active (`devbox shell` at repo root)
- Root `.env` sourced — must contain `TF_VAR_s3_access_key`, `TF_VAR_s3_secret_key`, `TF_VAR_s3_endpoint`
- Node physical NIC connected to the managed switch on VLAN 2 (access port, native VLAN 2, block all tagged)
- OPNsense reachable and DHCP active on `10.0.2.0/24`
- Kubeconfig for the cluster available at `~/.kube/mgmt-kubeconfig`

---

## 1. Boot the node into maintenance mode

Node imaging and PXE booting is handled by the
[yk-talos-manager](https://github.com/yuriy-kovalchuk/yk-talos-management) custom controller.
It manages the Talos image lifecycle — schematic generation, iPXE boot, install image selection —
so no manual USB flashing is required.

**This step is manual.** Place the node definition CR in `talos-nodes/` and apply it:

```bash
kubectl --kubeconfig ~/.kube/mgmt-kubeconfig apply -f clusters/management-prd/talos-nodes/
```

Wait for yk-talos-manager to complete the boot before proceeding.

---

## 2. Find the node MAC address

Before booting, note the MAC address of the NIC that will be on VLAN 2. You can read it from:

- The physical label on the NIC bracket
- The BIOS/UEFI network configuration screen
- iDRAC / IPMI web interface → Network settings

Alternatively, look up the MAC from OPNsense's DHCP leases after first boot:
**Services → Kea DHCP → DHCPv4 → Leases**.

---

## 3. Reserve static IP in Kea

Add a DHCP reservation in OPNsense so the node always boots with `10.0.2.2`:

1. Open the OPNsense web UI → **Services → Kea DHCP → DHCPv4 → Reservations**
2. Click **+** and fill in:
   - Subnet: `10.0.2.0/24`
   - MAC address: `<node MAC from step 2>`
   - IP address: `10.0.2.2`
   - Description: `mgmt-1 — management control-plane`
3. Click **Save** and **Apply**

The node will always receive `10.0.2.2` from DHCP. yk-talos-manager then applies the machine
config which sets the same address as a static route, so after the first full boot the node
no longer depends on DHCP.

---

## 4. Confirm node is ready

After yk-talos-manager has provisioned the node, confirm it is reachable and the kubeconfig
is in place:

```bash
kubectl --kubeconfig ~/.kube/mgmt-kubeconfig get nodes
```

Nodes will show `NotReady` until Cilium is installed in the next step.

---

## 5. Apply CNI — Cilium (`terraform/cni/`)

```bash
cd clusters/management-prd/terraform/cni
source .env
tf_init
tf_apply
```

Nodes will transition to `Ready` once Cilium daemonset pods are running. Verify:

```bash
kubectl --kubeconfig ~/.kube/mgmt-kubeconfig get nodes
kubectl --kubeconfig ~/.kube/mgmt-kubeconfig -n kube-system get pods -l app.kubernetes.io/name=cilium
```

---

## 6. Apply FluxCD (`terraform/fluxcd/`)

```bash
cd clusters/management-prd/terraform/fluxcd
tf_init
tf_apply
```

This installs the flux-operator via Helm and creates a `FluxInstance` that deploys the
full FluxCD controller suite (source, kustomize, helm, notification, image controllers).

Verify the controllers are running:

```bash
kubectl --kubeconfig ~/.kube/mgmt-kubeconfig -n flux-system get pods
```

---

## 7. Bootstrap GitOps sync

Apply the bootstrap manifests to connect FluxCD to this repository:

```bash
kubectl --kubeconfig ~/.kube/mgmt-kubeconfig \
  apply -k clusters/management-prd/flux-system/
```

This creates:
- `GitRepository/homelab` — watches the `main` branch of this repo
- `Kustomization/flux-system` — reconciles `clusters/management-prd/flux-system/` (self-manages)
- `Kustomization/infrastructure` → `infrastructure/overlays/management-prd/`
- `Kustomization/apps` → `apps/overlays/management-prd/`

Watch the reconciliation:

```bash
kubectl --kubeconfig ~/.kube/mgmt-kubeconfig \
  -n flux-system get kustomizations -w
```

All Kustomizations should reach `Ready=True`. Infrastructure components (cert-manager,
Cilium gateway, Longhorn, Vault, Harbor, etc.) will be reconciled automatically.

---

## Network

| Host  | IP        | VLAN              |
|-------|-----------|-------------------|
| mgmt-1  | 10.0.2.2  | k8s-mgmt (VLAN 2) |

See [`NETWORK.md`](../../NETWORK.md) for the full VLAN layout and firewall rules.
Firewall rules allow VLAN 4, 5, and 6 to reach Vault and Harbor on this cluster.
