output "network_id" {
  description = "VPC network ID"
  value       = google_compute_network.vpc.id
}

output "network_self_link" {
  description = "VPC network self_link"
  value       = google_compute_network.vpc.self_link
}

output "network_name" {
  description = "VPC network name"
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "Runtime subnet ID"
  value       = google_compute_subnetwork.runtime.id
}

output "subnet_self_link" {
  description = "Runtime subnet self_link"
  value       = google_compute_subnetwork.runtime.self_link
}

output "subnet_name" {
  description = "Runtime subnet name"
  value       = google_compute_subnetwork.runtime.name
}

output "psa_range_name" {
  description = "Private Service Access reserved range name"
  value       = google_compute_global_address.psa.name
}

output "psa_connection_id" {
  description = "Service networking connection ID (for depends_on)"
  value       = google_service_networking_connection.psa.id
}
