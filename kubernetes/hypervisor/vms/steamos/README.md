# steamos VM

SteamOS on KubeVirt in the `kubevirt-steamos` namespace, on bahamut, with the Radeon AI PRO
R9700 passed through. Played on a monitor plugged into the R9700 or streamed (Moonlight /
Steam Remote Play).

## Specs

- 6 vCPU (`host-passthrough`), 16 GiB RAM, UEFI (Secure Boot off)
- GPU: R9700 + its HDMI/DP audio (`amd.com/r9700`, `amd.com/r9700-audio`), only while the card
  is in vfio mode ([`gpu-passthrough/r9700`](../../gpu-passthrough/r9700/README.md))
- Game disk `steamos-disk`: 150 GiB, `longhorn-gpu` (one replica on bahamut's NVMe). bahamut's
  disk is nearly fully scheduled (strata 300, forgejo-runner-talos 200, sd-server 50, …): Longhorn
  could schedule ~168 GiB more before this volume.
- Installer `steamos-installer`: 16 GiB on `longhorn` (control planes), filled by upload, deleted
  after the install
- Network: pod network (KubeVirt `masquerade`), internet through Cilium
  (`kubernetes/network-policies/base/vms-steamos.yaml`). Streaming on the LoadBalancer IP
  `10.0.4.52` (`steamos-streaming`), from the trusted VLAN and Tailscale only.

Flux manages the definition (`vm-steamos` in `clusters/workload-prd/flux-system/vms.yaml`,
`prune: false`); `virtctl` starts and stops it (`runStrategy: Manual`).

The VM and the R9700 LLM workloads (strata, llama-cpp, llama-cpp-rocm) never run at the same
time: the card is exclusive, and strata's 52 GiB memory request leaves no room for the VM anyway.

## Start / stop

```bash
kubectl -n llm-strata scale deploy/strata --replicas=0      # whichever R9700 workload runs
kubernetes/hypervisor/gpu-passthrough/r9700/gpu-mode.sh vfio
virtctl start steamos -n kubevirt-steamos

virtctl stop steamos -n kubevirt-steamos
kubernetes/hypervisor/gpu-passthrough/r9700/gpu-mode.sh amdgpu
kubectl -n llm-strata scale deploy/strata --replicas=1
```

## Install (once)

1. **Get the image.** On Valve's [SteamOS "build your own" page](https://store.steampowered.com/steamos/buildyourown),
   download the image for PCs, not the Steam Deck recovery image. RDNA 4 needs SteamOS 3.8 or newer.
   Check it against Valve's published checksum, then unpack it (`bunzip2 -k` for `.bz2`, `unzip` for
   `.zip`). CDI imports raw, gz and xz, not bz2, which is why it is uploaded and not fetched.
2. **Upload it** into the `steamos-installer` DataVolume (Flux created it, waiting for an upload):

   ```bash
   kubectl -n cdi port-forward svc/cdi-uploadproxy 18443:443 &
   virtctl image-upload dv steamos-installer -n kubevirt-steamos --no-create \
     --image-path=steamos-*.img --uploadproxy-url=https://127.0.0.1:18443 --insecure
   kill %1
   ```

3. **Boot the installer.** Switch the card to vfio and start the VM (above). The game disk is empty,
   so the firmware boots the installer (`bootOrder` 2). Watch it on the R9700's monitor or with
   `virtctl vnc steamos -n kubevirt-steamos`, and install onto the 150 GiB virtio disk (the
   installer's "re-image" / install entry wipes the target disk; pick the 150 GiB one).
4. **Remove the installer.** Once SteamOS boots from its own disk: delete the `installer` disk
   and volume from `vm.yaml` and `installer-dv.yaml` from the kustomization, push, then
   `kubectl -n kubevirt-steamos delete dv steamos-installer` (Flux does not prune here).

If the VM boots the installer again (or the UEFI shell) after the install, the firmware lost the
boot entry SteamOS wrote: UEFI variables are not persisted between VM starts here. Fix it with
`efi.persistent: true` on the VM, which needs `vmStateStorageClass` in the KubeVirt CR.

## Display

SteamOS drives the R9700: the monitor on its outputs (DP-1 today) is the screen. QEMU's emulated
display is off (`autoattachGraphicsDevice: false`): it served the install over `virtctl vnc`, and
afterwards showed up in the guest as a second connected monitor (`Virtual-1`, `bochs-drm`) that Game
Mode and games could pick. `virtctl vnc` does not work any more; use the monitor, SSH or Sunshine.
To reinstall, turn it back on first: `vm.yaml` keeps the steps in a `REINSTALL` comment (drop
`autoattachGraphicsDevice: false`, uncomment the `tablet` input), and undo that afterwards.

## Input on bahamut

KubeVirt passes PCI devices, not single USB devices, so the VM gets a whole USB controller
(`amd.com/bahamut-xhci`), as on yojimbo. `gpu-mode.sh` moves it with the card. bahamut has four
xHCI controllers, each alone in its IOMMU group:

| PCI | ID | Note |
|---|---|---|
| `c7:00.3` | `1022:15b9` | **passed to the VM**: the 8BitDo receiver (`2dc8:301c`) and the MT7925's Bluetooth (`0e8d:7925`, unused by the host) |
| `c7:00.4` | `1022:15ba` | host |
| `c9:00.3` | `1022:15c0` | host |
| `c9:00.4` | `1022:15c1` | host |

Plug the controller's receiver (or a keyboard) into a port of `c7:00.3`: the one the 8BitDo
receiver is in. Anything plugged into that controller's other ports goes to the VM as well. To see
which bus a device lands on:

```bash
TALOSCONFIG=~/.talos/config-prod talosctl -e 10.0.4.5 -n 10.0.4.12 ls -l /sys/bus/usb/devices | grep -E ' [0-9]+-[0-9.]+ ->'
```

Bus 1 and 2 are `c7:00.3`, 3 and 4 `c7:00.4`, 5 and 6 `c9:00.3`, 7 and 8 `c9:00.4`.

## Streaming

- **Moonlight (recommended):** install Sunshine in SteamOS's Desktop Mode (Discover, Flatpak),
  pair from Moonlight with the PIN shown on `https://10.0.4.52:47990`, and add the host by IP
  (`10.0.4.52`). Works from the trusted VLAN and over Tailscale.
- **Steam Remote Play:** works through Valve's relay with no inbound access. Steam Link's LAN
  discovery is broadcast and does not reach `10.0.4.52`.

A drain or Talos upgrade of bahamut stops the VM hard (no live migration with a passthrough
device).
