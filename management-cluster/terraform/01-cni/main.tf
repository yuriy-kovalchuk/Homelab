module "cilium" {
  source = "../../../terraform/modules/cilium"

  cilium_version = var.cilium_version
  namespace      = "kube-system"

  values = [
    file(var.cilium_values_file)
  ]
}
