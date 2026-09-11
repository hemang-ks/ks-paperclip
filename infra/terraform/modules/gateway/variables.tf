variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Cloud Run region (same as Paperclip)"
}

variable "service_name" {
  type        = string
  description = "Cloud Run service name"
  default     = "litellm"
}

variable "image" {
  type        = string
  description = "Gateway image as a digest reference (…@sha256:…). Never a mutable tag."

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.image))
    error_message = "image must be a digest reference ending in @sha256:<64 hex chars>."
  }
}

variable "service_account_email" {
  type        = string
  description = "Runtime service account email (litellm-runtime)"
}

variable "secret_ids" {
  type        = map(string)
  description = "Map of logical name -> Secret Manager secret_id from the gateway secrets module"
}

variable "mount_anthropic" {
  type        = bool
  description = "Mount ANTHROPIC_API_KEY. Secret must already have an enabled version or the revision fails to start."
  default     = false
}

variable "cpu" {
  type        = string
  description = "vCPU limit"
  default     = "1"
}

variable "memory" {
  type        = string
  description = "Memory limit"
  default     = "1Gi"
}

variable "timeout" {
  type        = string
  description = "Request timeout"
  default     = "300s"
}

variable "max_concurrency" {
  type        = number
  description = "Max concurrent requests per instance"
  default     = 40
}

variable "min_instance_count" {
  type        = number
  description = "Min instances. 0 is fine — no heartbeat scheduler on the gateway."
  default     = 0
}

variable "max_instance_count" {
  type        = number
  description = "Max instances (cost cap)"
  default     = 2
}

variable "ingress" {
  type        = string
  description = "INTERNAL_ONLY: same-project Cloud Run (Paperclip) can call; internet cannot."
  default     = "INGRESS_TRAFFIC_INTERNAL_ONLY"
}

variable "labels" {
  type    = map(string)
  default = {}
}
