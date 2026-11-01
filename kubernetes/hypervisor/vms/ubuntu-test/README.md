# ubuntu-test VM

Ubuntu 24.04 (Noble) test VM running on KubeVirt in the `kubevirt-ubuntu-test` namespace on `yojimbo`, with its GTX 1070 passed through on demand (see GPU passthrough).

## Specs

- 4 vCPU, 8 GB RAM
- 50 GB Longhorn PVC (RWO — no live migration), one replica on yojimbo's `vms` disk (volume `nodeSelector`/`diskSelector: [vms]`, set on the Longhorn volume, not in Git). Unavailable while yojimbo is off, which is also when the VM can't run.
- Networking: one NIC on VNet `vnet-test`, subnet `vnet-test-vms` (Kube-OVN custom Vpc,
  `172.20.1.0/24`): address `172.20.1.10` from OVN's DHCP, MAC `02:00:ac:14:01:0a`. No pod-network
  NIC, so **no internet and no remote access** for now (see Networking notes)
- Desktop: XFCE4 + LightDM, on yojimbo's own monitor/keyboard/mouse while the VM holds the card

**Flux is suspended for this component** (`suspend: true` in
`kubernetes/clusters/workload-prd/flux-system/vms.yaml`): changes here are applied from the
terminal (`kubectl apply --server-side -f …`). Keep the files in sync with what you apply, and set
`suspend: false` to hand it back to Flux.

## GPU passthrough (GTX 1070)

The card (`10de:1b81`, `01:00.0`) and its HDMI audio (`10de:10f0`, `01:00.1`, same IOMMU group)
belong either to containers or to this VM, switched at runtime with [`gpu-mode.sh`](gpu-mode.sh).
yojimbo's Talos config is unchanged: it boots with the card on `nvidia`, so a reboot also gives it
back to containers.

| Mode | Driver | Offered as | Used by |
|---|---|---|---|
| `nvidia` (boot default) | `nvidia` | DRA `gpu.nvidia.com` (`gpu-0`) | llama-cpp-cuda |
| `vfio` | `vfio-pci` | KubeVirt `nvidia.com/gtx1070` + `nvidia.com/gtx1070-audio` (`permittedHostDevices` in `hypervisor/kubevirt/base/cr.yaml`) | this VM (`vm.yaml` `gpus` / `hostDevices`) |

```bash
# to the VM
kubectl -n llm scale deploy llama-cpp-cuda --replicas=0
kubernetes/hypervisor/vms/ubuntu-test/gpu-mode.sh vfio      # refuses while anything claims the card
virtctl --kubeconfig ~/.kube/workload start ubuntu-test -n kubevirt-ubuntu-test

# back to containers
virtctl --kubeconfig ~/.kube/workload stop ubuntu-test -n kubevirt-ubuntu-test
kubernetes/hypervisor/vms/ubuntu-test/gpu-mode.sh nvidia    # refuses while the VM runs
kubectl -n llm scale deploy llama-cpp-cuda --replicas=1

kubernetes/hypervisor/vms/ubuntu-test/gpu-mode.sh status    # which driver holds each function
```

yojimbo's monitor follows the card: the VM while it holds it, the Talos dashboard otherwise, but
only until the first round trip. The firmware framebuffer yojimbo boots with is removed for good
once the card goes to `vfio-pci`, so after `gpu-mode.sh nvidia` the monitor stays dark until the
next reboot of yojimbo. Known and accepted. Do not set `nvidia_drm modeset=1 fbdev=1` to get the
console back: tried on 2026-11-01, and every bind back to `nvidia` crashed the kernel the moment
fbcon took over the new nvidia-drm framebuffer (driver 580, Pascal), rebooting yojimbo (last
kernel line: `fbcon: nvidia-drmdrmfb (fb0) is primary device`). Retry only with a newer driver.

