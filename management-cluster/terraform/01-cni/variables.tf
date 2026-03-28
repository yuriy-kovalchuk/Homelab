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

variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
}

variable "cilium_values_file" {
  description = "Path to Cilium Helm values YAML file"
  type        = string
  default     = "helm_values/values.yaml"
}
