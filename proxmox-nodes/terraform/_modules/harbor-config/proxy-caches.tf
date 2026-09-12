# One pull-through cache per upstream registry, replacing what zot's sync
# extension used to do. Each entry becomes a harbor_registry (the upstream
# endpoint) plus a harbor_project bound to it via registry_id.
#
# The project name is what Talos will address in phase 2 — the mirror endpoint
# is https://harbor.yuriykovalchuk.dev/v2/<project> with overridePath: true —
# so renaming a key here means re-rolling the cluster's machine config.
#
# provider_name is a fixed enum in the Harbor API, and — importantly — only a
# subset of those types may back a proxy cache. Harbor checks the registry type
# against PERMITTED_REGISTRY_TYPES_FOR_PROXY_CACHE when the project is created
# (src/server/v2.0/handler/project.go), which on v2.15.2 is:
#
#   docker-hub, harbor, azure-acr, ali-acr, aws-ecr, google-gcr,
#   docker-registry, github-ghcr, jfrog-artifactory
#
# Anything outside that list fails with "unsupported registry type" at project
# creation, even though the registry itself is created successfully — which is
# why quay.io below uses the generic adapter.
#
# Of the permitted types, `aws-ecr`/`azure-acr`/`google-gcr` target private
# ECR/ACR/GCR with credentials, so they are the wrong choice for the public
# mirrors here. `docker-registry` is the correct generic adapter for anonymous
# pulls from any OCI-compliant registry.
locals {
  proxy_caches = {
    dockerhub = {
      mirror_host   = "docker.io"
      provider_name = "docker-hub"
      endpoint_url  = "https://hub.docker.com"
      quota_gb      = 20
    }
    ghcr = {
      mirror_host   = "ghcr.io"
      provider_name = "github"
      endpoint_url  = "https://ghcr.io"
      quota_gb      = 15
    }
    # Not provider_name = "quay": Harbor will create a registry of that type,
    # but refuses to bind a proxy cache project to it — quay is absent from
    # PERMITTED_REGISTRY_TYPES_FOR_PROXY_CACHE (see the note below). quay.io is
    # OCI-compliant and allows anonymous pulls, so the generic adapter is fine.
    quay = {
      mirror_host   = "quay.io"
      provider_name = "docker-registry"
      endpoint_url  = "https://quay.io"
      quota_gb      = 10
    }
    k8s = {
      mirror_host   = "registry.k8s.io"
      provider_name = "docker-registry"
      endpoint_url  = "https://registry.k8s.io"
      quota_gb      = 10
    }
    gcr = {
      mirror_host   = "gcr.io"
      provider_name = "docker-registry"
      endpoint_url  = "https://gcr.io"
      quota_gb      = 5
    }
    mcr = {
      mirror_host   = "mcr.microsoft.com"
      provider_name = "docker-registry"
      endpoint_url  = "https://mcr.microsoft.com"
      quota_gb      = 5
    }
    ecr-public = {
      mirror_host   = "public.ecr.aws"
      provider_name = "docker-registry"
      endpoint_url  = "https://public.ecr.aws"
      quota_gb      = 5
    }
  }
}

resource "harbor_registry" "proxy" {
  for_each = local.proxy_caches

  name          = each.key
  provider_name = each.value.provider_name
  endpoint_url  = each.value.endpoint_url
  description   = "Upstream endpoint for the ${each.key} proxy cache"
}

resource "harbor_project" "proxy" {
  for_each = local.proxy_caches

  name        = each.key
  registry_id = harbor_registry.proxy[each.key].registry_id

  # Public so Talos needs no pull secret. These hold nothing private — every
  # image in them is a copy of something already publicly pullable upstream.
  public = true

  # Quotas total 70GB across the seven caches, against a 100GiB dataset. Without
  # them a single runaway cache could fill tank/harbor and take the registry down.
  storage_quota = each.value.quota_gb

  # Scan on pull-through, so Trivy reports accumulate before any gate is enabled.
  vulnerability_scanning = true

  # Keep serving an image from cache after it disappears upstream (deleted tag,
  # yanked repo). Requires Harbor >= 2.15.1.
  proxy_cache_local_on_not_found = true

  # PHASE 4, deliberately unset: setting deployment_security to critical/high/etc
  # starts blocking pulls of images whose scan exceeds the threshold — and blocks
  # any scannable image that has no report yet, which includes the first pull of
  # anything new. Do not enable until the cluster is routed through Harbor and
  # scan results have been observed for a while.
  # deployment_security = "high"

  # Cached images are all re-pullable from upstream, so tearing a cache down and
  # rebuilding it costs nothing but bandwidth.
  force_destroy = true
}
