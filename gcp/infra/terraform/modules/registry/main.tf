resource "google_artifact_registry_repository" "paperclip" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_version_count
    }
  }

  cleanup_policies {
    id     = "delete-untagged-old"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.delete_untagged_after_days * 24 * 60 * 60}s"
    }
  }

  labels = var.labels
}

resource "google_artifact_registry_repository_iam_member" "runtime_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.paperclip.location
  repository = google_artifact_registry_repository.paperclip.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.runtime_service_account_email}"
}

resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.paperclip.location
  repository = google_artifact_registry_repository.paperclip.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.deployer_service_account_email}"
}
