# Homelab — working notes for Claude

Read [README.md](README.md) for the repo layout, Flux layers and component
list, [docs/NETWORK.md](docs/NETWORK.md) for topology and firewall, and
[docs/DEVICES.md](docs/DEVICES.md) for every IP, MAC and hardware detail.
This file holds the rules and pitfalls that are not obvious from the code.

## Ground rules

- **Never commit or push.** The user commits. Leave changes in the working tree and list them.
- **Flux owns the cluster.** Anything in Git that is patched live gets reverted on the next sync. Fix it in Git; live patches are only a stopgap for objects outside Git or for an incident.
- **Node names are lowercase** everywhere, including prose: valefor, ifrit, shiva, ixion, bahamut (Final Fantasy eidolons). Old names (controlplane-1/2/3, worker-1) are gone; don't reintroduce them.
- **Goal of the cluster:** drains and upgrades with no data loss and no downtime. Prefer changes that keep that true (spread constraints, PDBs, replicas ≥ 2 for stateless services).
- **Workers are not always on**, bahamut especially. Anything that must stay up runs on the control planes, and its Longhorn data stays on `system`-tagged nodes.
- **bahamut is for GPU workloads only** (taint `workload=gpu:NoSchedule`). forgejo-runner is the one deliberate exception.
- `docs/` and `netbox/homelab.yaml` must stay in sync: a new device, address, cable, VLAN or rule goes into DEVICES.md / NETWORK.md and homelab.yaml in the same change, then `netbox/sync.py` (idempotent, never deletes; token header in `.playground/netbox-auth-header`).

## Kubernetes conventions

**Component shape.** `base/` = workload (HelmRepository in `flux-system` + HelmRelease), `overlays/workload-prd/` = patches, `http-route.yaml`. Register the component in its layer's `overlays/workload-prd/kustomization.yaml`.

**Centralized objects** (never inside the component folder), file name `{layer}-{component}.yaml`:
- Namespace → `kubernetes/namespaces/base/`
- CiliumNetworkPolicy → `kubernetes/network-policies/base/`
- ExternalSecret → `kubernetes/secrets/base/`
- PolicyException → `kubernetes/policies/base/exceptions/`

**Kustomization rules**
- A Kustomization that installs CRDs through a HelmRelease must not contain instances of those CRDs (cold-start race, caused a full outage once). Put the instances in a later layer with `dependsOn`. A CRD shipped as a raw manifest may share a Kustomization with its instances.
- Renaming or deleting a Kustomization, or moving resources out of one, garbage-collects what it manages. Set `spec.prune: false` live on the affected Kustomization **before** the change merges.
- One unhealthy ExternalSecret in `secrets` blocks every layer below it.
- Immutable objects (Jobs, StorageClasses) need `kustomize.toolkit.fluxcd.io/force: enabled` before their spec can change.

**Network policies (Cilium)**
- Every new component needs its own policy. A namespace only gets the Kyverno-generated `allow-same-namespace` policy, which does **not** allow the kube-apiserver. When Longhorn 1.13 added `longhorn-global-manager` without one, Longhorn's remount recovery was silently off cluster-wide.
- API access: separate egress rules for `kube-apiserver` and for `host`/`remote-node`, each allowing **both 6443 and 443** (pods use `10.96.0.1:443`).
- DNS egress, health probes, Flux and Alloy scraping are allowed cluster-wide in `network-policies/base/cluster-wide/`; don't repeat them.
- Gateway ingress: `fromEntities: [cluster, ingress]`.
- CNPG operator access is covered generically by `platform-cloudnative-pg.yaml`.

**Kyverno PolicyException** (namespace-scoped; list only the policies actually violated):
```yaml
apiVersion: policies.kyverno.io/v1beta1
kind: PolicyException
metadata:
  name: {component}
  namespace: {namespace}
spec:
  matchConditions:
    - name: exclude-{component}
      expression: "object.metadata.namespace == '{namespace}'"
  policyRefs:
    - kind: ValidatingPolicy
      name: restrict-seccomp-strict
```
One broken CEL expression denies every workload that shares those policyRefs; guard label access with `has()`.

**Exposing an app.** Add an HTTPS listener `https-{app}` for `{app}.yuriykovalchuk.dev` to `kubernetes/platform/infra/gateway/overlays/workload-prd/gateway-patch.yaml` (cert secret `{app}-gw-tls`, `allowedRoutes` limited to the app namespace), then an HTTPRoute with `parentRefs: internal / kube-system / sectionName: https-{app}`.

## GPUs (DRA)

- GPUs are claimed through DRA, never hostPath or privileged. A `ResourceClaimTemplate` selects the card by sysfs PCI device ID: `0x7551` R9700, `0x1900` Radeon 780M (both bahamut), `0x1681` Radeon 680M (ixion). `productName` is empty on these cards, so selectors on it match nothing.
- Claims are exclusive cluster-wide. Two pods share a card only through one named `ResourceClaim` (Immich does this). Only one R9700 workload runs at a time.
- GPU Deployments must use `strategy: Recreate` and tolerate `workload=gpu:NoSchedule`; the claim itself pins the node.
- Immich spoofs gfx1035 with `HSA_OVERRIDE_GFX_VERSION=10.3.0`; change it if the claim moves to another card.
- llama.cpp runs in router mode: models from the models PVC, per-model settings in `kubernetes/llm/llama-cpp/base/models-preset-configmap.yaml`, downloads in `models.txt`. Replicas in `llm` are ignored by Flux, so `kubectl scale` sticks.

## Storage

