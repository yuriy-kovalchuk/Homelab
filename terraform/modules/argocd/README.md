# Argo CD Module

This module manages the installation of Argo CD using Helm.

## Usage

```hcl
module "argo_cd" {
  source = "../../modules/argocd"

  argocd_version = "7.7.0"
  namespace      = "argo-cd"

  values = [
    file("${path.module}/helm_values/argocd/argocd-values.yaml")
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| argocd_version | Version of Argo CD to install | `string` | n/a | yes |
| namespace | Namespace to install Argo CD into | `string` | `"argo-cd"` | no |
| values | Additional Helm values to apply | `list(string)` | `[]` | no |
| create_namespace | Whether to create the namespace | `bool` | `true` | no |
