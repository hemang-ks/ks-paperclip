output "bucket_name" {
  description = "Uploads bucket name"
  value       = google_storage_bucket.uploads.name
}

output "bucket_location" {
  description = "Bucket location (use as PAPERCLIP_STORAGE_S3_REGION for SigV4)"
  value       = google_storage_bucket.uploads.location
}

output "bucket_url" {
  description = "gs:// URL"
  value       = google_storage_bucket.uploads.url
}

output "hmac_service_account_email" {
  description = "Dedicated HMAC service account email"
  value       = google_service_account.hmac.email
}

output "hmac_access_id" {
  description = "HMAC access ID (AWS_ACCESS_KEY_ID). Null if create_hmac_key=false."
  value       = var.create_hmac_key ? google_storage_hmac_key.uploads[0].access_id : null
}

output "hmac_secret" {
  description = "HMAC secret (AWS_SECRET_ACCESS_KEY). Null if create_hmac_key=false. Sensitive — lives in Terraform state when created here."
  value       = var.create_hmac_key ? google_storage_hmac_key.uploads[0].secret : null
  sensitive   = true
}
