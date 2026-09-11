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

## Custom domain (Squarespace + Cloud Run)

Cost-optimized v1 has **no ALB / Certificate Manager**. Use Cloud Run **domain
mapping** (Preview) so Google issues and renews HTTPS. Squarespace only holds DNS.

Example values used in this project:

| Item | Example |
|---|---|
| Registered domain | `legotick.com` (Squarespace) |
| Paperclip hostname | `paperclip.legotick.com` (prefer a subdomain over the apex) |
| `PAPERCLIP_PUBLIC_URL` | `https://paperclip.legotick.com` |
| Cloud Run service | `paperclip` |
| Region | `us-west1` |
| Project | `paperclip-ks-prod` |

Set the GitHub Actions variable before (or when) the service is applied:

```bash
gh variable set PAPERCLIP_PUBLIC_URL --body "https://paperclip.legotick.com"
```

Better Auth must see this exact HTTPS origin. Mapping region must match the service.

### Order of operations

1. Deploy Cloud Run `paperclip` (image pin + apply with `PAPERCLIP_PUBLIC_URL` set).
2. Verify ownership of the **base** domain (`legotick.com`) with Google.
3. Create the Cloud Run domain mapping for `paperclip.legotick.com`.
4. Add the DNS records Google prints into Squarespace.
5. Wait for the managed certificate (often ~15 minutes; can take hours).
6. Confirm `https://paperclip.legotick.com/api/health`, then run first-admin bootstrap
   against that URL.

You do **not** buy or install an SSL certificate in Squarespace for this path.

### 1. Verify domain ownership

Cloud Run refuses mappings until the domain is verified for the **same Google
account** you use with `gcloud`:

```text
ERROR: The provided domain does not appear to be verified for the current account.
```

Check:

```bash
gcloud domains list-user-verified
```

If `legotick.com` is missing, start verification (opens Search Console):

```bash
gcloud domains verify legotick.com
```

In Search Console, add a **Domain** property for `legotick.com` (verify the base
domain even if you only map a subdomain).

#### Squarespace TXT record

Search Console shows a value like `google-site-verification=...`.

Squarespace: **Domains → legotick.com → DNS → DNS Settings → Custom records → Add**

| Field | Value |
|---|---|
| Type | `TXT` |
| Host | `@` (root) |
| Data | full `google-site-verification=...` string |
| TTL | default |

Save, wait a few minutes, click **Verify** in Search Console. Re-check:

```bash
gcloud domains list-user-verified
```

Keep the verification TXT in place after success.

**Gotchas**

- `gcloud` user must be the verified Search Console owner (or added as an owner).
- Verify `legotick.com`, not `paperclip.legotick.com`.
- If the GCP project is under a different Google account than Search Console,
  re-verify with the project owner account or add that account as a verified owner.

### 2. Create the Cloud Run domain mapping

```bash
gcloud beta run domain-mappings create \
  --service=paperclip \
  --domain=paperclip.legotick.com \
  --region=us-west1 \
  --project=paperclip-ks-prod
```

Show the DNS records to add:

```bash
gcloud beta run domain-mappings describe \
  --domain=paperclip.legotick.com \
  --region=us-west1 \
  --project=paperclip-ks-prod
```

For a subdomain you usually get a **CNAME**, for example:

| Type | Host (Squarespace) | Data |
|---|---|---|
| `CNAME` | `paperclip` | `ghs.googlehosted.com.` |

Use **exactly** the `name` / `rrdata` / `type` from `describe`.

Check certificate / ready conditions:

```bash
gcloud beta run domain-mappings describe \
  --domain=paperclip.legotick.com \
  --region=us-west1 \
  --project=paperclip-ks-prod \
  --format='yaml(status.conditions)'
```

### 3. Squarespace DNS for the mapping

**Domains → legotick.com → DNS → Custom records → Add**

- Type: **CNAME** (or A/AAAA if Google asks for apex)
- Host: `paperclip` (not the FQDN)
- Data: value from `domain-mappings describe` (often `ghs.googlehosted.com`)
- Remove any conflicting `paperclip` A/CNAME records

**Apex (`legotick.com` only):** Google typically requires several **A** / **AAAA**
records on `@`. A subdomain is simpler on Squarespace.

### 4. HTTPS

After DNS is correct, Cloud Run provisions and renews a **Google-managed**
certificate automatically. No Squarespace SSL step.

Test:

```bash
curl -sS https://paperclip.legotick.com/api/health
```

If the cert stays pending: wrong DNS, slow propagation, or a **CAA** record on
`legotick.com` blocking `pki.goog` / Let’s Encrypt.

### Notes

- Domain mapping is **Preview** / limited availability. Google recommends a global
  HTTPS load balancer for stricter production needs; that is out of scope for the
  cost-optimized plan (no ALB).
- Mapping must be in the **same region** as the service (`us-west1` here).
- Official docs: [Mapping custom domains](https://cloud.google.com/run/docs/mapping-custom-domains).

## LiteLLM gateway (Phase 2.3)

Cloud Run service `litellm`. Internal ingress (not curl-able from a laptop).
Auth on `/v1/*` is `LITELLM_MASTER_KEY`. Provider keys stay on this service.

### Order

1. Merge the Phase 2.3 PR and approve Environment `dev`. First apply creates
   gateway **secret containers** (imports `litellm-gemini-api-key` if it already
   exists). Cloud Run `litellm` stays gated until the image digest is real.
2. Seed the gateway master key (does not print the value):

   ```bash
   ./scripts/seed-secrets.sh --project-id "$GCP_PROJECT_ID" --gateway-only
   ```

3. Dispatch **gateway-build** (Actions). Merge the digest-pin PR it opens.
4. Approve Environment `dev` again. That apply creates Cloud Run `litellm`.
5. Confirm:

   ```bash
   gcloud run services describe litellm \
     --region="$GCP_REGION" \
     --project="$GCP_PROJECT_ID" \
     --format='value(status.url,status.conditions)'
   ```

   The URL is internal. Do not expect `curl` from your laptop to succeed.
   Paperclip in the same project can reach it (Phase 2.4 adapter).

### Change a model without touching agents

Edit `gateway/config/config.yaml` (`litellm_params.model` under `worker` /
`reasoning` / `premium`), then gateway-build → pin PR → apply.

### `premium` / Anthropic

If `litellm-anthropic-api-key` has an enabled version, CI sets
`litellm_mount_anthropic=true`. Until then, `premium` calls fail; `worker` and
`reasoning` still work.
