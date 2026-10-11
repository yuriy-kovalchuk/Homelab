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
  description = "Proxmox node name"
  type        = string
  default     = "gateway"
}

variable "proxmox_iso_datastore" {
  description = "Datastore for cloud images"
  type        = string
  default     = "local"
}

variable "proxmox_vm_datastore" {
  description = "Datastore for VM disks"
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "VLAN-aware bridge shared with OPNsense's LAN trunk"
  type        = string
  default     = "vmbr1"
}

variable "vlan_id" {
  description = "VLAN tag of the remote-access network"
  type        = number
  default     = 6
}

variable "vm_id" {
  description = "VM ID"
  type        = number
  default     = 1010
}

variable "vm_ip" {
  description = "Static IP on the remote-access VLAN"
  type        = string
  default     = "10.0.6.10"
}

variable "vm_gateway" {
  description = "OPNsense address on the remote-access VLAN (gateway and DNS)"
  type        = string
  default     = "10.0.6.1"
}

variable "vm_ssh_key_path" {
  description = "Path to the SSH public key injected into the VM"
  type        = string
  default     = "~/.ssh/homelab_ed25519.pub"
}
