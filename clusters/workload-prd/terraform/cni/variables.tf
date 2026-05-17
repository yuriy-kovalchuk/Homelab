variable "kubeconfig_path" {
  type = string
}

variable "cilium_version" {
  type = string
}

variable "cilium_values_file" {
  type    = string
  default = "helm_values/values.yaml"
}
