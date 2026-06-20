variable "truenas_host" {
  description = "TrueNAS host IP or hostname"
  type        = string
  default     = "10.0.3.3"
}

variable "truenas_ssh_private_key" {
  description = "SSH private key content for TrueNAS root access"
  type        = string
  sensitive   = true
}

variable "truenas_ssh_host_fingerprint" {
  description = "SHA256 host key fingerprint — get via: ssh-keyscan 10.0.3.3 2>/dev/null | ssh-keygen -lf -"
  type        = string
}

variable "truenas_pool_name" {
  description = "Name of the ZFS pool"
  type        = string
  default     = "tank"
}
