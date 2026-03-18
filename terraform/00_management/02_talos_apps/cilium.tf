module "cilium" {
  source = "../../modules/cilium"

  cilium_version = var.cilium_version
  namespace      = "kube-system"

  values = [
    templatefile("${path.module}/helm_values/cilium/cilium-values.yaml.tftpl", {
      k8s_service_host = var.k8s_service_host
      k8s_service_port = var.k8s_service_port
    })
  ]
}
