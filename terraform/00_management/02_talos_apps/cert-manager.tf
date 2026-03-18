# Cert-Manager Installation
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_version
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.namespace"
    value = "cert-manager"
  }

  set {
    name  = "config.apiVersion"
    value = "controller.config.cert-manager.io/v1alpha1"
  }

  set {
    name  = "config.kind"
    value = "ControllerConfiguration"
  }

  set {
    name  = "config.enableGatewayAPI"
    value = "true"
  }

  # Use public DNS servers for DNS01 challenge verification
  values = [<<-YAML
    extraArgs:
      - --dns01-recursive-nameservers-only
      - --dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53
  YAML
  ]
}

# Cloudflare API Token Secret
resource "kubectl_manifest" "cloudflare_api_token_secret" {
  depends_on = [helm_release.cert_manager]

  yaml_body = <<-YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: cloudflare-api-token-secret
      namespace: cert-manager
    type: Opaque
    stringData:
      api-token: ${var.acme_cf_token}
  YAML
}

# Let's Encrypt ClusterIssuer with Cloudflare DNS01
resource "kubectl_manifest" "letsencrypt_dns_issuer" {
  depends_on = [kubectl_manifest.cloudflare_api_token_secret]

  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-dns
    spec:
      acme:
        email: ${var.acme_email}
        server: https://acme-v02.api.letsencrypt.org/directory
        privateKeySecretRef:
          name: letsencrypt-dns-key
        solvers:
          - dns01:
              cloudflare:
                email: ${var.acme_email}
                apiTokenSecretRef:
                  name: cloudflare-api-token-secret
                  key: api-token
  YAML
}
