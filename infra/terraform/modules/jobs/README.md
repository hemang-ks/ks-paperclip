# Jobs module — `paperclip-auth-bootstrap`

One-shot Cloud Run Job that mints the first-admin invite for `authenticated` /
`public` mode. Browser self-claim is disabled; see `local/FINDINGS-L3.md`.

## What it does

1. Writes `config.json` at `$PAPERCLIP_CONFIG` with `"$meta.source": "configure"`
   (CLI requires the file; the server alone never creates it).
2. Runs `pnpm paperclipai auth bootstrap-ceo --base-url $PAPERCLIP_PUBLIC_URL`.
3. Prints the invite URL to stdout → Cloud Logging.

No migrate Job here — cost-optimized v1 uses auto-migrate on the service.

## Execute

```bash
gcloud run jobs execute paperclip-auth-bootstrap \
  --region="$GCP_REGION" \
  --project="$GCP_PROJECT_ID" \
  --wait
```

Retrieve the invite URL:

```bash
gcloud logging read \
  'resource.type="cloud_run_job" AND resource.labels.job_name="paperclip-auth-bootstrap"' \
  --project="$GCP_PROJECT_ID" \
  --limit=50 \
  --format='value(textPayload)'
```

See `docs/runbook.md` → First admin bootstrap.
