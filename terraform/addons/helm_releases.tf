resource "helm_release" "cilium" {
  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium_version

  values = [
    file("${path.module}/helm_values/cilium/cilium-values.yaml")
  ]
}

resource "helm_release" "argo_cd" {
  name       = "argo-cd"
  namespace  = "argo-cd"
  create_namespace = true
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  values = [
    file("${path.module}/helm_values/argocd/argocd-values.yaml")
  ]

  wait = true
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_version

  set = [
    {
      name  = "args[0]"
      value = "--kubelet-insecure-tls"
    }
  ]

  wait = true
}

# TODO patch coredns forward