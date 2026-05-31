resource "helm_release" "fluxcd" {
  name             = "flux-operator"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart            = "flux-operator"
  version          = var.fluxcd_version
  namespace        = var.namespace
  create_namespace = var.create_namespace

  values = var.values
}
