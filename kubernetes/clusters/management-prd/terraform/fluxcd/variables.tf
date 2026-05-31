variable "kubeconfig_path" {
  type = string
}

variable "fluxcd_version" {
  type = string
}

variable "fluxcd_values_file" {
  type    = string
  default = "helm_values/values.yaml"
}

variable "flux_distribution_version" {
  type    = string
  default = "2.x"
}

variable "flux_distribution_registry" {
  type    = string
  default = "ghcr.io/fluxcd"
}

variable "flux_components" {
  type = list(string)
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
  type    = string
  default = "medium"
}
