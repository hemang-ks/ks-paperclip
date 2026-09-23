#!/usr/bin/env bash
# Idempotent directory scaffold for Phase 1.1.
# Creates the tree Terraform / CI / gateway will fill; does not vendor Paperclip.
set -euo pipefail

# Script lives in gcp/scripts/ — repo root is two levels up.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Cost-optimized plan: one env (dev), no ALB/edge module, no Paperclip source tree.
DIRS=(
  .github/workflows
  gcp/infra/terraform/modules/network
  gcp/infra/terraform/modules/database
  gcp/infra/terraform/modules/registry
  gcp/infra/terraform/modules/secrets
  gcp/infra/terraform/modules/storage
  gcp/infra/terraform/modules/service
  gcp/infra/terraform/modules/jobs
  gcp/infra/terraform/modules/gateway
  gcp/infra/terraform/envs/dev
  gcp/scripts
  gcp/docs
  gcp/config
  gateway/config
  local
  lab
)

keep_if_empty() {
  local dir="$1"
  mkdir -p "$dir"
  if [[ -z "$(ls -A "$dir" 2>/dev/null || true)" ]]; then
    touch "${dir}/.gitkeep"
  fi
}

echo "==> Scaffolding directories under ${ROOT}"
for dir in "${DIRS[@]}"; do
  keep_if_empty "$dir"
  echo "    ${dir}"
done

echo "==> Done (idempotent; re-run is safe)"
