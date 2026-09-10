#!/usr/bin/env bash
# Smoke-test a Paperclip deployment. Exits non-zero on failure.
set -euo pipefail

BASE_URL="${1:-${PAPERCLIP_PUBLIC_URL:-}}"
[[ -n "${BASE_URL}" ]] || {
  echo "usage: scripts/smoke-test.sh <base-url>" >&2
  echo "   or: PAPERCLIP_PUBLIC_URL=https://… scripts/smoke-test.sh" >&2
  exit 2
}

BASE_URL="${BASE_URL%/}"
HEALTH_URL="${BASE_URL}/api/health"

echo "==> GET ${HEALTH_URL}"
body="$(curl -fsS --max-time 30 "${HEALTH_URL}")"
echo "${body}"

python3 -c '
import json, sys
data = json.loads(sys.argv[1])
status = data.get("status")
if status != "ok":
    raise SystemExit(f"health status not ok: {status!r}")
print("smoke ok: status=ok deploymentMode=%s bootstrapStatus=%s" % (
    data.get("deploymentMode"),
    data.get("bootstrapStatus"),
))
' "${body}"
