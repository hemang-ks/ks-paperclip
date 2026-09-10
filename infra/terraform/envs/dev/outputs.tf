output "network_id" {
  value = module.network.network_id
}

output "subnet_id" {
  value = module.network.subnet_id
}

output "cloud_sql_connection_name" {
  value = module.database.instance_connection_name
}

output "cloud_sql_private_ip" {
  description = "Use when composing paperclip-database-url for Secret Manager seeding"
  value       = module.database.private_ip_address
}

output "database_name" {
  value = module.database.database_name
}

output "database_user" {
  value = module.database.database_user
}

output "artifact_registry_url" {
  value = module.registry.repository_url
}

output "secret_ids" {
  value = module.secrets.secret_ids
}

output "uploads_bucket_name" {
  value = module.storage.bucket_name
}

output "uploads_bucket_location" {
  value = module.storage.bucket_location
}

output "hmac_access_id" {
  value = module.storage.hmac_access_id
}

output "hmac_secret" {
  description = "Sensitive — only if create_hmac_key=true. Seed into Secret Manager; do not commit."
  value       = module.storage.hmac_secret
  sensitive   = true
}

output "paperclip_runtime_email" {
  value = google_service_account.paperclip_runtime.email
}

output "litellm_runtime_email" {
  value = google_service_account.litellm_runtime.email
}

output "db_password" {
  description = "Sensitive. Prefer Secret Manager after 1.7 seeding; exposed so operators can seed paperclip-db-password once."
  value       = random_password.db.result
  sensitive   = true
}

output "paperclip_service_uri" {
  description = "Cloud Run URI when the service module is deployed (empty until image digest + public_url are set)"
  value       = try(module.service[0].uri, null)
}

output "paperclip_service_name" {
  value = try(module.service[0].service_name, null)
}

output "paperclip_image_ready" {
  description = "True when paperclip_image_digest looks like a real sha256 digest"
  value       = local.paperclip_image_ready
}

output "auth_bootstrap_job_name" {
  description = "Cloud Run Job that mints the first-admin invite (null until image+URL gated)"
  value       = try(module.jobs[0].job_name, null)
}
