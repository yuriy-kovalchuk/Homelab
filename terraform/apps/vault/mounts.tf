# Vault KV Secret Engine

resource "vault_mount" "kubernetes" {
  path        = "kubernetes"
  type        = "kv"
  options     = { version = "2" }
  description = "KV store for Kubernetes secrets"
}
