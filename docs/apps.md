# Kubernetes Applications

This document lists all applications deployed to the main Kubernetes cluster via Argo CD.

## Application Deployment Pattern

All applications follow a consistent structure:

```
kubernetes/apps/<app-name>/
├── <app-name>-app.yaml         # Argo CD Application definition
└── manifest/
    ├── Chart.yaml              # Helm chart metadata
    ├── values.yaml             # Custom values (overrides)
    ├── values_original.yaml    # Original upstream values (reference)
    └── templates/              # Custom K8s templates
```

Applications are managed via Argo CD with:
- Automatic sync with self-heal enabled
- Server-side apply for CRDs
- Automatic namespace creation
- Cilium network policies for traffic control

---

## Applications by Category

### Infrastructure & Core (8)

| Application | Version | Description |
|-------------|---------|-------------|
| **argo-cd** | - | GitOps continuous delivery controller |
| **cert-manager** | v1.17.1 | X.509 certificate management & ClusterIssuers |
| **sealed-secrets** | 2.17.3 | Encrypted secrets for GitOps workflows |
| **cilium** | - | CNI plugin with eBPF-based networking |
| **cilium-network-policies** | - | Network policy definitions for Cilium |
| **envoy-gateway** | v1.6.0 | Kubernetes-native API gateway (Envoy-based) |
| **external-secrets** | - | Sync secrets from external secret stores |
| **metrics-server** | - | Resource metrics for HPA and kubectl top |

### Storage (4)

| Application | Version | Description |
|-------------|---------|-------------|
| **minio** | 5.4.0 | S3-compatible object storage |
| **longhorn** | 1.10.1 | Cloud-native distributed block storage |
| **democratic-csi-nfs** | 0.15.1 | NFS storage provisioner (TrueNAS) |
| **democratic-csi-iscsi** | 0.15.1 | iSCSI storage provisioner (TrueNAS) |

### Monitoring & Observability (6)

| Application | Version | Description |
|-------------|---------|-------------|
| **grafana** | 10.2.0 | Metrics visualization and dashboards |
| **k8s-monitoring** | 3.6.1 | Grafana Kubernetes monitoring stack |
| **loki** | - | Log aggregation system |
| **mimir** | - | Scalable long-term metrics storage |
| **trivy** | - | Container vulnerability scanner |
| **trivy-converter** | - | Trivy result format converter |
| **kyverno-reporter** | - | Policy audit and violation reporting |

### Policy & Security (4)

| Application | Version | Description |
|-------------|---------|-------------|
| **kyverno** | - | Kubernetes-native policy engine |
| **kyverno-policies** | - | Policy definitions (pod security, etc.) |
| **cloudnative-pg** | - | PostgreSQL operator for cloud-native deployments |
| **ulimit-tuner** | - | System limit configuration for containers |

### Applications & Services (9)

| Application | Version | Description |
|-------------|---------|-------------|
| **authentik** | 2025.10.2 | Identity provider & access management (OIDC/SAML) |
| **harbor** | 1.18.0 | Container registry with vulnerability scanning |
| **netbox** | 7.2.15 | Network/datacenter infrastructure management (IPAM/DCIM) |
| **homepage** | - | Customizable dashboard/start page |
| **headlamp** | - | Kubernetes web UI dashboard |
| **uptime-kuma** | - | Self-hosted uptime monitoring |
| **whoami** | - | HTTP echo service for testing |
| **httpbin** | - | HTTP request/response testing service |
| **dns-sync** | - | DNS record synchronization |

### Utilities (1)

| Application | Version | Description |
|-------------|---------|-------------|
| **clean-pods** | - | Automated cleanup of failed/completed pods |

---

## Total: 33 Applications

| Category | Count |
|----------|-------|
| Infrastructure & Core | 8 |
| Storage | 4 |
| Monitoring & Observability | 7 |
| Policy & Security | 4 |
| Applications & Services | 9 |
| Utilities | 1 |
| **Total** | **33** |

---

## Key Integrations

### Authentication Flow
```
User -> Envoy Gateway -> Authentik (OIDC) -> Application
```

### Monitoring Stack
```
Applications -> Metrics (Mimir) -> Grafana
            -> Logs (Loki) ------^
```

### Secret Management
```
Sealed Secret (encrypted) -> Kubernetes Secret (decrypted at runtime)
External Secret Store -> External Secrets Operator -> Kubernetes Secret
```

### Storage Flow
```
Pod -> PVC -> StorageClass -> Longhorn (replicated)
                           -> Democratic-CSI -> TrueNAS (iSCSI/NFS)
```

---

## Creating New Applications

Use the helper script to scaffold new applications:

```bash
devbox run k_argo_app
```

This runs `devbox_scripts/new_app.sh` which creates the required directory structure and boilerplate files.

---

## Related Documentation

- [Architecture Overview](architecture.md)
- [Infrastructure](infrastructure.md)
- [kubernetes/apps/README.md](../kubernetes/apps/README.md) - Detailed app configurations
