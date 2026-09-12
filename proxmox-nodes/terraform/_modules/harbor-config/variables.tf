variable "harbor_url" {
  description = "Base URL of the Harbor instance"
  type        = string
  default     = "https://harbor.yuriykovalchuk.dev"
}

variable "harbor_username" {
  description = "Harbor user used by Terraform — needs system admin to manage registries and projects"
  type        = string
  default     = "admin"
}

variable "harbor_password" {
  description = "Password for harbor_username"
  type        = string
  sensitive   = true
}
