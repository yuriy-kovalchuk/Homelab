# Network Devices

All static/reserved devices on the homelab network. Update this file whenever a new device is added.

## Home Network (192.168.0.0/24) — WAN side, unmanaged

| IP              | Hostname          | Device              | Notes                        |
|-----------------|-------------------|---------------------|------------------------------|
| 192.168.0.1     | —                 | Home router         | ISP gateway                  |
| 192.168.0.110   | opnsense          | OPNsense VM         | WAN IP, firewall/router      |
| 192.168.0.254   | gateway-pve       | Proxmox (gateway)   | Homelab hypervisor — gateway |

## VLAN 2 — deprecated (10.0.2.0/24, opt1)

No active devices. Pending removal from switch and OPNsense config.

| IP              | Hostname | Device            | Notes                              |
|-----------------|----------|-------------------|------------------------------------|
| 10.0.2.1        | —        | OPNsense opt1     | VLAN gateway                       |

## VLAN 3 — storage (10.0.3.0/24, opt2)

| IP         | Hostname     | Device              | Notes                                         |
|------------|--------------|---------------------|-----------------------------------------------|
| 10.0.3.1   | —            | OPNsense opt2       | VLAN gateway                                  |
| 10.0.3.2   | storage      | Proxmox (storage)   | Storage node hypervisor                       |
| 10.0.3.3   | truenas      | TrueNAS SCALE VM    | NAS — NFS/SMB, Vault, Zot, RustFS, apps      |

## VLAN 4 — k8s-workload (10.0.4.0/24, opt3)

| IP         | Hostname        | Device        | Notes                                          |
|------------|-----------------|---------------|------------------------------------------------|
| 10.0.4.1   | —               | OPNsense opt3 | VLAN gateway                                   |
| 10.0.4.6   | controlplane-3  | Talos node    | Workload control-plane (offline, coming back)  |
| 10.0.4.3   | controlplane-1  | Talos node    | Workload control-plane                         |
| 10.0.4.4   | worker-1        | Talos node    | Workload worker — AMD 780M GPU                 |
| 10.0.4.5   | controlplane-2  | Talos node    | Workload control-plane                         |
| 10.0.4.50–.99 | —            | LB pool       | Cilium BGP LoadBalancer IP pool                |

## VLAN 5 — phys-workload (10.0.5.0/24, opt4)

| IP         | Hostname     | Device              | Notes                        |
|------------|--------------|---------------------|------------------------------|
| 10.0.5.1   | —            | OPNsense opt4       | VLAN gateway                 |

## VLAN 6 — private-wifi (10.0.6.0/24, opt5)

| IP         | Hostname     | Device              | Notes                        |
|------------|--------------|---------------------|------------------------------|
| 10.0.6.1   | —            | OPNsense opt5       | VLAN gateway                 |

## VLAN 7 — guest-wifi (10.0.7.0/24, opt6)

| IP         | Hostname     | Device              | Notes                        |
|------------|--------------|---------------------|------------------------------|
| 10.0.7.1   | —            | OPNsense opt6       | VLAN gateway                 |
