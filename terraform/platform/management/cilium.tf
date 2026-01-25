# Cilium CNI installation via Helm
resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io/"
  chart            = "cilium"
  version          = var.cilium_version
  namespace        = "kube-system"
  create_namespace = false

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }

  set {
    name  = "securityContext.capabilities.ciliumAgent"
    value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
  }

  set {
    name  = "securityContext.capabilities.cleanCiliumState"
    value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
  }

  set {
    name  = "cgroup.autoMount.enabled"
    value = "false"
  }

  set {
    name  = "cgroup.hostRoot"
    value = "/sys/fs/cgroup"
  }

  set {
    name  = "k8sServiceHost"
    value = var.k8s_service_host
  }

  set {
    name  = "k8sServicePort"
    value = var.k8s_service_port
  }

  set {
    name  = "operator.replicas"
    value = "1"
  }

  # Gateway API
  set {
    name  = "gatewayAPI.enabled"
    value = "true"
  }

  set {
    name  = "gatewayAPI.enabledAlpn"
    value = "true"
  }

  set {
    name  = "gatewayAPI.enabledAppProtocol"
    value = "true"
  }

  # BPF
  set {
    name  = "bpf.masquerade"
    value = "true"
  }

  # BGP Control Plane
  set {
    name  = "bgpControlPlane.enabled"
    value = "true"
  }

  set {
    name  = "externalIPs.enabled"
    value = "true"
  }

  # Hubble Observability
  set {
    name  = "hubble.enabled"
    value = "true"
  }

  set {
    name  = "hubble.relay.enabled"
    value = "true"
  }

  set {
    name  = "hubble.ui.enabled"
    value = "true"
  }
}
