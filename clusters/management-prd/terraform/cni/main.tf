module "cni" {
  source = "../../../modules/cni"

  cilium_version = var.cilium_version
  namespace      = "kube-system"

  values = [
    file(var.cilium_values_file)
  ]
}
