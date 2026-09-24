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

- Set `GEMINI_API_KEY` and `ANTHROPIC_API_KEY` (LiteLLM only). Those provider
  keys stay on the LiteLLM container.
- Set `LITELLM_MASTER_KEY`. This is the gateway password Paperclip sends as
  `Authorization: Bearer …`. Compose also copies it onto the Paperclip service
  as `GEMINI_API_KEY` so agents can call the gateway. LiteLLM requires the
  `sk-` prefix (same form as `gcp/scripts/seed-secrets.sh`). Generate it on the
  Mini and paste the line into `.env`:

  ```bash
  echo "sk-$(openssl rand -hex 24)"
  ```

- Replace `mac-mini.tailnet.ts.net` with this Mini's Tailscale MagicDNS name.
  Tailscale must be running (`tailscale up`). Look the name up on the Mini:

  ```bash
  tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))'
  ```

  Put that name in all three places. Also set `PAPERCLIP_PUBLISH_HOST` to
  `tailscale ip -4`. Compose publishes port 3100 only on that address.
  `PAPERCLIP_BIND` stays `lan`: the container has no Tailscale interface, so
  `tailnet` makes the process crash-loop. On this Mini the name is
  `hemangs-mac-mini.tailfbfa38.ts.net`:

  ```bash
  PAPERCLIP_PUBLIC_URL=http://hemangs-mac-mini.tailfbfa38.ts.net:3100
  PAPERCLIP_API_URL=http://hemangs-mac-mini.tailfbfa38.ts.net:3100
  PAPERCLIP_ALLOWED_HOSTNAMES=hemangs-mac-mini.tailfbfa38.ts.net
  ```

  `PAPERCLIP_PUBLIC_URL` has to be the exact URL opened in the browser, or
  login fails. Other computers join the same Tailscale network. Do not
  port-forward 3100.
- Generate four independent Paperclip auth/signing secrets. Each variable
  gets its own output. Do not reuse one value across them: a leak of any one
  would then stand in for the others. Run `openssl rand -hex 32` three times,
  once per variable:

  ```bash
  echo "BETTER_AUTH_SECRET=$(openssl rand -hex 32)"
  echo "PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=$(openssl rand -hex 32)"
  echo "PAPERCLIP_AGENT_JWT_SECRET=$(openssl rand -hex 32)"
  echo "PAPERCLIP_SECRETS_MASTER_KEY=$(openssl rand -base64 32)"
  ```

  `BETTER_AUTH_SECRET` signs sessions. `PAPERCLIP_TOOL_ACTION_SIGNING_SECRET`
  signs tool calls. `PAPERCLIP_AGENT_JWT_SECRET` signs agent tokens.
  `PAPERCLIP_SECRETS_MASTER_KEY` encrypts stored secrets and must be the
  base64 form (32 bytes). This matches `gcp/scripts/seed-secrets.sh`, which
  writes a fresh value into each secret.

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
