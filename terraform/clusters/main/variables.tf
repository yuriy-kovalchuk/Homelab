variable "control_plane_nodes" {
  description = "List of control plane nodes with their network info"
  type = list(object({
    ip        = string
    hostname  = string
    interface = string
    disk      = optional(string) # only if you want custom disk
    wipe      = optional(bool)   # only if you want wipe
  }))
}


variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "talos-prd-cluster"
}

variable "gateway" {
  description = "Default gateway for control plane node"
  type        = string
}

variable "talos_version" {
  description = "Talos version for installation"
  type        = string
  default     = "v1.11.5"
}


variable "cni_name" {
  description = "CNI plugin to use"
  type        = string
  default     = "none"
}

variable "extensions" {
  description = "Talos image extensions to include"
  type        = list(string)
  default     = ["siderolabs/iscsi-tools", "siderolabs/util-linux-tools"]
}

variable "image_registry" {
  description = "Registry prefix for Talos installer image"
  type        = string
  default     = "factory.talos.dev/nocloud-installer"
}

variable "allow_scheduling_on_control_planes" {
  description = "Allow scheduling workloads on control plane nodes"
  type        = bool
  default     = true
}

# Harbor Registry Mirror Configuration
variable "registry_mirrors_enabled" {
  description = "Enable Harbor as upstream registry mirror for all image pulls"
  type        = bool
  default     = true
}

variable "harbor_hostname" {
  description = "Harbor registry hostname (e.g., harbor.example.com)"
  type        = string
  default     = "harbor.yuriy-lab.cloud"
}

variable "s3_access_key" {
  description = "Access key for S3/MinIO backend"
  type        = string
  sensitive   = true
}

variable "s3_secret_key" {
  description = "Secret key for S3/MinIO backend"
  type        = string
  sensitive   = true
}

variable "s3_endpoint" {
  description = "Endpoint for S3/MinIO backend"
  type        = string
  sensitive   = true
}

