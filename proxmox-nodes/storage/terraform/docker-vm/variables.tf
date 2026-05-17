# Proxmox connection — shared with truenas-install, set in global .env
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

variable "storage_proxmox_node_name" {
  description = "Proxmox node name"
  type        = string
  default     = "storage"
}

variable "storage_proxmox_iso_datastore" {
  description = "Datastore for cloud images"
  type        = string
  default     = "local"
}

variable "storage_proxmox_vm_datastore" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "storage_proxmox_network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

# Docker VM
variable "docker_vm_ssh_key_path" {
  description = "Path to the SSH public key injected into the VM"
  type        = string
  default     = "~/.ssh/homelab_ed25519.pub"
}

variable "docker_vm_id" {
  description = "VM ID"
  type        = number
  default     = 200
}

variable "docker_vm_ip" {
  description = "Static IP on the storage VLAN"
  type        = string
  default     = "10.0.3.4"
}

