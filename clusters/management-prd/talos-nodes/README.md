# talos-nodes

Custom resource manifests consumed by
[yk-talos-manager](https://github.com/yuriy-kovalchuk/yk-talos-management).

Place node definition YAMLs here and apply them manually — this directory is **not**
watched by FluxCD. Apply with:

```bash
kubectl --kubeconfig ~/.kube/talos-management.yaml apply -f clusters/management-prd/talos-nodes/
```
