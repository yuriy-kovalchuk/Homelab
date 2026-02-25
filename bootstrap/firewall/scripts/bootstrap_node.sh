#!/bin/bash

# Proxmox Bootstrap Script (Native CLI version)
set -e

# --- CONFIGURATION ---
NODE="firewall"
STORAGE="local-lvm"
UBUNTU_VMID=1001

# --- PRE-FLIGHT ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

while true; do
    read -s -p "Enter password for Ubuntu VM user 'ubuntu': " UBUNTU_PASS
    echo
    read -s -p "Confirm password: " UBUNTU_PASS_CONFIRM
    echo
    if [ "$UBUNTU_PASS" == "$UBUNTU_PASS_CONFIRM" ] && [ -n "$UBUNTU_PASS" ]; then
        break
    else
        echo "Passwords do not match or are empty. Please try again."
    fi
done

# --- STEP 1: NETWORK BRIDGES (using pvesh) ---
echo "--- Configuring Network Bridges ---"

function create_bridge() {
    local iface=$1
    local ports=$2
    local addr=$3
    local gw=$4
    local desc=$5

    echo "Checking bridge $iface..."
    if ! pvesh get /nodes/$NODE/network/$iface >/dev/null 2>&1; then
        echo "Creating bridge $iface ($desc)..."
        local args="--iface $iface --type bridge --autostart 1 --comments '$desc'"
        
        if [ "$ports" != "none" ]; then
            if ip link show "$ports" >/dev/null 2>&1; then
                args="$args --bridge_ports $ports"
            else
                echo "WARNING: Physical interface $ports not found. Creating bridge $iface without ports."
            fi
        fi
        
        [ -n "$addr" ] && args="$args --address $addr"
        [ -n "$gw" ] && args="$args --gateway $gw"
        
        eval "pvesh create /nodes/$NODE/network $args"
        NEEDS_RELOAD=1
    else
        echo "Bridge $iface already exists."
    fi
}

create_bridge "vmbr0" "enp1s0" "192.168.0.112/24" "192.168.0.1" "WAN"
create_bridge "vmbr1" "enp2s0" "10.0.1.1/24" "" "Wireless AP"
create_bridge "vmbr2" "enp3s0" "10.0.8.1/24" "" "Kubernetes"
create_bridge "vmbr10" "none" "10.0.10.1/24" "" "Virtual Workloads"
create_bridge "vmbr3" "enp4s0" "10.0.2.1/24" "" "Physical Workloads"

if [ "$NEEDS_RELOAD" == "1" ]; then
    echo "Applying network changes..."
    pvesh create /nodes/$NODE/network
    # ifupdown2 should be installed to use ifreload
    if command -v ifreload >/dev/null 2>&1; then
        ifreload -a
    else
        echo "WARNING: ifreload not found. Reboot or run 'apt install ifupdown2' to apply network changes."
    fi
fi

# --- STEP 2: UBUNTU DOCKER VM ---
echo "--- Provisioning Ubuntu Docker VM ---"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMG_DEST="/var/lib/vz/template/iso/ubuntu-noble-cloud.img"

if [ ! -f "$IMG_DEST" ]; then
    echo "Downloading Ubuntu Cloud Image..."
    wget -O "$IMG_DEST" "$IMG_URL"
fi

if ! qm status $UBUNTU_VMID >/dev/null 2>&1; then
    echo "Creating Ubuntu VM $UBUNTU_VMID..."
    qm create $UBUNTU_VMID --name ubuntu-docker --memory 8196 --cores 2 --net0 virtio,bridge=vmbr10 --scsihw virtio-scsi-pci --vga std --agent enabled=1 --ostype l26
    qm importdisk $UBUNTU_VMID "$IMG_DEST" $STORAGE
    qm set $UBUNTU_VMID --virtio0 $STORAGE:vm-$UBUNTU_VMID-disk-0
    qm set $UBUNTU_VMID --ide2 $STORAGE:cloudinit
    qm set $UBUNTU_VMID --boot order=virtio0
    qm resize $UBUNTU_VMID virtio0 30G
fi

# Always apply Cloud-Init
echo "Applying Cloud-Init settings..."
SSH_KEY_FILE="$HOME/.ssh/id_rsa.pub"
SSH_KEY_ARG=""
[ -f "$SSH_KEY_FILE" ] && SSH_KEY_ARG="--sshkeys $SSH_KEY_FILE"

qm set $UBUNTU_VMID --citype nocloud --ciuser ubuntu --cipassword "$UBUNTU_PASS" $SSH_KEY_ARG --ipconfig0 "ip=10.0.10.40/24,gw=10.0.10.254"

echo "Starting Ubuntu VM..."
qm start $UBUNTU_VMID || true


echo "Bootstrap complete!"
