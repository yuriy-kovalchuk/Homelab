#!/usr/bin/env bash
# Switch bahamut's Radeon AI PRO R9700 between containers and KubeVirt VMs, at
# runtime, without touching the Talos config or rebooting.
#
#   gpu-mode.sh vfio     card + HDMI audio -> vfio-pci (KubeVirt amd.com/r9700,
#                        amd.com/r9700-audio, see hypervisor/kubevirt/base/cr.yaml)
#   gpu-mode.sh amdgpu   card -> amdgpu (DRA gpu.amd.com: strata, llama-cpp,
#                        llama-cpp-rocm), audio -> unbound (its boot state)
#   gpu-mode.sh status   which driver holds each function, who claims the card
#
# Boot default is amdgpu and bahamut does not load vfio-pci by itself, so a
# reboot also returns the card to containers. Running a mode twice is safe:
# a rebind is skipped when the function is already where it belongs.
#
# Only the R9700 moves. The 780M (c7:00.0, sd-server) stays on amdgpu. The two
# PCIe switch ports above the card (01:00.0, 02:00.0, AMD 1478/1479) stay on
# pcieport. Card and audio are alone in their IOMMU groups (16, 17).
#
# The rebind runs in a short-lived privileged pod on bahamut in kube-amd-gpu
# (privileged Pod Security level and a PolicyException that already covers
# host PID, hostPath and privileged for the DRA kubelet plugin). Afterwards
# virt-handler and the AMD DRA kubelet plugin on bahamut are restarted so they
# re-scan the card.
set -euo pipefail

CTX="${KUBE_CONTEXT:-admin@workload-prd}"
NODE=bahamut
POD_NS=kube-amd-gpu
GPU=0000:03:00.0      # 1002:7551 Navi 48
AUDIO=0000:03:00.1    # 1002:ab40 HDMI/DP audio, no host driver at boot
DEVICE_ID=0x7551      # DRA attribute deviceID (sysfs PCI device ID)
RES=amd.com/r9700     # KubeVirt resource names (permittedHostDevices)
RES_AUDIO=amd.com/r9700-audio
POD="gpu-mode-$$"
k() { kubectl --context "$CTX" "$@"; }

mode="${1:-}"
case "$mode" in vfio|amdgpu|status) ;; *) echo "usage: $0 vfio|amdgpu|status" >&2; exit 2 ;; esac

