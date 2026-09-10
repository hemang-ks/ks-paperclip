# Service module — Cloud Run `paperclip`

Stateless Paperclip control plane on Cloud Run v2.

## Hard requirements (do not “optimize” away)

| Setting | Value | Why |
|---|---|---|
| `min` / `max` instances | **1 / 1** | Heartbeat scheduler has no leader election; WebSocket state is per-process. Correctness, not cost. |
| CPU always allocated | `cpu_idle = false` | Scheduler is `setInterval`; throttled CPU freezes agents between requests. |
| Memory | **4Gi** | Local L7 peak ~2 GiB; keep headroom. |
| CPU | **1** (default) | Cost-optimized plan / STATUS 1.4 (upstream AWS ref used 2). |
| Timeout | **3600s** | Live-event WebSockets. |
| VPC egress | `PRIVATE_RANGES_ONLY` | Private IP to Cloud SQL; public HTTPS exits Cloud Run (no NAT). |
| Migrations | `PAPERCLIP_MIGRATION_AUTO_APPLY=true` | Cost-optimized v1; no dedicated migrate Job. |

Image must be a **digest** reference (`…@sha256:…`), never a tag.

Do **not** set `PAPERCLIP_TRUSTED_MCP_RUNTIME_HOST` — local stdio MCP stays fail-closed.

## Secrets vs plain env

Secret Manager (`value_source.secret_key_ref`): `DATABASE_URL`, auth/signing secrets,
master key, GCS HMAC pair.

Plain: deployment mode/URLs, storage endpoint/bucket/region, heartbeat, auto-migrate.

Optional provider keys (`ANTHROPIC_API_KEY`, etc.) are off by default in Phase 1 —
agents go through LiteLLM in Phase 2.

## Public access

`allow_unauthenticated=true` sets `invoker_iam_disabled` (no `allUsers` IAM). Paperclip’s
Better Auth is the real gate.
