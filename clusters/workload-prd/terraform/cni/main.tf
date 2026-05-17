module "cni" {
  source = "../../../modules/cni"

  cilium_version     = var.cilium_version
  namespace          = "kube-system"
  cilium_values_file = var.cilium_values_file

  values = [
    file(var.cilium_values_file)
  ]
}
