# Storage module

GCS uploads bucket for Paperclip's S3-compatible storage provider, plus a
**bucket-scoped** HMAC service account.

## App env vars

```text
PAPERCLIP_STORAGE_PROVIDER=s3
PAPERCLIP_STORAGE_S3_BUCKET=<bucket>
PAPERCLIP_STORAGE_S3_ENDPOINT=https://storage.googleapis.com
PAPERCLIP_STORAGE_S3_FORCE_PATH_STYLE=true
PAPERCLIP_STORAGE_S3_REGION=<must match bucket location for SigV4>
PAPERCLIP_STORAGE_S3_PREFIX=uploads
AWS_ACCESS_KEY_ID=<hmac access id>
AWS_SECRET_ACCESS_KEY=<hmac secret>
```

## HMAC and Terraform state

Default: `create_hmac_key = false` (no HMAC secret in Terraform state).

Create out-of-band after the HMAC service account and bucket exist:

```bash
# List the HMAC SA email from terraform output hmac_service_account_email,
# or: paperclip-gcs-hmac@$PROJECT_ID.iam.gserviceaccount.com
gcloud storage hmac create EMAIL \
  --project="$PROJECT_ID"
```

Seed `paperclip-gcs-hmac-access-key` / `paperclip-gcs-hmac-secret` via
`scripts/seed-secrets.sh` (prompts if not using `--from-terraform`).

Set `create_hmac_key = true` only if the deployer has `roles/storage.hmacKeyAdmin`
(bootstrap grants it) and you accept the secret living in state.

## IAM

HMAC SA gets `roles/storage.objectAdmin` **on this bucket only** — no project-level
storage admin.
