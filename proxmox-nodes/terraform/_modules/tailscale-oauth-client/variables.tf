variable "router_tag" {
  description = "Tag the client may put on auth keys (must exist in the tailnet policy)"
  type        = string
  default     = "tag:homelab-router"
}
