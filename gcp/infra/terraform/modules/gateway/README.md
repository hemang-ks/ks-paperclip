# Gateway module — Cloud Run `litellm`

LiteLLM proxy. Provider keys stay on this service.

## Settings

| Setting | Value | Why |
|---|---|---|
| Ingress | `ALL` | Paperclip `PRIVATE_RANGES_ONLY` sends `*.run.app` to the public frontend; `INTERNAL_ONLY` 404s. Not anonymous — `LITELLM_MASTER_KEY` is required. |
| Invoker IAM | disabled | Paperclip HTTP/OpenAI adapter sends `Authorization: Bearer <LITELLM_MASTER_KEY>`. A GCP identity token would collide on that header. |
| Min instances | **0** | No heartbeat scheduler. Scale-to-zero is fine. |
| CPU idle | true | Proxy; no always-on loop. |
| Memory / CPU | 1Gi / 1 | Proxy, not the Paperclip control plane. |
| Port | **4000** | LiteLLM default. Do not set `PORT` in env. |
| Probes | `/health/liveliness` | Unauthenticated, no provider calls. |

Image must be a **digest** reference (`…@sha256:…`).

## Secrets

Always mounted: `GEMINI_API_KEY`, `LITELLM_MASTER_KEY`.

`ANTHROPIC_API_KEY` only when `mount_anthropic=true` **and** the secret has an
enabled version (Cloud Run will not start if `secret_key_ref` points at an
empty secret).
