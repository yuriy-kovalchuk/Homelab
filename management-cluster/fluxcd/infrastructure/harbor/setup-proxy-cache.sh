#!/usr/bin/env bash
set -euo pipefail

HARBOR_URL="${HARBOR_URL:-https://harbor-mgmt.yuriy-lab.cloud}"
HARBOR_USER="${HARBOR_USER:-admin}"
HARBOR_PASS="${HARBOR_PASS:?Set HARBOR_PASS}"

API="${HARBOR_URL}/api/v2.0"

auth_header() {
  echo -n "${HARBOR_USER}:${HARBOR_PASS}" | base64
}

get_registry_id() {
  local name="$1"
  curl -sk -H "Authorization: Basic $(auth_header)" \
    "${API}/registries?name=${name}" | jq -r '.[0].id // empty'
}

get_project_id() {
  local name="$1"
  curl -sk -H "Authorization: Basic $(auth_header)" \
    "${API}/projects?name=${name}" | jq -r '.[0].project_id // empty'
}

create_registry() {
  local name="$1" provider="$2" url="$3" description="$4"
  if [[ -n "$(get_registry_id "$name")" ]]; then
    echo "Registry '${name}' already exists, skipping"
    return
  fi
  echo "Creating registry: ${name}"
  curl -sk -w "\nHTTP %{http_code}\n" -X POST "${API}/registries" \
    -H "Authorization: Basic $(auth_header)" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg name "$name" \
      --arg type "$provider" \
      --arg url "$url" \
      --arg desc "$description" \
      '{
        name: $name,
        type: $type,
        url: $url,
        description: $desc,
        credential: {
          type: "basic",
          access_key: "",
          secret: ""
        }
      }'
    )"
}

create_proxy_project() {
  local name="$1" registry_name="$2"
  if [[ -n "$(get_project_id "$name")" ]]; then
    echo "Project '${name}' already exists, skipping"
    return
  fi
  local registry_id
  registry_id="$(get_registry_id "$registry_name")"
  if [[ -z "$registry_id" ]]; then
    echo "ERROR: Registry '${registry_name}' not found"
    return 1
  fi
  echo "Creating proxy project: ${name} -> registry_id: ${registry_id}"
  curl -sk -w "\nHTTP %{http_code}\n" -X POST "${API}/projects" \
    -H "Authorization: Basic $(auth_header)" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg name "$name" \
      --argjson regid "$registry_id" \
      '{
        project_name: $name,
        registry_id: $regid,
        metadata: { public: "true" }
      }'
    )"
}

# --- Registries ---
create_registry "dockerhub"     "docker-hub"      "https://hub.docker.com"      "Docker Hub - Official Docker registry"
create_registry "ghcr"          "docker-registry" "https://ghcr.io"              "GitHub Container Registry"
create_registry "gcr"           "docker-registry" "https://gcr.io"               "Google Container Registry"
create_registry "k8s"           "docker-registry" "https://registry.k8s.io"      "Kubernetes Official Registry"
create_registry "quay"          "docker-registry" "https://quay.io"              "Red Hat Quay Registry"
create_registry "ecr-public"    "docker-registry" "https://public.ecr.aws"       "Amazon ECR Public Gallery"
create_registry "mcr"           "docker-registry" "https://mcr.microsoft.com"    "Microsoft Container Registry"

# --- Proxy Cache Projects ---
create_proxy_project "dockerhub"    "dockerhub"
create_proxy_project "ghcr"        "ghcr"
create_proxy_project "gcr"         "gcr"
create_proxy_project "k8s"         "k8s"
create_proxy_project "quay"        "quay"
create_proxy_project "ecr-public"  "ecr-public"
create_proxy_project "mcr"         "mcr"

echo "Done"
