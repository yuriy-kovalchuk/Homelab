# Harbor Registry Proxy Configuration
# This configures Harbor as an upstream proxy cache for common container registries.
# Secondary Kubernetes clusters can use Harbor as their only allowed registry,
# and all image pulls will be proxied through Harbor.

# Registry Endpoints - Define upstream registries to proxy

# Docker Hub (docker.io)
resource "harbor_registry" "dockerhub" {
  provider_name = "docker-hub"
  name          = "dockerhub"
  endpoint_url  = "https://hub.docker.com"
  description   = "Docker Hub - Official Docker registry"

  depends_on = [helm_release.harbor]
}

# GitHub Container Registry (ghcr.io)
resource "harbor_registry" "ghcr" {
  provider_name = "github"
  name          = "ghcr"
  endpoint_url  = "https://ghcr.io"
  description   = "GitHub Container Registry"

  depends_on = [helm_release.harbor]
}

# Google Container Registry (gcr.io)
resource "harbor_registry" "gcr" {
  provider_name = "docker-registry"
  name          = "gcr"
  endpoint_url  = "https://gcr.io"
  description   = "Google Container Registry"

  depends_on = [helm_release.harbor]
}

# Kubernetes Registry (registry.k8s.io)
resource "harbor_registry" "k8s" {
  provider_name = "docker-registry"
  name          = "k8s"
  endpoint_url  = "https://registry.k8s.io"
  description   = "Kubernetes Official Registry"

  depends_on = [helm_release.harbor]
}

# Quay.io
resource "harbor_registry" "quay" {
  provider_name = "docker-registry"
  name          = "quay"
  endpoint_url  = "https://quay.io"
  description   = "Red Hat Quay Registry"

  depends_on = [helm_release.harbor]
}

# Amazon ECR Public
resource "harbor_registry" "ecr_public" {
  provider_name = "docker-registry"
  name          = "ecr-public"
  endpoint_url  = "https://public.ecr.aws"
  description   = "Amazon ECR Public Gallery"

  depends_on = [helm_release.harbor]
}

# Microsoft Container Registry (mcr.microsoft.com)
resource "harbor_registry" "mcr" {
  provider_name = "docker-registry"
  name          = "mcr"
  endpoint_url  = "https://mcr.microsoft.com"
  description   = "Microsoft Container Registry"

  depends_on = [helm_release.harbor]
}

# Proxy Cache Projects - These projects act as pull-through caches

# Docker Hub proxy project
resource "harbor_project" "dockerhub_proxy" {
  name        = "dockerhub"
  registry_id = harbor_registry.dockerhub.registry_id
  public      = true

  depends_on = [harbor_registry.dockerhub]
}

# GitHub Container Registry proxy project
resource "harbor_project" "ghcr_proxy" {
  name        = "ghcr"
  registry_id = harbor_registry.ghcr.registry_id
  public      = true

  depends_on = [harbor_registry.ghcr]
}

# Google Container Registry proxy project
resource "harbor_project" "gcr_proxy" {
  name        = "gcr"
  registry_id = harbor_registry.gcr.registry_id
  public      = true

  depends_on = [harbor_registry.gcr]
}

# Kubernetes Registry proxy project
resource "harbor_project" "k8s_proxy" {
  name        = "k8s"
  registry_id = harbor_registry.k8s.registry_id
  public      = true

  depends_on = [harbor_registry.k8s]
}

# Quay.io proxy project
resource "harbor_project" "quay_proxy" {
  name        = "quay"
  registry_id = harbor_registry.quay.registry_id
  public      = true

  depends_on = [harbor_registry.quay]
}

# Amazon ECR Public proxy project
resource "harbor_project" "ecr_public_proxy" {
  name        = "ecr-public"
  registry_id = harbor_registry.ecr_public.registry_id
  public      = true

  depends_on = [harbor_registry.ecr_public]
}

# Microsoft Container Registry proxy project
resource "harbor_project" "mcr_proxy" {
  name        = "mcr"
  registry_id = harbor_registry.mcr.registry_id
  public      = true

  depends_on = [harbor_registry.mcr]
}