# DRA claims allocated to the R9700 (any namespace). The device name in the
# ResourceSlice (gpu-<n>-<render minor>) changes after a rebind, so it is looked
# up by deviceID each time.
r9700_device() {
  k get resourceslices -o json | jq -r --arg node "$NODE" --arg id "$DEVICE_ID" '.items[]
    | select(.spec.driver == "gpu.amd.com" and .spec.nodeName == $node)
    | .spec.devices[] | select(.attributes.deviceID.string == $id) | .name' | head -1
}
r9700_claims() {
  local dev; dev=$(r9700_device)
  [ -n "$dev" ] || return 0
  k get resourceclaims -A -o json | jq -r --arg node "$NODE" --arg dev "$dev" '.items[]
    | select(any(.status.allocation.devices.results[]?;
        .driver == "gpu.amd.com" and .pool == $node and .device == $dev))
    | .metadata.namespace + "/" + .metadata.name'
}
# Pods on bahamut that request the passthrough card (virt-launchers, running or
# still terminating: QEMU holds the card until the pod is gone).
vm_pods() {
  k get pods -A --field-selector spec.nodeName=$NODE -o json | jq -r --arg r "$RES" '.items[]
    | select(any(.spec.containers[]; (.resources.limits // {}) | has($r)))
    | .metadata.namespace + "/" + .metadata.name'
}

if [ "$mode" = vfio ]; then
  claims=$(r9700_claims)
  if [ -n "$claims" ]; then
    echo "R9700 still claimed through DRA: $(echo $claims)" >&2
    echo "scale its owners to 0 first, e.g. kubectl -n llm-strata scale deploy/strata --replicas=0" >&2
    echo "(the R9700 Deployments: llm-strata/strata, llm/llama-cpp, llm/llama-cpp-rocm)" >&2
    exit 1
  fi
fi
if [ "$mode" = amdgpu ]; then
  # A VMI can be gone while its virt-launcher is still terminating; wait it out.
  for _ in $(seq 1 30); do
    holders=$(vm_pods)
    [ -z "$holders" ] && break
    sleep 2
  done
  [ -z "$holders" ] || { echo "VM pods still hold the R9700: $(echo $holders); stop the VMs first (virtctl stop)" >&2; exit 1; }
fi

# Runs inside the pod (host PID namespace, so /proc lists the node's processes;
# in a privileged container /sys is the node's sysfs).
inner_script() {
cat <<EOF
set -eu
drv() { # current driver of a PCI function, 'none' when unbound
  link=\$(readlink /sys/bus/pci/devices/\$1/driver 2>/dev/null) || { echo none; return; }
  basename "\$link"
}
show() { echo "$GPU: \$(drv $GPU)   $AUDIO: \$(drv $AUDIO)"; }
# Processes on the node holding this card's DRM nodes (card*/renderD*). /dev/kfd
# is shared with the 780M, so it can't tell the two apart and is not checked.
holders() {
  nodes=\$(ls /sys/bus/pci/devices/$GPU/drm 2>/dev/null | grep -E '^(card|renderD)[0-9]+\$' || true)
  [ -n "\$nodes" ] || return 0
  for fd in /proc/[0-9]*/fd/*; do
    t=\$(readlink "\$fd" 2>/dev/null) || continue
    for n in \$nodes; do
      if [ "\$t" = "/dev/dri/\$n" ]; then
        pid=\${fd#/proc/}; pid=\${pid%%/*}
        echo "pid \$pid (\$(cat /proc/\$pid/comm 2>/dev/null)) has /dev/dri/\$n open"
      fi
    done
  done | sort -u
}
rebind() { # \$1 device, \$2 target driver ('' = none), \$3 timeout for the bind
  dev=/sys/bus/pci/devices/\$1
  cur=\$(drv \$1)
  [ "\$cur" = "\${2:-none}" ] && return 0
  if [ "\$cur" != none ]; then
    timeout 60 sh -c "echo \$1 > \$dev/driver/unbind" || { echo "unbind of \$1 from \$cur timed out: something holds the card" >&2; exit 1; }
  fi
  if [ -n "\$2" ]; then
    echo "\$2" > \$dev/driver_override
    timeout "\${3:-30}" sh -c "echo \$1 > /sys/bus/pci/drivers/\$2/bind" || { echo "bind of \$1 to \$2 failed (dmesg on bahamut has the reason)" >&2; exit 1; }
  else
    echo > \$dev/driver_override
  fi
}
case "$mode" in
  status)
    show
    h=\$(holders); [ -z "\$h" ] || echo "\$h" ;;
  vfio)
    # bahamut boots without vfio-pci loaded (yojimbo's comes from the NVIDIA DRA
    # plugin). Signed module from the node's own /lib/modules.
    if [ ! -d /sys/bus/pci/drivers/vfio-pci ]; then
      modprobe vfio-pci || { echo "modprobe vfio-pci failed; add machine.kernel.modules [vfio_pci] to bahamut's Talos config" >&2; exit 1; }
    fi
    h=\$(holders)
    if [ -n "\$h" ]; then echo "the R9700 is still in use on the node:" >&2; echo "\$h" >&2; exit 1; fi
    rebind $GPU vfio-pci
    rebind $AUDIO vfio-pci
    show ;;
  amdgpu)
    # amdgpu re-initializes the card (firmware, VRAM training): give the bind time.
    rebind $GPU amdgpu 120
    # Back to the boot state: no driver (the Talos kernel has no snd_hda_intel).
    rebind $AUDIO ''
    ls /sys/bus/pci/devices/$GPU/drm >/dev/null 2>&1 || { echo "amdgpu bound but registered no DRM device; check dmesg, a reboot of bahamut resets the card" >&2; exit 1; }
    show ;;
esac
EOF
}
script=$(inner_script)
kver=$(k get node "$NODE" -o jsonpath='{.status.nodeInfo.kernelVersion}')

SCRIPT="$script" jq -n --arg node "$NODE" --arg pod "$POD" --arg ns "$POD_NS" --arg kver "$kver" '{
  apiVersion: "v1", kind: "Pod",
  metadata: {name: $pod, namespace: $ns, labels: {app: "gpu-mode"}},
  spec: {
    nodeName: $node, restartPolicy: "Never", hostPID: true,
    tolerations: [{key: "workload", operator: "Equal", value: "gpu", effect: "NoSchedule"}],
    containers: [{name: "gpu-mode", image: "docker.io/library/busybox:1.37.0",
      command: ["sh", "-c", env.SCRIPT],
      securityContext: {privileged: true},
      volumeMounts: [{name: "modules", mountPath: ("/lib/modules/" + $kver), readOnly: true}]}],
    volumes: [{name: "modules", hostPath: {path: ("/lib/modules/" + $kver), type: "Directory"}}]
  }}' | k apply -f - >/dev/null

trap 'k -n "$POD_NS" delete pod "$POD" --ignore-not-found --wait=false >/dev/null' EXIT
phase=Pending
for _ in $(seq 1 90); do
  phase=$(k -n "$POD_NS" get pod "$POD" -o jsonpath='{.status.phase}')
  case "$phase" in Succeeded|Failed) break ;; esac
  sleep 2
done
k -n "$POD_NS" logs "$POD"
if [ "$mode" = status ]; then
  claims=$(r9700_claims); vms=$(vm_pods)
  echo "DRA claims on the R9700: ${claims:-none}"
  echo "VM pods with $RES:       ${vms:-none}"
  exit 0
fi
[ "$phase" = Succeeded ] || { echo "rebind pod ended $phase" >&2; exit 1; }

# Let the device plugins re-scan the card.
k -n kubevirt delete pod -l kubevirt.io=virt-handler --field-selector spec.nodeName=$NODE --wait=false >/dev/null
k -n "$POD_NS" delete pod -l app.kubernetes.io/name=k8s-gpu-dra-driver,app.kubernetes.io/component=kubeletplugin \
  --field-selector spec.nodeName=$NODE --wait=false >/dev/null
k -n kubevirt rollout status ds/virt-handler --timeout=180s >/dev/null
k -n "$POD_NS" rollout status ds/gpu-dra-driver-k8s-gpu-dra-driver-kubeletplugin --timeout=180s >/dev/null

offers() { k get node $NODE -o json | jq -c '.status.allocatable | with_entries(select(.key | test("r9700")))'; }
# Wait for the state the mode should produce instead of a fixed sleep.
ready=no
for _ in $(seq 1 45); do
  case "$mode" in
    vfio)   offers | jq -e --arg a "$RES" --arg b "$RES_AUDIO" '.[$a] == "1" and .[$b] == "1"' >/dev/null && ready=yes ;;
    amdgpu) [ -n "$(r9700_device)" ] && ready=yes ;;
  esac
  [ "$ready" = yes ] && break
  sleep 2
done
echo "bahamut offers:   $(offers)"
echo "DRA R9700 device: $(r9700_device)"
[ "$ready" = yes ] || { echo "devices not advertised as expected after 90s" >&2; exit 1; }
