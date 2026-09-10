# Runbook

Operational procedures for ks-paperclip. Task checklist stays in [`STATUS.md`](../STATUS.md).

## First admin bootstrap

`authenticated` / `public` disables browser self-claim. You must mint a one-time
invite via the `paperclip-auth-bootstrap` Cloud Run Job (verified in
`local/FINDINGS-L3.md`).

### Prerequisites

- Cloud Run service `paperclip` is up and healthy
- Secret values seeded with `scripts/seed-secrets.sh` (especially
  `paperclip-database-url` and auth secrets)
- Image digest pinned and jobs module applied

### Execute the job

```bash
gcloud run jobs execute paperclip-auth-bootstrap \
  --region="$GCP_REGION" \
  --project="$GCP_PROJECT_ID" \
  --wait
```

### Find the invite URL

```bash
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="paperclip-auth-bootstrap"' \
  --project="$GCP_PROJECT_ID" \
  --limit=50 \
  --format='value(textPayload)'
```

Open the invite URL in a browser, create the admin account, finish setup.

### Lock down signup

After the first admin exists, set `paperclip_auth_disable_sign_up = true` in
Terraform vars and apply (Environment `dev`) so
`PAPERCLIP_AUTH_DISABLE_SIGN_UP=true` on the next revision. Invite accept still
works when signup is disabled.

### Fallback

If the job fails (CLI/config issues), check job logs first and re-run — the job is
idempotent enough to mint another invite while `bootstrap_pending`. Do **not** rely
on raw UI signup without an invite (L3: signup without invite does not grant
`instance_admin`).

Cloud Armor / private-exposure fallbacks from the older plan are out of scope for
the cost-optimized deploy (no ALB).

## Schema / image rollback

Migrations are **forward-only** (service auto-migrates on boot). Rolling Cloud Run
traffic back to a previous revision does **not** reverse schema. If a bad image
ships a migration, fix forward or restore Cloud SQL from backup and consult this
runbook before re-applying.
