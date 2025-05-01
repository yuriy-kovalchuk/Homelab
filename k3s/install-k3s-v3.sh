#!/bin/bash

#-----------------------------

# Variables
K3S_VERSION="v1.31.6+k3s1" # Adjust version as needed
MASTER_USER="master"
MAIN_MASTER_NODE="10.0.8.20"
MASTER_NODES=() # List of master node IP addresses
WORKER_NODES=("10.0.8.24" "10.0.8.25") # List of worker node IP addresses
K3S_CLUSTER_TOKEN=${K3S_VAR_CLUSTER_TOKEN} # Replace with your desired K3s cluster token

# kubeconfig
REMOTE_KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml" # Path to the Kubeconfig on the remote node
LOCAL_KUBECONFIG_PATH="${HOME}/.kube/config" # Path to the local Kubeconfig

#-----------------------------




gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "Hello, there! Welcome to the $(gum style --foreground 212 'K3S') installation script."

sleep 1; clear

echo "Select $(gum style --foreground "#04B575" "K3S") installation mode"
sleep 1

INSTALL_MODE=$(gum choose "SINGLE_MASTER" "SINGLE_MASTER_WITH_WORKERS" "HA_CLUSTER")

echo "=========================================="
echo "          K3s Cluster Recap               "
echo "=========================================="

echo "🔹 Installation Mode:         $INSTALL_MODE"
echo ""
echo "🔹 K3s Version:               $K3S_VERSION"
echo ""
echo "🔹 Main Master Node:          $MAIN_MASTER_NODE"
echo "🔹 Master User:               $MASTER_USER"
echo "🔹 Master Nodes:              ${MASTER_NODES[*]}"
echo "🔹 Worker Nodes:              ${WORKER_NODES[*]}"
echo ""
echo "🔹 K3s Cluster Token:         [HIDDEN]"
echo ""
echo "🔹 Remote Kubeconfig Path:    $REMOTE_KUBECONFIG_PATH"
echo "🔹 Local Kubeconfig Path:     $LOCAL_KUBECONFIG_PATH"
echo ""
echo "=========================================="
echo "🚀 Ready to deploy your K3s cluster!      "
echo "=========================================="







if gum confirm "Proceed with these settings?"; then
    gum log --structured --level info "Proceeding"
else
    gum log --structured --level debug "Please review the variables and restart"
    exit 1
fi







# Disable swap (required for K3s and Cilium) - executed on each master node
disable_swap() {
    DISABLE_SWAP_NODES=("${MASTER_NODES[@]}" "${WORKER_NODES[@]}")
    DISABLE_SWAP_NODES+=("$MAIN_MASTER_NODE")

    for NODE in "${DISABLE_SWAP_NODES[@]}"; do
        echo "Disabling swap on master node: $NODE"
        gum log --structured --level info "Disabling SWAP on extra master node" node $NODE
        ssh $MASTER_USER@$NODE "sudo swapoff -a"
        ssh $MASTER_USER@$NODE "sudo sed -i '/ swap / s/^/#/' /etc/fstab"
    done
}

# Install K3s on the first master node
install_k3s_single_master() {

    if [ -z "$MAIN_MASTER_NODE" ]; then
        gum log --structured --level error "No nodes provided, skipping the installation of the master node"
        return 1
    fi
    gum log --structured --level info "Installing k3s in the main master node" node $MAIN_MASTER_NODE

    ssh $MASTER_USER@$MAIN_MASTER_NODE "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=$K3S_CLUSTER_TOKEN sh -s - \
--flannel-backend=none \
--disable-kube-proxy \
--disable servicelb \
--disable-network-policy \
--disable traefik \
    --node-ip=$MAIN_MASTER_NODE \
--cluster-init \
--write-kubeconfig-mode=644 \
--kube-apiserver-arg default-not-ready-toleration-seconds=30 \
--kube-apiserver-arg default-unreachable-toleration-seconds=30 \
--kube-controller-arg node-monitor-period=20s \
--kube-controller-arg node-monitor-grace-period=20s \
--kube-controller-manager-arg bind-address=0.0.0.0 \
--kube-scheduler-arg bind-address=0.0.0.0 \
--etcd-expose-metrics true \
--kubelet-arg containerd=/run/k3s/containerd/containerd.sock \
--kubelet-arg node-status-update-frequency=5s
    "

    ssh $MASTER_USER@$MAIN_MASTER_NODE "kubectl taint nodes $MASTER_NODE_NAME node-role.kubernetes.io/master=:NoSchedule --overwrite"




    export JOIN_TOKEN=$(ssh $MASTER_USER@$MAIN_MASTER_NODE "sudo cat /var/lib/rancher/k3s/server/node-token")
    gum log --structured --level debug "Join token" token $JOIN_TOKEN
}

