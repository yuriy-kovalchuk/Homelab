variable "cilium_version" {
  type        = string
  description = "Version of Cilium to install"
}

variable "namespace" {
  type        = string
  default     = "kube-system"
  description = "Namespace to install Cilium into"
}

variable "values" {
  type        = list(string)
  default     = []
  description = "Additional Helm values to apply"
}

variable "create_namespace" {
  type        = bool
  default     = false
  description = "Whether to create the namespace"
}
