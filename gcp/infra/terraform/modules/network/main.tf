# VPC for Cloud Run Direct VPC egress + private Cloud SQL (PSA).
# No Cloud NAT — Cloud Run uses PRIVATE_RANGES_ONLY so public API calls egress
# directly from Cloud Run (~$35/mo NAT avoided).

resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Direct VPC egress requires a /26 or larger (64+ addresses). Do not shrink.
resource "google_compute_subnetwork" "runtime" {
  project                  = var.project_id
  name                     = var.subnet_name
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true

  purpose = "PRIVATE"
}

resource "google_compute_global_address" "psa" {
  project       = var.project_id
  name          = var.psa_range_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.psa_prefix_length
  network       = google_compute_network.vpc.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_networking_connection" "psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psa.name]

  lifecycle {
    prevent_destroy = true
  }
}
