variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Primary region for Cloud Run, Cloud SQL, Artifact Registry, and GCS"
}

variable "environment" {
  type        = string
  description = "Environment name (used in labels)"
  default     = "dev"
}

variable "deployer_service_account_email" {
  type        = string
  description = "CI deployer SA from bootstrap (terraform-deployer@…). Used for Artifact Registry writer."
}

variable "uploads_bucket_name" {
  type        = string
  description = "Globally unique GCS bucket name for Paperclip uploads"
}

variable "cloud_sql_tier" {
  type        = string
  description = "Cloud SQL machine tier"
  default     = "db-custom-1-3840"
}

variable "create_hmac_key" {
  type        = bool
  description = "Create GCS HMAC in Terraform (secret enters state). Default false — create out-of-band for 1.7."
  default     = false
}

variable "labels" {
  type        = map(string)
  description = "Common resource labels"
  default     = {}
}

variable "paperclip_source_ref" {
  type        = string
  description = "Upstream GHCR tag that was promoted (informational; deploy uses digest)"
  default     = "sha-e55d702"
}

variable "paperclip_image_digest" {
  type        = string
  description = "Immutable sha256 digest of the Paperclip image in Artifact Registry (set by image-promote)"
  default     = "sha256:PENDING_RUN_IMAGE_PROMOTE"
}

variable "paperclip_schema_last_migration" {
  type        = string
  description = "OCI label io.github.paperclipai.schema.last-migration from the pinned image"
  default     = ""
}

variable "paperclip_schema_migration_count" {
  type        = string
  description = "OCI label io.github.paperclipai.schema.migration-count from the pinned image"
  default     = ""
}

variable "paperclip_public_url" {
  type        = string
  description = "Public HTTPS URL for Paperclip (PAPERCLIP_PUBLIC_URL). Required to create the Cloud Run service."
  default     = ""
}

variable "paperclip_allowed_hostnames" {
  type        = string
  description = "Override PAPERCLIP_ALLOWED_HOSTNAMES; defaults to host parsed from paperclip_public_url"
  default     = ""
}

variable "paperclip_cpu" {
  type        = string
  description = "Cloud Run CPU limit"
  default     = "1"
}

variable "paperclip_memory" {
  type        = string
  description = "Cloud Run memory limit"
  default     = "4Gi"
}

variable "paperclip_auth_disable_sign_up" {
  type        = bool
  description = "Set true after first admin is claimed"
  default     = false
}

variable "litellm_image_digest" {
  type        = string
  description = "Immutable sha256 digest of the LiteLLM gateway image in Artifact Registry (set by gateway-build)"
  default     = "sha256:PENDING_RUN_GATEWAY_BUILD"
}

variable "litellm_import_secret_ids" {
  type        = list(string)
  description = "Gateway secrets that already exist (created in 2.2). Terraform imports then manages them."
  default     = ["litellm-gemini-api-key"]

  validation {
    condition = alltrue([
      for id in var.litellm_import_secret_ids : contains(
        [
          "litellm-master-key",
          "litellm-gemini-api-key",
          "litellm-anthropic-api-key",
        ],
        id
      )
    ])
    error_message = "litellm_import_secret_ids entries must be litellm-master-key, litellm-gemini-api-key, or litellm-anthropic-api-key."
  }
}

variable "litellm_mount_anthropic" {
  type        = bool
  description = "Mount ANTHROPIC_API_KEY on LiteLLM. Requires an enabled version of litellm-anthropic-api-key."
  default     = false
}
