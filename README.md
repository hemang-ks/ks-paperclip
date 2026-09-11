# ks-paperclip

GCP deployment for [Paperclip](https://github.com/paperclipai/paperclip). This repo does **not** vendor Paperclip source. It consumes the published image `ghcr.io/paperclipai/paperclip:sha-e55d702` (v2026.722.0).

## Start here

1. **[`STATUS.md`](STATUS.md)** — where we are and every task (the only checklist).
2. **[`.cursor/plans/paperclip-cost-optimized-execution.md`](.cursor/plans/paperclip-cost-optimized-execution.md)** — working plan: target architecture, constraints, what we are not building.
3. **[`local/README.md`](local/README.md)** — local Compose harness. Phase L findings: `local/FINDINGS-L*.md`.

Older docs ([deployment plan](.cursor/plans/paperclip-deployment.md), [original execution guide](.cursor/plans/paperclip-execution-guide.md), [cost-optimized runbook](docs/Paperclip-GCP-Cost-Optimized-Deployment-Execution-Runbook.md)) are background. Do not treat them as the task list.

## Current target

Paperclip on Cloud Run → adapter → LiteLLM → Gemini Flash (default) / Gemini Pro / Claude (premium only). CI via GitHub Actions applies Terraform. No GPU until usage data says otherwise.

## Layout

| Path | Purpose |
|---|---|
| `STATUS.md` | Task tracker |
| `local/` | Docker Compose validation harness |
| `scripts/bootstrap-gcp.sh` | One-time GCP bootstrap for Terraform + Actions (Phase 0) |
| `scripts/scaffold-dirs.sh` | Idempotent Phase 1 directory scaffold |
| `scripts/promote-image.sh` | Mirror Paperclip GHCR → Artifact Registry; print digest + schema labels |
| `scripts/build-gateway.sh` | Build LiteLLM gateway image → Artifact Registry; print digest |
| `scripts/ci-prepare-tfvars.sh` | Build `envs/dev/terraform.tfvars` in CI from repo variables + image pin |
| `scripts/smoke-test.sh` | `GET /api/health` smoke check after deploy |
| `scripts/seed-secrets.sh` | Seed Secret Manager values (never prints secrets). `--gateway-only` for `litellm-master-key` |
| `docs/` | Bootstrap notes, runbook (incl. Squarespace custom domain), architecture runbook |
| `config/` | Bootstrap `config.json` template for first admin |
| `infra/` | Terraform modules + `envs/dev` |
| `gateway/` | LiteLLM config + Dockerfile (Phase 2) |
| `.github/workflows/` | CI: `image-promote`, `gateway-build`, `terraform-plan`, `terraform-apply` (Environment `dev`), `deploy` |
