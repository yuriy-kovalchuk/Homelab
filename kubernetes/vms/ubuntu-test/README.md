# ubuntu-test VM

Ubuntu 24.04 (Noble) test VM running on KubeVirt in the `kubevirt-ubuntu-test` namespace on `bahamut`.

## Specs

- 4 vCPU, 8 GB RAM
- 50 GB Longhorn PVC (RWO — no live migration)
- Networking: KubeVirt bridge mode (VM shares pod IP, no iptables/passt required)
- Desktop: XFCE4 + LightDM
- Remote desktop: xrdp on `10.0.4.51:3389`; SSH on `10.0.4.51:22` (see Access)

**Flux is suspended for this component** (`suspend: true` in
`kubernetes/clusters/workload-prd/flux-system/vms.yaml`): changes here are applied from the
terminal (`kubectl apply --server-side -f …`). Keep the files in sync with what you apply, and set
`suspend: false` to hand it back to Flux.

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
by bahamut only, `externalTrafficPolicy: Local`, no NodePort). Nothing goes through the kube-apiserver.
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
