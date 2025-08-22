# k3s on Proxmox-hosted nodes

This folder contains helper scripts to install and bootstrap a k3s cluster on nodes that are already provisioned in Proxmox. The installer supports multiple cluster topologies (single master, single master with workers, and HA with multiple masters) and prepares the environment for using Cilium as the CNI later.

## Contents

- `install-k3s-v3.sh` — interactive installer (uses `gum`) that:
  - disables swap on all target nodes;
  - installs the first master (server) with flannel/kube-proxy/traefik disabled (to use Cilium later);
  - optionally joins worker nodes and/or extra master nodes;
  - fetches and merges the remote kubeconfig into your local `${HOME}/.kube/config`;
  - taints all master nodes with `NoSchedule`.
- `generate-k3s-node-rsa.sh` — helper to generate an SSH key for a target node, add a host block to `~/.ssh/config`, copy the public key to the node, and test the SSH connection.

## Prerequisites

- Proxmox VMs already provisioned for masters and (optionally) workers.
- Network connectivity from your admin machine to those VMs (SSH on port 22).
- On your admin machine:
  - `bash`, `ssh`, `scp`, `sed`, `kubectl` installed and in PATH.
  - `gum` installed (for the interactive prompts). Install via:
    - macOS (Homebrew): `brew install gum`
    - Linux: see https://github.com/charmbracelet/gum#installation
- A user on the target nodes with passwordless sudo (default in script: `master`).
- Firewall rules allow access between nodes on Kubernetes ports (e.g., 6443 API, etc.).

## Before you begin

1. Ensure you can SSH to all nodes using a key. You can use the helper script for an initial node:
   - Edit `k3s/generate-k3s-node-rsa.sh` variables: `KEY_NAME`, `REMOTE_HOST`, `USERNAME`.
   - Run: `./generate-k3s-node-rsa.sh`
2. Decide your cluster layout and gather IPs:
   - Main master (API endpoint): `MAIN_MASTER_NODE`
   - Optional extra masters: `MASTER_NODES=("10.0.8.X" "10.0.8.Y")`
   - Optional workers: `WORKER_NODES=("10.0.8.A" "10.0.8.B")`
3. Prepare a secure cluster token. The installer reads it from the environment variable `K3S_VAR_CLUSTER_TOKEN`.
   - Example (temporary shell session):
     - `export K3S_VAR_CLUSTER_TOKEN="$(openssl rand -hex 32)"`

## How the installer configures k3s

The first master is installed with flags oriented to use Cilium later:
- `--flannel-backend=none` (no Flannel)
- `--disable-kube-proxy`
- `--disable servicelb`
- `--disable-network-policy`
- `--disable traefik`
- several tuning flags for API/controller/scheduler and kubelet update frequency

Extra master nodes (HA) and workers join the cluster pointing to `https://<MAIN_MASTER_NODE>:6443`.

After installation, the script:
- fetches `/etc/rancher/k3s/k3s.yaml` from the main master and merges it into your local `${HOME}/.kube/config` with the correct server address;
- taints all master nodes with `node-role.kubernetes.io/master=:NoSchedule`.

Note: Cilium itself is not installed by this script. Install it afterwards using `kubernetes/setup/cilium/` (see that README/script).

## Usage

1. Edit variables at the top of `install-k3s-v3.sh` as needed:
   - `K3S_VERSION` (default: `v1.31.6+k3s1`)
   - `MASTER_USER` (default: `master`)
   - `MAIN_MASTER_NODE` (IP of your primary master)
   - `MASTER_NODES` (array of extra master IPs; leave empty for non-HA)
   - `WORKER_NODES` (array of worker IPs)
   - Ensure `K3S_VAR_CLUSTER_TOKEN` is exported in your shell
2. Make the script executable and run it from your admin machine:
   - `cd k3s`
   - `chmod +x install-k3s-v3.sh`
   - `./install-k3s-v3.sh`
3. Choose installation mode when prompted:
   - `SINGLE_MASTER` — only the main master
   - `SINGLE_MASTER_WITH_WORKERS` — main master + workers
   - `HA_CLUSTER` — main master + extra masters (+ you can also keep workers in the array; they will be joined when you pick this mode)

The script will:
- confirm the recap of your settings;
- disable swap across nodes;
- install k3s on the main master;
- optionally join workers or extra masters according to the selected mode;
- fetch and merge kubeconfig locally;
- taint masters.

## After installation

- Validate cluster access:
  - `kubectl get nodes`
- Install Cilium (CNI) using the dedicated script:
  - `cd kubernetes/setup/cilium && ./install-cilium.sh`
- Proceed with Argo CD setup if you use GitOps (see `kubernetes/setup/argocd`).

## Troubleshooting

- SSH failures: verify `~/.ssh/config` host blocks and key permissions, or re-run the RSA helper for each host.
- Token issues: ensure `K3S_VAR_CLUSTER_TOKEN` is exported in the shell starting the installer.
- kubeconfig merge on macOS: `sed -i` may require a backup extension (BSD sed). Run on Linux or adjust `sed` as needed.
- Gum not found: install gum and ensure it’s in your PATH.
- CNI not ready: remember flannel and kube-proxy are disabled by design; install Cilium next.

## Security notes

- Treat `K3S_VAR_CLUSTER_TOKEN` as a secret. Avoid committing it or storing it in shell history.
- Limit SSH access to admin IPs and use key-based auth.

## Related

- Kubernetes bootstrap and apps: `kubernetes/setup` and `kubernetes/apps`
- Cilium installation: `kubernetes/setup/cilium/`
- Argo CD installation: `kubernetes/setup/argocd/`