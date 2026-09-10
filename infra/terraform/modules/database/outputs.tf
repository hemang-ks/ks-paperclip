output "instance_connection_name" {
  description = "project:region:instance for Cloud SQL connectors"
  value       = google_sql_database_instance.paperclip.connection_name
}

output "private_ip_address" {
  description = "Private IP of the Cloud SQL instance"
  value       = google_sql_database_instance.paperclip.private_ip_address
}

output "database_name" {
  description = "Application database name"
  value       = google_sql_database.paperclip.name
}

output "database_user" {
  description = "Application database user"
  value       = google_sql_user.paperclip.name
}

output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.paperclip.name
}
