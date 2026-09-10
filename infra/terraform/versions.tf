# Shared Terraform version constraints for this repo.
# Environment roots (envs/dev) should require these providers as well.

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
