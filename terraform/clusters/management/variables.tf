# Talos Cluster Configuration
variable "talos_cluster_name" {
  description = "Name of the Talos cluster"
  type        = string
  default     = "management-talos"
}

variable "talos_cluster_endpoint_ip" {
  description = "IP address of the Talos cluster endpoint"
  type        = string
  default     = "10.0.2.10"
}

variable "talos_cluster_endpoint_port" {
  description = "Port for the Talos cluster endpoint"
  type        = number
  default     = 6443
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
  default     = "1.12.1"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the Talos cluster"
  type        = string
  default     = "1.34.0"
}

variable "talos_image_schematic_id" {
  description = "Talos image schematic ID from factory.talos.dev"
  type        = string
  default     = "70d243b7e2cbe699e4db5e73356a2add6b4bb8e34eadba9db22c823110e79099"
}

# Talos Machine Config Patch Variables
variable "talos_install_disk" {
  description = "Disk device path for Talos installation"
  type        = string
  default     = "/dev/sda"
}

variable "talos_install_image" {
  description = "Talos install image (set to use factory image with schematic)"
  type        = string
  default     = ""
}

variable "talos_dns" {
  description = "DNS server for the Talos node"
  type        = string
  default     = "10.0.2.254"
}

variable "talos_ip_cidr" {
  description = "CIDR suffix for node IP address (e.g., /24)"
  type        = string
  default     = "/24"
}

variable "talos_network" {
  description = "Network CIDR for routing (e.g., 0.0.0.0/0 for default route)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "talos_network_gateway" {
  description = "Network gateway IP address"
  type        = string
  default     = "10.0.2.254"
}

variable "talos_network_interface" {
  description = "Network interface name for the Talos node (typically ens18 on Proxmox)"
  type        = string
  default     = "ens18"
}

# Cluster Configuration
variable "talos_allow_scheduling_on_control_planes" {
  description = "Allow scheduling workloads on control plane nodes"
  type        = bool
  default     = true
}
