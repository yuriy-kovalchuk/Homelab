# Shared Cilium Gateway
resource "kubectl_manifest" "shared_gateway" {
  depends_on = [
    helm_release.cilium,
    kubectl_manifest.letsencrypt_dns_issuer
  ]

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: shared-gateway
      namespace: kube-system
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-dns
    spec:
      gatewayClassName: cilium
      addresses:
        - type: IPAddress
          value: "${var.gateway_ip}"
      listeners:
        - name: http
          port: 80
          protocol: HTTP
          allowedRoutes:
            namespaces:
              from: All
        - name: https-harbor
          port: 443
          protocol: HTTPS
          hostname: "${var.harbor_hostname}"
          tls:
            mode: Terminate
            certificateRefs:
              - name: harbor-tls
                kind: Secret
          allowedRoutes:
            namespaces:
              from: All
  YAML
}
