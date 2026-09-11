#!/usr/bin/env bash
# Build the LiteLLM gateway image and push it to Artifact Registry.
# Prints the immutable sha256 digest. Tags are never used in Terraform.
#
# Usage:
#   scripts/build-gateway.sh --project-id ID --region REGION
#
# Optional:
#   --repository REPO     AR repository id (default: paperclip)
#   --image-name NAME     Image name inside the repo (default: litellm)
#   --tag TAG             Push tag (default: git short SHA or "dev")
#   --github-output       Also write digest/digest_ref to $GITHUB_OUTPUT
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-${GCP_PROJECT_ID:-}}"
REGION="${REGION:-${GCP_REGION:-}}"
REPOSITORY="paperclip"
IMAGE_NAME="litellm"
TAG=""
EMIT_GITHUB_OUTPUT=0

usage() {
  cat <<'EOF'
Usage: scripts/build-gateway.sh --project-id ID --region REGION [options]

Build gateway/Dockerfile (linux/amd64) and push to
  REGION-docker.pkg.dev/PROJECT/paperclip/litellm:<tag>
then print the immutable digest.

Options:
  --project-id PROJECT_ID
  --region REGION
  --repository REPO     (default: paperclip)
  --image-name NAME     (default: litellm)
  --tag TAG             (default: git short SHA)
  --github-output
  -h, --help
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --project-id|--project)
      [[ $# -ge 2 ]] || die "missing value for $1"
      PROJECT_ID="$2"; shift 2 ;;
    --region)
      [[ $# -ge 2 ]] || die "missing value for $1"
      REGION="$2"; shift 2 ;;
    --repository)
      [[ $# -ge 2 ]] || die "missing value for $1"
      REPOSITORY="$2"; shift 2 ;;
    --image-name)
      [[ $# -ge 2 ]] || die "missing value for $1"
      IMAGE_NAME="$2"; shift 2 ;;
    --tag)
      [[ $# -ge 2 ]] || die "missing value for $1"
      TAG="$2"; shift 2 ;;
    --github-output) EMIT_GITHUB_OUTPUT=1; shift ;;
    *) die "unknown argument: $1 (see --help)" ;;
  esac
done

[[ -n "${PROJECT_ID}" ]] || die "PROJECT_ID required"
[[ -n "${REGION}" ]] || die "REGION required"
command -v docker >/dev/null 2>&1 || die "docker not on PATH"
command -v gcloud >/dev/null 2>&1 || die "gcloud not on PATH"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "${ROOT}/gateway/Dockerfile" ]] || die "missing gateway/Dockerfile"

if [[ -z "${TAG}" ]]; then
  TAG="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo dev)"
fi

HOST="${REGION}-docker.pkg.dev"
DEST="${HOST}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}"
TAGGED="${DEST}:${TAG}"

gcloud auth configure-docker "${HOST}" --quiet --project="${PROJECT_ID}"

echo "==> docker build ${TAGGED} (linux/amd64)"
docker build \
  --platform linux/amd64 \
  -t "${TAGGED}" \
  -f "${ROOT}/gateway/Dockerfile" \
  "${ROOT}/gateway"

echo "==> docker push ${TAGGED}"
docker push "${TAGGED}"

DIGEST="$(gcloud artifacts docker images describe "${TAGGED}" \
  --project="${PROJECT_ID}" \
  --format='value(image_summary.digest)')"
[[ "${DIGEST}" == sha256:* ]] || die "could not resolve digest for ${TAGGED} (got: ${DIGEST})"

DIGEST_REF="${DEST}@${DIGEST}"
echo "digest=${DIGEST}"
echo "digest_ref=${DIGEST_REF}"

if [[ "${EMIT_GITHUB_OUTPUT}" -eq 1 ]]; then
  [[ -n "${GITHUB_OUTPUT:-}" ]] || die "--github-output requires \$GITHUB_OUTPUT"
  {
    echo "digest=${DIGEST}"
    echo "digest_ref=${DIGEST_REF}"
    echo "tag=${TAG}"
  } >> "${GITHUB_OUTPUT}"
fi
