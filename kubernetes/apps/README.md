# Kubernetes Apps (Argo CD)

Generated on: 2025-08-22 12:24

This directory contains Argo CD applications that manage the deployment of various components in the cluster. Each application points Argo CD to a local path in this repository where a Helm chart (umbrella or app-specific) lives under a manifest/ or deployment/ directory.

Below is an inventory of the applications, their target namespaces, and the installed chart versions. Version information is derived from the Helm Chart.yaml in each app's manifest (or deployment) directory and, where applicable, from the dependencies listed there.

## Applications Inventory

| Application | Namespace | Chart/App (umbrella) | Upstream Chart (if any) | Version | Source Repo | Path |
|---|---|---|---|---|---|---|
| cert-manager | cert-manager | cert-manager-yk | cert-manager (Jetstack) | v1.17.1 | local Git (this repo) | kubernetes/apps/cert-manager |
| sealed-secrets | sealed-secrets | sealed-secrets-yk | sealed-secrets (bitnami-labs) | 2.17.3 | local Git (this repo) | kubernetes/apps/sealed-secrets |
| ingress-nginx | ingress-nginx | ingress-nginx-yk | ingress-nginx (kubernetes/ingress-nginx) | 4.12.1 | local Git (this repo) | kubernetes/apps/ingress-nginx |
| grafana-prometheus | monitoring | monitoring-stack-yk | kube-prometheus-stack (prometheus-community) | 70.10.0 | local Git (this repo) | kubernetes/apps/grafana-prometheus |
| rancher | cattle-system | rancher-yk | rancher (stable) | 2.11.3 | local Git (this repo) | kubernetes/apps/rancher |
| portainer | portainer | portainer-yk | portainer (portainer/k8s) | 1.0.64 | local Git (this repo) | kubernetes/apps/portainer |
| homepage | homepage | homepage-yk | (custom manifests) | 1.0.0 | local Git (this repo) | kubernetes/apps/homepage |
| uptime-kuma | uptime-kuma | uptimekuma-yk | (custom manifests) | 1.0.0 | local Git (this repo) | kubernetes/apps/uptime-kuma |
| whoami | whoami | whoami-yk | (custom manifests) | 1.0.0 | local Git (this repo) | kubernetes/apps/whoami |
| pihole-v6 | pihole-v6 | pihole-yk | (custom manifests) | 1.0.0 | local Git (this repo) | kubernetes/apps/pihole |
| hello-world | default | hello-world | (sample chart) | 1.0.0 | local Git (this repo) | kubernetes/apps/hello-world |
| ingress-exporter | pihole-v6 | ingress-watcher-yk | (custom manifests) | 1.0.0 | local Git (this repo) | kubernetes/apps/ingress-hostname-exporter |

Notes:
- “Chart/App (umbrella)” is the local chart name defined in manifest/Chart.yaml (or deployment/Chart.yaml for hello-world).
- “Upstream Chart (if any)” is present for umbrella charts that include dependencies; otherwise the app deploys custom Kubernetes manifests/templates.
- Source Repo for all Argo CD apps is this same Git repository, referenced by the application spec’s source.repoURL and path fields.

## App Details

### cert-manager
- Argo CD Application: kubernetes/apps/cert-manager/cert-manager-app.yaml
- Helm umbrella chart: kubernetes/apps/cert-manager/manifest/Chart.yaml
- Dependencies: cert-manager v1.17.1 from https://charts.jetstack.io
- Purpose: Provides certificate management and ClusterIssuer; includes sealed secret token for Cloudflare.

### sealed-secrets
- Argo CD Application: kubernetes/apps/sealed-secrets/sealed-secrets-app.yaml
- Helm umbrella chart: kubernetes/apps/sealed-secrets/manifest/Chart.yaml
- Dependencies: sealed-secrets 2.17.3 from https://bitnami-labs.github.io/sealed-secrets/
- Purpose: Enables encryption of Kubernetes Secrets as SealedSecrets for GitOps workflows.

### ingress-nginx
- Argo CD Application: kubernetes/apps/ingress-nginx/ingress-nginx-app.yaml
- Helm umbrella chart: kubernetes/apps/ingress-nginx/manifest/Chart.yaml
- Dependencies: ingress-nginx 4.12.1 from https://kubernetes.github.io/ingress-nginx
- Purpose: Kubernetes Ingress controller to expose HTTP(S) routes from outside the cluster to services within the cluster.

### grafana-prometheus (kube-prometheus-stack)
- Argo CD Application: kubernetes/apps/grafana-prometheus/grafana-prometheus-app.yaml
- Helm umbrella chart: kubernetes/apps/grafana-prometheus/manifest/Chart.yaml
- Dependencies: kube-prometheus-stack 70.10.0 from https://prometheus-community.github.io/helm-charts
- Purpose: Monitoring stack including Prometheus, Alertmanager, Grafana, and exporters.

