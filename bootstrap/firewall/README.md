# Firewall Node Bootstrap

This directory contains the "Phase 0" bootstrap automation for the Proxmox firewall node. This is intended to solve the chicken-and-egg problem where the network must be established before full IaC (Ansible/Terraform) can be used.

## Purpose

The bootstrap script performs the following foundation tasks directly on the Proxmox host:
1.  **Network Bridges**: Configures `vmbr0` through `vmbr10` with correct IPs and descriptions.
2.  **Ubuntu Docker VM**: Downloads the cloud image, provisions VM 200, and configures it with a static IP and Docker-ready settings.
3.  **OPNsense Shell**: Creates the VM shell (VM 100) with the correct network interfaces, ready for manual OS installation.

## Usage

1.  **Copy the scripts** to your Proxmox host:
    ```bash
    scp bootstrap/firewall/scripts/*.sh root@<PROXMOX_IP>:/root/
    ```

2.  **Run the bootstrap script** as root:
    ```bash
    ssh root@<PROXMOX_IP> 'bash /root/bootstrap_node.sh'
    ```

3.  **Install Docker on Ubuntu VM**:
    - From the Proxmox host, run:
    ```bash
    bash /root/install_docker_remote.sh
    ```

## Post-Bootstrap: Local Access & Docker

Once the bootstrap is complete, you need to grant your local machine (e.g., your Mac) access to the Ubuntu VM for management.

### 1. Authorize your Local SSH Key
Since the VM only has the Proxmox host's key by default, use the Proxmox host as a bridge to install your local key:
```bash
cat ~/.ssh/id_rsa.pub | ssh root@<PROXMOX_IP> "ssh -o StrictHostKeyChecking=no ubuntu@10.0.10.40 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'"
```

### 2. Set up Docker Context
Manage containers on the VM directly from your local terminal using Docker Contexts:
```bash
# Create the context
docker context create firewall-vm --docker "host=ssh://ubuntu@10.0.10.40"

# Use the context
docker context use firewall-vm

# Verify connection
docker ps
```

## Next Steps

Once the network is up and OPNsense is routing traffic:
1.  **Complete OPNsense Installation**:
    - Log in to the Proxmox Web UI.
    - Attach the OPNsense ISO to VM 100.
    - Start the VM and follow the installation prompts.
    - **Interface Mapping**:
        - `vtnet0` -> WAN (vmbr0)
        - `vtnet1` -> LAN (vmbr1)
        - `vtnet2` -> Kubernetes (vmbr2)
    - **Initial Config**: Set the LAN IP to `10.0.1.254` (or your preferred gateway for that subnet).
    - **API Access**: Enable the OPNsense API to allow `dns-sync` and other tools to communicate with the firewall.
2.  **Manage Services**: Deploy core services using Docker Compose through the `firewall-vm` context:
    - **RustFS**: S3-compatible storage for Terraform state ([bootstrap/firewall/compose/rustfs/](compose/rustfs/))
    - **Portainer**: Docker management UI ([bootstrap/firewall/compose/portainer/](compose/portainer/))
3.  **IaC**: Use Terraform to manage other infrastructure components.
