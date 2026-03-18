# Cilium Module

This module manages the installation of the Cilium CNI using Helm.

## Usage

```hcl
module "cilium" {
  source = "../../modules/cilium"

  cilium_version = "1.18.6"
  namespace      = "kube-system"

  values = [
    templatefile("${path.module}/helm_values/cilium/cilium-values.yaml.tftpl", {
      k8s_service_host = var.k8s_service_host
      k8s_service_port = var.k8s_service_port
    })
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cilium_version | Version of Cilium to install | `string` | n/a | yes |
| namespace | Namespace to install Cilium into | `string` | `"kube-system"` | no |
| values | Additional Helm values to apply | `list(string)` | `[]` | no |
| create_namespace | Whether to create the namespace | `bool` | `false` | no |
