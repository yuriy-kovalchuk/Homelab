# ubuntu-test VM

Ubuntu 24.04 (Noble) test VM running on KubeVirt in the `vms` namespace on `worker-1`.

## Specs

- 2 vCPU, 4 GB RAM
- 30 GB Longhorn PVC (RWO — no live migration)
- Networking: KubeVirt bridge mode (VM shares pod IP, no iptables/passt required)
- Desktop: XFCE4 + LightDM

## Access

### Option 1 — virtctl proxy (no extra setup)

Requires `virtctl` and a VNC client (e.g. TigerVNC Viewer).

```bash
# Start the VNC proxy on localhost:5901
virtctl --kubeconfig ~/.kube/workload vnc ubuntu-test -n vms --proxy-only --port 5901 &

# Open TigerVNC Viewer and connect to 127.0.0.1:5901 (no password)
```

To stop the proxy:
```bash
kill $(lsof -ti:5901)
```

### Option 2 — direct LoadBalancer (persistent, no virtctl needed)

Runs a VNC server inside the VM and exposes it via a Cilium BGP LoadBalancer IP.

**1. Install VNC server inside the VM** (one-time, via console or SSH):

```bash
sudo apt install -y tigervnc-standalone-server

# Set a VNC password
vncpasswd

# Create a startup script for the XFCE session
mkdir -p ~/.vnc
cat > ~/.vnc/xstartup << 'EOF'
#!/bin/sh
exec startxfce4
EOF
chmod +x ~/.vnc/xstartup

# Start VNC server on display :0 (port 5900)
vncserver :0 -geometry 1920x1080 -depth 24

# To auto-start on boot, enable the systemd service:
sudo systemctl enable vncserver@:0
```

**2. Apply the LoadBalancer Service** (`kubernetes/vms/ubuntu-test/vnc-service.yaml`):

```bash
kubectl --kubeconfig ~/.kube/workload apply -f kubernetes/vms/ubuntu-test/vnc-service.yaml
```

**3. Get the assigned IP:**

```bash
kubectl --kubeconfig ~/.kube/workload get svc ubuntu-test-vnc -n vms
```

Connect TigerVNC Viewer to `<EXTERNAL-IP>:5900`.

## Console access

```bash
virtctl --kubeconfig ~/.kube/workload console ubuntu-test -n vms
```

Exit with `Ctrl+]`.

## VM lifecycle

```bash
# Start
virtctl --kubeconfig ~/.kube/workload start ubuntu-test -n vms

# Stop
virtctl --kubeconfig ~/.kube/workload stop ubuntu-test -n vms

# Restart
virtctl --kubeconfig ~/.kube/workload restart ubuntu-test -n vms
```

## Credentials

| User | Password |
|------|----------|
| ubuntu | ubuntu |

## Networking notes

Bridge mode is used because Talos Linux + Cilium (eBPF, kube-proxy replacement) does not load
netfilter/iptables kernel modules. Masquerade networking requires `nf_nat` (unavailable), and
passt networking requires user namespaces (`user.max_user_namespaces > 0`, disabled by default on
Talos). Bridge mode uses virt-launcher's built-in DHCP server with no kernel module dependencies.
