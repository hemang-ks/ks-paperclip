#!/usr/bin/env bash
# Mirror Paperclip from public GHCR into Artifact Registry and resolve an
# immutable digest. Tags are never used in deploy config — digests are.
#
# Upstream facts:
#   - ghcr.io/paperclipai/paperclip is public (anonymous pull works)
#   - No version tags on GHCR; use sha-<short> (pin: sha-e55d702 = v2026.722.0)
#   - OCI labels io.github.paperclipai.schema.last-migration and
#     io.github.paperclipai.schema.migration-count for schema gating
set -euo pipefail

DEFAULT_SOURCE_REF="sha-e55d702"
SOURCE_REGISTRY="ghcr.io/paperclipai/paperclip"
SOURCE_REF="${DEFAULT_SOURCE_REF}"
PROJECT_ID="${PROJECT_ID:-${GCP_PROJECT_ID:-}}"
REGION="${REGION:-${GCP_REGION:-}}"
REPOSITORY="paperclip"
IMAGE_NAME="paperclip"
VERSION_LABEL=""
GITHUB_OUTPUT_FILE="${GITHUB_OUTPUT:-}"
BUILD_FROM_SOURCE=0
EMIT_GITHUB_OUTPUT=0

usage() {
  cat <<'EOF'
Usage: scripts/promote-image.sh [options]

Mirror ghcr.io/paperclipai/paperclip:<ref> →
  REGION-docker.pkg.dev/PROJECT/paperclip/paperclip:<version-label>
and print the immutable sha256 digest + schema labels.

Options:
  --project-id PROJECT_ID     GCP project (or PROJECT_ID / GCP_PROJECT_ID)
  --region REGION             Artifact Registry region (or REGION / GCP_REGION)
  --source-ref REF            GHCR tag (default: sha-e55d702)
  --repository REPO           AR repository id (default: paperclip)
  --image-name NAME           Image name inside the repo (default: paperclip)
  --version-label LABEL       Destination tag (default: same as --source-ref)
  --github-output             Also write digest/labels to $GITHUB_OUTPUT
  --build-from-source         Document the source-build fallback and exit 2
  -h, --help                  Show this help

Requires: crane (https://github.com/google/go-containerregistry/blob/main/cmd/crane)
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_crane() {
  if command -v crane >/dev/null 2>&1; then
    return 0
  fi
  cat >&2 <<'EOF'
error: crane is not installed or not on PATH.

Install (pick one):
  # Homebrew
  brew install crane

  # Go
  go install github.com/google/go-containerregistry/cmd/crane@latest

  # GitHub release binary
  # https://github.com/google/go-containerregistry/releases

crane does a registry-to-registry copy (fast, preserves multi-arch index).
Do not docker pull/push for promotion.
EOF
  exit 1
}

build_from_source_docs() {
  cat <<'EOF'
--build-from-source is a documented fallback only; this script does not build.

When you need the upstream Dockerfile `--target cloud` variant (Daytona / managed
sandbox plugins), upstream does NOT publish release-commit tags for it. You would:

  1. Clone https://github.com/paperclipai/paperclip at the desired commit
  2. docker buildx build --target cloud -t LOCAL_TAG .
  3. Push LOCAL_TAG to Artifact Registry
  4. Resolve digest with: crane digest REGION-docker.pkg.dev/PROJECT/paperclip/paperclip:TAG
  5. Pin that digest in infra/terraform/envs/dev (image-promote PR flow)

Default path remains: crane copy from public GHCR sha-* tags. Prefer that.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --project-id|--project)
      [[ $# -ge 2 ]] || die "missing value for $1"
      PROJECT_ID="$2"; shift 2 ;;
    --project-id=*|--project=*) PROJECT_ID="${1#*=}"; shift ;;
    --region)
      [[ $# -ge 2 ]] || die "missing value for $1"
      REGION="$2"; shift 2 ;;
    --region=*) REGION="${1#*=}"; shift ;;
    --source-ref)
      [[ $# -ge 2 ]] || die "missing value for $1"
      SOURCE_REF="$2"; shift 2 ;;
    --source-ref=*) SOURCE_REF="${1#*=}"; shift ;;
    --repository)
      [[ $# -ge 2 ]] || die "missing value for $1"
      REPOSITORY="$2"; shift 2 ;;
    --repository=*) REPOSITORY="${1#*=}"; shift ;;
    --image-name)
      [[ $# -ge 2 ]] || die "missing value for $1"
      IMAGE_NAME="$2"; shift 2 ;;
    --image-name=*) IMAGE_NAME="${1#*=}"; shift ;;
    --version-label)
      [[ $# -ge 2 ]] || die "missing value for $1"
      VERSION_LABEL="$2"; shift 2 ;;
    --version-label=*) VERSION_LABEL="${1#*=}"; shift ;;
    --github-output) EMIT_GITHUB_OUTPUT=1; shift ;;
    --build-from-source) BUILD_FROM_SOURCE=1; shift ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

if [[ "${BUILD_FROM_SOURCE}" -eq 1 ]]; then
  build_from_source_docs
fi

[[ -n "${PROJECT_ID}" ]] || die "PROJECT_ID required (--project-id)"
[[ -n "${REGION}" ]] || die "REGION required (--region)"
[[ -n "${SOURCE_REF}" ]] || die "source ref must not be empty"
VERSION_LABEL="${VERSION_LABEL:-${SOURCE_REF}}"

need_crane

SRC="${SOURCE_REGISTRY}:${SOURCE_REF}"
DST="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${VERSION_LABEL}"

printf '==> Copying %s\n' "${SRC}"
printf '         → %s\n' "${DST}"

crane copy "${SRC}" "${DST}"

DIGEST="$(crane digest "${DST}")"
[[ "${DIGEST}" == sha256:* ]] || die "unexpected digest from crane: ${DIGEST}"

CONFIG_JSON="$(crane config "${DST}")"
read -r SCHEMA_LAST SCHEMA_COUNT < <(
  printf '%s' "${CONFIG_JSON}" | python3 -c '
import json, sys
c = json.load(sys.stdin)
cfg = c.get("config", {})
labels = cfg.get("Labels") or cfg.get("labels") or {}
last = labels.get("io.github.paperclipai.schema.last-migration", "")
count = labels.get("io.github.paperclipai.schema.migration-count", "")
print(last, count)
'
)

DIGEST_REF="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}@${DIGEST}"

printf '\n==> Promoted\n'
printf '    source_ref:              %s\n' "${SOURCE_REF}"
printf '    destination_tag:         %s\n' "${DST}"
printf '    digest:                  %s\n' "${DIGEST}"
printf '    digest_ref:              %s\n' "${DIGEST_REF}"
printf '    schema.last-migration:   %s\n' "${SCHEMA_LAST:-"(none)"}"
printf '    schema.migration-count:  %s\n' "${SCHEMA_COUNT:-"(none)"}"

JSON="$(SOURCE_REF="${SOURCE_REF}" DST="${DST}" DIGEST="${DIGEST}" DIGEST_REF="${DIGEST_REF}" \
  SCHEMA_LAST="${SCHEMA_LAST}" SCHEMA_COUNT="${SCHEMA_COUNT}" python3 -c '
import json, os
print(json.dumps({
  "source_ref": os.environ["SOURCE_REF"],
  "destination_tag": os.environ["DST"],
  "digest": os.environ["DIGEST"],
  "digest_ref": os.environ["DIGEST_REF"],
  "schema_last_migration": os.environ.get("SCHEMA_LAST", ""),
  "schema_migration_count": os.environ.get("SCHEMA_COUNT", ""),
}, indent=2))
')"

printf '\n%s\n' "${JSON}"

if [[ "${EMIT_GITHUB_OUTPUT}" -eq 1 ]]; then
  [[ -n "${GITHUB_OUTPUT_FILE}" ]] || die "--github-output set but GITHUB_OUTPUT is empty"
  {
    echo "source_ref=${SOURCE_REF}"
    echo "destination_tag=${DST}"
    echo "digest=${DIGEST}"
    echo "digest_ref=${DIGEST_REF}"
    echo "schema_last_migration=${SCHEMA_LAST}"
    echo "schema_migration_count=${SCHEMA_COUNT}"
  } >> "${GITHUB_OUTPUT_FILE}"
fi
