# Proxmox connection
variable "storage_proxmox_endpoint" {
  description = "Proxmox API endpoint URL"
  type        = string
  sensitive   = true
}

variable "storage_proxmox_username" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "storage_proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

# Proxmox node
variable "storage_proxmox_node_name" {
  description = "Name of the Proxmox node"
  type        = string
  default     = "storage"
}

variable "storage_proxmox_iso_datastore" {
  description = "Datastore for ISO files"
  type        = string
  default     = "local"
}

variable "storage_proxmox_vm_datastore" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "storage_proxmox_network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr0"
}

# VM
variable "storage_vm_id" {
  description = "VM ID for the TrueNAS VM"
  type        = number
  default     = 1000
}

variable "storage_vm_cores" {
  description = "Number of VM CPU cores"
  type        = number
  default     = 2
}

variable "storage_vm_memory" {
  description = "VM memory in MB"
  type        = number
  default     = 8192
}

variable "storage_vm_disk_size" {
  description = "VM boot disk size in GB"
  type        = number
  default     = 32
}

# PCIe passthrough
variable "storage_pcie_controller" {
  description = "PCIe address of the storage controller to pass through (e.g. 0000:04:00.0)"
  type        = string
}

# ACME / Let's Encrypt
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

variable "storage_acme_domain" {
  description = "Domain for the Proxmox ACME certificate (e.g. storage.example.com)"
  type        = string
}
