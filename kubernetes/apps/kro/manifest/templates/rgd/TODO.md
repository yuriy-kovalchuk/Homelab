# YKApplication Future Implementation Ideas

This document contains potential features and enhancements for future versions of the YKApplication ResourceGraphDefinition.

## Current Status
- **v1**: Basic deployment/statefulset with volumes
- **v2**: Added PVC forEach logic and improved volume configuration
- **v3**: Added environment variable support (map-based)

---

## Suggested Future Implementations

### 1. **Probes & Health Checks**
Add support for liveness, readiness, and startup probes:
```yaml
probes:
  liveness:
    enabled: true
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
  readiness:
    enabled: true
    httpGet:
      path: /ready
      port: 8080
```

### 2. **Init Containers**
Support for init containers using a map structure:
```yaml
initContainers:
  migration:
    image: "my-app:migrate"
    command: ["/migrate.sh"]
  setup:
    image: "busybox"
    command: ["sh", "-c", "echo setup"]
```

### 3. **Service Account Support**
Allow specifying custom service accounts:
```yaml
serviceAccount:
  create: true
  name: "my-app-sa"
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::..."
```

### 4. **Resource Annotations & Labels**
More flexible annotation/label support per resource type:
```yaml
annotations:
  deployment:
    "reloader.stakater.com/auto": "true"
  service:
    "metallb.universe.tf/address-pool": "production"
```

### 5. **HorizontalPodAutoscaler (HPA)**
Auto-scaling support:
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### 6. **PodDisruptionBudget (PDB)**
High availability support:
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
  # or maxUnavailable: 1
```

### 7. **Network Policies**
Security policies for pod communication:
```yaml
networkPolicy:
  enabled: true
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
```

### 8. **ConfigMap & Secret Generation**
Create ConfigMaps/Secrets alongside the app:
```yaml
configMaps:
  app-config:
    data:
      app.conf: |
        key=value
secrets:
  app-secrets:
    stringData:
      password: "changeme"
```

### 9. **Multiple Container Support**
Sidecar containers in the pod:
```yaml
containers:
  app:
    image: "main-app:latest"
    port: 8080
  sidecar:
    image: "logging-sidecar:latest"
    port: 9090
```

### 10. **Topology Spread Constraints**
Better pod distribution across nodes/zones:
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: "topology.kubernetes.io/zone"
    whenUnsatisfiable: DoNotSchedule
```

### 11. **Affinity & Anti-Affinity**
Pod scheduling preferences:
```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: myapp
          topologyKey: kubernetes.io/hostname
```

### 12. **Lifecycle Hooks**
PreStop and PostStart hooks:
```yaml
lifecycle:
  preStop:
    exec:
      command: ["/bin/sh", "-c", "sleep 15"]
  postStart:
    httpGet:
      path: /warmup
      port: 8080
```

### 13. **Multiple Ports**
Support for multiple container ports:
```yaml
ports:
  http: 8080
  metrics: 9090
  grpc: 50051
```

### 14. **Ingress Support** (in addition to HTTPRoute)
Traditional Ingress resources:
```yaml
ingress:
  enabled: true
  className: nginx
  host: app.example.com
  tls:
    enabled: true
    secretName: app-tls
```

### 15. **Job/CronJob Support**
Add applicationType for jobs:
```yaml
applicationType: "cronjob"
schedule: "0 2 * * *"
restartPolicy: OnFailure
```

### 16. **Priority Class**
Pod priority and preemption:
```yaml
priorityClassName: "high-priority"
```

### 17. **RuntimeClass**
Specify container runtime (gVisor, Kata, etc.):
```yaml
runtimeClassName: "kata"
```

### 18. **Value References for Env Variables**
Support for valueFrom (ConfigMap/Secret keys):
```yaml
envFromRefs:
  DATABASE_PASSWORD:
    secretKeyRef:
      name: db-secret
      key: password
  APP_CONFIG:
    configMapKeyRef:
      name: app-config
      key: config.json
```

### 19. **Volume Snapshots**
Support for volume snapshot references:
```yaml
volumes:
  restored-data:
    type: snapshot
    snapshotName: "backup-snapshot"
    mountPath: /data
```

### 20. **Custom Metrics for HPA**
Advanced HPA with custom metrics:
```yaml
autoscaling:
  customMetrics:
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"
```

---

## Known Limitations

### Environment Variables from ConfigMaps/Secrets (v3)
**Issue**: Cannot use `envFrom` with ConfigMaps and Secrets dynamically.

**Reason**: KRO's CEL `dyn()` function returns dynamic types which don't match Kubernetes' strict type requirements for `envFrom` structures. The error encountered was:
```
type mismatch: got "map(string, dyn)", expected "string"
```

**Current Workaround**: Use simple key-value env variables via the `env` map.

**Potential Solutions**:
1. Define structured objects instead of using `dyn()` and maps
2. Use KRO's native support for complex types (if available in newer versions)
3. Pre-define envFrom sources as static lists in instance YAML
4. Create ConfigMaps/Secrets as separate resources and reference them manually

---

## Priority Suggestions

### High Priority
- Probes & Health Checks (#1)
- HorizontalPodAutoscaler (#5)
- PodDisruptionBudget (#6)
- Service Account Support (#3)

### Medium Priority
- Multiple Ports (#13)
- Lifecycle Hooks (#12)
- Init Containers (#2)
- ConfigMap & Secret Generation (#8)

### Low Priority
- Network Policies (#7)
- Job/CronJob Support (#15)
- Custom Metrics for HPA (#20)

---

## Implementation Notes

- Each major feature should increment the API version (v1alpha4, v1alpha5, etc.)
- Maintain backward compatibility with previous versions when possible
- Test thoroughly with dry-run before applying
- Update examples folder with new feature demonstrations
- Consider CEL type limitations when working with complex nested structures
