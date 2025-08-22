# Kubernetes Test

This folder is for quick testing of Kubernetes manifests before promoting them into the managed apps under `kubernetes/apps`.

Typical use:

- Create a temporary namespace (optional):
  - kubectl create namespace test
- Apply a manifest from this folder:
  - kubectl apply -n test -f ./volumes.yaml
- Clean up when done:
  - kubectl delete -n test -f ./volumes.yaml
  - kubectl delete namespace test

Notes:
- Resources here are not managed by Argo CD; they are meant for ad‑hoc experiments.
- Keep files minimal and self‑contained. Remove anything no longer needed to avoid confusion.