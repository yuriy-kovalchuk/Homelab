variable "split_dns_domain" {
  description = "Domain resolved by the lab's DNS for tailnet clients"
  type        = string
  default     = "yuriykovalchuk.dev"
}

variable "split_dns_nameservers" {
  description = "OPNsense Unbound on the remote-access VLAN (advertised by the subnet router)"
  type        = list(string)
  default     = ["10.0.6.1"]
}

variable "router_tag" {
  description = "Tag carried by the subnet router"
  type        = string
  default     = "tag:homelab-router"
}

variable "policy_repo_url" {
  description = "Where the policy is maintained (shown in the admin console)"
  type        = string
  default     = "https://github.com/yuriy-kovalchuk/Homelab/blob/main/proxmox-nodes/terraform/_modules/tailscale-tailnet/policy.hujson"
}
