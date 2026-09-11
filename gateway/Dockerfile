# LiteLLM proxy with baked-in alias config.
# Cloud Run deploys the *output* digest from gateway-build, never a tag.
#
# Base: ghcr.io/berriai/litellm:v1.76.1-stable (multi-arch index).
FROM ghcr.io/berriai/litellm:v1.76.1-stable@sha256:222cbb6aa30f3315572a7b3c5ab22407b1e61a11a3ed4334463dbbbfa1a0f742

# Do not set DATABASE_URL / STORE_MODEL_IN_DB — config.yaml is the source of
# truth (no LiteLLM Postgres).
COPY config/config.yaml /app/config.yaml

# Official image ENTRYPOINT is docker/prod_entrypoint.sh; CMD is --port 4000.
# Cloud Run overrides args to pass --config. Do not set PORT in Terraform
# (Cloud Run injects it to match container_port 4000).
EXPOSE 4000
