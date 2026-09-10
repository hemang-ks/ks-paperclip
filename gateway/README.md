# LLM gateway

LiteLLM (and related config) for Phase 2. Not wired in Phase 1.

| Path | Purpose |
|---|---|
| `config/` | LiteLLM model / alias config (filled in Phase 2) |

Provider keys stay in Secret Manager and are mounted on the gateway service, not
on Paperclip.