The script does the rebind from a short-lived privileged busybox pod on yojimbo in
`nvidia-dra-driver` (privileged Pod Security level and a PolicyException there). It stops the Talos
`ext-nvidia-persistenced` service first (it holds `/dev/nvidia0` open, and the unbind from `nvidia`
would hang on it), sets `driver_override`, unbinds and binds, then restarts virt-handler and the DRA
kubelet plugin on yojimbo so both re-scan the card. `nvidia` mode starts persistenced again. If the
unbind times out (30 s), something still holds the card.

It talks to yojimbo's Talos API too: `TALOSCONFIG` defaults to `~/.talos/config-prod`, endpoint
`10.0.4.5` and node `10.0.4.13` (override with `TALOS_ENDPOINT` / `TALOS_NODE_IP`).

Starting the VM while the card is in `nvidia` mode leaves it Pending (`Insufficient
nvidia.com/gtx1070`). That is harmless; switch modes and it schedules.

Why not DRA: the dynamic `vfio.gpu.nvidia.com` claim (`resource-claim-template.yaml`, not applied)
would do this switch automatically, but driver 0.5.1 can't prepare it on Talos. See
[`platform/infra/nvidia-dra-driver/VFIO-TALOS-ISSUES.md`](../../../platform/infra/nvidia-dra-driver/VFIO-TALOS-ISSUES.md).
Once that is fixed, re-add the claim and drop `gpu-mode.sh`.

### In the guest

`lspci -nn -d 10de:` shows `10de:1b81` and `10de:10f0`. Install the 580 driver (the last branch
with Pascal) and check it:

```bash
sudo apt install -y nvidia-driver-580-server nvidia-utils-580-server   # pulls nvidia-dkms + dkms
sudo reboot
nvidia-smi
```

### Local display on the 1070

Left alone, X auto-configures onto QEMU's emulated VGA (`1234:1111`) and the monitor plugged into
the card stays dark; vfio gives no option ROM, so there is no POST picture either. Pin X to the GPU
with `/etc/X11/xorg.conf.d/10-nvidia.conf` in the guest:

```xorg
Section "ServerFlags"
    Option "AutoAddGPU" "false"
EndSection

Section "Device"
    Identifier "GP104"
    Driver     "nvidia"
    BusID      "PCI:11:0:0"
EndSection

Section "Screen"
    Identifier "scr"
    Device     "GP104"
EndSection
```

`PCI:11:0:0` is the guest slot QEMU gave the card (`lspci` shows `0b:00.0`) — not the host's
`01:00.0`, so re-check it if the VM's PCI topology changes. The monitor is on the card's HDMI out
(`HDMI-0`). `xrandr` on `:0` (as root, `XAUTHORITY=/var/run/lightdm/root/:0`) is the check.
After this, `virtctl vnc` shows nothing (the emulated VGA is idle); RDP on `10.0.4.51:3389` runs its
own X on `:10` and is unaffected.

A drain or Talos upgrade of yojimbo stops the VM hard (no live migration with a passthrough device).

## First boot setup

After the VM boots for the first time, install the desktop environment:

```bash
sudo apt update && sudo apt install -y xfce4 xfce4-goodies lightdm lightdm-gtk-greeter dbus-x11
sudo reboot
```

## Access

> Since the VM moved to `vnet-test-vms` (single Kube-OVN NIC), Options 1–2 and SSH below **do not
> work**: VNC needs the emulated display (`autoattachGraphicsDevice: false`), and the `10.0.4.51`
> LoadBalancer Services point at the virt-launcher pod, which the VM is no longer attached to.
> What works: yojimbo's monitor/keyboard/mouse (while the VM holds the card) and the serial console.
> Kept for when ingress into the VNet exists (an edge gateway with inbound NAT rules).

### Option 1 — virtctl proxy (no extra setup)

Requires `virtctl` and a VNC client (e.g. TigerVNC Viewer).

```bash
# Start the VNC proxy on localhost:5901
virtctl --kubeconfig ~/.kube/workload vnc ubuntu-test -n kubevirt-ubuntu-test --proxy-only --port 5901 &

# Open TigerVNC Viewer and connect to 127.0.0.1:5901 (no password)
```

To stop the proxy:
```bash
kill $(lsof -ti:5901)
```

