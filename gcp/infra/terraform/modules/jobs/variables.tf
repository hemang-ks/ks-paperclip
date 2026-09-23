variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "job_name" {
  type    = string
  default = "paperclip-auth-bootstrap"
}

variable "image" {
  type        = string
  description = "Digest-pinned Paperclip image (…@sha256:…)"

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must be a digest reference ending in @sha256:<64 hex chars>."
  }
}

variable "service_account_email" {
  type        = string
  description = "Same runtime SA as the Cloud Run service"
}

variable "network" {
  type = string
}

variable "subnet" {
  type = string
}

variable "secret_ids" {
  type        = map(string)
  description = "Secret Manager secret_id map from the secrets module"
}

variable "public_url" {
  type        = string
  description = "Public base URL passed to bootstrap-ceo --base-url"
}

variable "storage_bucket" {
  type = string
}

variable "storage_region" {
  type = string
}

variable "storage_endpoint" {
  type    = string
  default = "https://storage.googleapis.com"
}

variable "storage_prefix" {
  type    = string
  default = "uploads"
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "2Gi"
}

variable "timeout" {
  type        = string
  description = "Job task timeout"
  default     = "600s"
}

variable "labels" {
  type    = map(string)
  default = {}
}
