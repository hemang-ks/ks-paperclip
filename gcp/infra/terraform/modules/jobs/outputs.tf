output "job_name" {
  value = google_cloud_run_v2_job.auth_bootstrap.name
}

output "job_id" {
  value = google_cloud_run_v2_job.auth_bootstrap.id
}

output "location" {
  value = google_cloud_run_v2_job.auth_bootstrap.location
}
