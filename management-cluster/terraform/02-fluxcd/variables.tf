variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the management cluster"
  type        = string
}

variable "s3_access_key" {
  type      = string
  sensitive = true
}

variable "s3_secret_key" {
  type      = string
  sensitive = true
}

variable "s3_endpoint" {
  type      = string
  sensitive = true
}

variable "fluxcd_version" {
  description = "Flux-operator Helm chart version"
  type        = string
}

variable "fluxcd_values_file" {
  description = "Path to FluxCD Helm values YAML file"
  type        = string
  default     = "helm_values/values.yaml"
}

variable "flux_distribution_version" {
  description = "Flux distribution version (semver range or exact)"
  type        = string
  default     = "2.x"
}

variable "flux_distribution_registry" {
  description = "Container registry for Flux distribution images"
  type        = string
  default     = "ghcr.io/fluxcd"
}

variable "flux_components" {
  description = "List of Flux components to install"
  type        = list(string)
  default = [
    "source-controller",
    "kustomize-controller",
    "helm-controller",
    "notification-controller",
    "image-reflector-controller",
    "image-automation-controller",
  ]
}

variable "flux_cluster_size" {
  description = "Cluster size for Flux scaling profile (small, medium, large)"
  type        = string
  default     = "medium"
}
