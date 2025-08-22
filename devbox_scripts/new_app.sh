#!/usr/bin/env bash
set -euo pipefail

# new_app.sh - Create a new Kubernetes app from kubernetes/apps/_template (Devbox script)
#
# Usage:
#   bash devbox_scripts/new_app.sh <app-name> [--namespace <ns>] [--no-templates] [--repo-url <url>] [--dry-run]
#
# Examples:
#   bash devbox_scripts/new_app.sh myapp
#   bash devbox_scripts/new_app.sh myapp --namespace myns --no-templates
#   bash devbox_scripts/new_app.sh myapp --repo-url "https://github.com/you/Homelab.git"
#
# Notes:
# - By default, the chart templates under manifest/templates are included. Use --no-templates to exclude them.
# - The script replaces __APP_NAME__ and __NAMESPACE__ placeholders in all files under the new app folder.
# - It renames TEMPLATE-app.yaml to <app-name>-app.yaml.
# - If --repo-url is provided, it will replace .spec.source.repoURL with your value in the Argo CD Application file.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
APPS_DIR="$REPO_ROOT/kubernetes/apps"
TEMPLATE_DIR="$APPS_DIR/_template"

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  echo "[ERROR] Template directory not found at: $TEMPLATE_DIR" >&2
  exit 1
fi

usage() {
  sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'
}

APP_NAME=""
NAMESPACE=""
INCLUDE_TEMPLATES=1
REPO_URL_OVERRIDE=""
DRY_RUN=0

while (( "$#" )); do
  case "${1}" in
    -h|--help)
      usage; exit 0;;
    --namespace)
      shift; NAMESPACE="${1:-}"; [[ -z "$NAMESPACE" ]] && echo "[ERROR] --namespace requires a value" && exit 1;;
    --no-templates)
      INCLUDE_TEMPLATES=0;;
    --repo-url)
      shift; REPO_URL_OVERRIDE="${1:-}"; [[ -z "$REPO_URL_OVERRIDE" ]] && echo "[ERROR] --repo-url requires a value" && exit 1;;
    --dry-run)
      DRY_RUN=1;;
    --*)
      echo "[ERROR] Unknown option: $1" >&2; usage; exit 1;;
    *)
      if [[ -z "$APP_NAME" ]]; then APP_NAME="$1"; else echo "[ERROR] Unexpected argument: $1" >&2; usage; exit 1; fi;;
  esac
  shift || true
done

if [[ -z "$APP_NAME" ]]; then
  echo "[ERROR] <app-name> is required" >&2
  usage
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

run() {
  echo "+ $*"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    eval "$@"
  fi
}

copy_template() {
  run "cp -R '$TEMPLATE_DIR' '$TARGET_DIR'"
}

rename_app_manifest() {
  local src="$TARGET_DIR/TEMPLATE-app.yaml"
  local dst="$TARGET_DIR/$APP_NAME-app.yaml"
  run "mv '$src' '$dst'"
}

# Portable in-place replacer for both GNU and BSD sed
replace_inplace() {
  local pattern="$1"; shift
  local replacement="$1"; shift
  local file
  for file in "$@"; do
    if sed --version >/dev/null 2>&1; then
      run "sed -i 's#${pattern}#${replacement}#g' '$file'"
    else
      run "sed -i '' 's#${pattern}#${replacement}#g' '$file'"
    fi
  done
}

replace_placeholders() {
  # Find all regular files within target
  local files
  IFS=$'\n' read -r -d '' -a files < <(find "$TARGET_DIR" -type f -print0 | xargs -0 -n1 printf "%s\n" && printf '\0') || true
  if [[ ${#files[@]} -eq 0 ]]; then return; fi
  # Replace __APP_NAME__ and __NAMESPACE__
  for f in "${files[@]}"; do
    case "$f" in *.tgz) continue;; esac
    replace_inplace "__APP_NAME__" "$APP_NAME" "$f"
    replace_inplace "__NAMESPACE__" "$NAMESPACE" "$f"
  done
}

maybe_override_repo_url() {
  [[ -z "$REPO_URL_OVERRIDE" ]] && return 0
  local app_file="$TARGET_DIR/$APP_NAME-app.yaml"
  if [[ ! -f "$app_file" ]]; then
    echo "[WARN] App manifest not found for repoURL override: $app_file" >&2
    return 0
  fi
  if sed --version >/dev/null 2>&1; then
    run "sed -i \"s#^\\([[:space:]]*repoURL:[[:space:]]*\).*#\\1$REPO_URL_OVERRIDE#\" '$app_file'"
  else
    run "sed -i '' \"s#^\\([[:space:]]*repoURL:[[:space:]]*\).*#\\1$REPO_URL_OVERRIDE#\" '$app_file'"
  fi
}

maybe_remove_templates() {
  if [[ "$INCLUDE_TEMPLATES" -eq 1 ]]; then return 0; fi
  local tpl_dir="$TARGET_DIR/manifest/templates"
  if [[ -d "$tpl_dir" ]]; then
    run "rm -rf '$tpl_dir'"
  fi
}

main() {
  echo "[INFO] Creating new app from template"
  echo "       app-name      : $APP_NAME"
  echo "       namespace     : $NAMESPACE"
  echo "       include templates: $([[ $INCLUDE_TEMPLATES -eq 1 ]] && echo yes || echo no)"
  if [[ -n "$REPO_URL_OVERRIDE" ]]; then
    echo "       repoURL override: $REPO_URL_OVERRIDE"
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[DRY RUN] No files will be modified"
  fi

  copy_template
  rename_app_manifest
  replace_placeholders
  maybe_override_repo_url
  maybe_remove_templates

  echo "[DONE] New app created at: $TARGET_DIR"
  echo "Next steps:"
  echo "  - Review $TARGET_DIR/manifest/Chart.yaml and values.yaml"
  if [[ "$INCLUDE_TEMPLATES" -eq 1 ]]; then
    echo "  - Adjust manifests under $TARGET_DIR/manifest/templates as needed"
  else
    echo "  - Add dependencies to $TARGET_DIR/manifest/Chart.yaml if using an upstream chart (umbrella)"
  fi
  echo "  - Apply the Argo CD app: kubectl apply -f $TARGET_DIR/$APP_NAME-app.yaml"
}

main "$@"
