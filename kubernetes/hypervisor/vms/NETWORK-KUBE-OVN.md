# VM networks with Multus + Kube-OVN (stage 1 live, stage 2 written)

Design record for giving VMs their own virtual networks instead of sharing the Cilium
pod network. Not applied yet: `ubuntu-test` still runs on `bridge: {}` + `pod: {}`,
described in [ubuntu-test/README.md](ubuntu-test/README.md).

Requirements this version is written against:

- VM addresses are **private to the cluster** — not reachable from the LAN.
- The operator can create **many vnets/subnets** and **grant access to a vnet
  explicitly**, per vnet.
- One NIC per VM.

## Why move off the pod network

- **Fragile addressing.** IP comes from Cilium's KubeVirt DHCP, the MAC is re-randomized
  per start, the NIC name follows the PCI slot. Pinning the MAC to fix that silently
  kills the datapath — Cilium keys its KubeVirt path off the *pod* MAC and drops every
  frame at `k6t-eth0` ([cilium/cilium#21347](https://github.com/cilium/cilium/issues/21347));
  it cost a full outage of the desktop VM on 2026-11-01.
- **No vnet model.** No subnets we own, no reservations, no isolation between VMs,
  no way to express "this VM may talk to that network".
- **Only inbound path is a LoadBalancer.** `10.0.4.51` is announced by Cilium's BGP and
  is reachable from every VLAN — the opposite of what we want now.

## No Talos change is needed

Checked live on yojimbo (`talosctl -n 10.0.4.13 get modules`, Talos 1.14.5 / kernel
6.18.58-talos): `openvswitch`, `geneve`, `vport_geneve`, `vxlan`, `bridge`,
`br_netfilter`, `nf_nat`, `nf_conntrack` are all **built into the kernel**, not
loadable modules. 631 built-in, 37 dynamic (extensions).

So kube-ovn's Talos step (`machine.kernel.modules: [openvswitch]`) is a no-op here —
nothing to load, no machine-config patch, no reboot, no schematic change. What remains
is Helm config only: `DISABLE_MODULES_MANAGEMENT=true` (the container must not try to
modprobe) plus the host-path values the Talos doc lists (`OPVSWITCH_DIR=/var/lib/openvswitch`,
`OVN_DIR=/var/lib/ovn`, `cni.MOUNT_LOCAL_BIN_DIR=false`).

Re-verify after any Talos upgrade: `talosctl get modules | grep -E 'openvswitch|geneve'`.

Side effect worth knowing: `nf_nat` being built-in means the README's "masquerade needs
`nf_nat` (unavailable)" note is out of date. Not acted on — Cilium's eBPF host routing
breaks kubevirt masquerade anyway ([cilium/cilium#32026](https://github.com/cilium/cilium/issues/32026)).

## Topology

Multus (meta-CNI) + kube-ovn **non-primary mode**; Cilium stays primary and untouched
for pods, gateway LoadBalancers and all existing policies. Install order: primary CNI →
Multus → kube-ovn. Overlay (geneve) only — a `vlan`/underlay provider network would
require enslaving a physical NIC with Talos `ignore: true`, and yojimbo has exactly one,
carrying `10.0.4.13`.

| object | role |
|---|---|
| `Vpc` | one per vnet group; maps to an OVN logical router; different VPCs are fully isolated and may even reuse a CIDR |
| `Subnet` | the vnet: `cidrBlock`, `excludeIps`, `gateway`, `natOutgoing`, `private`, `allowSubnets`, `acls` |
| `NetworkAttachmentDefinition` | one per vnet, in the namespace of the VMs that use it; `type: kube-ovn`, `provider: <nad>.<vpc>.ovn` |
| VM | `autoattachPodInterface: false`, `networks: [{name: vmnet, nads: [...]}]`, `interfaces: [{name: vmnet, bridge: {}}]`; fixed `ovn.kubernetes.io/ip_address` / `mac_address` / `logical_switch` annotations → stable across restarts |

CIDRs must avoid `10.244.0.0/16` (pods), `10.96.0.0/12` (Services) and the whole LAN
space; use something clearly non-LAN, e.g. `172.20.0.0/16` split into `/22` vnets.

### Two ways to express a vnet — pick one

| | default VPC + `private: true` | custom `Vpc` |
|---|---|---|
| isolation | soft: isolated from other subnets and external until whitelisted | hard: separate logical router, no route at all |
| whitelist | `allowSubnets: [cidr...]` (bidirectional) | `VpcPeering` / `StaticRoute` / `PolicyRoute` |
| egress | `natOutgoing: true` on the distributed gateway → SNAT to the node IP | only via a `VpcNatGateway` pod (SNAT/EIP/FIP) |
| k8s niceties (DNS, Services, NodePort) | mostly available | not available (`vpc-dns` exists) |
| cost | least moving parts | per-vnet NAT gateway pods, more objects |

Recommendation: start with **default VPC + `private: true` subnets**, and move a vnet to
a custom `Vpc` only when it needs its own NAT gateway/peering. `natOutgoing`/gateway
settings only work on overlay subnets of the **default VPC**.

### "Not reachable from the LAN" falls out for free

The LAN has no route to the overlay CIDRs, so nothing can reach a VM address from
outside — no OPNsense route, no firewall rule, no Cilium BGP announcement. Egress is a
per-vnet choice: `private: true` = nothing; `natOutgoing: true` = outbound SNATed to the
node address, so the LAN only ever sees `10.0.4.13`. OPNsense rules still apply to that.

Granting access later, explicitly: `allowSubnets` (cluster-internal), `VpcPeering`
(vnet↔vnet), or one EIP/FIP per VM if a VM should ever get a LAN address. Physical-LAN
vnets (kube-ovn `Vlan` + `ProviderNetwork`) stay off the table while yojimbo has one NIC.

## Exposing a VM deliberately

Private-by-default does not mean unreachable. Five ways in, cheapest first; they differ
mostly in *who authenticates* and *what the LAN can see*.

| option | what it is | who can reach it | cost |
|---|---|---|---|
| **a. `virtctl port-forward`** | `virtctl port-forward vm/ubuntu-test tcp/3389 tcp/22` — websocket tunnel via kube-apiserver to the launcher | anything holding a kubeconfig (today: admin context over the tailnet) | none, no route, no pod; session-scoped |
| **b. per-vnet Tailscale subnet router** | one small Deployment in the vnet's namespace: kube-ovn NIC into the vnet + primary NIC for tailnet control/DERP, `tailscale` with `--advertise-routes=<vnet cidr>` | tailnet devices allowed by `policy.hujson` (Terraform-managed); **nothing on the LAN** | one Deployment + Kyverno PolicyException (`NET_ADMIN`) + Cilium egress policy for the router pod; tailnet route approval |
| **c. proxy behind the `internal` Gateway** | a per-VM forwarder pod (Envoy/Traefik/HAProxy, or Guacamole for browser RDP) with a kube-ovn NIC; a listener on the existing Gateway (`10.0.4.50`) like the precedent `ssh-forgejo` TCP/22 listener, or HTTPS + `{app}-gw-tls` | trusted VLAN **and** tailnet (the Gateway is already reachable from both), on that one port/hostname | Gateway listener + HTTPRoute + cert + DNS record, following the usual "exposing an app" convention; pair with real auth (Guacamole login / TLS client cert) |
| **d. OPNsense route + source-scoped rules** | `natOutgoing: false` for the vnet, static route `<vnet> → 10.0.4.13`, then allow only the remote-access sources (opt1 rules) and mirror it with kube-ovn ACLs | whatever the firewall rules say; real client IPs reach the guest | one routable vnet on the LAN = one bad rule away from exposure; Ansible + `docs/NETWORK.md` changes |
| **e. kube-ovn EIP/FIP on one VM** | ~~`ovn.kubernetes.io/eip`/`fip`~~ | — | **not available on this cluster**, see below |

Recommendation: **(a) as the default** — it needs nothing and is the most auditable —
plus **(b)** the moment they want persistent remote-desktop access from anywhere: it is
the same shape as the existing `tailscale` subnet-router VM (VLAN 6), just living inside
the vnet, so the tailnet policy stays the single place that decides who gets in, and no
LAN address is ever involved. **(c)** is the pick for browser/phone access without a
tailnet client. **(d)/(e)** are for when a VM genuinely needs to look like a LAN device.

For reference, what exists today (`10.0.4.51` LoadBalancer, `lbipam` sharing-key,
advertised by Cilium BGP from yojimbo) is the maximally-exposed variant: reachable from
every VLAN. It goes away with the single-NIC move.

### (c) in detail — a two-NIC forwarder is mandatory

The Gateway's Envoy pods live on the Cilium pod network and have **no route into an OVN
vnet**, and secondary networks are not part of the Service/LB datapath — so a `Service`
whose Endpoints hold a VM's vnet address would never be reachable from the Gateway.
Every exposed port therefore needs a forwarder pod with *both* faces:

```
client ─▶ Gateway 10.0.4.50 (or a dedicated lbipam LB IP)
              │  pod network — Cilium policies decide who may connect
              ▼
        forwarder pod (envoy / haproxy / nginx stream / Guacamole)
              │  kube-ovn vnet NIC — OVN ACLs decide what it may reach
              ▼
        VM @ fixed vnet address
```

Front-door variants:

- **shared `internal` Gateway**: a `TCPRoute` on its own port (the `ssh-forgejo` TCP/22
  listener is the precedent) or an HTTPS listener + `{app}-gw-tls` + hostname, with
  `allowedRoutes` scoped to the VM namespace. Least new machinery, hostname-based.
- **dedicated `LoadBalancer` Service + `lbipam` IP** in front of the forwarder: this is
  today's `10.0.4.51` pattern pointed at a proxy instead of at the VM, and it keeps the
  whole exposure decision inside Cilium policy and Git (`fromCIDRSet`, `toEntities`).

RDP reality: RDP clients do not send TLS SNI, so TLS-passthrough-by-hostname is
unreliable — use a dedicated TCP port, or terminate the session in **Guacamole**
(browser RDP/VNC over HTTPS, its own login, session recording), which also removes raw
RDP from the network entirely.

What it costs: one hop per exposed VM (geneve overhead, MTU), the guest sees the
forwarder's vnet address as the source (real client IP needs PROXY protocol or an
`X-Forwarded-*`-capable protocol), the fixed VM IP annotation is what keeps the
forwarder's target stable across restarts, and the forwarder joins the availability path.

A true **bastion** is a different, cheap addition if per-user auth and client-chosen
destinations are ever wanted: an `openssh` pod with a vnet NIC and `ssh -J` into it.
Option (a) is already bastion-shaped — the apiserver is the jump host, the kubeconfig is
the credential, and the destination is chosen by the operator at connect time.

### (e) is blocked here

kube-ovn's EIP/SNAT path (and `externalEgressGateway`, `Vlan`/`ProviderNetwork` — same
prerequisite) needs real underlay attachment: "a separate NIC must be bridged into the
OVS bridge … the host must have other NICs for management", plus ConfigMap
`ovn-external-gw-config` with `external-gw-nic`, `external-gw-addr`, and an unused
`nic-ip`/`nic-mac` on the physical subnet (`distributed` mode wants that NIC on every
node). yojimbo has one NIC and it carries `10.0.4.13`. So (e) means added hardware or a
trunked port 5 plus taking that NIC out of Talos's management path — and its traffic
lands flat on the LAN with nothing filtering it. It increases LAN dependence rather than
removing it.

## Policies: Cilium no longer sees this traffic

**No** — a CiliumNetworkPolicy only governs a VM's *primary pod-network* interface. Once
the NIC is a kube-ovn port, Cilium has no endpoint for it and
`network-policies/base/vms-ubuntu-test.yaml` becomes inert; Kubernetes Services and
LoadBalancers also do not reach secondary networks (upstream limitation).

Enforcement after the move, all of it OVN ACLs under the hood:

- `Subnet.spec.private` + `allowSubnets` — the vnet-level default-deny/whitelist.
- `Subnet.spec.acls` — OVN match/action/priority rules, fine-grained.
- `SecurityGroup` CRD — port/protocol/CIDR rules on ports or subnets.
- standard k8s `NetworkPolicy` — kube-ovn implements them; whether they bite on a
  KubeVirt secondary port has to be verified in stage 4 before we rely on it.
- kube-ovn warns that mixing several of these mechanisms can produce ACL priority
  conflicts → pick one per vnet.

Consequences for the repo: the "every component gets a CiliumNetworkPolicy" convention
needs a VM carve-out in `AGENTS.md`/`CLAUDE.md` and `docs/NETWORK.md`, and the
`ubuntu-test-ssh`/`ubuntu-test-rdp` Services plus the `vms-ubuntu-test` policy are deleted
in the same change. What stays Cilium-managed: the virt-launcher pod's own management
traffic and everything else in the cluster.

## Repo shape

- `kubernetes/hypervisor/multus/`: raw manifests (no official chart), thick plugin
  v4.3.1, NAD CRD shipped alongside (raw CRD may share the Kustomization). DaemonSet
  pinned to yojimbo for the first rollout; **target is every worker** (bahamut,
  yojimbo), never the control planes. kube-ovn's CNI agent follows the same node set.
  No `defaultNetworks`, so Cilium stays the only network a pod gets
  unless it asks for a NAD. Hostnetwork, so no CiliumNetworkPolicy applies to it.
  **Prerequisite:** Cilium `cni.exclusive: false` (Terraform `clusters/workload-prd/terraform/cni`),
  applied before the DaemonSet lands.
- `kubernetes/hypervisor/kube-ovn/`: official `kube-ovn-v2` chart (OCI,
  `HelmRepository` type `oci` in `flux-system`; not an `OCIRepository`, whose
  `+digest` chart version breaks the pre-upgrade hook's labels), v1.16.17, `cni.nonPrimaryCNI: true`. Base holds the
  behaviour (Talos paths, `disableModulesManagement`, join CIDR `172.31.255.0/24`
  instead of Tailscale's `100.64/10`, OVN LB and NetworkPolicy off); the overlay holds
  placement (yojimbo; `kube-ovn-cni` pinned and `kube-ovn-pinger` removed through
  `postRenderers`, the chart has no values for either). `disableWait` on install/upgrade
  so an install/upgrade while the workers are off cannot fail the release.
- CNI file ordering: the agent always writes a conflist, even non-primary. It is
  `90-kube-ovn.conflist` (after `05-cilium`) and Multus is pinned with
  `multusMasterCNI: 05-cilium.conflist`; either alone stops Kube-OVN from becoming the
  primary network after a Multus restart.
- kube-ovn CRDs ship from the chart → `Vpc`/`Subnet`/NAD instances go in a **later**
  Kustomization with `dependsOn` (CRD-through-Helm cold-start rule).
- vnets are data, not infra: keep `vms/<name>/network.yaml` (NAD) + a `vnet` layer of
  `Subnet`/`Vpc` objects, so adding a vnet is one commit.
- `docs/NETWORK.md`, `docs/DEVICES.md`, `netbox/homelab.yaml` + `netbox/sync.py` in the
  same commit.

## Staged plan (each step reversible)

1. *(done 2026-11-01)* Cilium `cni.exclusive: false`, then Multus on yojimbo →
   verify `00-multus.conf` exists and no `*.cilium_bak`, a fresh pod on yojimbo still
   gets `10.244.x` + DNS, an existing policy still enforces, `ubuntu-test` still has
   network after a restart. Highest-risk step; revert = delete the DaemonSet, set
   `cni.exclusive: true` again and restart the yojimbo agent (moves `00-multus.conf` aside).
2. *(written, not applied)* kube-ovn non-primary on yojimbo → verify: pods healthy;
   `/etc/cni/net.d` = `00-multus.conf`, `05-cilium.conflist`, `90-kube-ovn.conflist`,
   and `00-multus.conf` still delegates to Cilium; `cilium-dbg status` devices still
   `enp4s0 siderolink` (no `ovn0`); a fresh pod on yojimbo still gets only `eth0`
   `10.244.x`; ubuntu-test still boots with network. Revert = delete the HelmRelease
   (its post-delete hook cleans OVN state). `90-kube-ovn.conflist` stays behind as a
   dead file; harmless, because Multus is pinned to Cilium.
3. One test vnet + NAD + a throwaway cirros VM on a **second** NIC → verify fixed IP/MAC
   survives restart, `private: true` really blocks, `allowSubnets` opens exactly one
   pair, NetworkPolicy behaviour on the VM port, and what DNS the guest receives.
4. Switch `ubuntu-test` to a single kube-ovn NIC; delete the two Services and the
   Cilium policy; access via `virtctl port-forward`. Rollback = re-add the pod-network
   interface + Services (one restart).
5. Docs, netbox, `AGENTS.md`/`CLAUDE.md` policy carve-out.

## Open decisions

1. vnet model: default VPC + `private` (recommended to start) vs custom `Vpc` per vnet.
2. CIDR plan and how many vnets to seed (`vms-private`, `vms-internet-ok`, …).
3. DNS for VMs: kube-ovn hands DNS out of the vnet (verify the field reaches the guest
   via DHCP, and whether it points at `10.0.4.1`/Unbound or at CoreDNS through
   `vpc-dns`).
4. Desktop access: (a) only, or (a)+(b) with a per-vnet Tailscale subnet router, or (c)
   through the Gateway.
5. ~~Chart v1 vs v2~~ — decided: v2 (`cni.nonPrimaryCNI`), rendered and checked.
6. ~~Where kube-ovn's `ovs-ovn` runs~~ — decided: same node set as Multus, i.e. the
   workers only (yojimbo first, then bahamut), never the control planes.
7. Availability is unchanged: the GPU pins the VM to yojimbo, so one VM per vnet stays a
   single point of failure.
