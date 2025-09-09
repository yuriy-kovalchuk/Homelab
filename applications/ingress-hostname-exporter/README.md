# Ingress Hostname Exporter

A small Go daemon that watches all Kubernetes Ingress resources and syncs their hostnames to OPNsense Unbound DNS as host overrides. For every Ingress rule host it finds, the application creates (or updates) a corresponding A record in OPNsense pointing to the Ingress’ LoadBalancer IP/hostname. It also batches and applies the Unbound configuration changes on OPNsense to avoid excessive reconfigures.

## How it works
- Connects to Kubernetes using in-cluster config (or local ~/.kube/config when run outside a cluster).
- Watches networking.k8s.io/v1 Ingress resources cluster‑wide.
- For each event, extracts:
  - Ingress namespace/name
  - LoadBalancer IP/hostname from status.loadBalancer.ingress[0]
  - All hostnames from spec.rules[*].host
- For every hostname (FQDN):
  - Checks existing Unbound host overrides on OPNsense via API.
  - If the A record already points to the same IP, it skips.
  - Otherwise it POSTs a new host override to OPNsense.
- Debounces OPNsense “reconfigure” so that multiple new/updated hosts within 5 seconds trigger only one apply call.

## Repository layout
- cmd/ingress-watcher/main.go: Program entrypoint; initializes env and clients and starts the watcher.
- pkg/k8s/k8s.go: Kubernetes client initialization, ingress watch loop, and conversion to internal model.
- pkg/opnsense/opnsense.go: OPNsense API client, env handling, HTTP client, add/lookup host overrides, and reconfigure logic.
- internal/models/*.go: Internal data structures for ingress and OPNsense API payloads/responses.
- dockerfile: Multi-stage Docker build for the binary.
- go.mod, go.sum: Go module dependencies.

## Requirements
- Go toolchain (if building locally), tested with Go 1.23.
- Access to a Kubernetes cluster (either in-cluster or via ~/.kube/config).
- An OPNsense instance with:
  - Unbound DNS service enabled.
  - API access enabled and credentials (API key and secret) that can manage Unbound.
  - Network access from where the app runs to OPNsense API endpoint.

## Configuration (Environment Variables)
- OPNSENSE_URI: Base URL to OPNsense, e.g. https://opnsense.local
- OPNSENSE_KEY: OPNsense API key
- OPNSENSE_SECRET: OPNsense API secret
- OPNSENSE_SKIP_TLS_VERIFY: Optional; set to "true" or "1" to skip TLS verification for self‑signed certs

If OPNSENSE_* variables are missing, the program exits.

## Run locally
1. Export OPNsense variables:
   - export OPNSENSE_URI=https://opnsense.local
   - export OPNSENSE_KEY=your_key
   - export OPNSENSE_SECRET=your_secret
   - export OPNSENSE_SKIP_TLS_VERIFY=true   # only if using self‑signed certs
2. Ensure your kubeconfig is at ~/.kube/config with access to your cluster.
3. Run:
   - go run ./cmd/ingress-watcher

## Build (binary)
- go build -o ingress-hostname-exporter ./cmd/ingress-watcher

## Build and push Docker image
Assuming you’re at applications/ingress-hostname-exporter directory:

- Build:
  - docker build -t YOUR_REGISTRY/ingress-hostname-exporter:TAG -f dockerfile .
- Push:
  - docker push YOUR_REGISTRY/ingress-hostname-exporter:TAG

Example:
- docker build -t ghcr.io/youruser/ingress-hostname-exporter:0.1.0 -f dockerfile .
- docker push ghcr.io/youruser/ingress-hostname-exporter:0.1.0

## Kubernetes deployment notes
A sample Helm chart exists in kubernetes/apps/ingress-hostname-exporter/manifest.
Ensure the Deployment sets the following environment variables from a Secret or values:
- OPNSENSE_URI
- OPNSENSE_KEY
- OPNSENSE_SECRET
- OPNSENSE_SKIP_TLS_VERIFY (optional)

The Pod needs permission to list/watch Ingresses cluster‑wide (ClusterRole + ClusterRoleBinding are included in the manifest). The container just executes the single binary built from cmd/ingress-watcher.

## Limitations / Assumptions
- Uses only the first status.loadBalancer.ingress entry of each Ingress.
- Creates A records (RR = "A"); IPv6 AAAA records are not currently handled.
- Only adds/updates entries; it does not clean up removed hosts.
- Expects FQDNs in ingress.spec.rules.host (splits into hostname + domain).

## Troubleshooting
- Set OPNSENSE_SKIP_TLS_VERIFY=true if your OPNsense uses self‑signed TLS.
- Ensure network connectivity from the Pod/host to the OPNsense API URI.
- Check logs for lines like “Watching ingress resources…”, “Added …”, or errors.
- If running outside cluster, verify that ~/.kube/config points to the right context.
