output "repository_id" {
  description = "Artifact Registry repository ID"
  value       = google_artifact_registry_repository.paperclip.repository_id
}

output "repository_name" {
  description = "Full resource name"
  value       = google_artifact_registry_repository.paperclip.name
}

output "repository_url" {
  description = "Prefix for image references: REGION-docker.pkg.dev/PROJECT/REPO"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.paperclip.repository_id}"
}
