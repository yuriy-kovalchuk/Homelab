resource "helm_release" "harbor" {
  name             = "harbor"
  namespace        = "harbor"
  repository       = "https://helm.goharbor.io"
  chart            = "harbor"
  create_namespace = true
  version          = var.harbor_version

  values = [
    yamlencode({
      expose = {
        type = "clusterIP"

        tls = {
          enabled = false
        }

        ingress = {
          enabled = false
        }
      }

      externalURL = "https://${var.harbor_hostname}"


      persistence = {
        enabled = var.harbor_persistence_enabled

        persistentVolumeClaim = {
          registry = {
            size = var.harbor_storage_registry
          }
          database = {
            size = var.harbor_storage_database
          }
          redis = {
            size = var.harbor_storage_redis
          }
          jobservice = {
            size = var.harbor_storage_jobservice
          }
          trivy = {
            size = var.harbor_storage_trivy
          }
        }
      }

      trivy = {
        enabled = var.harbor_trivy_enabled
      }

      metrics = {
        enabled = var.harbor_metrics_enabled
      }
    })
  ]
}

# HTTPRoute for Harbor via Gateway API
resource "kubectl_manifest" "harbor_httproute" {
  depends_on = [
    helm_release.harbor,
    kubectl_manifest.shared_gateway
  ]

  yaml_body = <<-YAML
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: harbor
      namespace: harbor
    spec:
      parentRefs:
        - name: shared-gateway
          namespace: kube-system
          sectionName: https-harbor
      hostnames:
        - "${var.harbor_hostname}"
      rules:
        - matches:
            - path:
                type: PathPrefix
                value: /
          backendRefs:
            - name: harbor
              port: 80
  YAML
}
