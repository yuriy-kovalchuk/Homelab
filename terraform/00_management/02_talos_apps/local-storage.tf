# TODO security baseline
resource "helm_release" "local_path_provisioner" {
  name       = "local-path-provisioner"
  repository = "https://charts.containeroo.ch"
  chart      = "local-path-provisioner"
  namespace  = "local-path-storage"
  create_namespace = true

  set {
    name  = "storageClass.create"
    value = "true"
  }

  set {
    name  = "storageClass.name"
    value = "local-path"
  }

  set {
    name  = "storageClass.defaultClass"
    value = "true"
  }
}
