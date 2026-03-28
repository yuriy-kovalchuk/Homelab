module "fluxcd" {
  source = "../../../terraform/modules/fluxcd"

  fluxcd_version = var.fluxcd_version
  namespace      = "flux-system"

  values = [
    file(var.fluxcd_values_file)
  ]
}

resource "kubectl_manifest" "flux_instance" {
  depends_on = [module.fluxcd]

  yaml_body = yamlencode({
    apiVersion = "fluxcd.controlplane.io/v1"
    kind       = "FluxInstance"
    metadata = {
      name      = "flux"
      namespace = "flux-system"
      annotations = {
        "fluxcd.controlplane.io/reconcile"        = "enabled"
        "fluxcd.controlplane.io/reconcileEvery"   = "1h"
        "fluxcd.controlplane.io/reconcileTimeout" = "5m"
      }
    }
    spec = {
      distribution = {
        version  = var.flux_distribution_version
        registry = var.flux_distribution_registry
      }
      components = var.flux_components
      cluster = {
        type          = "kubernetes"
        size          = var.flux_cluster_size
        multitenant   = false
        networkPolicy = true
        domain        = "cluster.local"
      }
      kustomize = {
        patches = [
          {
            target = {
              kind = "Deployment"
            }
            patch = <<-EOT
              - op: replace
                path: /spec/template/spec/nodeSelector
                value:
                  kubernetes.io/os: linux
              - op: add
                path: /spec/template/spec/tolerations
                value:
                  - key: node-role.kubernetes.io/control-plane
                    operator: Exists
                    effect: NoSchedule
            EOT
          }
        ]
      }
    }
  })
}
