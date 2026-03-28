variable "control_plane_nodes" {
  description = "List of control plane nodes with their network info"
  type = list(object({
    ip                = string
    hostname          = string
    interface         = string
    gateway           = string
    disk              = optional(string)
    wipe              = optional(bool)
    node_labels       = optional(map(string), {})
    extensions        = optional(list(string))
    extra_kernel_args = optional(list(string))
    gpu_passthrough = optional(object({
      enabled = bool
      pci_devices = list(object({
        pci_address   = string
        vendor_device = string
        resource_name = string
      }))
      kernel_args    = optional(list(string), [])
      kernel_modules = optional(list(string), ["vfio_pci", "vfio", "vfio_iommu_type1"])
    }))
  }))
}

variable "cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
}

variable "talos_version" {
  description = "Talos version to install"
  type        = string
  default     = "v1.12.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy (defaults to Talos bundled version)"
  type        = string
  default     = null
}

variable "cni_name" {
  description = "CNI plugin to deploy (use 'none' to manage CNI separately)"
  type        = string
  default     = "none"
}

variable "extensions" {
  description = "Default Talos image extensions to include when node-level overrides are not set"
  type        = list(string)
  default     = ["siderolabs/iscsi-tools", "siderolabs/util-linux-tools"]
}

variable "extra_kernel_args" {
  description = "Default extra kernel arguments when node-level overrides are not set"
  type        = list(string)
  default     = []
}

variable "image_registry" {
  description = "Registry prefix for the Talos installer image"
  type        = string
  default     = "factory.talos.dev/metal-installer"
}

variable "allow_scheduling_on_control_planes" {
  description = "Allow scheduling workloads on control plane nodes"
  type        = bool
  default     = true
}

variable "registry_mirrors" {
  description = "Map of registry hostnames to list of mirror endpoint URLs"
  type        = map(list(string))
  default     = {}
}
