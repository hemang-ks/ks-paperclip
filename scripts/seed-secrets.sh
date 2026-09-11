#!/usr/bin/env bash
# Seed Secret Manager *values* for Paperclip (containers must already exist).
#
# Never prints secret values. Never writes secrets to disk (except you may fetch
# the master key yourself via gcloud after seeding — see messages).
#
# Recommended after first Terraform apply:
#   scripts/seed-secrets.sh \
#     --project-id "$GCP_PROJECT_ID" \
#     --private-ip "$(cd infra/terraform/envs/dev && terraform output -raw cloud_sql_private_ip)" \
#     --from-terraform infra/terraform/envs/dev
#
# Idempotent: skips secrets that already have a version unless --force.
# paperclip-secrets-master-key additionally requires
#   --i-understand-this-destroys-all-stored-secrets
# to overwrite.
#
# Phase 2 gateway key (no DB / HMAC):
#   scripts/seed-secrets.sh --project-id "$GCP_PROJECT_ID" --gateway-only
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-${GCP_PROJECT_ID:-}}"
PRIVATE_IP=""
DB_USER="paperclip"
DB_NAME="paperclip"
FORCE=0
DESTROY_MASTER_ACK=0
SKIP_PROVIDER_KEYS=1
GATEWAY_ONLY=0
FROM_TERRAFORM=""
DB_PASSWORD=""
HMAC_ACCESS_ID=""
HMAC_SECRET=""

usage() {
  cat <<'EOF'
Usage: scripts/seed-secrets.sh --project-id ID --private-ip IP [options]
       scripts/seed-secrets.sh --project-id ID --gateway-only

Seed Secret Manager versions. Secret *containers* must already exist
(Terraform secrets module). Does not print secret values.

Required (Paperclip / 1.7):
  --project-id PROJECT_ID   GCP project (or PROJECT_ID / GCP_PROJECT_ID)
  --private-ip IP           Cloud SQL private IP (terraform output cloud_sql_private_ip)

Required (LiteLLM / 2.3):
  --gateway-only            Seed litellm-master-key only (no --private-ip).
                            Does not touch Gemini/Anthropic (those are 2.2).
                            Does not write Paperclip provider keys.

Options:
  --from-terraform DIR      Read db_password (+ hmac if present) from
                            `terraform output -raw` in DIR (recommended)
  --db-user NAME            DB user (default: paperclip)
  --db-name NAME            DB name (default: paperclip)
  --force                   Overwrite secrets that already have a version
  --i-understand-this-destroys-all-stored-secrets
                            Required with --force to overwrite
                            paperclip-secrets-master-key
  --with-provider-keys      Interactively prompt for Anthropic/OpenAI/GitHub
                            on Paperclip secrets (not the LiteLLM gateway)
  --skip-provider-keys      Skip Paperclip provider API keys (default)
  -h, --help                Show help

Environment (alternative to --from-terraform; values are never echoed):
  PAPERCLIP_DB_PASSWORD
  PAPERCLIP_GCS_HMAC_ACCESS_ID
  PAPERCLIP_GCS_HMAC_SECRET
EOF
}

