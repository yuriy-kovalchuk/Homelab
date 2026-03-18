# Bank-Vaults (Banzai Cloud) - Vault Operator, Secrets Webhook, and Vault Instance

# Namespace for Vault components
resource "kubernetes_namespace" "vault_system" {
  metadata {
    name = "vault-system"
    labels = {
      # Pod Security Standards - baseline is sufficient with disable_mlock
      "pod-security.kubernetes.io/enforce" = "baseline"
      "pod-security.kubernetes.io/audit"   = "baseline"
      "pod-security.kubernetes.io/warn"    = "baseline"
    }
  }
}

# CiliumNetworkPolicy for Vault
resource "kubectl_manifest" "vault_network_policy" {
  depends_on = [kubernetes_namespace.vault_system]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: vault
      namespace: vault-system
    spec:
      endpointSelector:
        matchLabels:
          app.kubernetes.io/name: vault
      ingress:
        # Allow Vault pods to communicate with each other (Raft clustering)
        - fromEndpoints:
            - matchLabels:
                app.kubernetes.io/name: vault
          toPorts:
            - ports:
                - port: "8200"
                  protocol: TCP
                - port: "8201"
                  protocol: TCP
        # Allow traffic from all pods in the cluster (for API access)
        - fromEndpoints:
            - {}
          toPorts:
            - ports:
                - port: "8200"
                  protocol: TCP
        # Allow traffic from the gateway
        - fromEntities:
            - cluster
          toPorts:
            - ports:
                - port: "8200"
                  protocol: TCP
      egress:
        # Allow Vault pods to communicate with each other
        - toEndpoints:
            - matchLabels:
                app.kubernetes.io/name: vault
          toPorts:
            - ports:
                - port: "8200"
                  protocol: TCP
                - port: "8201"
                  protocol: TCP
        # Allow DNS
        - toEndpoints:
            - matchLabels:
                k8s:io.kubernetes.pod.namespace: kube-system
                k8s-app: kube-dns
          toPorts:
            - ports:
                - port: "53"
                  protocol: UDP
                - port: "53"
                  protocol: TCP
        # Allow Kubernetes API access (for auth, service account validation)
        - toEntities:
            - kube-apiserver
  YAML
}

# Service Account for Vault pods
resource "kubernetes_service_account" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }
}

# ClusterRoleBinding for Vault to perform token reviews (for Kubernetes auth)
resource "kubernetes_cluster_role_binding" "vault_auth_delegator" {
  metadata {
    name = "vault-auth-delegator"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault.metadata[0].name
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }
}

# Role for Vault to manage secrets (unseal keys, root token)
resource "kubernetes_role" "vault_secrets" {
  metadata {
    name      = "vault-secrets"
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "patch", "update"]
  }
}

# RoleBinding for Vault secrets management
resource "kubernetes_role_binding" "vault_secrets" {
  metadata {
    name      = "vault-secrets"
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_secrets.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault.metadata[0].name
    namespace = kubernetes_namespace.vault_system.metadata[0].name
  }
}

# Vault Operator - manages Vault clusters
resource "helm_release" "vault_operator" {
  name             = "vault-operator"
  namespace        = kubernetes_namespace.vault_system.metadata[0].name
  repository       = "oci://ghcr.io/bank-vaults/helm-charts"
  chart            = "vault-operator"
  version          = var.vault_operator_version
  create_namespace = false

  depends_on = [kubernetes_namespace.vault_system]

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          memory = "256Mi"
        }
      }
    })
  ]
}

# Vault Secrets Webhook - injects secrets into pods
resource "helm_release" "vault_secrets_webhook" {
  name             = "vault-secrets-webhook"
  namespace        = kubernetes_namespace.vault_system.metadata[0].name
  repository       = "oci://ghcr.io/bank-vaults/helm-charts"
  chart            = "vault-secrets-webhook"
  version          = var.vault_secrets_webhook_version
  create_namespace = false

  depends_on = [helm_release.vault_operator]

  values = [
    yamlencode({
      replicaCount = var.vault_webhook_replicas

      # Webhook configuration
      env = {
        VAULT_IMAGE             = "hashicorp/vault:${var.vault_image_tag}"
        VAULT_ENV_FROM_PATH     = "secret/data/env"
        VAULT_SKIP_VERIFY       = "true"
        VAULT_IGNORE_MISSING_SECRETS = "true"
      }

      # Pod security
      podSecurityContext = {
        runAsNonRoot = true
        runAsUser    = 65534
        fsGroup      = 65534
      }

      securityContext = {
        allowPrivilegeEscalation = false
        readOnlyRootFilesystem   = true
        capabilities = {
          drop = ["ALL"]
        }
      }

      # Resources
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }

      # Webhook namespaceSelector - inject into all namespaces except system ones
      namespaceSelector = {
        matchExpressions = [
          {
            key      = "kubernetes.io/metadata.name"
            operator = "NotIn"
            values   = ["kube-system", "vault-system"]
          }
        ]
      }
    })
  ]
}

