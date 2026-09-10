terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Partial backend: bucket comes from -backend-config or GH Actions TF_STATE_BUCKET.
  backend "gcs" {
    prefix = "paperclip/dev"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
