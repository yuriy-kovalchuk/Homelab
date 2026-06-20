variable "proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
  sensitive   = true
}

variable "proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node_name" {
  description = "Name of the Proxmox node"
  type        = string
  default     = "storage"
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

variable "vm_id" {
  description = "VM ID for the TrueNAS VM"
  type        = number
  default     = 1000
}

variable "vm_cores" {
  description = "Number of VM CPU cores"
  type        = number
  default     = 2
}

variable "vm_memory" {
  description = "VM memory in MB"
  type        = number
  default     = 8192
}

variable "vm_disk_size" {
  description = "VM boot disk size in GB"
  type        = number
  default     = 32
}

variable "pcie_controller" {
  description = "PCIe address of the storage controller to pass through (e.g. 0000:04:00.0)"
  type        = string
}

variable "acme_email" {
  description = "ACME email for the Let's Encrypt account"
  type        = string
  sensitive   = true
}

variable "acme_cf_account_id" {
  description = "Cloudflare account ID for DNS challenge"
  type        = string
  sensitive   = true
}

variable "acme_cf_token" {
  description = "Cloudflare API token for DNS challenge"
  type        = string
  sensitive   = true
}

variable "acme_domain" {
  description = "Domain for the Proxmox ACME certificate (e.g. storage.yuriy-lab.cloud)"
  type        = string
}
