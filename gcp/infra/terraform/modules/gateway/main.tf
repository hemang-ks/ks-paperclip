# Cloud Run v2 LiteLLM gateway.
#
# Auth: LITELLM_MASTER_KEY on /v1/* (no anonymous API).
# Exposure: all ingress + invoker_iam_disabled. Paperclip Direct VPC uses
# PRIVATE_RANGES_ONLY, so *.run.app goes out the public frontend; INTERNAL_ONLY
# returns Google HTML 404. A Cloud Run identity token would collide with
# Authorization: Bearer <master key>, so IAM invoker is not the app gate.
#
# Do not set PORT — Cloud Run injects it to match container_port (4000).

locals {
  secret_env = {
    GEMINI_API_KEY     = var.secret_ids["litellm-gemini-api-key"]
    LITELLM_MASTER_KEY = var.secret_ids["litellm-master-key"]
    ANTHROPIC_API_KEY  = try(var.secret_ids["litellm-anthropic-api-key"], null)
  }

  required_secret_env = {
    GEMINI_API_KEY     = local.secret_env.GEMINI_API_KEY
    LITELLM_MASTER_KEY = local.secret_env.LITELLM_MASTER_KEY
  }

  optional_secret_env = {
    for k, secret_id in {
      ANTHROPIC_API_KEY = local.secret_env.ANTHROPIC_API_KEY
    } : k => secret_id if secret_id != null && var.mount_anthropic
  }

  plain_env = {
    STORE_MODEL_IN_DB = "False"
    LITELLM_LOG       = "INFO"
    LITELLM_MODE      = "PRODUCTION"
  }
}

resource "google_cloud_run_v2_service" "litellm" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  ingress  = var.ingress

  invoker_iam_disabled = true

  template {
    service_account                  = var.service_account_email
    timeout                          = var.timeout
    max_instance_request_concurrency = var.max_concurrency

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      name  = "litellm"
      image = var.image
      args  = ["--config", "/app/config.yaml", "--port", "4000"]

      ports {
        name           = "http1"
        container_port = 4000
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = local.plain_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.required_secret_env
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

      startup_probe {
        http_get {
          path = "/health/liveliness"
          port = 4000
        }
        initial_delay_seconds = 10
        timeout_seconds       = 5
        period_seconds        = 10
        failure_threshold     = 24
      }

      liveness_probe {
        http_get {
          path = "/health/liveliness"
          port = 4000
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
