output "service_name" {
  value = google_cloud_run_v2_service.litellm.name
}

output "service_id" {
  value = google_cloud_run_v2_service.litellm.id
}

output "uri" {
  description = "HTTPS URL of the Cloud Run service (public ingress; LITELLM_MASTER_KEY required)"
  value       = google_cloud_run_v2_service.litellm.uri
}

output "location" {
  value = google_cloud_run_v2_service.litellm.location
}