### rancher
- Argo CD Application: kubernetes/apps/rancher/rancher-app.yaml
- Helm umbrella chart: kubernetes/apps/rancher/manifest/Chart.yaml
- Dependencies: rancher 2.11.3 from https://releases.rancher.com/server-charts/stable
- Purpose: Rancher multi-cluster Kubernetes management platform.

### portainer
- Argo CD Application: kubernetes/apps/portainer/portainer-app.yaml
- Helm umbrella chart: kubernetes/apps/portainer/manifest/Chart.yaml
- Dependencies: portainer 1.0.64 from https://portainer.github.io/k8s/
- Purpose: Portainer UI for Kubernetes management.

### homepage
- Argo CD Application: kubernetes/apps/homepage/homepage-app.yaml
- Local chart: kubernetes/apps/homepage/manifest/ (custom templates under templates/ and files/)
- Version: 1.0.0 (appVersion)
- Purpose: Homepage dashboard with services, widgets, and settings defined in files/.

### uptime-kuma
- Argo CD Application: kubernetes/apps/uptime-kuma/uptime-kuma-app.yaml
- Local chart: kubernetes/apps/uptime-kuma/manifest/
- Version: 1.0.0 (appVersion)
- Purpose: Uptime monitoring application with PVC, Service and Ingress.

### whoami
- Argo CD Application: kubernetes/apps/whoami/whoami-app.yaml
- Local chart: kubernetes/apps/whoami/manifest/
- Version: 1.0.0 (appVersion)
- Purpose: Minimal HTTP echo service for testing Ingress/Service routing.

### pihole-v6
- Argo CD Application: kubernetes/apps/pihole/pihole-v6-app.yaml
- Local chart: kubernetes/apps/pihole/manifest/
- Version: 1.0.0 (appVersion)
- Purpose: Pi-hole DNS sinkhole deployment with StatefulSet and Ingress.

### ingress-exporter (ingress-hostname-exporter)
- Argo CD Application: kubernetes/apps/ingress-hostname-exporter/ingress-exporter-app.yaml
- Local chart: kubernetes/apps/ingress-hostname-exporter/manifest/
- Version: 1.0.0 (appVersion)
- Purpose: Custom controller/exporter that watches Ingress resources and exports hostnames (paired with a small Go utility in applications/ingress-hostname-exporter).

### hello-world (sample)
- Argo CD Application: kubernetes/apps/hello-world/argo/hello-world.yaml
- Chart: kubernetes/apps/hello-world/deployment/Chart.yaml (sample Helm chart)
- Version: 1.0.0
- Purpose: Simple demo application to validate Argo CD Helm deployment flow.

## How Argo CD Uses This Repository
- Each Argo CD Application points to this repo (repoURL) and a specific subpath (path) under kubernetes/apps/<app-name>/manifest (or deployment for hello-world).
- Argo CD syncs the desired state in Git with the cluster. Most apps have automated sync enabled with self-heal and prune, and CreateNamespace=true.

## Updating Versions
- To update an upstream chart version, edit the dependencies section in the corresponding manifest/Chart.yaml and update values.yaml as needed.
- For custom apps (those without dependencies), update templates and bump appVersion in Chart.yaml to reflect significant changes.



## Support Script: Create a New App (automatic)

Use the helper script to scaffold a new application from the template:

- Script path: devbox_scripts/new_app.sh
- Usage:
  - bash devbox_scripts/new_app.sh <app-name> [--namespace <ns>] [--no-templates] [--repo-url <url>] [--dry-run]
- Flags:
  - --namespace <ns>: Target namespace (defaults to <app-name>).
  - --no-templates: Do not include files under manifest/templates (useful if you plan to wrap an upstream Helm chart as an umbrella and don't need custom manifests).
  - --repo-url <url>: Override .spec.source.repoURL in the generated Argo CD Application.
  - --dry-run: Show actions without making changes.

Examples:
- bash devbox_scripts/new_app.sh myapp
- bash devbox_scripts/new_app.sh myapp --namespace myns --no-templates
- bash devbox_scripts/new_app.sh myapp --repo-url "https://github.com/you/Homelab.git"

What it does:
- Copies kubernetes/apps/_template to kubernetes/apps/<app-name>.
- Renames TEMPLATE-app.yaml to <app-name>-app.yaml.
- Replaces placeholders __APP_NAME__ and __NAMESPACE__ across files.
- Optionally removes manifest/templates when --no-templates is provided.
- Optionally sets the ArgoCD repoURL with --repo-url.
