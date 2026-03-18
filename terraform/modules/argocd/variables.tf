variable "argocd_version" {
  type        = string
  description = "Version of Argo CD to install"
}

variable "namespace" {
  type        = string
  default     = "argo-cd"
  description = "Namespace to install Argo CD into"
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
