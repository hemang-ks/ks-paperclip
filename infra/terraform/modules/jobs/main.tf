# Cloud Run Jobs for Paperclip.
#
# Cost-optimized v1: auth-bootstrap only. No dedicated migrate Job — the service
# uses PAPERCLIP_MIGRATION_AUTO_APPLY=true (see STATUS L8 / plan).

locals {
  config_path = "/paperclip/instances/default/config.json"

  # Seed config.json (CLI requires on-disk file; server boots from env alone).
  # $meta.source must be "configure". Values come from job env at runtime.
  bootstrap_script = <<-EOF
    set -euo pipefail
    CONFIG="${local.config_path}"
    mkdir -p "$(dirname "$CONFIG")"
    python3 - <<'PY'
    import json, os, datetime
    path = "/paperclip/instances/default/config.json"
    public_url = os.environ["PAPERCLIP_PUBLIC_URL"]
    config = {
      "$meta": {
        "version": 1,
        "updatedAt": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "source": "configure",
      },
      "database": {
        "mode": "postgres",
        "connectionString": os.environ["DATABASE_URL"],
        "backup": {"enabled": False},
      },
      "logging": {
        "mode": "file",
        "logDir": "/paperclip/instances/default/logs",
      },
      "server": {
        "deploymentMode": "authenticated",
        "exposure": "public",
        "bind": "lan",
        "host": "0.0.0.0",
        "port": 3100,
        "serveUi": True,
      },
      "auth": {
        "baseUrlMode": "explicit",
        "publicBaseUrl": public_url,
        "disableSignUp": False,
      },
      "storage": {
        "provider": "s3",
        "s3": {
          "bucket": os.environ["PAPERCLIP_STORAGE_S3_BUCKET"],
          "region": os.environ["PAPERCLIP_STORAGE_S3_REGION"],
          "endpoint": os.environ["PAPERCLIP_STORAGE_S3_ENDPOINT"],
          "forcePathStyle": True,
          "prefix": os.environ.get("PAPERCLIP_STORAGE_S3_PREFIX", "uploads"),
        },
      },
      "secrets": {"provider": "local_encrypted", "strictMode": False},
      "telemetry": {"enabled": False},
    }
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
      json.dump(config, f, indent=2)
      f.write("\n")
    print("wrote", path, flush=True)
    PY
    cd /app
    pnpm paperclipai auth bootstrap-ceo --config "$CONFIG" --base-url "$PAPERCLIP_PUBLIC_URL"
  EOF

  secret_env = {
    DATABASE_URL                         = var.secret_ids["paperclip-database-url"]
    BETTER_AUTH_SECRET                   = var.secret_ids["paperclip-better-auth-secret"]
    PAPERCLIP_SECRETS_MASTER_KEY         = var.secret_ids["paperclip-secrets-master-key"]
    PAPERCLIP_TOOL_ACTION_SIGNING_SECRET = var.secret_ids["paperclip-tool-action-signing-secret"]
    PAPERCLIP_AGENT_JWT_SECRET           = var.secret_ids["paperclip-agent-jwt-secret"]
    PAPERCLIP_DECISION_SIGNING_SECRET    = var.secret_ids["paperclip-decision-signing-secret"]
    AWS_ACCESS_KEY_ID                    = var.secret_ids["paperclip-gcs-hmac-access-key"]
    AWS_SECRET_ACCESS_KEY                = var.secret_ids["paperclip-gcs-hmac-secret"]
  }

  plain_env = {
    PAPERCLIP_HOME                        = "/paperclip"
    PAPERCLIP_INSTANCE_ID                 = "default"
    PAPERCLIP_CONFIG                      = local.config_path
    PAPERCLIP_DEPLOYMENT_MODE             = "authenticated"
    PAPERCLIP_DEPLOYMENT_EXPOSURE         = "public"
    PAPERCLIP_PUBLIC_URL                  = var.public_url
    PAPERCLIP_API_URL                     = var.public_url
    PAPERCLIP_STORAGE_PROVIDER            = "s3"
    PAPERCLIP_STORAGE_S3_BUCKET           = var.storage_bucket
    PAPERCLIP_STORAGE_S3_REGION           = var.storage_region
    PAPERCLIP_STORAGE_S3_ENDPOINT         = var.storage_endpoint
    PAPERCLIP_STORAGE_S3_FORCE_PATH_STYLE = "true"
    PAPERCLIP_STORAGE_S3_PREFIX           = var.storage_prefix
  }
}

resource "google_cloud_run_v2_job" "auth_bootstrap" {
  project  = var.project_id
  name     = var.job_name
  location = var.region

  template {
    task_count  = 1
    parallelism = 1

    template {
      service_account = var.service_account_email
      timeout         = var.timeout
      max_retries     = 0

      vpc_access {
        egress = "PRIVATE_RANGES_ONLY"
        network_interfaces {
          network    = var.network
          subnetwork = var.subnet
        }
      }

      containers {
        name    = "auth-bootstrap"
        image   = var.image
        command = ["sh", "-c"]
        args    = [local.bootstrap_script]

        resources {
          limits = {
            cpu    = var.cpu
            memory = var.memory
          }
        }

        dynamic "env" {
          for_each = local.plain_env
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  labels = var.labels

  lifecycle {
    ignore_changes = [
      # Executions launch out-of-band; don't fight launch_stage churn.
      launch_stage,
      client,
      client_version,
    ]
  }
}
