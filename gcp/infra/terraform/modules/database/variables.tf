variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Cloud SQL region (same as Cloud Run)"
}

variable "private_network" {
  type        = string
  description = "VPC self_link or id for private IP"
}

variable "instance_name" {
  type        = string
  description = "Cloud SQL instance name"
  default     = "paperclip"
}

variable "tier" {
  type        = string
  description = "Machine tier. Default is a small custom VM suitable for personal/dev use (ENTERPRISE edition)."
  default     = "db-custom-1-3840"
}

variable "edition" {
  type        = string
  description = "Cloud SQL edition. ENTERPRISE allows db-custom-* / shared-core tiers. ENTERPRISE_PLUS needs db-perf-optimized-N-*."
  default     = "ENTERPRISE"

  validation {
    condition     = contains(["ENTERPRISE", "ENTERPRISE_PLUS"], var.edition)
    error_message = "edition must be ENTERPRISE or ENTERPRISE_PLUS."
  }
}

variable "availability_type" {
  type        = string
  description = "ZONAL (cheaper) or REGIONAL"
  default     = "ZONAL"
}

variable "disk_size_gb" {
  type        = number
  description = "Initial SSD size in GB"
  default     = 20
}

variable "deletion_protection" {
  type        = bool
  description = "GCP-level deletion protection"
  default     = true
}

variable "database_name" {
  type    = string
  default = "paperclip"
}

variable "database_user" {
  type    = string
  default = "paperclip"
}

variable "database_password" {
  type        = string
  description = "DB user password. Sourced by the caller (e.g. random_password or Secret Manager). Never outputted."
  sensitive   = true
}

variable "backup_start_time" {
  type        = string
  description = "HH:MM UTC"
  default     = "07:00"
}

variable "retained_backups" {
  type    = number
  default = 7
}

variable "transaction_log_retention_days" {
  type        = number
  description = "WAL / PITR retention in days"
  default     = 7
}

variable "maintenance_window_day" {
  type        = number
  description = "1=Monday … 7=Sunday"
  default     = 7
}

variable "maintenance_window_hour" {
  type        = number
  description = "0–23 UTC"
  default     = 8
}

variable "query_insights_enabled" {
  type    = bool
  default = true
}

variable "labels" {
  type    = map(string)
  default = {}
}
