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
  default     = "gaia"
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

