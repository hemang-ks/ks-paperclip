# Secret Manager containers + per-secret IAM only.
# NEVER create secret versions or accept plaintext values in this module.
# Values are seeded out-of-band (scripts/seed-secrets.sh / gcloud secrets versions add).

locals {
  ordinary_secret_ids = toset([
    for id in var.secret_ids : id if id != "paperclip-secrets-master-key"
  ])
  include_master_key = contains(var.secret_ids, "paperclip-secrets-master-key")
}

resource "google_secret_manager_secret" "this" {
  for_each = local.ordinary_secret_ids

  project   = var.project_id
  secret_id = each.value
  labels    = var.labels

  replication {
    dynamic "auto" {
      for_each = var.replication_location == null ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = var.replication_location != null ? [1] : []
      content {
        replicas {
          location = var.replication_location
        }
      }
    }
  }
}

# WARNING: every company secret Paperclip stores is encrypted with this key.
# Loss or rotation without re-encryption makes them permanently undecryptable.
# Exclude from routine rotation. Backup the value to a password manager after seeding.
resource "google_secret_manager_secret" "master_key" {
  count = local.include_master_key ? 1 : 0

  project   = var.project_id
  secret_id = "paperclip-secrets-master-key"
  labels    = merge(var.labels, { critical = "true" })

  replication {
    dynamic "auto" {
      for_each = var.replication_location == null ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = var.replication_location != null ? [1] : []
      content {
        replicas {
          location = var.replication_location
        }
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret_iam_member" "runtime_accessor" {
  for_each = local.ordinary_secret_ids

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.key].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runtime_service_account_email}"
}

resource "google_secret_manager_secret_iam_member" "master_key_accessor" {
  count = local.include_master_key ? 1 : 0

  project   = var.project_id
  secret_id = google_secret_manager_secret.master_key[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.runtime_service_account_email}"
}
