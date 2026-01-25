# Harbor Registry Proxy Cache

Harbor is configured as a pull-through cache for common container registries. All images pulled through Harbor are cached locally, reducing bandwidth and improving pull times.

## Available Mirrors

| Original Registry | Harbor Mirror |
|-------------------|---------------|
| docker.io | `harbor.yuriy-lab.cloud/dockerhub` |
| ghcr.io | `harbor.yuriy-lab.cloud/ghcr` |
| gcr.io | `harbor.yuriy-lab.cloud/gcr` |
| registry.k8s.io | `harbor.yuriy-lab.cloud/k8s` |
| quay.io | `harbor.yuriy-lab.cloud/quay` |
| public.ecr.aws | `harbor.yuriy-lab.cloud/ecr-public` |
| mcr.microsoft.com | `harbor.yuriy-lab.cloud/mcr` |

## Usage

### Local Docker

Pull images using the Harbor prefix:

```bash
# Docker Hub
docker pull harbor.yuriy-lab.cloud/dockerhub/library/nginx:latest
docker pull harbor.yuriy-lab.cloud/dockerhub/bitnami/redis:latest

# GitHub Container Registry
docker pull harbor.yuriy-lab.cloud/ghcr/actions/runner:latest

# Kubernetes Registry
docker pull harbor.yuriy-lab.cloud/k8s/pause:3.9

# Quay.io
docker pull harbor.yuriy-lab.cloud/quay/prometheus/prometheus:latest

# ECR Public
docker pull harbor.yuriy-lab.cloud/ecr-public/aws-observability/aws-otel-collector:latest

# Microsoft Container Registry
docker pull harbor.yuriy-lab.cloud/mcr/dotnet/sdk:8.0
```

### Talos Linux

Add registry mirrors to your Talos machine config:

```yaml
machine:
  registries:
    mirrors:
      docker.io:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/dockerhub
        overridePath: true
      ghcr.io:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/ghcr
        overridePath: true
      gcr.io:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/gcr
        overridePath: true
      registry.k8s.io:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/k8s
        overridePath: true
      quay.io:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/quay
        overridePath: true
      public.ecr.aws:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/ecr-public
        overridePath: true
      mcr.microsoft.com:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/mcr
        overridePath: true
```

Apply the config:

```bash
talosctl apply-config --nodes <node-ip> --file machineconfig.yaml
```

### Restricting to Harbor Only (Air-gapped)

To force all pulls through Harbor and block direct internet access, add to Talos config:

```yaml
machine:
  registries:
    mirrors:
      "*":
        endpoints: []
      docker.io:
        endpoints:
          - https://harbor.yuriy-lab.cloud/v2/dockerhub
        overridePath: true
      # ... add other mirrors as above
```

## Verify Caching

After pulling an image, check Harbor UI at `https://harbor.yuriy-lab.cloud`:
1. Navigate to the corresponding project (e.g., `dockerhub`)
2. The cached image should appear in the repository list
