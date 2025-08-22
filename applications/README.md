# Applications (Custom Code)

This directory contains the source code for custom applications that run in the Kubernetes cluster. Each subfolder is a separate application with its own build and runtime configuration (typically a container image built from a Dockerfile).

These applications are deployed and managed via Argo CD using the manifests under kubernetes/apps/<app-name>. In other words:
- applications/ holds the code and container build context.
- kubernetes/apps/ holds the Kubernetes manifests/Helm charts and Argo CD Application definitions that reference the built container images.

## Repository layout

- applications/
  - <app-name>/
    - dockerfile (or Dockerfile) — multi-stage build is recommended
    - src/ — application source code (language-specific)
    - other files as needed (README, configs, etc.)

## Applications overview

Currently included:
- ingress-hostname-exporter — Watches Kubernetes Ingress resources cluster-wide and updates Pi-hole local DNS records so each Ingress hostname resolves to the cluster Ingress load balancer IP.

See details per app below.

## App details

### ingress-hostname-exporter
- Purpose: Maintain Pi-hole DNS host entries for all Kubernetes Ingress hostnames. On Ingress add/update/delete events, it computes the Ingress LoadBalancer IP/hostname and pairs it with each rule.host, then calls the Pi-hole REST API to upsert host records.
- How it works:
  - Connects to the cluster using in-cluster config (when running in Kubernetes) or $KUBECONFIG (when running locally).
  - Watches networking.k8s.io/v1 Ingress resources in all namespaces via a watch loop and reconnects automatically if the watch ends.
  - For each event, builds a list of hostnames and the LoadBalancer IP (or hostname) from status.loadBalancer.ingress[0].
  - Authenticates to each configured Pi-hole endpoint and performs a PUT to /api/config/dns/hosts/<payload>?sid=<sid> for each hostname, where payload is "<IP> <hostname>" (URL-escaped). A per-endpoint session ID (SID) is cached until expiration.
- Configuration (env vars):
  - PIHOLE_PASSWORD — required. Password for Pi-hole API authentication. In cluster, supply via a Secret (see the deployment).
  - PIHOLE_ENDPOINTS — required. Comma-separated list of Pi-hole base URLs, e.g. "http://pihole-v6-0-svc,http://pihole-v6-1-svc".
  - KUBECONFIG — optional. Used only when running outside the cluster.
- Build:
  - Dockerfile: applications/ingress-hostname-exporter/dockerfile (multi-stage Go build producing a static binary on alpine).
  - Example image reference in manifests: yuriykovalchuk92/ingress-exporter:latest.
- Kubernetes manifests:
  - App path: kubernetes/apps/ingress-hostname-exporter
  - Deployment: kubernetes/apps/ingress-hostname-exporter/manifest/templates/deployments.yaml
  - RBAC/SA: kubernetes/apps/ingress-hostname-exporter/manifest/templates/{service-account,cluster-role,cluster-role-binding}.yaml
  - Notes: The Deployment pulls PIHOLE_PASSWORD from a Secret (pihole-v6-password) and sets PIHOLE_ENDPOINTS. Adjust these to your environment.
- Operational notes:
  - If the Ingress does not yet have a LoadBalancer address, the app uses a placeholder ("No LoadBalancer IP assigned"); such entries won’t be useful in Pi-hole. You may want to filter or delay updates until an address is assigned in your environment.
  - The watcher is long-running; logs indicate reconnects. Session IDs to Pi-hole are cached per-endpoint with their server-provided validity.

## Building and publishing images

Use your preferred registry (e.g., Docker Hub, GHCR, private registry). The general flow:

1. Choose a tag
   - export IMAGE="<registry-namespace>/<repo>:<tag>"  # e.g., docker.io/you/myapp:v0.1.0
2. Build
   - docker build -t "$IMAGE" -f applications/<app-name>/dockerfile applications/<app-name>
3. Push
   - docker push "$IMAGE"
4. Update manifests
   - Edit kubernetes/apps/<app-name>/manifest/templates/* (or values.yaml) to use the new tag
   - Commit and push; Argo CD will sync, or kubectl apply if you manage it manually

Notes:
- Multi-stage builds help produce small images (as in the ingress-hostname-exporter example using golang:alpine → alpine:latest).
- For reproducibility, prefer pinned base image tags (e.g., alpine:3.20) and set a meaningful appVersion in the chart.

## Local development

- You can develop and test locally, then build/push images as above.
- For quick cluster tests without going through Argo CD, you may use kubernetes/test for ad‑hoc manifests (not GitOps-managed). Prefer Argo CD for long‑lived changes.

## Creating a new custom application

1. Create a new folder under applications/<your-app> with at least:
   - dockerfile (container build recipe)
   - src/ (your code)
2. Build and push the image (see build steps above).
3. Scaffold or copy an app under kubernetes/apps/<your-app> (you can use devbox_scripts/new_app.sh for Kubernetes manifests scaffolding):
   - devbox run argo_new_app <your-app>
   - Adjust the generated manifest/values to reference your image/tag.
4. Apply or let Argo CD pick up the change from Git.

## Conventions and recommendations

- Folder name matches the app/deploy name when possible.
- Use lowercase, hyphen-separated names (e.g., my-new-service).
- Keep Dockerfiles minimal; copy only what is needed and avoid leaking build caches with wildcards.
- Pin base images where practical; use multi-stage to minimize final image size.
- Include a short README in each app folder if there are special build/run notes.
- Security: avoid embedding secrets in code or Dockerfiles; use Kubernetes Secrets/SealedSecrets.
