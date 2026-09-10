# GCS uploads bucket + optional HMAC key for Paperclip's S3 storage provider.

resource "google_service_account" "hmac" {
  project      = var.project_id
  account_id   = var.hmac_service_account_id
  display_name = "Paperclip GCS HMAC"
  description  = "HMAC access to the Paperclip uploads bucket only"
}

resource "google_storage_bucket" "uploads" {
  project                     = var.project_id
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      days_since_noncurrent_time = var.noncurrent_version_days
      with_state                 = "ARCHIVED"
    }
  }

  labels = var.labels
}

resource "google_storage_bucket_iam_member" "hmac_object_admin" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.hmac.email}"
}

resource "google_storage_hmac_key" "uploads" {
  count = var.create_hmac_key ? 1 : 0

  project               = var.project_id
  service_account_email = google_service_account.hmac.email
}
