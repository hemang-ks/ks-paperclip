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

`google_storage_hmac_key` writes the secret into **Terraform state**. Keep the
state bucket private with restricted IAM (bootstrap already does this).

Prefer `create_hmac_key = false` if you want zero HMAC material in state: create
the key with `gcloud storage hmac create`, then seed
`paperclip-gcs-hmac-access-key` / `paperclip-gcs-hmac-secret` out of band.

## IAM

HMAC SA gets `roles/storage.objectAdmin` **on this bucket only** — no project-level
storage admin.
