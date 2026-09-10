# Cloud SQL PostgreSQL 17 — private IP only. Password is an input (never generated
# or outputted here). Caller sources it from Secret Manager / out-of-band seed.

resource "google_sql_database_instance" "paperclip" {
  project             = var.project_id
  name                = var.instance_name
  database_version    = "POSTGRES_17"
  region              = var.region
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.private_network
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = var.backup_start_time
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = var.transaction_log_retention_days
      backup_retention_settings {
        retained_backups = var.retained_backups
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = var.query_insights_enabled
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = false
      record_client_address   = false
    }

    user_labels = var.labels
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_sql_database" "paperclip" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.paperclip.name
}

resource "google_sql_user" "paperclip" {
  project  = var.project_id
  name     = var.database_user
  instance = google_sql_database_instance.paperclip.name
  password = var.database_password
}
