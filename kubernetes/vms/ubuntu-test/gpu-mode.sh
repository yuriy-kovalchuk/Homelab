#!/usr/bin/env bash
# Switch yojimbo's GTX 1070 between containers and the ubuntu-test VM, at
# runtime, without touching the Talos config or rebooting.
#
#   gpu-mode.sh vfio     card + HDMI audio + USB controller -> vfio-pci (KubeVirt
#                        nvidia.com/gtx1070, nvidia.com/gtx1070-audio, intel.com/xhci)
#   gpu-mode.sh nvidia   card -> nvidia (DRA gpu.nvidia.com, llama-cpp-cuda) and the
#                        USB controller -> xhci_pci (keyboard/mouse back to the node)
#   gpu-mode.sh status   show which driver holds each device
#
# Boot default stays nvidia + xhci_pci (yojimbo's Omni patch is unchanged), so a
# reboot also returns everything to the node.
#
# Why not the DRA vfio claim: driver 0.5.1 can't prepare it on Talos, see
# kubernetes/platform/infra/nvidia-dra-driver/VFIO-TALOS-ISSUES.md. This script
# does the same rebind the driver would, minus its fuser check.
#
# Talos runs nvidia-persistenced (ext-nvidia-persistenced), which holds
# /dev/nvidia0 open and makes the unbind from nvidia hang, so the script stops
# that service on the way to vfio and starts it again on the way back.
#
# The rebind runs in a short-lived privileged pod on yojimbo in
# nvidia-dra-driver (privileged Pod Security level and a PolicyException for
# the driver's own mounts). Afterwards virt-handler and the DRA kubelet plugin
# on yojimbo are restarted so they re-scan the card.
set -euo pipefail

CTX="${KUBE_CONTEXT:-admin@workload-prd}"
NODE=yojimbo
# yojimbo's Talos API: endpoint is a control plane, not the VIP (see CLAUDE.md).
TALOS_EP="${TALOS_ENDPOINT:-10.0.4.5}"
TALOS_NODE="${TALOS_NODE_IP:-10.0.4.13}"
export TALOSCONFIG="${TALOSCONFIG:-$HOME/.talos/config-prod}"
NS=kubevirt-ubuntu-test
# privileged PSA + a Kyverno exception for privileged/hostPath, like the plugin
POD_NS=nvidia-dra-driver
GPU=0000:01:00.0
AUDIO=0000:01:00.1
# The PCH xHCI (8086:a12f), alone in IOMMU group 3: everything in the case's USB
# ports, so the VM gets the keyboard and mouse plugged into yojimbo itself.
USB=0000:00:14.0
POD="gpu-mode-$$"
k() { kubectl --context "$CTX" "$@"; }

mode="${1:-}"
case "$mode" in vfio|nvidia|status) ;; *) echo "usage: $0 vfio|nvidia|status" >&2; exit 2 ;; esac

nvidia_claims() {
  k get resourceclaims -A -o json | jq -r '.items[]
    | select([.status.allocation.devices.results[]?.driver] | index("gpu.nvidia.com"))
    | .metadata.namespace + "/" + .metadata.name'
}

if [ "$mode" = vfio ]; then
  replicas=$(k -n llm get deploy llama-cpp-cuda -o jsonpath='{.spec.replicas}')
  [ "$replicas" = 0 ] || { echo "llama-cpp-cuda has $replicas replica(s); scale it to 0 first" >&2; exit 1; }
  claims=$(nvidia_claims)
  [ -z "$claims" ] || { echo "GPU still claimed: $claims" >&2; exit 1; }
  talosctl -e "$TALOS_EP" -n "$TALOS_NODE" service ext-nvidia-persistenced stop
fi
if [ "$mode" = nvidia ] && k -n "$NS" get vmi ubuntu-test >/dev/null 2>&1; then
  echo "ubuntu-test is running; stop it first: virtctl stop ubuntu-test -n $NS" >&2; exit 1
fi

