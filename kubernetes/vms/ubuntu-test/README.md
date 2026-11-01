# ubuntu-test VM

Ubuntu 24.04 (Noble) test VM running on KubeVirt in the `kubevirt-ubuntu-test` namespace on `yojimbo`, with its GTX 1070 passed through on demand (see GPU passthrough).

## Specs

- 4 vCPU, 8 GB RAM
- 50 GB Longhorn PVC (RWO — no live migration), one replica on yojimbo's `vms` disk (volume `nodeSelector`/`diskSelector: [vms]`, set on the Longhorn volume, not in Git). Unavailable while yojimbo is off, which is also when the VM can't run.
- Networking: KubeVirt bridge mode (VM shares pod IP, no iptables/passt required)
- Desktop: XFCE4 + LightDM
- Remote desktop: xrdp on `10.0.4.51:3389`; SSH on `10.0.4.51:22` (see Access)

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
| `vfio` | `vfio-pci` | KubeVirt `nvidia.com/gtx1070` + `nvidia.com/gtx1070-audio` (`permittedHostDevices` in `platform/infra/kubevirt/base/cr.yaml`) | this VM (`vm.yaml` `gpus` / `hostDevices`) |

```bash
# to the VM
kubectl -n llm scale deploy llama-cpp-cuda --replicas=0
kubernetes/vms/ubuntu-test/gpu-mode.sh vfio      # refuses while anything claims the card
virtctl --kubeconfig ~/.kube/workload start ubuntu-test -n kubevirt-ubuntu-test

# back to containers
virtctl --kubeconfig ~/.kube/workload stop ubuntu-test -n kubevirt-ubuntu-test
kubernetes/vms/ubuntu-test/gpu-mode.sh nvidia    # refuses while the VM runs
kubectl -n llm scale deploy llama-cpp-cuda --replicas=1

kubernetes/vms/ubuntu-test/gpu-mode.sh status    # which driver holds each function
```

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
[`platform/infra/nvidia-dra-driver/VFIO-TALOS-ISSUES.md`](../../platform/infra/nvidia-dra-driver/VFIO-TALOS-ISSUES.md).
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

Bridge mode is used because Talos Linux + Cilium (eBPF, kube-proxy replacement) does not load
netfilter/iptables kernel modules. Masquerade networking requires `nf_nat` (unavailable), and
passt networking requires user namespaces (`user.max_user_namespaces > 0`, disabled by default on
Talos). Bridge mode uses virt-launcher's built-in DHCP server with no kernel module dependencies.
