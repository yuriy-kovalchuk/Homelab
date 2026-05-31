# Infrastructure TODOs

- [ ] Create a common library chart in `kubernetes/charts/common` to standardize shared templates:
    - `CiliumNetworkPolicy` (Standardized namespaced vs cluster-wide logic)
    - `Namespace` (With default labels for monitoring and security)
    - `HTTPRoute` / `SecurityPolicy` (Envoy Gateway & Authentik patterns)
- [ ] Refactor existing apps (Kyverno, Trivy, etc.) to use the common library chart.
