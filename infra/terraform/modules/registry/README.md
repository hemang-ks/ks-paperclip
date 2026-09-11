# Registry module

Docker Artifact Registry repository for Paperclip and LiteLLM gateway images.

Image naming:

```text
<REGION>-docker.pkg.dev/<PROJECT_ID>/paperclip/paperclip@sha256:…
<REGION>-docker.pkg.dev/<PROJECT_ID>/paperclip/litellm@sha256:…
```

Keep the repo in the **same region** as Cloud Run — the image is ~1.46 GB compressed;
cross-region pulls worsen cold start.

## IAM

| Principal | Role |
|---|---|
| `paperclip-runtime` (module) | `roles/artifactregistry.reader` |
| `litellm-runtime` (`envs/dev`) | `roles/artifactregistry.reader` |
| CI deployer SA (`terraform-deployer`) | `roles/artifactregistry.writer` |

Cleanup: keep last N versions (default 10); delete untagged images older than 30 days.
