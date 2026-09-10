variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "secret_ids" {
  type        = list(string)
  description = "Secret Manager secret IDs to create (containers only; no values)"
  default = [
    "paperclip-db-password",
    "paperclip-database-url",
    "paperclip-better-auth-secret",
    "paperclip-secrets-master-key",
    "paperclip-tool-action-signing-secret",
    "paperclip-agent-jwt-secret",
    "paperclip-decision-signing-secret",
    "paperclip-gcs-hmac-access-key",
    "paperclip-gcs-hmac-secret",
    "paperclip-anthropic-api-key",
    "paperclip-openai-api-key",
    "paperclip-github-token",
  ]
}

variable "runtime_service_account_email" {
  type        = string
  description = "Cloud Run runtime SA granted secretAccessor on each secret"
}

variable "replication_location" {
  type        = string
  description = "If set, use user-managed replication in this region; otherwise automatic"
  default     = null
}

variable "labels" {
  type    = map(string)
  default = {}
}