# Install K3s on worker nodes with the same configuration as the first master node
install_k3s_worker() {
    if [ -z "$WORKER_NODES" ]; then
        gum log --structured --level error "No nodes provided, skipping the installation of the worker nodes"
        return 0
    fi

    for NODE_IP in "${WORKER_NODES[@]}"; do 
        gum log --structured --level info "Installing k3s on the worker node" node $NODE_IP
        ssh $MASTER_USER@$NODE_IP "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_URL=https://$MAIN_MASTER_NODE:6443 K3S_TOKEN=$JOIN_TOKEN sh -s - agent --kubelet-arg node-status-update-frequency=5s"
    done
}

# Install Cilium CLI only on the main master node
install_cilium_cli() {

    if [ -z "$MAIN_MASTER_NODE" ]; then
        gum log --structured --level error "No nodes provided, skipping the installation of the master node"
        return 1
    fi

    gum log --structured --level info "Installing Cilium CLI on the target node" node $MAIN_MASTER_NODE
    ssh $MASTER_USER@$MAIN_MASTER_NODE '
if command -v cilium &>/dev/null; then
echo "Cilium is already installed"
else
export CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
export CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then export CLI_ARCH=arm64; fi
curl -L --fail --remote-name https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
curl -L --fail --remote-name https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
fi
    '
}

# Install K3s on extra master nodes
install_k3s_extra_master() {
    if [ -z "$MAIN_MASTER_NODE" ]; then
        gum log --structured --level error "No nodes provided, skipping the installation of the master node"
        return 1
    fi

    for NODE_IP in "${MASTER_NODES[@]}"; do
        gum log --structured --level info "Installing k3s on the extra master node" node $NODE_IP
        ssh $MASTER_USER@$NODE_IP "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=$K3S_CLUSTER_TOKEN sh -s - server \
        --server "https://${MAIN_MASTER_NODE}:6443" \
--flannel-backend=none \
--disable-kube-proxy \
--disable servicelb \
--disable-network-policy \
--disable traefik \
--write-kubeconfig-mode=644 \
--kube-apiserver-arg default-not-ready-toleration-seconds=30 \
--kube-apiserver-arg default-unreachable-toleration-seconds=30 \
--kube-controller-arg node-monitor-period=20s \
--kube-controller-arg node-monitor-grace-period=20s \
--kube-controller-manager-arg bind-address=0.0.0.0 \
--kube-scheduler-arg bind-address=0.0.0.0 \
--etcd-expose-metrics true \
--kubelet-arg containerd=/run/k3s/containerd/containerd.sock \
--kubelet-arg node-status-update-frequency=5s
        "
    done
}




#TODO fix the merge process
get_remote_kubeconfig() {

    mkdir -p "${HOME}/.kube"

    # Fetch the Kubeconfig from the remote node
    gum log --structured --level info "Fetching Kubeconfig from remote node..."
    scp ${MASTER_USER}@${MAIN_MASTER_NODE}:${REMOTE_KUBECONFIG_PATH} /tmp/k3s_remote_kubeconfig.yaml

    # Check if the remote Kubeconfig file was fetched successfully
    if [[ ! -f /tmp/k3s_remote_kubeconfig.yaml ]]; then
        gum log --structured --level error "Failed to fetch remote Kubeconfig!"
        exit 1
    fi

    # Replace the server address in the fetched Kubeconfig
    gum log --structured --level info "Replacing server address in remote Kubeconfig..."
    sed -i "s|server: .*|server: https://$MAIN_MASTER_NODE:6443|" /tmp/k3s_remote_kubeconfig.yaml

    # Merge the remote Kubeconfig with the local one
    gum log --structured --level info "Merging remote Kubeconfig with local Kubeconfig..."
    export KUBECONFIG=$LOCAL_KUBECONFIG_PATH:/tmp/k3s_remote_kubeconfig.yaml
    kubectl config view --merge --flatten >/tmp/merged_kubeconfig.yaml

    # Move the merged Kubeconfig to the correct location
    mv /tmp/merged_kubeconfig.yaml $LOCAL_KUBECONFIG_PATH

    # Clean up
    rm /tmp/k3s_remote_kubeconfig.yaml
    gum log --structured --level info "Kubeconfig merged successfully!"

}

taint_all_master_nodes() {
    # Taint all master nodes in the cluster
    gum log --structured --level info "Tainting all master nodes"

    NODES_TO_TAINT=$(kubectl get nodes -l node-role.kubernetes.io/master -o jsonpath='{.items[*].metadata.name}')

    # Loop through and taint each master node
    for NODE in $NODES_TO_TAINT; do
        kubectl taint nodes $NODE node-role.kubernetes.io/master=:NoSchedule --overwrite
    done
}




disable_swap

install_k3s_single_master

if [ "$INSTALL_MODE" = "SINGLE_MASTER" ]; then
    echo "Setting up a single master node."
elif [ "$INSTALL_MODE" = "SINGLE_MASTER_WITH_WORKERS" ]; then
    echo "Setting up a single master with worker nodes."
    install_k3s_worker
elif [ "$INSTALL_MODE" = "HA_CLUSTER" ]; then
    echo "Setting up a high-availability cluster."
    install_k3s_extra_master
else
    echo "Invalid selection. Exiting."
    exit 1
fi

get_remote_kubeconfig

taint_all_master_nodes