# Vault Custom Resource - Vault cluster with Raft storage
resource "kubectl_manifest" "vault" {
  depends_on = [
    helm_release.vault_operator,
    kubectl_manifest.shared_gateway,
    kubernetes_service_account.vault,
    kubernetes_cluster_role_binding.vault_auth_delegator,
    kubernetes_role_binding.vault_secrets
  ]

  yaml_body = <<-YAML
    apiVersion: "vault.banzaicloud.com/v1alpha1"
    kind: "Vault"
    metadata:
      name: "vault"
      namespace: "vault-system"
      labels:
        app.kubernetes.io/name: vault
        vault_cr: vault
    spec:
      size: ${var.vault_replicas}
      image: hashicorp/vault:${var.vault_image_tag}
      bankVaultsImage: ghcr.io/bank-vaults/bank-vaults:${var.bank_vaults_version}

      serviceAccount: vault
      serviceType: ClusterIP

      # Persistent storage for Raft (matching reference example)
      volumeClaimTemplates:
        - metadata:
            name: vault-raft
          spec:
            accessModes:
              - ReadWriteOnce
            volumeMode: Filesystem
            resources:
              requests:
                storage: ${var.vault_storage_size}

      volumeMounts:
        - name: vault-raft
          mountPath: /vault/file

      config:
        storage:
          raft:
            path: "/vault/file"
            retry_join:
              - leader_api_addr: "https://vault-0:8200"
                leader_ca_cert_file: /vault/tls/ca.crt
              - leader_api_addr: "https://vault-1:8200"
                leader_ca_cert_file: /vault/tls/ca.crt
              - leader_api_addr: "https://vault-2:8200"
                leader_ca_cert_file: /vault/tls/ca.crt
        listener:
          tcp:
            address: "0.0.0.0:8200"
            tls_cert_file: /vault/tls/server.crt
            tls_key_file: /vault/tls/server.key
        api_addr: https://vault.vault-system:8200
        cluster_addr: "https://$${.Env.POD_NAME}:8201"
        disable_mlock: true
        ui: true

      statsdDisabled: true
      serviceRegistrationEnabled: true

      resources:
        vault:
          requests:
            cpu: "${var.vault_cpu_request}"
            memory: "${var.vault_memory_request}"
          limits:
            memory: "${var.vault_memory_limit}"

      unsealConfig:
        options:
          preFlightChecks: true
          storeRootToken: true
          secretShares: 5
          secretThreshold: 3
        kubernetes:
          secretNamespace: vault-system

      externalConfig:
        policies:
          - name: allow_secrets
            rules: path "secret/*" {
              capabilities = ["create", "read", "update", "delete", "list"]
              }

        auth:
          - type: kubernetes
            roles:
              - name: default
                bound_service_account_names: ["*"]
                bound_service_account_namespaces: ["*"]
                policies: ["default", "allow_secrets"]
                ttl: 1h

        secrets:
          - path: secret
            type: kv
            description: General secrets
            options:
              version: 2

      vaultEnvsConfig:
        - name: VAULT_LOG_LEVEL
          value: debug
  YAML
}

# HTTPRoute for Vault UI and API via Gateway API
resource "kubectl_manifest" "vault_httproute" {
  depends_on = [
    kubectl_manifest.vault,
    kubectl_manifest.shared_gateway
  ]

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: vault
      namespace: vault-system
    spec:
      parentRefs:
        - name: shared-gateway
          namespace: kube-system
          sectionName: https-vault
      hostnames:
        - "${var.vault_hostname}"
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - name: h2h-proxy
              port: 80
  YAML
}



resource "kubectl_manifest" "h2h_proxy" {
  yaml_body = <<-YAML
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: h2h-proxy
        namespace: "vault-system"
        labels:
          app: h2h-proxy
      spec:
        replicas: 1
        selector:
          matchLabels:
            app: h2h-proxy
        template:
          metadata:
            labels:
              app: h2h-proxy
          spec:
            containers:
              - name: nginx
                image: nginx:1.25-alpine
                ports:
                  - containerPort: 8080
                command:
                  - /bin/sh
                  - -c
                  - |
                    cat <<'EOF' >/tmp/nginx.conf
                    events {}

                    http {
                        # Essential for debugging: see exactly why it's 500ing
                        error_log /dev/stdout debug;
                        access_log /dev/stdout;

                        upstream vault_backend {
                            server vault.vault-system.svc.cluster.local:8200;
                        }

                        server {
                            listen 8080;

                            location / {
                                proxy_pass https://vault_backend;

                                # Tell Nginx to use the internal DNS name for the TLS handshake
                                proxy_ssl_server_name on;
                                proxy_ssl_name vault.vault-system.svc.cluster.local;
                                proxy_ssl_verify off;

                                # Headers for Vault
                                proxy_set_header Host $host;
                                proxy_set_header X-Real-IP $remote_addr;
                                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                                proxy_set_header X-Forwarded-Proto https;

                                # Increase timeouts (Vault unseal/login can be slow)
                                proxy_connect_timeout 60s;
                                proxy_read_timeout 60s;
                                
                                # Handle the 301/302 redirects from Vault
                                proxy_redirect https://vault.vault-system.svc.cluster.local:8200/ /;
                            }
                        }
                    }
                    EOF

                    exec nginx -g 'daemon off;' -c /tmp/nginx.conf

  YAML
}


resource "kubectl_manifest" "h2h_proxy_svc" {
  yaml_body = <<-YAML
      apiVersion: v1
      kind: Service
      metadata:
        name: h2h-proxy
        namespace: "vault-system"
      spec:
        selector:
          app: h2h-proxy
        ports:
          - port: 80
            targetPort: 8080
            protocol: TCP
  YAML
}
