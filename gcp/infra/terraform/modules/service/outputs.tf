output "service_name" {
  value = google_cloud_run_v2_service.paperclip.name
}

output "service_id" {
  value = google_cloud_run_v2_service.paperclip.id
}

output "uri" {
  description = "HTTPS URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.paperclip.uri
}

output "location" {
  value = google_cloud_run_v2_service.paperclip.location
}
