# `dev` Terraform root

Single environment for ks-paperclip (cost-optimized plan).

## What this root creates (Phase 1.2)

- Required GCP APIs (re-asserted; bootstrap already enabled them)
- Runtime SAs: `paperclip-runtime`, `litellm-runtime`
- VPC + `/26` subnet + PSA (no Cloud NAT)
- Private Cloud SQL PostgreSQL 17
- Artifact Registry `paperclip`
- Secret Manager **containers** (no values) — Paperclip list plus LiteLLM gateway list
- GCS uploads bucket (+ optional HMAC key)

Cloud Run `paperclip` / bootstrap job: Phase 1.4–1.5. Created when a real
image digest **and** `paperclip_public_url` are set (same gate).

Cloud Run `litellm`: Phase 2.3. Created when `litellm_image_digest` is a real
sha256 (after `gateway-build`). Ingress is internal; `LITELLM_MASTER_KEY` is
required on `/v1/*`.

## Apply path

GitHub Actions only. You approve Environment `dev`. Do **not** run
`terraform apply` from a laptop.

Backend bucket = `TF_STATE_BUCKET` from bootstrap. Prefix: `paperclip/dev`.

## Local validate (no backend / no apply)

```bash
cd infra/terraform/envs/dev
terraform init -backend=false
terraform validate
```

## Seed secrets (1.7)

After the first Terraform apply (secret **containers** + Cloud SQL exist):

```bash
cd infra/terraform/envs/dev
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
PRIVATE_IP="$(terraform output -raw cloud_sql_private_ip)"

cd ../../../../
./scripts/seed-secrets.sh \
  --project-id "$GCP_PROJECT_ID" \
  --private-ip "$PRIVATE_IP" \
  --from-terraform infra/terraform/envs/dev
```

Uses the Terraform-managed DB password. HMAC defaults to out-of-band: after apply,
create a key for `paperclip-gcs-hmac@…` with `gcloud storage hmac create`, then let
`seed-secrets.sh` prompt for the pair (or set `PAPERCLIP_GCS_HMAC_*` env vars).

Provider API keys for **Paperclip** are skipped by default (`--with-provider-keys`).
Phase 2 provider keys live on LiteLLM (`litellm-gemini-api-key`, optional
`litellm-anthropic-api-key`). After the Phase 2 apply creates gateway secret
**containers**:

```bash
./scripts/seed-secrets.sh --project-id "$GCP_PROJECT_ID" --gateway-only
```

That seeds `litellm-master-key` only. Dispatch `gateway-build` (or merge its pin
PR) so `litellm_image_digest` is real, then approve Environment `dev`. Seed the
master key **before** that apply or Cloud Run `litellm` will fail to start.

## Image pin

`paperclip_image_digest` (and schema label fields) live in
`terraform.tfvars.example` and are updated by `.github/workflows/image-promote.yml`.
`litellm_image_digest` is updated by `.github/workflows/gateway-build.yml`.
Deploy config must use the digest, never a mutable tag.
