# KubeVirt TODO

## Done
- [x] KubeVirt v1.8.4 operator + CR deployed via FluxCD platform kustomization
- [x] CDI v1.65.0 operator + CR deployed
- [x] AMD 780M GPU passthrough configured in CR (`1002:1900`, `1002:1640`)
- [x] CiliumClusterwideNetworkPolicy for kubevirt + cdi namespaces

## Remaining

### GPU device plugin
Need to deploy the AMD GPU device plugin so Kubernetes exposes `amd.com/780m` as a schedulable resource on worker-1.
Check whether `gpu-tools` (already in platform) covers this or if a separate device plugin is needed.

### Verify PCI device IDs
Confirm the GPU vendor/device IDs on worker-1 match what's in the CR:
```bash
talosctl -n 10.0.4.4 get hardwareinfo | grep -i gpu
# or via kubectl debug node
lspci -nn | grep -iE "1002:1900|1002:1640"
```

### Storage class for VM disks
Decide which storage class to back VM DataVolumes:
- `truenas-iscsi` (democratic-csi) — block storage, good for VM disks
- `longhorn` — already running, HA but shared memory

### Kyverno PolicyExceptions
KubeVirt virt-handler and virt-launcher run privileged. May need PolicyExceptions
for `restrict-seccomp-strict` and similar policies — check after first VM attempt.

### Test VM
Create a basic test DataVolume + VirtualMachine to validate the full stack:
- CDI imports image via DataVolume
- VM schedules on worker-1
- GPU passthrough works (if applicable)
