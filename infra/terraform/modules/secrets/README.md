# Secrets module

Creates **Secret Manager containers**, replication, and per-secret IAM only.

**Never** puts plaintext values into Terraform. Seed with
`gcloud secrets versions add` or `scripts/seed-secrets.sh` (Phase 1.7).

## Critical: `paperclip-secrets-master-key`

Every company secret Paperclip stores is encrypted with this key. If it is lost or
rotated without a re-encryption plan, those secrets become **permanently
undecryptable**. This secret has `lifecycle.prevent_destroy`. Backup the seeded
value to a password manager. Exclude it from routine rotation.

## IAM

Each secret grants `roles/secretmanager.secretAccessor` to the runtime service
account passed into the module **individually** (no project-level Secret Manager
role). Instantiate twice if Paperclip and LiteLLM must not share provider keys.

## Default secret IDs

See `variables.tf` for the Paperclip list. Gateway secrets (`litellm-*`) are a
second module call in `envs/dev` (Phase 2.3). Model provider **values** stay
out of Terraform.
