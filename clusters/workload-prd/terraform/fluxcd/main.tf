module "fluxcd" {
  source = "../../../modules/fluxcd"

  fluxcd_version             = var.fluxcd_version
  namespace                  = "flux-system"
  flux_distribution_version  = var.flux_distribution_version
  flux_distribution_registry = var.flux_distribution_registry
  flux_components            = var.flux_components
  flux_cluster_size          = var.flux_cluster_size

  values = [
    file(var.fluxcd_values_file)
  ]
}
