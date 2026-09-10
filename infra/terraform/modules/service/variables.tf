variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Cloud Run region"
}

variable "service_name" {
  type        = string
  description = "Cloud Run service name"
  default     = "paperclip"
}

variable "image" {
  type        = string
  description = "Container image as a digest reference (…@sha256:…). Never a mutable tag."

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must be a digest reference ending in @sha256:<64 hex chars>."
  }
}

variable "service_account_email" {
  type        = string
  description = "Runtime service account email (paperclip-runtime)"
}

variable "network" {
  type        = string
  description = "VPC network id/self_link for Direct VPC egress"
}

variable "subnet" {
  type        = string
  description = "Subnet id/self_link (/26+) for Direct VPC egress"
}

variable "secret_ids" {
  type        = map(string)
  description = "Map of logical name -> Secret Manager secret_id from the secrets module"
}

variable "optional_provider_secret_env" {
  type        = list(string)
  description = "Optional provider env keys to mount when present in secret_ids (Phase 1 usually empty; agents need Phase 2 gateway)"
  default     = []
}

variable "public_url" {
  type        = string
  description = "Public base URL (PAPERCLIP_PUBLIC_URL / PAPERCLIP_API_URL). Required for authenticated/public."
}

variable "allowed_hostnames" {
  type        = string
  description = "Comma-separated hostnames for PAPERCLIP_ALLOWED_HOSTNAMES"
}

variable "storage_bucket" {
  type        = string
  description = "GCS uploads bucket name"
}

variable "storage_region" {
  type        = string
  description = "Must match bucket location for SigV4 (PAPERCLIP_STORAGE_S3_REGION)"
}

variable "storage_endpoint" {
  type        = string
  description = "S3-compatible endpoint"
  default     = "https://storage.googleapis.com"
}

variable "storage_prefix" {
  type    = string
  default = "uploads"
}

variable "cpu" {
  type        = string
  description = "vCPU limit. STATUS / cost-optimized default is 1."
  default     = "1"
}

variable "memory" {
  type        = string
  description = "Memory limit"
  default     = "4Gi"
}

variable "timeout" {
  type        = string
  description = "Request timeout (platform max 3600s for long-lived WebSockets)"
  default     = "3600s"
}

variable "max_concurrency" {
  type        = number
  description = "Max concurrent requests per instance"
  default     = 80
}

variable "ingress" {
  type        = string
  description = "Cloud Run ingress. ALB not in cost-optimized plan; default ALL."
  default     = "INGRESS_TRAFFIC_ALL"
}

variable "deployment_exposure" {
  type        = string
  description = "PAPERCLIP_DEPLOYMENT_EXPOSURE"
  default     = "public"
}

variable "auth_disable_sign_up" {
  type        = bool
  description = "PAPERCLIP_AUTH_DISABLE_SIGN_UP — false until first admin is claimed"
  default     = false
}

variable "allow_unauthenticated" {
  type        = bool
  description = "Disable Cloud Run invoker IAM so browsers can reach Paperclip (app does Better Auth). Does not grant allUsers."
  default     = true
}

variable "extra_env" {
  type        = map(string)
  description = "Additional plain environment variables"
  default     = {}
}

variable "labels" {
  type    = map(string)
  default = {}
}
