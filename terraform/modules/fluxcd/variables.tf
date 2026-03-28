variable "fluxcd_version" {
  type        = string
  description = "Version of flux-operator Helm chart to install"
}

variable "namespace" {
  type        = string
  default     = "flux-system"
  description = "Namespace to install FluxCD into"
}

variable "values" {
  type        = list(string)
  default     = []
  description = "Additional Helm values to apply"
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether to create the namespace"
}