### Option 2 — RDP on its own LoadBalancer IP (recommended)

`rdp-service.yaml` exposes TCP 3389 of the VM on **`10.0.4.51`** (Cilium LB pool, advertised over BGP
by yojimbo only, `externalTrafficPolicy: Local`, no NodePort). Nothing goes through the kube-apiserver.
The `ubuntu-test-remote-ingress` CiliumNetworkPolicy (`kubernetes/network-policies/base/vms-ubuntu-test.yaml`)
allows it only from the trusted VLAN (`10.0.5.0/24`) and the Tailscale subnet router (`10.0.6.10`).

**1. Install xrdp inside the VM** (one-time, via the console or SSH, as the desktop user):

```bash
sudo apt install -y xrdp
echo "startxfce4" > ~/.xsession          # XFCE session for RDP logins
sudo adduser xrdp ssl-cert               # lets xrdp read its TLS key
sudo systemctl enable --now xrdp
```

Log out of the XFCE session on the VM console first: a user can't be logged in on the console and
over xrdp at the same time.

**2. Connect** with Microsoft "Windows App" (free, Mac App Store; macOS has no built-in RDP client)
to `10.0.4.51`, with the VM user's credentials.

### SSH

`ssh-service.yaml` puts SSH on the same IP (`ubuntu-test-ssh`, `10.0.4.51:22`, the two Services share
it through `lbipam.cilium.io/sharing-key: ubuntu-test`), allowed by the same policy.

```bash
ssh-copy-id -i ~/.ssh/homelab_ed25519.pub <vm-user>@10.0.4.51   # once, with the VM password
ssh -i ~/.ssh/homelab_ed25519 <vm-user>@10.0.4.51
```

The cloud-init enables password logins (`ssh_pwauth: true`). Once your key works, turn them off in the
guest (`PasswordAuthentication no` in `/etc/ssh/sshd_config.d/`, then `sudo systemctl reload ssh`).

## Console access

```bash
virtctl --kubeconfig ~/.kube/workload console ubuntu-test -n kubevirt-ubuntu-test
```

Exit with `Ctrl+]`.

## VM lifecycle

```bash
# Start
virtctl --kubeconfig ~/.kube/workload start ubuntu-test -n kubevirt-ubuntu-test

# Stop
virtctl --kubeconfig ~/.kube/workload stop ubuntu-test -n kubevirt-ubuntu-test

# Restart
virtctl --kubeconfig ~/.kube/workload restart ubuntu-test -n kubevirt-ubuntu-test
```

## Credentials

Credentials are managed via Vault → ExternalSecret → `ubuntu-test-cloudinit` Secret.
See `kubernetes/clusters/workload-prd/terraform/vault/kubevirt-ubuntu-test.tf`.

## Networking notes

The VM has a single NIC on VNet `vnet-test` / subnet `vnet-test-vms`
(`kubernetes/hypervisor/networks/vnet-test/`), attached through the NAD `vnet-test-vms` in this
namespace (`autoattachPodInterface: false`, no pod-network NIC). That Vpc is isolated: no route to
the pod network, the nodes, the LAN or the internet. Internet and inbound access are planned as a
per-VNet edge gateway (outbound NAT + inbound NAT rules), not built yet.

- Address: OVN's DHCP hands out the address Kube-OVN reserved for the VM (`172.20.1.10`, kept across
  restarts by `enableKeepVmIps`), with `router=172.20.1.1`, `mtu=1400`. Nothing is pinned by an
  annotation.
- The MAC is fixed (`02:00:ac:14:01:0a`, no Cilium on this port, so that is safe) and the guest's
  netplan (`/etc/netplan/50-cloud-init.yaml`, same as the cloud-init `networkData`) matches the NIC
  by that MAC, so its guest name does not matter.
- The NIC is pinned to `pciAddress: 0000:01:00.0`, the slot the old pod NIC had, so the GPU, USB
  and disk slots stay where they have always been.
- The virt-launcher pod still has its own Cilium `eth0` (the namespace's Cilium policy applies to
  it), but the VM is not connected to it.
