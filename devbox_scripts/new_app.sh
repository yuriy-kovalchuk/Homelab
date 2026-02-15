#!/usr/bin/env bash
set -euo pipefail

# new_app.sh - Scaffold a new Kubernetes app (OCI-based)
# Usage: bash devbox_scripts/new_app.sh <app-name> [--namespace <ns>]

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
APPS_DIR="$REPO_ROOT/kubernetes/apps"
TEMPLATE_DIR="$REPO_ROOT/kubernetes/_template"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "[ERROR] Template directory not found at: $TEMPLATE_DIR" >&2
  exit 1
fi

APP_NAME=""
NAMESPACE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)
      if [[ -z "${2:-}" ]]; then
        echo "[ERROR] --namespace requires a value" >&2
        exit 1
      fi
      NAMESPACE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 <app-name> [--namespace <ns>]"
      exit 0
      ;;
    *)
      if [[ -z "$APP_NAME" ]]; then
        APP_NAME="$1"
      else
        echo "[ERROR] Unknown argument: $1" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$APP_NAME" ]]; then
  echo "[ERROR] App name is required."
  echo "Usage: $0 <app-name> [--namespace <ns>]"
  exit 1
fi

if [[ -z "$NAMESPACE" ]]; then
  NAMESPACE="$APP_NAME"
fi

TARGET_DIR="$APPS_DIR/$APP_NAME"

if [[ -e "$TARGET_DIR" ]]; then
  echo "[ERROR] Target already exists: $TARGET_DIR" >&2
  exit 1
fi

echo "[INFO] Creating new app '$APP_NAME' (namespace: '$NAMESPACE')..."

# 1. Copy Template
cp -R "$TEMPLATE_DIR" "$TARGET_DIR"

# 2. Replace Placeholders
# Portable in-place sed
replace_in_file() {
  local pattern="$1"
  local replacement="$2"
  local file="$3"
  
  if sed --version >/dev/null 2>&1; then
    sed -i "s#${pattern}#${replacement}#g" "$file"
  else
    sed -i '' "s#${pattern}#${replacement}#g" "$file"
  fi
}

find "$TARGET_DIR" -type f -print0 | while IFS= read -r -d '' file; do
  replace_in_file "__APP_NAME__" "$APP_NAME" "$file"
  replace_in_file "__NAMESPACE__" "$NAMESPACE" "$file"
done

echo "[DONE] Created at: $TARGET_DIR"
echo ""
echo "Next Steps:"
echo "1. Configure: Edit $TARGET_DIR/manifest/Chart.yaml and values.yaml"
echo "2. Release:   make release APP=$APP_NAME"
echo "3. Deploy:    Add to kubernetes/management/manifest/values.yaml"
