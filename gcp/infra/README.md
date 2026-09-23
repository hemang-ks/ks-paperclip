# Infrastructure (Terraform)

GCP resources for Paperclip are defined under `terraform/`. GitHub Actions
applies them; do not run `terraform apply` locally.

| Path | Purpose |
|---|---|
| `terraform/versions.tf` | Shared Terraform / provider pins (`>= 1.9`, `hashicorp/google ~> 6.0`) |
| `terraform/modules/` | Reusable modules (network, database, registry, secrets, storage, service, jobs, gateway) |
| `terraform/envs/dev/` | Root module for the single `dev` environment (foundation + gated service/jobs) |

No `edge` / ALB module — out of scope for the cost-optimized plan. No Paperclip
source tree; Cloud Run consumes the published image pin documented in the root README.