log()  { printf '==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --project-id|--project)
      [[ $# -ge 2 ]] || die "missing value for $1"
      PROJECT_ID="$2"; shift 2 ;;
    --project-id=*) PROJECT_ID="${1#*=}"; shift ;;
    --private-ip)
      [[ $# -ge 2 ]] || die "missing value for $1"
      PRIVATE_IP="$2"; shift 2 ;;
    --private-ip=*) PRIVATE_IP="${1#*=}"; shift ;;
    --db-user)
      [[ $# -ge 2 ]] || die "missing value for $1"
      DB_USER="$2"; shift 2 ;;
    --db-name)
      [[ $# -ge 2 ]] || die "missing value for $1"
      DB_NAME="$2"; shift 2 ;;
    --from-terraform)
      [[ $# -ge 2 ]] || die "missing value for $1"
      FROM_TERRAFORM="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --i-understand-this-destroys-all-stored-secrets) DESTROY_MASTER_ACK=1; shift ;;
    --with-provider-keys) SKIP_PROVIDER_KEYS=0; shift ;;
    --skip-provider-keys) SKIP_PROVIDER_KEYS=1; shift ;;
    --gateway-only) GATEWAY_ONLY=1; shift ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[[ -n "${PROJECT_ID}" ]] || die "PROJECT_ID required"
if [[ "${GATEWAY_ONLY}" -ne 1 ]]; then
  [[ -n "${PRIVATE_IP}" ]] || die "--private-ip required (Cloud SQL private IP), or pass --gateway-only"
fi
command -v gcloud >/dev/null 2>&1 || die "gcloud not on PATH"
command -v openssl >/dev/null 2>&1 || die "openssl not on PATH"
command -v python3 >/dev/null 2>&1 || die "python3 not on PATH"

gcloud auth print-access-token --project="${PROJECT_ID}" >/dev/null 2>&1 \
  || die "gcloud not authenticated for project ${PROJECT_ID}"

# ---------------------------------------------------------------------------
# Helpers (secrets stay in shell vars / pipes — not logged)
# ---------------------------------------------------------------------------

secret_has_version() {
  local secret_id="$1"
  local ver
  ver="$(gcloud secrets versions list "${secret_id}" \
    --project="${PROJECT_ID}" \
    --filter='state=ENABLED' \
    --limit=1 \
    --format='value(name)' 2>/dev/null || true)"
  [[ -n "${ver}" ]]
}

add_secret_version() {
  local secret_id="$1"
  local value="$2"
  local force_this="${3:-0}"

  if ! gcloud secrets describe "${secret_id}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    die "secret container '${secret_id}' does not exist — apply Terraform first"
  fi

  if secret_has_version "${secret_id}"; then
    if [[ "${secret_id}" == "paperclip-secrets-master-key" ]]; then
      if [[ "${FORCE}" -eq 1 ]]; then
        if [[ "${DESTROY_MASTER_ACK}" -ne 1 ]]; then
          cat >&2 <<'EOF'
error: refusing to overwrite paperclip-secrets-master-key.

Overwriting it without re-encrypting every company secret stored by Paperclip
makes those secrets permanently undecryptable.

Re-run with BOTH:
  --force
  --i-understand-this-destroys-all-stored-secrets
EOF
          return 1
        fi
        # fall through and add a new version
      else
        info "skip (already has a version): ${secret_id}  (pass --force + destruction ack to overwrite)"
        return 0
      fi
    elif [[ "${FORCE}" -ne 1 && "${force_this}" -ne 1 ]]; then
      info "skip (already has a version): ${secret_id}  (pass --force to overwrite)"
      return 0
    fi
  fi

  # Pipe value — never write a tempfile with secret contents.
  local version
  version="$(printf '%s' "${value}" | gcloud secrets versions add "${secret_id}" \
    --project="${PROJECT_ID}" \
    --data-file=- \
    --format='value(name)')"
  info "seeded ${secret_id} → ${version}"
}

rand_hex_32() { openssl rand -hex 32; }
rand_b64_32() { openssl rand -base64 32 | tr -d '\n'; }

prompt_secret() {
  local prompt="$1"
  local value=""
  if [[ -t 0 ]]; then
    read -r -s -p "${prompt}: " value
    printf '\n' >&2
  else
    die "refusing to prompt on non-TTY for: ${prompt}"
  fi
  printf '%s' "${value}"
}

compose_database_url() {
  local password="$1"
  DB_USER="${DB_USER}" DB_NAME="${DB_NAME}" PRIVATE_IP="${PRIVATE_IP}" \
    PASSWORD="${password}" python3 -c '
import os, urllib.parse
user = os.environ["DB_USER"]
name = os.environ["DB_NAME"]
ip = os.environ["PRIVATE_IP"]
pw = urllib.parse.quote(os.environ["PASSWORD"], safe="")
print(f"postgresql://{user}:{pw}@{ip}:5432/{name}?sslmode=require")
'
}

seed_litellm_master_key() {
  local required="${1:-1}"
  if ! gcloud secrets describe "litellm-master-key" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    if [[ "${required}" -eq 1 ]]; then
      die "secret container 'litellm-master-key' does not exist — apply Terraform first (Phase 2.3)"
    fi
    info "skip: litellm-master-key (container not created yet)"
    return 0
  fi
  log "Seeding litellm-master-key (value not printed)"
  add_secret_version "litellm-master-key" "sk-$(openssl rand -hex 24)"
}

if [[ "${GATEWAY_ONLY}" -eq 1 ]]; then
  seed_litellm_master_key 1
  log "Done. Only secret names/versions were printed above — no secret values."
  info "Next: dispatch gateway-build, merge the digest pin, approve Environment dev."
  info "Do not paste the master key into chat. Paperclip will read it in Phase 2.4."
  exit 0
fi

# ---------------------------------------------------------------------------
# Resolve DB password + HMAC
# ---------------------------------------------------------------------------

if [[ -n "${FROM_TERRAFORM}" ]]; then
  [[ -d "${FROM_TERRAFORM}" ]] || die "--from-terraform directory not found: ${FROM_TERRAFORM}"
  command -v terraform >/dev/null 2>&1 || die "terraform not on PATH (needed for --from-terraform)"
  log "Reading sensitive outputs from ${FROM_TERRAFORM} (not printed)"
  DB_PASSWORD="$(cd "${FROM_TERRAFORM}" && terraform output -raw db_password)"
  [[ -n "${DB_PASSWORD}" ]] || die "terraform output db_password was empty"
  # HMAC may be null when create_hmac_key=false
  HMAC_ACCESS_ID="$(cd "${FROM_TERRAFORM}" && terraform output -raw hmac_access_id 2>/dev/null || true)"
  if [[ "${HMAC_ACCESS_ID}" == "null" ]]; then HMAC_ACCESS_ID=""; fi
  if [[ -n "${HMAC_ACCESS_ID}" ]]; then
    HMAC_SECRET="$(cd "${FROM_TERRAFORM}" && terraform output -raw hmac_secret)"
  fi
fi

DB_PASSWORD="${DB_PASSWORD:-${PAPERCLIP_DB_PASSWORD:-}}"
HMAC_ACCESS_ID="${HMAC_ACCESS_ID:-${PAPERCLIP_GCS_HMAC_ACCESS_ID:-}}"
HMAC_SECRET="${HMAC_SECRET:-${PAPERCLIP_GCS_HMAC_SECRET:-}}"

if [[ -z "${DB_PASSWORD}" ]]; then
  if [[ -t 0 ]]; then
    log "Enter the Cloud SQL app password (must match the terraform-managed user)"
    DB_PASSWORD="$(prompt_secret "DB password")"
  else
    die "DB password required via --from-terraform or PAPERCLIP_DB_PASSWORD"
  fi
fi
[[ -n "${DB_PASSWORD}" ]] || die "DB password is empty"

if [[ -z "${HMAC_ACCESS_ID}" || -z "${HMAC_SECRET}" ]]; then
  if [[ -t 0 ]]; then
    log "GCS HMAC (leave blank to skip if you will seed later)"
    HMAC_ACCESS_ID="$(prompt_secret "HMAC access id (AWS_ACCESS_KEY_ID)")"
    if [[ -n "${HMAC_ACCESS_ID}" ]]; then
      HMAC_SECRET="$(prompt_secret "HMAC secret (AWS_SECRET_ACCESS_KEY)")"
    fi
  else
    info "HMAC not provided — skipping paperclip-gcs-hmac-* (set via --from-terraform or env)"
  fi
fi

DATABASE_URL="$(compose_database_url "${DB_PASSWORD}")"

# ---------------------------------------------------------------------------
# Seed
# ---------------------------------------------------------------------------

log "Seeding secrets in project ${PROJECT_ID}"

add_secret_version "paperclip-db-password" "${DB_PASSWORD}"
add_secret_version "paperclip-database-url" "${DATABASE_URL}"

add_secret_version "paperclip-better-auth-secret" "$(rand_hex_32)"
add_secret_version "paperclip-tool-action-signing-secret" "$(rand_hex_32)"
add_secret_version "paperclip-agent-jwt-secret" "$(rand_hex_32)"
add_secret_version "paperclip-decision-signing-secret" "$(rand_hex_32)"

had_master=0
secret_has_version "paperclip-secrets-master-key" && had_master=1
add_secret_version "paperclip-secrets-master-key" "$(rand_b64_32)"
if [[ "${had_master}" -eq 0 ]] || { [[ "${FORCE}" -eq 1 ]] && [[ "${DESTROY_MASTER_ACK}" -eq 1 ]]; }; then
  cat <<EOF
    IMPORTANT: Back up paperclip-secrets-master-key to your password manager NOW.
    Retrieve it once with (this prints the secret):

      gcloud secrets versions access latest \\
        --secret=paperclip-secrets-master-key \\
        --project=${PROJECT_ID}

    Losing or casually rotating this key makes every Paperclip-encrypted company
    secret permanently undecryptable.
EOF
fi

if [[ -n "${HMAC_ACCESS_ID}" && -n "${HMAC_SECRET}" ]]; then
  add_secret_version "paperclip-gcs-hmac-access-key" "${HMAC_ACCESS_ID}"
  add_secret_version "paperclip-gcs-hmac-secret" "${HMAC_SECRET}"
else
  info "skip: paperclip-gcs-hmac-access-key / paperclip-gcs-hmac-secret (no HMAC material)"
fi

if [[ "${SKIP_PROVIDER_KEYS}" -eq 0 ]]; then
  log "Provider keys (Phase 2+) — blank skips"
  anth="$(prompt_secret "ANTHROPIC_API_KEY (optional)")"
  [[ -n "${anth}" ]] && add_secret_version "paperclip-anthropic-api-key" "${anth}"
  oai="$(prompt_secret "OPENAI_API_KEY (optional)")"
  [[ -n "${oai}" ]] && add_secret_version "paperclip-openai-api-key" "${oai}"
  gh="$(prompt_secret "GITHUB_TOKEN (optional)")"
  [[ -n "${gh}" ]] && add_secret_version "paperclip-github-token" "${gh}"
else
  info "skip: provider API keys (default). Pass --with-provider-keys to prompt."
fi

seed_litellm_master_key 0

log "Done. Only secret names/versions were printed above — no secret values."
info "Next: set PAPERCLIP_PUBLIC_URL, run image-promote, approve Environment dev apply, then auth-bootstrap job."
