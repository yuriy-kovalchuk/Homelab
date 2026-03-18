output "metrics_server_status" {
  description = "Metrics Server deployment status"
  value       = helm_release.metrics_server.status
}


output "gateway_api_version" {
  description = "Installed Gateway API version"
  value       = var.gateway_api_version
}

output "harbor_registry_mirrors" {
  description = "Harbor registry mirror endpoints for secondary cluster configuration"
  value = {
    harbor_url = "https://${var.harbor_hostname}"
    mirrors = {
      "docker.io"          = "${var.harbor_hostname}/dockerhub"
      "ghcr.io"            = "${var.harbor_hostname}/ghcr"
      "gcr.io"             = "${var.harbor_hostname}/gcr"
      "registry.k8s.io"    = "${var.harbor_hostname}/k8s"
      "public.ecr.aws"     = "${var.harbor_hostname}/ecr-public"
      "mcr.microsoft.com"  = "${var.harbor_hostname}/mcr"
    }
  }
}
