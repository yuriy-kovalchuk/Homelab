provider "helm" {
  kubernetes = {
    config_path = "talos-kubeconfig"
  }
}

provider "kubernetes" {
  config_path = "talos-kubeconfig"
}


resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.4"

  values = [
    file("${path.module}/values/cilium-values.yaml")
  ]
}

resource "kubernetes_manifest" "cilium_l2_policy" {
  depends_on = [helm_release.cilium]
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumL2AnnouncementPolicy"
    metadata = {
      name      = "default-l2-announcement-policy"
    }
    spec = {
      externalIPs     = true
      loadBalancerIPs = true
    }
  }
}

resource "kubernetes_manifest" "cilium_lb_pool" {
  depends_on = [helm_release.cilium]
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "services-ip-pool"
    }
    spec = {
      blocks = [
        {
          start = "10.0.8.50"
          stop  = "10.0.8.200"
        }
      ]
    }
  }
}

resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  namespace  = "argo-cd"
  create_namespace = true
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.1.3"
  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

  wait = true
}



resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.13.0"

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]
}

# TODO patch coredns forward