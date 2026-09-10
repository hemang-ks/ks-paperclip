# `dev` Terraform root

Single environment for ks-paperclip (cost-optimized plan).

## What this root creates (Phase 1.2)

- Required GCP APIs (re-asserted; bootstrap already enabled them)
- Runtime SAs: `paperclip-runtime`, `litellm-runtime` (placeholder for Phase 2)
- VPC + `/26` subnet + PSA (no Cloud NAT)
- Private Cloud SQL PostgreSQL 17
- Artifact Registry `paperclip`
- Secret Manager **containers** (no values)
- GCS uploads bucket (+ optional HMAC key)

Cloud Run service / bootstrap job: Phase 1.4–1.5. Both are created when a real
image digest **and** `paperclip_public_url` are set (same gate).

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

Uses the Terraform-managed DB password and HMAC (if created). Does not print
secret values. Back up `paperclip-secrets-master-key` via
`gcloud secrets versions access` immediately after first seed.

Provider API keys are skipped by default (`--with-provider-keys` for Phase 2).

## Image pin

`paperclip_image_digest` (and schema label fields) live in
`terraform.tfvars.example` and are updated by `.github/workflows/image-promote.yml`.
Deploy config must use the digest, never a mutable tag.
