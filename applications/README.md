# Applications

Purpose
- This directory contains custom applications developed for this homelab. These apps provide bespoke functionality not covered by off‑the‑shelf tools.
- Each subfolder is a standalone application. The internal structure may differ per app and depends on the programming language, build system, and runtime.

What you’ll typically find in a subfolder
- Source code for the app (layout varies by language; e.g., Go may use cmd/, pkg/, internal/; Node/TS may have src/; Python may have a module directory, etc.).
- A container build definition (e.g., Dockerfile or dockerfile) to build a runnable image for Kubernetes.
- Language/package metadata (e.g., go.mod, package.json, pyproject.toml) when relevant.
- A README specific to the app explaining what it does, how to configure it, and how to build/push its image.

How these apps are used
- Applications here are generally built into container images and deployed to the cluster via the manifests/Helm charts under kubernetes/apps/.
- Per‑app configuration is typically handled via environment variables, ConfigMaps, and Secrets in the corresponding Kubernetes chart.

Example
- ingress-hostname-exporter: A Go daemon that watches Kubernetes Ingress resources and syncs their hostnames to OPNsense Unbound DNS. See applications/ingress-hostname-exporter/README.md for details.

Contributing a new app
- Create a new subfolder under applications/ with the app’s name.
- Add your source code following conventions for your language of choice.
- Provide a container build file (e.g., Dockerfile) that produces a minimal runtime image.
- Document the app in a README.md (purpose, configuration, how to build & push).
- Add a deployment under kubernetes/apps/ (a simple Helm chart or raw manifests) to run it in the cluster.

Notes
- There is no enforced, single “one‑size‑fits‑all” structure here. Choose a sensible layout for your language/runtime.
- Keep secrets out of source: use Kubernetes Secrets (optionally sealed-secrets) and reference them from your manifests.
