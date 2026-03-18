variable "kubeconfig_path" {
  description = "Path to the kubeconfig file for the management cluster"
  type        = string
  default     = "~/.kube/management-talos.yaml"
}

# Metrics Server
variable "metrics_server_version" {
  description = "Metrics Server Helm chart version"
  type        = string
  default     = "3.12.2"
}

# Gateway API
variable "gateway_api_version" {
  description = "Gateway API CRDs version"
  type        = string
  default     = "v1.2.0"
}

variable "gateway_api_channel" {
  description = "Gateway API channel (standard or experimental)"
  type        = string
  default     = "standard"
}

# Local Storage
variable "local_storage_path" {
  description = "Path on the node for local storage"
  type        = string
  default     = "/var/local-storage"
}

# Cilium Configuration
variable "cilium_version" {
  description = "Cilium Helm chart version"
  type        = string
  default     = "1.19.1"
}

variable "k8s_service_host" {
  description = "Kubernetes API server host for Cilium"
  type        = string
  default     = "localhost"
}

variable "k8s_service_port" {
  description = "Kubernetes API server port for Cilium (7445 for Talos)"
  type        = string
  default     = "7445"
}

# Cilium BGP Configuration
variable "bgp_local_asn" {
  description = "Local ASN for the Kubernetes cluster"
  type        = number
  default     = 65001
}

variable "bgp_peer_asn" {
  description = "ASN of the BGP peer (OPNsense router)"
  type        = number
  default     = 65551
}

variable "bgp_peer_address" {
  description = "IP address of the BGP peer (OPNsense router)"
  type        = string
  default     = "10.0.2.254"
}

variable "cilium_lb_ip_range_start" {
  description = "IP range (CIDR) for Cilium LoadBalancer services"
  type        = string
  default     = "10.2.0.100"
}


variable "cilium_lb_ip_range_end" {
  description = "IP range (CIDR) for Cilium LoadBalancer services"
  type        = string
  default     = "10.2.0.200"
}

# Gateway Configuration
variable "gateway_ip" {
  description = "IP address for the shared Cilium Gateway"
  type        = string
  default     = "10.2.0.100"
}

# Cert-Manager Configuration
variable "cert_manager_version" {
  description = "Cert-Manager Helm chart version"
  type        = string
  default     = "v1.17.2"
}

variable "acme_email" {
  description = "Email address for ACME certificate registration"
  type        = string
  sensitive   = true
}


variable "acme_cf_token" {
  description = "Cloudflare API token for DNS01 challenge"
  type        = string
  sensitive   = true
}

# Harbor Configuration
variable "harbor_version" {
  description = "Harbor Helm chart version (null for latest)"
  type        = string
  default     = null
}

variable "harbor_hostname" {
  description = "Hostname for Harbor (used in HTTPRoute and externalURL)"
  type        = string
  default     = "harbor.yuriy-lab.cloud"
}


variable "harbor_persistence_enabled" {
  description = "Enable persistence for Harbor"
  type        = bool
  default     = true
}

variable "harbor_storage_registry" {
  description = "Storage size for Harbor registry"
  type        = string
  default     = "100Gi"
}

variable "harbor_storage_database" {
  description = "Storage size for Harbor database"
  type        = string
  default     = "20Gi"
}

variable "harbor_storage_redis" {
  description = "Storage size for Harbor redis"
  type        = string
  default     = "1Gi"
}

variable "harbor_storage_jobservice" {
  description = "Storage size for Harbor jobservice"
  type        = string
  default     = "1Gi"
}

variable "harbor_storage_trivy" {
  description = "Storage size for Harbor trivy"
  type        = string
  default     = "20Gi"
}

variable "harbor_trivy_enabled" {
  description = "Enable Trivy vulnerability scanner"
  type        = bool
  default     = true
}

variable "harbor_metrics_enabled" {
  description = "Enable metrics for Harbor"
  type        = bool
  default     = false
}

variable "harbor_admin_password" {
  description = "Harbor admin password for API access"
  type        = string
  sensitive   = true
}

variable "harbor_insecure" {
  description = "Skip TLS verification when connecting to Harbor API"
  type        = bool
  default     = false
}

# Vault Configuration (Bank-Vaults)
variable "vault_operator_version" {
  description = "Vault Operator Helm chart version"
  type        = string
  default     = "1.22.5"
}

variable "vault_secrets_webhook_version" {
  description = "Vault Secrets Webhook Helm chart version"
  type        = string
  default     = "1.22.2"
}

variable "vault_image_tag" {
  description = "HashiCorp Vault image tag"
  type        = string
  default     = "1.18.3"
}

variable "bank_vaults_version" {
  description = "Bank-Vaults sidecar image version"
  type        = string
  default     = "v1.31.3"
}

variable "vault_hostname" {
  description = "Hostname for Vault (used in HTTPRoute and API address)"
  type        = string
  default     = "vault-intra.yuriy-lab.cloud"
}

variable "vault_replicas" {
  description = "Number of Vault replicas (use odd numbers for Raft consensus)"
  type        = number
  default     = 3
}

variable "vault_webhook_replicas" {
  description = "Number of Vault Secrets Webhook replicas"
  type        = number
  default     = 2
}

variable "vault_storage_size" {
  description = "Storage size for Vault Raft data"
  type        = string
  default     = "1Gi"
}

variable "vault_cpu_request" {
  description = "CPU request for Vault pods"
  type        = string
  default     = "100m"
}

variable "vault_memory_request" {
  description = "Memory request for Vault pods"
  type        = string
  default     = "256Mi"
}

variable "vault_memory_limit" {
  description = "Memory limit for Vault pods"
  type        = string
  default     = "512Mi"
}
