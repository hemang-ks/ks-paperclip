variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Region for the runtime subnet"
}

variable "network_name" {
  type        = string
  description = "VPC network name"
  default     = "paperclip-vpc"
}

variable "subnet_name" {
  type        = string
  description = "Subnet name for Cloud Run Direct VPC egress"
  default     = "paperclip-runtime"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet CIDR. Must be /26 or larger for Direct VPC egress."
  default     = "10.10.0.0/26"

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr)) && tonumber(split("/", var.subnet_cidr)[1]) <= 26
    error_message = "subnet_cidr must be a /26 or larger (smaller prefix length)."
  }
}

variable "psa_range_name" {
  type        = string
  description = "Name of the reserved IP range for Private Service Access"
  default     = "paperclip-psa"
}

variable "psa_prefix_length" {
  type        = number
  description = "Prefix length for the PSA allocated range"
  default     = 16
}
