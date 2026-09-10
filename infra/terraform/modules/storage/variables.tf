variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Bucket location (same region as Cloud Run)"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique GCS bucket name for uploads"
}

variable "hmac_service_account_id" {
  type        = string
  description = "Account ID for the dedicated HMAC service account"
  default     = "paperclip-gcs-hmac"
}

variable "create_hmac_key" {
  type        = bool
  description = "If true, create google_storage_hmac_key (secret lands in Terraform state). If false, create the HMAC out-of-band and seed Secret Manager yourself."
  default     = true
}

variable "noncurrent_version_days" {
  type        = number
  description = "Purge noncurrent object versions after this many days"
  default     = 30
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket destroy when non-empty (dev only)"
  default     = false
}

variable "labels" {
  type    = map(string)
  default = {}
}
