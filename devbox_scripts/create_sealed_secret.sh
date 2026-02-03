#!/usr/bin/env bash
set -euo pipefail

# Usage: create_sealed_secret.sh <name> <key> <value> <namespace>

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <secret-name> <secret-key> <secret-value> <namespace>" >&2
  exit 1
fi

echo -n "$3" | kubectl create secret generic "$1" \
  --namespace "$4" \
  --dry-run=client \
  --from-file="$2"=/dev/stdin -o yaml | \
kubeseal \
  --controller-namespace sealed-secrets \
  --controller-name sealed-secrets \
  --scope strict \
  -o yaml
