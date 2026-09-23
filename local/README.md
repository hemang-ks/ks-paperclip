# Local Paperclip (Mac Mini)

Durable Docker Compose deploy for day-to-day use on the Mini. Named volumes keep
Postgres, MinIO, and Paperclip home (`/paperclip`) across restarts — unlike the
old ephemeral harness in [`../lab/`](../lab/), which deliberately had no volume
on `/paperclip`.

Shared LiteLLM config is built from [`../gateway/`](../gateway/). This stack does
**not** read or write the GCP project (no Cloud SQL, GCS, or Secret Manager).

Image pin: `ghcr.io/paperclipai/paperclip:sha-e55d702` (same as GCP).

---

## 1. Env file

```bash
cd local
cp .env.example .env
```

Edit `.env`:

- Set `GEMINI_API_KEY` and `ANTHROPIC_API_KEY` (LiteLLM only).
- Set `LITELLM_MASTER_KEY` (generate a strong secret; Paperclip uses this as its
  gateway key via compose).
- Replace `mac-mini.tailnet.ts.net` in `PAPERCLIP_PUBLIC_URL`,
  `PAPERCLIP_API_URL`, and `PAPERCLIP_ALLOWED_HOSTNAMES` with this Mini's
  Tailscale MagicDNS name.
- Generate Paperclip auth/signing secrets locally:
  - `openssl rand -hex 32` for `BETTER_AUTH_SECRET`,
    `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET`, `PAPERCLIP_AGENT_JWT_SECRET`
  - `openssl rand -base64 32` for `PAPERCLIP_SECRETS_MASTER_KEY`

Do **not** copy values from GCP Secret Manager. This is a fresh instance.

## 2. Start

```bash
docker compose up -d
```

## 3. First admin (once)

```bash
./bootstrap-admin.sh
```

Open the invite URL it prints (on a machine that can reach the Mini over Tailscale).

## 4. Lock signup

Set `PAPERCLIP_AUTH_DISABLE_SIGN_UP=true` in `.env`, then:

```bash
docker compose up -d --force-recreate paperclip
```

## 5. Other computers

Join the same Tailscale network and open `PAPERCLIP_PUBLIC_URL`. Do **not**
port-forward 3100 from the Mini.

## 6. Backups

This stack is the only copy of Mini data. Back up the three named volumes
(`paperclip-postgres`, `paperclip-minio`, `paperclip-home`) — for example with
`docker compose` volume backup tooling or by copying the volume data directories.

## Files

| Path | Purpose |
|------|---------|
| `compose.yaml` | paperclip + postgres + minio + litellm |
| `.env.example` | placeholders only |
| `gemini-cli/settings.json` | Gemini CLI headless auth selection |
| `bootstrap-admin.sh` | mint first-admin invite inside the container |