- Longhorn node tags: `system` on control planes (default classes), `gpu` on bahamut (`longhorn-gpu`), `vms` + `nvidia` on yojimbo (`longhorn-vms`, `longhorn-nvidia`; set live on the Longhorn node CR, the annotation was ignored). New nodes pick up tags from the Talos annotation `node.longhorn.io/default-node-tags`.
- `longhorn-1r` is single-replica: when its one replica times out the volume faults, ext4 goes read-only, and the pod stays Running on a dead mount until it is **deleted** (a container restart reuses the bad mount). Longhorn's auto-remount needs the `longhorn-global-manager` lease; check `kubectl -n longhorn-system get lease longhorn-global-manager` exists.
- Stale Longhorn node CRs (after a rename/removal) can only be deleted after `spec.allowScheduling: false` on the node; disk edits are refused once the Kubernetes node is gone.
- A re-created Longhorn disk defaults to 30% reserved; workers use 10 GiB.
- TrueNAS must keep its static IP; democratic-csi and Vault break otherwise.

## Talos

- Configs live outside the repo (`.playground/talos/`, gitignored, and `~/.talos/`). Use `talosctl -e <a control plane>`; the endpoint is not the VIP.
- Upgrades: always pass the node's factory image, e.g. `-i factory.talos.dev/metal-installer/<schematic>:v1.14.2`. talosctl 1.14 defaults to a vanilla image and would drop the extensions (amdgpu, iscsi-tools…). Schematics are in DEVICES.md.
- Upgrades keep EPHEMERAL (Longhorn data). `talosctl reset` does not; never reset or reinstall a node that holds the only Longhorn replica of a volume without asking.
- Drain first, then `talosctl upgrade --drain=false`. Single-instance CNPG clusters and single-replica volumes block drains.
- Talos cannot add `nodeTaints` to a worker after it registers (NodeRestriction), and that failure also blocks its labels and annotations. Set them with kubectl.
- Merge patches append to lists (e.g. interface addresses); to replace one, edit and apply the full config.
- The homebrew talosctl may be older than the cluster; check `talosctl version --client`.

## OPNsense / Ansible

- Run from `proxmox-nodes/ansible` with `-i inventories/prd/gateway`, the `OPNSENSE_*` variables from `.env` loaded, and a Python that has `httpx` (`-e ansible_python_interpreter=…`).
- `oxlorg.opnsense` 26.x: modules default `reload` to false; set `reload: false` per task and reload once at the end. **Read live state back after every change.**
- `dhcp_subnet` wipes DNS/NTP servers unless they are passed (it caused a trusted-network outage).
- `haproxy_healthcheck` reports changed but never saves; create health checks through `oxlorg.opnsense.raw`.
- Removing an item from a loop does not delete it in OPNsense; delete it explicitly.
- BGP neighbors match on IP only (`match_fields: ["ip"]`); renaming a description otherwise creates a duplicate.
- Interface assignment and interface IPs are GUI-only.
- Host-type aliases (e.g. `PROXMOX`) are filled only by `firewall/alias/reconfigure`; a rule reload leaves them empty and every rule using them matches nothing. Check with `firewall/alias_util/list/<alias>`.
- `unbound/service/dnsbl` re-downloads every blocklist (~1 min of no DNS) and needs `timeout: 180`. The HaGeZi VPN-bypass list blocks Tailscale; the allowlist in `dns.yml` must stay.
- To see why traffic is blocked, read `diagnostics/firewall/log` (newest first) instead of guessing.

## Gateway host (Proxmox) management

- Management is `10.0.5.3` on `vmbr1.5` (trusted VLAN); `vmbr0` carries no host address (OPNsense WAN only). Break-glass: `nic1`/`vmbr9` at `172.30.0.1/24`, direct laptop cable. All in `proxmox-nodes/terraform/prd/gateway/network` (`lockdown` true = normal, false = rebuild via `192.168.0.254`).
- Flipping `lockdown` removes the address Terraform may be talking to: set `GATEWAY_PROXMOX_ENDPOINT` to the address that survives the change first, and run from trusted or break-glass.
- The cluster cannot reach the trusted VLAN by design, so nothing in Kubernetes (e.g. Homepage siteMonitor) may depend on reaching `10.0.5.3`.

## Tailscale (remote access)

- Subnet router VM `tailscale` (10.0.6.10, VLAN 6, gateway host). Remote clients are SNATed to it, so Cilium policies that allow outside clients (`allow-gateway-frontend`, `allow-kube-system`) list `10.0.6.10/32`.
- Tailnet config is Terraform: `prd/tailscale` (policy, split DNS, settings, router key) runs with the OAuth client in `.env`. Never put the OAuth client in that unit — it can't read itself and would be recreated. It lives in `prd/tailscale-bootstrap`, applied only with a short-lived `TAILSCALE_API_KEY` (and the OAuth vars unset; the provider rejects both at once).
- The policy file is authoritative: console edits are overwritten on the next apply.

## Secrets and Vault

- Vault runs on TrueNAS, not in the cluster. Its Kubernetes auth `kubernetes_host` must be the API VIP; the bootstrap is in `kubernetes/core/external-secrets/overlays/workload-prd/README.md` and must be redone when the external-secrets ServiceAccount is recreated.
- A sealed Vault stops ESO and, through the `secrets` layer, everything after it: unseal, restart ESO, reconcile.

## Observability

- Query Mimir through `mimir-query-frontend:8080/prometheus` with header `X-Scope-OrgID: anonymous`; Loki through `loki-gateway` with the same header.
- Ingesters, store-gateways and the other Mimir/Tempo components have hard one-per-node spreads. Keep that in mind for scaling and maintenance: with 3 control planes, a node down means a Pending replica.
- After an ingestion outage, Alloy replays its backlog into rate limits; restarting the `alloy-metrics` DaemonSet drops the backlog (its queue is in the container filesystem).
