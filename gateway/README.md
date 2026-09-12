# LLM gateway (LiteLLM)

Paperclip calls this OpenAI-compatible proxy. Provider keys stay here (Secret
Manager → Cloud Run), not on Paperclip.

## Aliases

| Alias | Upstream (change here) | Role |
|---|---|---|
| `worker` | `gemini/gemini-2.5-flash` | Default / cheap |
| `reasoning` | `gemini/gemini-2.5-pro` | Harder questions |
| `premium` | `anthropic/claude-sonnet-4-5` | Escalation only |
| `gemini-2.5-flash-lite` / `gemini-2.5-flash` / `gemini-2.5-pro` | same Gemini models | Native IDs from Gemini CLI / Paperclip `cheap` profile |

Paperclip agents should use the alias names when the UI allows a custom model.
The Gemini CLI dropdown and Paperclip's default `cheap` wake profile send native
IDs instead; those are listed so the proxy does not 404.

To swap a provider model, edit `config/config.yaml`, run **gateway-build**, merge
the digest pin, approve Environment `dev`.

`premium` needs `litellm-anthropic-api-key` seeded **and** an enabled secret
version (CI sets `litellm_mount_anthropic=true` when that version exists).
Until then, `premium` calls fail; `worker` / `reasoning` still work.

## Auth and exposure

- `LITELLM_MASTER_KEY` is required on every `/v1/*` call (`Authorization: Bearer …`).
- Ingress is **internal** (same GCP project). The internet cannot reach the
  service. Cloud Run invoker IAM is disabled so Paperclip’s HTTP/OpenAI adapter
  can send the master key in `Authorization` (GCP identity tokens would collide
  with that header).
- Probe paths `/health/liveliness` and `/health/readiness` are unauthenticated
  by LiteLLM design; they do not call providers.

Do not grant `allUsers`. Do not put Gemini/Anthropic keys on Paperclip.

## How Paperclip calls this gateway

Pinned Paperclip (`sha-e55d702`) has no OpenAI-compatible adapter. The built-in
`http` type is a webhook, not `/v1/chat/completions`.

**Reuse `gemini_local`.** Cloud Run `paperclip` has `GOOGLE_GEMINI_BASE_URL`
(this service), `GEMINI_API_KEY` set to the LiteLLM master key, plus Gemini CLI
`settings.json` selecting `gemini-api-key` and `GEMINI_CLI_TRUST_WORKSPACE=true`.
Point a test agent at engine `cli` (see `docs/runbook.md`).

## Image

Dockerfile bakes `config/config.yaml` onto `ghcr.io/berriai/litellm:v1.76.1-stable`.

```bash
# CI: dispatch `.github/workflows/gateway-build.yml` (WIF, push to Artifact Registry, pin PR)
./scripts/build-gateway.sh --project-id "$GCP_PROJECT_ID" --region "$GCP_REGION"
```

Cloud Run uses `…/paperclip/litellm@sha256:…` from `litellm_image_digest`.

## Secrets

| Secret | Env on LiteLLM | Who seeds |
|---|---|---|
| `litellm-gemini-api-key` | `GEMINI_API_KEY` | You (2.2) |
| `litellm-master-key` | `LITELLM_MASTER_KEY` | `scripts/seed-secrets.sh --gateway-only` |
| `litellm-anthropic-api-key` | `ANTHROPIC_API_KEY` | You (optional) |

Terraform creates/imports **containers** only. Values never go in `.tfvars`.

After the first Phase 2 apply (containers exist, Cloud Run still gated on the
image pin):

```bash
./scripts/seed-secrets.sh --project-id "$GCP_PROJECT_ID" --gateway-only
```
