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
| TBD | Management | TBD | Infrastructure management |
| TBD | Production | TBD | Kubernetes cluster |
| TBD | Storage | TBD | iSCSI/NFS traffic |
| TBD | IoT | TBD | IoT devices (isolated) |

## IP Addressing

### Static Assignments

| Device/Service | IP Address | Notes |
|----------------|------------|-------|
| OPNsense | TBD | Firewall gateway |
| Proxmox (Firewall Node) | TBD | |
| Proxmox (Maya) | 10.0.2.2 | From Terraform config |
| TrueNAS | TBD | Storage backend |
| K8s Node 1 | TBD | |
| K8s Node 2 | TBD | |
| K8s Node 3 | TBD | |
| MinIO | 10.0.10.10 | S3 storage (from .env reference) |

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
