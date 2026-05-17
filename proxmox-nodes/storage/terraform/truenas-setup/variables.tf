variable "truenas_host" {
  description = "TrueNAS host IP or hostname"
  type        = string
  default     = "10.0.3.3"
}

variable "truenas_token" {
  description = "TrueNAS API token"
  type        = string
  sensitive   = true
}

variable "truenas_pool_name" {
  description = "Name of the ZFS pool"
  type        = string
  default     = "tank"
}

variable "truenas_pool_disks" {
  description = "List of disk identifiers to include in the pool (e.g. [\"sdb\"]). Find with: Storage → Disks in TrueNAS UI."
  type        = list(string)
}

variable "nfs_general_quota_bytes" {
  description = "Quota for the general NFS dataset in bytes."
  type        = number
  default     = 107374182400 # 100 GiB
}

variable "smb_general_quota_bytes" {
  description = "Quota for the general SMB dataset in bytes."
  type        = number
  default     = 107374182400 # 100 GiB
}

variable "truenas_nas_username" {
  description = "Username for the NAS SMB user."
  type        = string
}

variable "truenas_nas_user_password" {
  description = "Password for the NAS SMB user."
  type        = string
  sensitive   = true
}
