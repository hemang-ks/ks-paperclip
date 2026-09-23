# ks-paperclip

Two deploy paths for [Paperclip](https://github.com/paperclipai/paperclip), sharing one LiteLLM gateway config. Image pin: `ghcr.io/paperclipai/paperclip:sha-e55d702` (v2026.722.0). This repo does **not** vendor Paperclip source.

## Local (Mac Mini)

```bash
cd local
cp .env.example .env   # fill keys, Tailscale hostname, generate auth secrets
docker compose up -d
./bootstrap-admin.sh
```

Details: [`local/README.md`](local/README.md).

## GCP

Merge and approve GitHub Environment `dev` (Actions applies Terraform). Do not run `terraform apply` from a laptop.

Runbook: [`gcp/docs/runbook.md`](gcp/docs/runbook.md).

---

`gateway/` is shared by both deploys. `lab/` is the old Cloud Run rehearsal harness, not a deploy. Task tracker: [`STATUS.md`](STATUS.md).
