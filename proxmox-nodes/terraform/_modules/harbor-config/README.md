# harbor-config

Configures the contents of the Harbor instance deployed by
[`truenas-apps/app-harbor.tf`](../truenas-apps/app-harbor.tf) — proxy caches,
the private project, the CI robot account and the scan schedule — using the
[`goharbor/harbor`](https://registry.terraform.io/providers/goharbor/harbor)
provider.

Harbor projects and registry endpoints are database objects, not configuration
files. They cannot be expressed in the app's compose, which is why they live in
their own stack.

## Prerequisites

- The `harbor` app is running and `https://harbor.yuriykovalchuk.dev` responds
- `HARBOR_ADMIN_PASSWORD` is set in the repo `.env`

## Apply

```bash
cd proxmox-nodes/terraform/prd/storage/harbor-config
terragrunt plan
terragrunt apply
```

## What this creates

| Project | Type | Quota | Upstream |
|---------|------|-------|----------|
| `dockerhub` | proxy cache | 20 GB | https://hub.docker.com |
| `ghcr` | proxy cache | 15 GB | https://ghcr.io |
| `quay` | proxy cache | 10 GB | https://quay.io |
| `k8s` | proxy cache | 10 GB | https://registry.k8s.io |
| `gcr` | proxy cache | 5 GB | https://gcr.io |
| `mcr` | proxy cache | 5 GB | https://mcr.microsoft.com |
| `ecr-public` | proxy cache | 5 GB | https://public.ecr.aws |
| `homelab` | hosted | 15 GB | — images built here |

`homelab` is public, which in Harbor means **anonymous pull, authenticated
push**. The cluster therefore needs no `imagePullSecret` for locally built
images; pushing still requires the robot account below (or an admin login).

85 GB of quota against the 100 GiB `tank/harbor` dataset. Quotas exist so one
runaway cache cannot fill the dataset and take the whole registry down.

### Registry types

Only the types in `PERMITTED_REGISTRY_TYPES_FOR_PROXY_CACHE` can back a proxy
cache — on v2.15.2 that is `docker-hub`, `harbor`, `azure-acr`, `ali-acr`,
`aws-ecr`, `google-gcr`, `docker-registry`, `github-ghcr`, `jfrog-artifactory`.
Notably **`quay` is not permitted**: Harbor creates the registry fine, then
rejects the project with `unsupported registry type quay`. quay.io is served
through the generic `docker-registry` adapter instead, as are registry.k8s.io,
gcr.io, mcr.microsoft.com and public.ecr.aws.

Plus a project-level robot account for the Forgejo Actions runners, and a daily
rescan so reports do not go stale as new CVEs are published.

## Getting the robot credentials

```bash
terragrunt output forgejo_runner_username
terragrunt output -raw forgejo_runner_secret
```

These would be better stored in Vault alongside the other app secrets; that is
not wired up yet.

## Phase 2 — routing Talos through these caches

```bash
terragrunt output talos_registry_mirrors
```

prints the `machine.registries.mirrors` content, one entry per upstream, mapped
to `https://harbor.yuriykovalchuk.dev/v2/<project>` with `overridePath: true`.

`skipFallback` is deliberately left at its default of `false`, so containerd
falls back to the upstream registry if Harbor is unavailable. Roll it out to one
worker first and verify pulls before touching the control planes.

## Phase 4 — the enforcement gate (not enabled)

`deployment_security` is commented out in both `proxy-caches.tf` and
`projects.tf`. Setting it (`critical`/`high`/`medium`/`low`) blocks pulls of any
image whose scan exceeds that severity.

Two things to understand before turning it on:

1. **It blocks unscanned images too.** Harbor's pull middleware treats a
   scannable artifact with no scan report as a policy violation, so the *first*
   pull of any new image through a proxy cache fails, and succeeds on retry once
   the scan completes. In Kubernetes that surfaces as a self-resolving
   `ImagePullBackOff`.
2. **It only holds if `skipFallback: true`.** With fallback enabled, containerd
   routes around Harbor exactly when Harbor denies a pull. Enabling it makes
   Harbor a hard dependency for every image pull in the cluster — see
   `docs/DISASTER_RECOVERY.md` before committing to that.

Note also that Harbor skips the vulnerability check for image *indexes* whose
artifact type is in its skip list, which covers most multi-arch manifest lists.
Test the behaviour you actually get before relying on it.