# Runs inside the pod. In a privileged container /sys is the node's sysfs, so the
# rebind is plain sysfs writes.
inner_script() {
cat <<EOF
set -eu
drv() { # current driver of a PCI function, 'none' when unbound
  link=\$(readlink /sys/bus/pci/devices/\$1/driver 2>/dev/null) || { echo none; return; }
  basename "\$link"
}
show() { echo "$GPU: \$(drv $GPU)   $AUDIO: \$(drv $AUDIO)   $USB: \$(drv $USB)"; }
rebind() { # \$1 device, \$2 target driver ('' = none)
  dev=/sys/bus/pci/devices/\$1
  cur=\$(drv \$1)
  [ "\$cur" = "\${2:-none}" ] && return 0
  if [ "\$cur" != none ]; then
    timeout 30 sh -c "echo \$1 > \$dev/driver/unbind" || { echo "unbind of \$1 from \$cur timed out: something holds the card" >&2; exit 1; }
  fi
  if [ -n "\$2" ]; then
    echo "\$2" > \$dev/driver_override
    echo \$1 > /sys/bus/pci/drivers/\$2/bind
  else
    echo > \$dev/driver_override
  fi
}
case "$mode" in
  status) show ;;
  vfio)
    rebind $GPU vfio-pci
    rebind $AUDIO vfio-pci
    rebind $USB vfio-pci
    show ;;
  nvidia)
    rebind $AUDIO ''
    rebind $GPU ''
    echo > /sys/bus/pci/devices/$GPU/driver_override
    echo $GPU > /sys/bus/pci/drivers/nvidia/bind
    # No explicit bind: clear the override and let xhci_pci re-claim it by ID.
    rebind $USB ''
    echo $USB > /sys/bus/pci/drivers_probe
    show ;;
esac
EOF
}
script=$(inner_script)

SCRIPT="$script" jq -n --arg node "$NODE" --arg pod "$POD" --arg ns "$POD_NS" '{
  apiVersion: "v1", kind: "Pod",
  metadata: {name: $pod, namespace: $ns, labels: {app: "gpu-mode"}},
  spec: {
    nodeName: $node, restartPolicy: "Never",
    tolerations: [{key: "workload", operator: "Equal", value: "gpu", effect: "NoSchedule"}],
    containers: [{name: "gpu-mode", image: "docker.io/library/busybox:1.37.0",
      command: ["sh", "-c", env.SCRIPT],
      securityContext: {privileged: true}}],
  }}' | k apply -f - >/dev/null

trap 'k -n "$POD_NS" delete pod "$POD" --ignore-not-found --wait=false >/dev/null' EXIT
for _ in $(seq 1 60); do
  phase=$(k -n "$POD_NS" get pod "$POD" -o jsonpath='{.status.phase}')
  case "$phase" in Succeeded|Failed) break ;; esac
  sleep 2
done
k -n "$POD_NS" logs "$POD"
[ "$phase" = Succeeded ] || { echo "rebind pod ended $phase" >&2; exit 1; }
[ "$mode" = status ] && exit 0

# Let the device plugins re-scan the card.
k -n kubevirt delete pod -l kubevirt.io=virt-handler --field-selector spec.nodeName=$NODE --wait=false >/dev/null
k -n nvidia-dra-driver delete pod -l app.kubernetes.io/name=dra-driver-nvidia-gpu --field-selector spec.nodeName=$NODE --wait=false >/dev/null
k -n kubevirt rollout status ds/virt-handler --timeout=180s >/dev/null
k -n nvidia-dra-driver rollout status ds/dra-driver-nvidia-gpu-kubelet-plugin --timeout=180s >/dev/null
if [ "$mode" = nvidia ]; then
  talosctl -e "$TALOS_EP" -n "$TALOS_NODE" service ext-nvidia-persistenced start
fi
sleep 10
echo "yojimbo offers: $(k get node $NODE -o json | jq -c '.status.allocatable | with_entries(select(.key | test("gtx1070")))')"
echo "DRA devices:    $(k get resourceslices -o json | jq -c '[.items[] | select(.spec.driver=="gpu.nvidia.com" and .spec.nodeName=="'$NODE'") | .spec.devices[].name]')"
