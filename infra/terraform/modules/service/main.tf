# Cloud Run v2 service for Paperclip (stateless control plane).
#
# CORRECTNESS (not cost): min_instance_count = max_instance_count = 1.
# The heartbeat scheduler has no leader election / advisory lock, and WebSocket
# state is per-process. Scaling above 1 is unsafe until that changes.
#
# cpu_idle = false (CPU always allocated): the scheduler is a setInterval; with
# CPU throttling it freezes between requests and agents never wake.

locals {
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

  optional_secret_env = {
    for k, secret_id in {
      ANTHROPIC_API_KEY = try(var.secret_ids["paperclip-anthropic-api-key"], null)
      OPENAI_API_KEY    = try(var.secret_ids["paperclip-openai-api-key"], null)
      GITHUB_TOKEN      = try(var.secret_ids["paperclip-github-token"], null)
    } : k => secret_id if secret_id != null && contains(var.optional_provider_secret_env, k)
  }

  plain_env = merge(
    {
      # Do not set PORT — Cloud Run reserves it and injects it to match container_port (3100).
      SERVE_UI                      = "true"
      PAPERCLIP_HOME                = "/paperclip"
      PAPERCLIP_INSTANCE_ID         = "default"
      PAPERCLIP_CONFIG              = "/paperclip/instances/default/config.json"
      PAPERCLIP_DEPLOYMENT_MODE     = "authenticated"
      PAPERCLIP_DEPLOYMENT_EXPOSURE = var.deployment_exposure
      PAPERCLIP_PUBLIC_URL          = var.public_url
      PAPERCLIP_API_URL             = var.public_url
      PAPERCLIP_ALLOWED_HOSTNAMES   = var.allowed_hostnames
      PAPERCLIP_BIND                = "lan"
      # Cost-optimized v1: auto-migrate on boot (no dedicated migrate Job).
      PAPERCLIP_MIGRATION_AUTO_APPLY        = "true"
      PAPERCLIP_DB_BACKUP_ENABLED           = "false"
      HEARTBEAT_SCHEDULER_ENABLED           = "true"
      PAPERCLIP_SECRETS_STRICT_MODE         = "true"
      PAPERCLIP_AUTH_DISABLE_SIGN_UP        = var.auth_disable_sign_up ? "true" : "false"
      PAPERCLIP_STORAGE_PROVIDER            = "s3"
      PAPERCLIP_STORAGE_S3_BUCKET           = var.storage_bucket
      PAPERCLIP_STORAGE_S3_REGION           = var.storage_region
      PAPERCLIP_STORAGE_S3_ENDPOINT         = var.storage_endpoint
      PAPERCLIP_STORAGE_S3_FORCE_PATH_STYLE = "true"
      PAPERCLIP_STORAGE_S3_PREFIX           = var.storage_prefix
    },
    var.extra_env,
  )
}

resource "google_cloud_run_v2_service" "paperclip" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  ingress  = var.ingress

  template {
    service_account                  = var.service_account_email
    timeout                          = var.timeout
    max_instance_request_concurrency = var.max_concurrency
    session_affinity                 = true

    scaling {
      # CORRECTNESS: single scheduler + per-process WS state. Do not raise max.
      min_instance_count = 1
      max_instance_count = 1
    }

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"
      network_interfaces {
        network    = var.network
        subnetwork = var.subnet
      }
    }

    containers {
      name  = "paperclip"
      image = var.image

      ports {
        name           = "http1"
        container_port = 3100
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = false # CPU always allocated — required for heartbeat scheduler
        startup_cpu_boost = true  # image ~1.46 GB compressed
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

      dynamic "env" {
        for_each = local.optional_secret_env
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

      # Cloud Run caps startup probe budget at ~240s. Auto-migrate (~seconds in L4)
      # fits; a dedicated migrate Job is not required for v1.
      startup_probe {
        http_get {
          path = "/api/health"
          port = 3100
        }
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 24
      }

      liveness_probe {
        http_get {
          path = "/api/health"
          port = 3100
        }
        initial_delay_seconds = 30
        timeout_seconds       = 5
        period_seconds        = 30
        failure_threshold     = 3
      }
    }

    labels = var.labels
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  labels = var.labels
}

# Paperclip does its own Better Auth. Cloud Run must accept unauthenticated
# invocations so the browser can reach the login / invite UI.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = google_cloud_run_v2_service.paperclip.project
  location = google_cloud_run_v2_service.paperclip.location
  name     = google_cloud_run_v2_service.paperclip.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
