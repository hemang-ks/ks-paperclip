# ks-paperclip

Deploy for [Paperclip](https://github.com/paperclipai/paperclip). This repo does not vendor Paperclip source. Both deploy paths run the published image `ghcr.io/paperclipai/paperclip:sha-e55d702` (v2026.722.0) and the same LiteLLM config in [`gateway/config/config.yaml`](gateway/config/config.yaml).

How the pieces connect, including the path from an agent to Gemini or Claude: [`ARCHITECTURE.md`](ARCHITECTURE.md).

Task tracker: [`STATUS.md`](STATUS.md).

## Prerequisites

Use this list when you clone the repo on a new machine. Install first, then log in, then clone.

The Paperclip image already contains Node, pnpm, and the Paperclip CLI. Terraform runs inside GitHub Actions. You do not install either one on the machine.

### Every machine

Install:

| Tool | Install | Why |
|---|---|---|
| [Cursor](https://cursor.com) | cursor.com | Edit this repo and run agents in it |
| Git | Xcode Command Line Tools on macOS (`xcode-select --install`), or [git-scm.com](https://git-scm.com/) | Clone, branch, commit, push |
| [GitHub CLI](https://cli.github.com/) | `brew install gh` | Pull requests, Actions variables, workflow dispatch |

Log in:

```bash
gh auth login
```

Choose GitHub.com, HTTPS or SSH, and authenticate in the browser. Grant the `repo` and `workflow` scopes so you can open pull requests and dispatch Actions. Then:

```bash
gh auth setup-git
gh auth status
```

`gh auth status` should show the account that can push to `hemang-ks/ks-paperclip`.

Clone and open:

```bash
gh repo clone hemang-ks/ks-paperclip
cd ks-paperclip
cursor .
```

Git commits also need a name and email on this machine (`git config --global user.name` and `git config --global user.email`) if they are not set yet.

### Mac Mini deploy

Install, in addition to the tools above:

| Tool | Install | Why |
|---|---|---|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | docker.com, Apple Silicon or Intel | Runs Paperclip, Postgres, MinIO, and LiteLLM. Start the app and wait until it is running. |
| [Tailscale](https://tailscale.com/download) | `brew install --cask tailscale`, then open the app | Dashboard from other computers. Those computers need Tailscale too. |
| `openssl` | Already on macOS | Local auth and signing secrets |

Log in:

```bash
tailscale up
tailscale status
```

Use the MagicDNS name from `tailscale status` (for example `mac-mini.tailnet.ts.net`) in `local/.env`. A Docker Hub login is optional. The Paperclip and LiteLLM images are public on GHCR.

Create the provider keys in a browser and keep them for `local/.env`:

- A [Gemini API key](https://aistudio.google.com/apikey) for the `worker` and `reasoning` aliases.
- An [Anthropic API key](https://console.anthropic.com/) for the `premium` alias.

Then follow [`local/README.md`](local/README.md): copy `.env.example`, fill the keys and the Tailscale hostname, generate the Paperclip secrets, and start Compose.

Leave the Mini awake and leave Docker Desktop running. The heartbeat scheduler lives inside the Paperclip container.

### GCP deploy from this machine

The GCP project is already bootstrapped (`paperclip-ks-prod`, region `us-west1`). A new machine still needs the Cloud SDK so you can read logs, run the auth-bootstrap job, and seed secrets. Applying Terraform stays on GitHub Actions.

Install:

| Tool | Install | Why |
|---|---|---|
| [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) | `brew install --cask google-cloud-sdk` | `gcloud` for logs, jobs, and secret seeding |

Log in:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project paperclip-ks-prod
gcloud config set run/region us-west1
gcloud auth list
```

The account in `gcloud auth list` needs access to project `paperclip-ks-prod`. Confirm with:

```bash
gcloud projects describe paperclip-ks-prod
```

GitHub login from the section above is the same login Actions uses. To approve an apply you also need to be a required reviewer on the GitHub Environment named `dev` (repository **Settings → Environments → dev**).

You do not run `terraform apply` on the laptop. Merge to `main` and approve `dev`. First-time project creation, if you ever repeat it, is [`gcp/docs/gcp-bootstrap.md`](gcp/docs/gcp-bootstrap.md). Day-to-day operations are [`gcp/docs/runbook.md`](gcp/docs/runbook.md).

## Ways to deploy

The two deploys do not share a database. Starting one does not change the other. How they are wired is in [`ARCHITECTURE.md`](ARCHITECTURE.md).

| | Mac Mini | GCP |
|---|---|---|
| When to use it | Day-to-day, one person, dashboard from other computers over Tailscale | Always-on host with a public URL |
| Where it runs | Docker Compose on the Mini | Cloud Run in `us-west1`, project `paperclip-ks-prod` |
| How you start it | Commands below, on the Mini | Merge to `main` and approve GitHub Environment `dev` |
| State | Postgres, MinIO, and `/paperclip` on named Docker volumes | Cloud SQL, GCS, Secret Manager |
| Dashboard | `http://<mini>.tailnet.ts.net:3100` | `https://paperclip.legotick.com` |
| Model router | LiteLLM container on the Compose network | Cloud Run service `litellm` |
| Detail | [`local/README.md`](local/README.md) | [`gcp/docs/runbook.md`](gcp/docs/runbook.md) |

`lab/` is the old Cloud Run rehearsal (no volumes, empty database). It is not a third deploy.

### Mac Mini

```bash
cd local
cp .env.example .env   # fill keys, Tailscale hostname, generate auth secrets
docker compose up -d
./bootstrap-admin.sh
```

Then set `PAPERCLIP_AUTH_DISABLE_SIGN_UP=true` and recreate the `paperclip` container. Secret commands and backups are in [`local/README.md`](local/README.md).

### GCP

GitHub Actions applies Terraform. Approving Environment `dev` is the apply button.

| Workflow | When it runs |
|---|---|
| `terraform-plan` | Pull requests that touch `gcp/infra` |
| `terraform-apply` | After you approve Environment `dev` |
| `deploy` | Image digest pin changes on `main`, or a manual dispatch. Same `dev` approval |
| `image-promote` | Manual. Copies the Paperclip image from GHCR into Artifact Registry and opens a pin PR |
| `gateway-build` | Manual. Builds the LiteLLM image from `gateway/` and opens a pin PR |

## Layout

| Path | Purpose |
|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Control plane, model call path, alias routing |
| [`local/`](local/README.md) | Mac Mini Compose stack |
| [`gcp/infra`](gcp/infra/README.md) | Terraform modules and `envs/dev` |
| [`gcp/scripts`](gcp/scripts) | Bootstrap, image promote, gateway build, seed secrets, smoke test |
| [`gcp/docs`](gcp/docs/runbook.md) | GCP runbook and bootstrap notes |
| [`gateway/`](gateway/README.md) | Shared LiteLLM config and image |
| [`lab/`](lab/README.md) | Old ephemeral rehearsal and Phase L findings |
| [`STATUS.md`](STATUS.md) | What is done and what is next |
| [`.github/workflows`](.github/workflows) | Plan, apply, deploy, image promote, gateway build |
