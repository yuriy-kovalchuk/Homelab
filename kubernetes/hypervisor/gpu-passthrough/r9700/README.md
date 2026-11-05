# R9700 passthrough to KubeVirt VMs (bahamut)

bahamut's Radeon AI PRO R9700 belongs either to containers (DRA `gpu.amd.com`: strata,
llama-cpp, llama-cpp-rocm) or to one KubeVirt VM, switched at runtime with
[`gpu-mode.sh`](gpu-mode.sh). Same approach as the GTX 1070 on yojimbo
([`vms/ubuntu-test`](../../vms/ubuntu-test/README.md)). bahamut boots with the card on
`amdgpu`; its Omni patch only loads `vfio_pci` and `vfio_iommu_type1` (`machine.kernel.modules`,
same as yojimbo), which binds nothing, so a reboot gives the card back to containers. No kernel
arguments are needed: the AMD IOMMU is on by default (yojimbo's `intel_iommu=on` is Intel-only).

| Function | PCI | ID | IOMMU group | Boot driver | VM resource |
|---|---|---|---|---|---|
| GPU (Navi 48, gfx1201) | `0000:03:00.0` | `1002:7551` | 16 | `amdgpu` | `amd.com/r9700` |
| HDMI/DP audio | `0000:03:00.1` | `1002:ab40` | 17 | none | `amd.com/r9700-audio` |
| USB controller (8BitDo receiver, MT7925 Bluetooth) | `0000:c7:00.3` | `1022:15b9` | 24 | `xhci_hcd` | `amd.com/bahamut-xhci` |
| USB controller (hub with Razer keyboard and mouse) | `0000:c9:00.3` | `1022:15c0` | 29 | `xhci_hcd` | `amd.com/bahamut-xhci-input` |
| MT7925 Wi-Fi (SteamOS setup needs Wi-Fi) | `0000:05:00.0` | `14c3:7925` | 19 | none | `mediatek.com/bahamut-wifi` |

The PCIe switch ports above the card (`01:00.0`, `02:00.0`, `1002:1478/1479`) stay on
`pcieport`, and the 780M (`c7:00.0`, sd-server) is not touched.

| Mode | Driver | Offered as | Used by |
|---|---|---|---|
| `amdgpu` (boot default) | `amdgpu` | DRA `gpu.amd.com`, deviceID `0x7551` | strata, llama-cpp, llama-cpp-rocm |
| `vfio` | `vfio-pci` | KubeVirt `amd.com/r9700` + `amd.com/r9700-audio` + `amd.com/bahamut-xhci` (`permittedHostDevices` in `hypervisor/kubevirt/base/cr.yaml`) | one VM at a time |

```bash
# to a VM
kubectl -n llm-strata scale deploy/strata --replicas=0       # whichever R9700 workload runs
kubernetes/hypervisor/gpu-passthrough/r9700/gpu-mode.sh vfio  # refuses while a DRA claim or process holds the card
virtctl start <vm> -n <namespace>

# back to containers
virtctl stop <vm> -n <namespace>
kubernetes/hypervisor/gpu-passthrough/r9700/gpu-mode.sh amdgpu  # refuses while a VM pod requests amd.com/r9700
kubectl -n llm-strata scale deploy/strata --replicas=1

kubernetes/hypervisor/gpu-passthrough/r9700/gpu-mode.sh status  # drivers, DRA claims, VM pods, open DRM nodes
```

What the script does, from a short-lived privileged busybox pod on bahamut in `kube-amd-gpu`
(its Pod Security level and PolicyException already allow privileged, host PID and hostPath):

- **vfio:** checks that no DRA claim is allocated on the R9700 and no process on the node has
  its `card*`/`renderD*` open, loads `vfio-pci` if the Omni patch did not (signed
  module from the node's `/lib/modules`), unbinds the card from `amdgpu`, sets `driver_override` and binds both
  functions to `vfio-pci`.
- **amdgpu:** waits for VM pods requesting `amd.com/r9700` to be gone (QEMU holds the card until
  then), binds the card back to `amdgpu` (up to 120 s: it re-initializes the card) and leaves the
  audio function unbound, as at boot.
- Both: restarts virt-handler and the AMD DRA kubelet plugin on bahamut, then waits until the card
  is offered as the mode expects. The DRA device name (`gpu-<n>-<render minor>`) can change after
  a round trip; the ResourceClaimTemplates select by `deviceID`, so nothing else changes.

Starting a VM while the card is in `amdgpu` mode leaves it Pending (`Insufficient
amd.com/r9700`). That is harmless; switch modes and it schedules.

## A VM on bahamut

The SteamOS VM ([`vms/steamos`](../../vms/steamos/README.md)) is the worked example.

KubeVirt already runs on bahamut (virt-handler is on both workers). A VM needs the node, the
taint toleration and the two devices. Use `longhorn-gpu` for its disk (one replica, strict-local
on bahamut's `gpu` disk). The 32 GiB BAR needs UEFI: SeaBIOS can't map it.

```yaml
spec:
  template:
    spec:
      nodeSelector:
        kubernetes.io/hostname: bahamut
      tolerations:
        - key: workload
          operator: Equal
          value: gpu
          effect: NoSchedule
      domain:
        firmware:
          bootloader:
            efi:
              secureBoot: false
        devices:
          gpus:
            - name: r9700
              deviceName: amd.com/r9700
          hostDevices:
            - name: r9700-audio
              deviceName: amd.com/r9700-audio
```

In the guest, `lspci -nn -d 1002:` shows `1002:7551` and `1002:ab40`; a Linux guest needs a
kernel with gfx1201 support (6.14 or newer, or the ROCm/amdgpu-dkms packages).

Keep the PCI slot note from `vms/ubuntu-test/vm.yaml` in mind: KubeVirt places `gpus` and
`hostDevices` in list order, so adding a device later moves the others.

## Caveats (not tried yet)

- **Round trip back to `amdgpu`.** `vfio-pci` resets the card with FLR (`reset_method`: `flr
  bus`) when the VM releases it, which RDNA4 is expected to survive. If `gpu-mode.sh amdgpu`
  reports a failed bind or no DRM device, reboot bahamut: that always restores `amdgpu`.
- **A drain or Talos upgrade of bahamut stops the VM hard** (no live migration with a passthrough
  device).
- **Large BAR.** bahamut runs Resizable BAR, so BAR0 is the full 32 GiB. If OVMF can't place it
  (the guest sees the card with no memory, or `amdgpu` fails with a BAR error), the BAR can be
  shrunk while the card is unbound (`resource0_resize`). The script does not do that today.
- **Local display and input.** The monitor follows the card's outputs while the VM holds it.
  The USB controller `c7:00.3` goes to the VM with the card, like yojimbo's xHCI: whatever is
  plugged into its ports (the 8BitDo receiver) and the MT7925's Bluetooth.
