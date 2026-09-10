#!/usr/bin/env bash
# Idempotent directory scaffold for Phase 1.1.
# Creates the tree Terraform / CI / gateway will fill; does not vendor Paperclip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Cost-optimized plan: one env (dev), no ALB/edge module, no Paperclip source tree.
DIRS=(
  .github/workflows
  infra/terraform/modules/network
  infra/terraform/modules/database
  infra/terraform/modules/registry
  infra/terraform/modules/secrets
  infra/terraform/modules/storage
  infra/terraform/modules/service
  infra/terraform/modules/jobs
  infra/terraform/envs/dev
  gateway/config
  scripts
  config
  docs
  local
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
