#!/bin/bash

# Remote Docker Installer for Ubuntu VM
# Run this from the Proxmox host after the VM is up.

VM_IP="10.0.10.40"
VM_USER="ubuntu"

# --- PRE-FLIGHT ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
    echo "Installing sshpass for automation..."
    apt update && apt install -y sshpass
fi

read -s -p "Enter password for Ubuntu VM user '$VM_USER': " VM_PASS
echo

echo "--- Installing Docker on $VM_IP ---"

# Use a HEREDOC to pass the command to avoid complex escaping issues
sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" /bin/bash << 'EOF'
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable docker --now
sudo usermod -aG docker $(whoami)
EOF

echo "Docker installation complete on $VM_IP!"
echo "You can now log in with: ssh $VM_USER@$VM_IP"
