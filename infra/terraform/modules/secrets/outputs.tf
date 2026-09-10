output "secret_ids" {
  description = "Map of secret name -> secret_id for Cloud Run secret_key_ref wiring"
  value = merge(
    { for k, s in google_secret_manager_secret.this : k => s.secret_id },
    local.include_master_key ? {
      "paperclip-secrets-master-key" = google_secret_manager_secret.master_key[0].secret_id
    } : {}
  )
}

output "secret_resource_names" {
  description = "Map of secret name -> full resource name"
  value = merge(
    { for k, s in google_secret_manager_secret.this : k => s.name },
    local.include_master_key ? {
      "paperclip-secrets-master-key" = google_secret_manager_secret.master_key[0].name
    } : {}
  )
}
