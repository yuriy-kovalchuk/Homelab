# VFIO passthrough on Talos: open driver bugs

Status (2026-11-01): **blocked upstream.** With `PassthroughSupport` and `DeviceMetadata` on
(driver 0.5.1), yojimbo advertises `gpu-vfio-0` and a VM claim on `vfio.gpu.nvidia.com` gets
allocated. But the driver can't switch the GTX 1070 from `nvidia` to `vfio-pci`, so the
virt-launcher pod (ubuntu-test) stays at `Init:0/1` and kubelet reports:

```
Failed to prepare dynamic resources: NodePrepareResources: rpc error: code = DeadlineExceeded
NodePrepareResources failed for ResourceClaim …: error acquiring prep/unprep lock: timeout acquiring lock (/var/lib/kubelet/plugins/gpu.nvidia.com/pu.lock)
```

The failed prepare rolls back cleanly: the card returns to `nvidia`, and llama-cpp-cuda can use it again.

Before rebinding, the driver (`cmd/gpu-kubelet-plugin/vfio-device.go`, `Configure`) runs these steps:

1. `disableGPUPersistenceMode`: turn persistence mode off if nvidia-persistenced is running. **Bug 1.**
2. `WaitForGPUFree`: wait until no process has `/dev/nvidiaN` open, up to `gpuFreeCheckTimeout` (60s). **Bug 2.**
3. `changeDriver`: unbind from `nvidia`, bind to `vfio-pci` (15s timeout).

Steps 1 and 2 assume a conventional host: the driver under `/`, and `fuser` available. Talos breaks both
assumptions. Kubelet's own NodePrepareResources deadline is also 60s, so step 2 runs out the whole budget.

## Bug 1: nvidia-persistenced is not detected

| | |
|---|---|
| Upstream fix | [kubernetes-sigs/dra-driver-nvidia-gpu#1568](https://github.com/kubernetes-sigs/dra-driver-nvidia-gpu/pull/1568), "Disable GPU persistence through a host-root nvidia-persistenced" (PR, **open**, 2026-10-15) |
| Workaround | Stop the Talos service before starting the VM (see below) |

**What it does.** nvidia-persistenced keeps the driver loaded and the GPU initialized while no
program uses it. That avoids 1–2 s of reinitialization on the next open and keeps clocks and
power limits. On Talos it is the `ext-nvidia-persistenced` service from the NVIDIA extensions.
Nothing in this cluster needs it: llama-cpp-cuda holds the GPU open the whole time it runs.

**Bug.** The driver decides whether persistenced is running by checking for its socket under the
*driver root*:

```go
os.Stat(filepath.Join(vm.containerDriverRoot, "/run/nvidia-persistenced/socket"))
```

Our driver root is `/usr/local` (`nvidiaDriverRoot`, where Talos installs the driver), so the
driver looks for `/usr/local/run/nvidia-persistenced/socket`. Talos's persistenced keeps its socket
at `/run/nvidia-persistenced/socket`. The plugin logs
`nvidia-persistenced is not running; nothing to do...`, leaves persistence mode on, and
persistenced keeps `/dev/nvidia0` open. That makes step 2 wait (even once bug 2 is fixed), and the
claim times out.

**Workaround** (until yojimbo reboots; the service comes back on every boot):

```bash
TALOSCONFIG=~/.talos/config-prod talosctl -e 10.0.4.5 -n 10.0.4.13 service ext-nvidia-persistenced stop
TALOSCONFIG=~/.talos/config-prod talosctl -e 10.0.4.5 -n 10.0.4.13 service ext-nvidia-persistenced   # STATE Finished
```

`~/.talos/config-prod` is the admin config. It has no endpoints, so pass `-e` with a control plane.

## Bug 2: `fuser` does not exist on Talos (hard blocker)

| | |
|---|---|
| Upstream fix | [kubernetes-sigs/dra-driver-nvidia-gpu#1504](https://github.com/kubernetes-sigs/dra-driver-nvidia-gpu/pull/1504), "Scan /proc for GPU holders instead of running fuser" (PR, **open**, 2026-09-29) |
| Workaround | None. Talos ships no `fuser` (psmisc), and there is no extension for it |

**Bug.** `WaitForGPUFree` checks for processes holding the GPU with:

```go
execCommandWithChroot(hostRoot, "fuser", []string{"<driver-root>/dev/nvidiaN"})
```

and only treats `fuser`'s exit code 1 ("no users") as free. On Talos the chroot exits 127 (command not
found) on every attempt. The loop treats that as "unknown, retry" until the 60s timeout, and kubelet
gives up first. The error is logged only at verbosity 6 (the chart runs at 4), so the plugin log
shows nothing after the persistenced line.

Checked on yojimbo with persistenced stopped: no process had `/dev/nvidia*` open (kepler and
the plugin itself only hold the plugin's lock file), and the prepare still timed out. Only the
missing `fuser` blocks it.

#1504 replaces `fuser` with a scan of `/proc/<pid>/fd` for character device `195:<minor>`. It
needs no host binary and also sees processes inside containers.

## Possible third blocker (not active today)

#1504 notes that holders inside the kernel are invisible to both checks. Example: the nvidia-drm fbdev
console (`nvidia_drm fbdev=1`); the unbind then fails with "non-zero usage count". On yojimbo,
`nvidia_drm.fbdev=Y` but `nvidia_drm.modeset=N` and there is no `/proc/fb`, so no console is
attached. Keep modeset off. If it is ever turned on (`nvidia-drm.modeset=1`), passthrough breaks this way.

## Ways forward

1. **Wait for a release** containing #1504 and #1568, then bump `version:` in
   `base/helm-release.yaml`. Nothing else changes.
2. **Patched image.** The PR author tested both PRs together, backported to v0.5.0, on Talos v1.14.0 + KubeVirt 1.9.0
   (RTX 3090 Ti): the card binds to `vfio-pci` and returns to `nvidia` when the VM stops. Build
   v0.5.1 with both cherry-picked, push to `harbor.yuriykovalchuk.dev/homelab` (amd64 via buildx),
   and set the chart's image in the overlay. With #1568 persistenced no longer needs stopping.
3. **Manual rebind + KubeVirt `permittedHostDevices`** (**in use since 2026-11-01**):
   `kubernetes/hypervisor/vms/ubuntu-test/gpu-mode.sh vfio|nvidia` does the switch the driver would do, at
   runtime, without the fuser check. Boot config unchanged; a reboot returns the card to `nvidia`.
   Not automatic: stop the VM / scale llama-cpp-cuda by hand. See `kubernetes/hypervisor/vms/ubuntu-test/README.md`.

## Re-test once fixed

```bash
kubectl -n llm scale deploy llama-cpp-cuda --replicas=0          # card must be free
virtctl start ubuntu-test -n kubevirt-ubuntu-test
kubectl -n kubevirt-ubuntu-test get vmi,resourceclaims           # Running, allocated,reserved
# guest: lspci -nn -d 10de:   → 10de:1b81, 10de:10f0
virtctl stop ubuntu-test -n kubevirt-ubuntu-test
TALOSCONFIG=~/.talos/config-prod talosctl -e 10.0.4.5 -n 10.0.4.13 ls /sys/bus/pci/drivers/nvidia   # 0000:01:00.0 is back
```

Then delete this file and the "blocked" note in `kubernetes/hypervisor/vms/ubuntu-test/README.md`.
