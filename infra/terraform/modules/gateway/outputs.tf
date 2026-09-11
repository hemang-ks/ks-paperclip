output "service_name" {
  value = google_cloud_run_v2_service.litellm.name
}

output "service_id" {
  value = google_cloud_run_v2_service.litellm.id
}

output "uri" {
  description = "HTTPS URL of the Cloud Run service (internal ingress — not reachable from the public internet)"
  value       = google_cloud_run_v2_service.litellm.uri
}

output "location" {
  value = google_cloud_run_v2_service.litellm.location
}
