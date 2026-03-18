# Network Topology

> **TODO:** This document is a placeholder. Network topology needs to be documented.

## Network Overview

```
                        +------------------+
                        |     Internet     |
                        +--------+---------+
                                 |
                        +--------v---------+
                        |   ISP Modem/     |
                        |   Router         |
                        +--------+---------+
                                 |
                        +--------v---------+
                        |    OPNsense      |
                        |    Firewall      |
                        +--------+---------+
                                 |
              +------------------+------------------+
              |                  |                  |
     +--------v-------+ +-------v--------+ +-------v--------+
     |   Management   | |   Production   | |     DMZ        |
     |    Network     | |    Network     | |   (if any)     |
     +----------------+ +----------------+ +----------------+
```

## VLANs / Subnets

| VLAN ID | Name | Subnet | Purpose |
|---------|------|--------|---------|
| vmbr0 | WAN | 192.168.0.0/24 | ISP Uplink |
| vmbr1 | LAN | 10.0.1.0/24 | Wireless AP / Production |
| vmbr2 | Kubernetes | 10.0.8.0/24 | Main Cluster nodes |
| vmbr10 | Virtual Workloads | 10.0.10.0/24 | Management containers (RustFS, NPM) |
| vmbr3 | Physical Workloads| 10.0.2.0/24 | Maya Node / Baremetal |

## IP Addressing

### Static Assignments

| Device/Service | IP Address | Notes |
|----------------|------------|-------|
| OPNsense Gateway| 10.0.10.254 | Primary router |
| Proxmox (Firewall Node) | 192.168.0.112 | Management IP |
| Ubuntu Docker VM | 10.0.10.40 | Hosts core services |
| RustFS | 10.0.10.40:9000 | S3 endpoint |
| Proxmox (Maya) | 10.0.2.2 | From Terraform config |
| TrueNAS | TBD | Storage backend |

### DHCP Ranges

| Network | DHCP Range | Notes |
|---------|------------|-------|
| TBD | TBD | TBD |

## DNS Configuration

| Service | Purpose |
|---------|---------|
| TBD | Internal DNS resolution |
| dns-sync | Synchronizes DNS records from Kubernetes |

## Firewall Rules Overview

| Rule | Source | Destination | Ports | Notes |
|------|--------|-------------|-------|-------|
| TBD | TBD | TBD | TBD | TBD |

## Load Balancing / Ingress

| Component | Purpose |
|-----------|---------|
| Envoy Gateway | Kubernetes ingress controller |
| Nginx Proxy Manager | External services proxy (on firewall node) |

## Kubernetes Networking

| Component | Technology |
|-----------|------------|
| CNI | Cilium |
| Service Mesh | N/A (Cilium provides L7 capabilities) |
| Network Policies | Cilium Network Policies |
| Load Balancer | TBD |

---

## Documentation TODO

- [ ] Document complete VLAN structure
- [ ] Map all IP addresses and their assignments
- [ ] Document firewall rules
- [ ] Create network diagram with all connections
- [ ] Document DNS zones and records
- [ ] Document inter-VLAN routing rules
- [ ] List all physical network connections
- [ ] Document WiFi networks and segmentation

---

## Related Documentation

- [Architecture Overview](architecture.md)
- [Infrastructure](infrastructure.md)
- [Hardware](hardware.md)
