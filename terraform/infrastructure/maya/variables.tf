variable "acme_email" {
  description = "ACME email used to create a default account"
  type        = string
  sensitive   = true
}

variable "acme_cf_account_id" {
  type      = string
  sensitive = true
}

variable "acme_cf_token" {
  type      = string
  sensitive = true
}

# Proxmox Node Configuration
variable "proxmox_node_name" {
  description = "Name of the Proxmox node"
  type        = string
  default     = "maya"
}

variable "proxmox_iso_datastore" {
  description = "Datastore for ISO files"
  type        = string
  default     = "local"
}

variable "proxmox_vm_datastore" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

# Talos VM Configuration
variable "talos_vm_name" {
  description = "Name of the Talos VM"
  type        = string
  default     = "management-talos-01"
}

variable "talos_vm_description" {
  description = "Description of the Talos VM"
  type        = string
  default     = "Talos Linux node managed by Terraform"
}

variable "talos_vm_id" {
  description = "VM ID for the Talos VM"
  type        = number
  default     = 1100
}

variable "talos_vm_cpu_cores" {
  description = "Number of CPU cores for the Talos VM"
  type        = number
  default     = 2
}

variable "talos_vm_memory" {
  description = "Memory in MB for the Talos VM"
  type        = number
  default     = 4096
}

variable "talos_vm_disk_size" {
  description = "Disk size in GB for the Talos VM"
  type        = number
  default     = 40
}

variable "talos_vm_mac_address" {
  description = "MAC address for the Talos VM network interface"
  type        = string
  default     = "BC:24:11:1A:26:95"
}

variable "talos_version" {
  description = "Talos Linux version for ISO download"
  type        = string
  default     = "1.12.1"
}

variable "talos_image_schematic_id" {
  description = "Talos image schematic ID from factory.talos.dev"
  type        = string
  default     = "70d243b7e2cbe699e4db5e73356a2add6b4bb8e34eadba9db22c823110e79099"
}
