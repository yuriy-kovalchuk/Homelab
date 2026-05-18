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
  default     = "gateway"
}

variable "proxmox_vm_datastore" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "vm_id" {
  description = "VM ID for the OPNsense VM"
  type        = number
  default     = 1002
}

variable "vm_name" {
  description = "Name of the OPNsense VM"
  type        = string
  default     = "opnsense"
}

variable "vm_memory" {
  description = "VM memory in MB"
  type        = number
  default     = 4096
}

variable "vm_cores" {
  description = "Number of VM CPU cores"
  type        = number
  default     = 2
}

variable "vm_disk_size" {
  description = "VM disk size in GB"
  type        = number
  default     = 32
}

variable "wan_bridge" {
  description = "WAN network bridge (uplink to home router)"
  type        = string
  default     = "vmbr0"
}

variable "lan_bridge" {
  description = "LAN network bridge (internal homelab network)"
  type        = string
  default     = "vmbr1"
}

variable "lan_bridge_port" {
  description = "Physical NIC to attach to the LAN bridge"
  type        = string
}

variable "opnsense_iso_file_id" {
  description = "Proxmox storage path to the uploaded OPNsense ISO"
  type        = string
  default     = "local:iso/OPNsense-26.1.6-dvd-amd64.iso"
}
