# Database module

Cloud SQL **PostgreSQL 17**, private IP only, backups + PITR.

## DATABASE_URL shape

Paperclip uses postgres.js as `postgres(url)` with **no options object**. Every
parameter must be in the URL:

```text
postgresql://paperclip:<pw>@<private-ip>:5432/paperclip?sslmode=require
```

Never put the password in Terraform outputs. Compose `paperclip-database-url` when
seeding Secret Manager (after apply, using the private IP output).

## Tier

| Tier | Notes |
|---|---|
| `db-custom-1-3840` (default) | 1 vCPU / 3.75 GiB — fine for personal/dev. Requires `edition = ENTERPRISE`. |
| `db-g1-small` | Cheaper shared-core option if you want to cut cost further |

Provider defaults can pick **ENTERPRISE_PLUS**, which rejects `db-custom-*`. This module
sets `edition = ENTERPRISE` explicitly.

## Inputs / outputs

See `variables.tf` / `outputs.tf`. On the root module, set
`depends_on = [module.network]` so PSA peering exists before the instance is created.
