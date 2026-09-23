variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Same region as Cloud Run (avoid cross-region pulls)"
}

variable "repository_id" {
  type        = string
  description = "Artifact Registry repository ID"
  default     = "paperclip"
}

variable "description" {
  type    = string
  default = "Paperclip platform images (mirrored from GHCR, digest-pinned)"
}

variable "keep_version_count" {
  type        = number
  description = "Keep the most recent N versions"
  default     = 10
}

variable "delete_untagged_after_days" {
  type        = number
  description = "Delete untagged images older than this many days"
  default     = 30
}

variable "runtime_service_account_email" {
  type        = string
  description = "Cloud Run runtime SA (pull images)"
}

variable "deployer_service_account_email" {
  type        = string
  description = "CI deployer SA (push images)"
}

variable "labels" {
  type    = map(string)
  default = {}
}
