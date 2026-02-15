variable "control_plane_nodes" {
  description = "List of control plane nodes with their network info"
  type = list(object({
    ip        = string
    hostname  = string
    interface = string
    disk      = optional(string)       # only if you want custom disk
    wipe      = optional(bool)         # only if you want wipe
    extensions = optional(list(string)) # node-specific extensions (overrides default)
    extra_kernel_args = optional(list(string)) # node-specific kernel args
    gpu_passthrough = optional(object({
      enabled     = bool
      pci_devices = list(object({
        pci_address   = string           # e.g., "0000:c4:00.0"
        vendor_device = string           # e.g., "1002:1900"
        resource_name = string           # e.g., "amd.com/780m"
      }))
      node_labels = optional(map(string)) # additional labels for GPU scheduling
    }))
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
  default     = "v1.12.2"
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

variable "extra_kernel_args" {
  description = "Extra kernel arguments to embed in the Talos image"
  type        = list(string)
  default     = []
}

variable "image_registry" {
  description = "Registry prefix for Talos installer image"
  type        = string
  default     = "factory.talos.dev/metal-installer"
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

