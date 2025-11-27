# OPNsense DNS Sync

A small Go daemon that watches Kubernetes Gateway API HTTPRoute resources and syncs their hostnames to OPNsense Unbound DNS as host overrides.
For every HTTPRoute hostname it finds, the application creates (or updates) a corresponding A record in OPNsense pointing to the exposed Gateway address (typically the LoadBalancer IP or hostname). It debounces and applies Unbound configuration changes on OPNsense to avoid excessive reconfigures.

## How it works
- Connects to Kubernetes using in-cluster config (or local ~/.kube/config when run outside a cluster).
- Watches Gateway API HTTPRoutes (sigs.k8s.io/gateway-api/apis/v1beta1) cluster‑wide.
- For each reconcile event, builds an internal model with:
  - HTTPRoute namespace/name
  - All hostnames from `spec.hostnames[*]`
  - Gateway addresses resolved from each `spec.parentRefs[*]` Gateway’s `status.addresses[*].value`
- For every hostname (FQDN):
  - Looks up existing Unbound host overrides on OPNsense via API.
  - If an override already points to the same address, it skips.
  - Otherwise it POSTs a new override or updates the existing one.
- Debounces OPNsense “reconfigure” so that multiple changes within ~5 seconds result in only one apply call.

## Repository layout
- src/cmd/dns-sync/main.go: Program entrypoint; initializes env and clients and starts the controller manager.
- src/pkg/k8s/k8s.go: Controller-runtime manager and reconciler for HTTPRoute; resolves hostnames and Gateway addresses.
- src/pkg/opnsense/opnsense.go: OPNsense API client, env handling, HTTP client, add/update/lookup host overrides, and reconfigure logic.
- src/internal/models/*.go: Internal data structures for HTTPRoute info and OPNsense API payloads/responses.
- dockerfile: Multi-stage Docker build for the binary.
- docker_build_push.sh: Helper script to build and optionally push a Docker image.
- src/go.mod, src/go.sum: Go module and dependencies (module name: `dns-sync`).

## Requirements
- Go toolchain (if building locally), tested with Go 1.25.4.
- Access to a Kubernetes cluster (either in-cluster or via ~/.kube/config).
- An OPNsense instance with:
  - Unbound DNS service enabled.
  - API access enabled and credentials (API key and secret) that can manage Unbound.
  - Network access from where the app runs to OPNsense API endpoint.

## Configuration (Environment Variables)
- OPNSENSE_URI: Base URL to OPNsense, e.g. `https://opnsense.local`
- OPNSENSE_KEY: OPNsense API key
- OPNSENSE_SECRET: OPNsense API secret
- OPNSENSE_SKIP_TLS_VERIFY: Optional; set to `"true"` or `"1"` to skip TLS verification for self‑signed certs

If OPNSENSE_* variables are missing, the program exits.

## Run locally
From the repository root of this app (`applications/opnsense-dns-sync`):

1. Export OPNsense variables:
   - `export OPNSENSE_URI=https://opnsense.local`
   - `export OPNSENSE_KEY=your_key`
   - `export OPNSENSE_SECRET=your_secret`
   - `export OPNSENSE_SKIP_TLS_VERIFY=true`   # only if using self‑signed certs
2. Ensure your kubeconfig is at `~/.kube/config` with access to your cluster.
3. Run:
   - `go run ./src/cmd/dns-sync`

## Build (binary)
- `go build -o dns-sync ./src/cmd/dns-sync`

## Build and push Docker image
From `applications/opnsense-dns-sync`:

```
docker buildx build --platform linux/amd64 -t harbor.yuriy-lab.cloud/library/opnsense-dns-sync:TAG -f dockerfile .
docker push harbor.yuriy-lab.cloud/library/opnsense-dns-sync:TAG
```

Alternatively, use the helper script:

```
./docker_build_push.sh
```


## Kubernetes deployment notes
No Helm chart is included for this service yet. Deploy as a simple Deployment with a ServiceAccount that has permissions to read HTTPRoutes and Gateways cluster‑wide.

Ensure the Deployment sets the following environment variables (from a Secret or values):
- `OPNSENSE_URI`
- `OPNSENSE_KEY`
- `OPNSENSE_SECRET`
- `OPNSENSE_SKIP_TLS_VERIFY` (optional)

Required RBAC (example):
- `apiGroups: ["gateway.networking.k8s.io"]` or `sigs.k8s.io/gateway-api` as appropriate for your cluster
- `resources: ["httproutes", "gateways"]`
- `verbs: ["get", "list", "watch"]`

The container executes a single static binary built from `src/cmd/dns-sync`.

## Limitations / Assumptions
- Uses only the first Gateway `status.addresses[*]` value when multiple are present.
- Creates A records (RR = "A"); IPv6 AAAA records are not currently handled.
- Only adds/updates entries; it does not clean up removed hosts.
- Expects FQDNs in `spec.hostnames[*]` (splits into hostname + domain using the first dot).

## Troubleshooting
- Set OPNSENSE_SKIP_TLS_VERIFY=true if your OPNsense uses self‑signed TLS.
- Ensure network connectivity from the Pod/host to the OPNsense API URI.
- Check logs for lines like “Starting manager and watching HTTPRoutes…”, “added/updated …”, or errors.
- If running outside cluster, verify that `~/.kube/config` points to the right context.
