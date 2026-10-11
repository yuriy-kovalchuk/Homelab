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

variable "lockdown" {
  description = <<-EOT
    false (setup): management also on the home LAN (vmbr0), default route via the ISP router.
    true (normal): vmbr0 carries no host address (OPNsense WAN only); management only on the
    trusted VLAN, default route via OPNsense. Break-glass works in both.
  EOT
  type        = bool
  default     = false
}

variable "wan_address" {
  description = "Setup-phase management address on the home LAN (vmbr0)"
  type        = string
  default     = "192.168.0.254/24"
}

variable "wan_gateway" {
  description = "ISP router, default route during setup"
  type        = string
  default     = "192.168.0.1"
}

variable "mgmt_vlan" {
  description = "Trusted VLAN carried on vmbr1"
  type        = number
  default     = 5
}

variable "mgmt_address" {
  description = "Management address on the trusted VLAN"
  type        = string
  default     = "10.0.5.3/24"
}

variable "mgmt_gateway" {
  description = "OPNsense on the trusted VLAN, default route after lockdown"
  type        = string
  default     = "10.0.5.1"
}

variable "breakglass_nic" {
  description = "Spare physical port for direct-cable emergency access"
  type        = string
  default     = "nic1"
}

variable "breakglass_address" {
  description = "Fixed address on the break-glass port (laptop uses another IP in this /24, no gateway)"
  type        = string
  default     = "172.30.0.1/24"
}
