locals {
  labels = merge(
    {
      app         = "paperclip"
      environment = var.environment
      managed-by  = "terraform"
    },
    var.labels,
  )

  # APIs needed by Phase 1 foundation. Bootstrap already enables these; Terraform
  # re-asserts them so a fresh project cannot skip the bootstrap list silently.
  required_apis = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.required_apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Runtime service accounts (Phase 1.2)
# ---------------------------------------------------------------------------

resource "google_service_account" "paperclip_runtime" {
  project      = var.project_id
  account_id   = "paperclip-runtime"
  display_name = "Paperclip Cloud Run runtime"
  description  = "Least-privilege SA for the Paperclip Cloud Run service and bootstrap job"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "litellm_runtime" {
  project      = var.project_id
  account_id   = "litellm-runtime"
  display_name = "LiteLLM Cloud Run runtime"
  description  = "Placeholder SA for Phase 2 LiteLLM gateway"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "paperclip_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.paperclip_runtime.email}"
}

resource "google_project_iam_member" "paperclip_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.paperclip_runtime.email}"
}

resource "google_project_iam_member" "paperclip_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.paperclip_runtime.email}"
}

resource "google_project_iam_member" "litellm_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.litellm_runtime.email}"
}

resource "google_project_iam_member" "litellm_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.litellm_runtime.email}"
}

# ---------------------------------------------------------------------------
# Foundation modules
# ---------------------------------------------------------------------------

module "network" {
  source = "../../modules/network"

  project_id = var.project_id
  region     = var.region

  depends_on = [google_project_service.required]
}

# DB password is generated once and kept in Terraform state (GCS backend is private).
# Also seed paperclip-db-password / paperclip-database-url via scripts/seed-secrets.sh
# after apply so Cloud Run can read them from Secret Manager (1.7).
resource "random_password" "db" {
  length  = 32
  special = false
}

module "database" {
  source = "../../modules/database"

  project_id        = var.project_id
  region            = var.region
  private_network   = module.network.network_id
  tier              = var.cloud_sql_tier
  database_password = random_password.db.result
  labels            = local.labels

  depends_on = [module.network]
}

module "registry" {
  source = "../../modules/registry"

  project_id                     = var.project_id
  region                         = var.region
  runtime_service_account_email  = google_service_account.paperclip_runtime.email
  deployer_service_account_email = var.deployer_service_account_email
  labels                         = local.labels

  depends_on = [google_project_service.required]
}

module "secrets" {
  source = "../../modules/secrets"

  project_id                    = var.project_id
  runtime_service_account_email = google_service_account.paperclip_runtime.email
  labels                        = local.labels

  depends_on = [google_project_service.required]
}

module "storage" {
  source = "../../modules/storage"

  project_id      = var.project_id
  region          = var.region
  bucket_name     = var.uploads_bucket_name
  create_hmac_key = var.create_hmac_key
  labels          = local.labels

  depends_on = [google_project_service.required]
}

# ---------------------------------------------------------------------------
# Cloud Run Paperclip (Phase 1.4)
# Created only when paperclip_image_digest is a real sha256 digest (after
# image-promote). Foundation resources still apply with the PENDING placeholder.
# ---------------------------------------------------------------------------

locals {
  paperclip_image_ready = can(regex("^sha256:[0-9a-f]{64}$", var.paperclip_image_digest))
  paperclip_image       = "${module.registry.repository_url}/paperclip@${var.paperclip_image_digest}"
  paperclip_hostname = try(
    regex("^https?://([^/]+)", var.paperclip_public_url)[0],
    "",
  )
}

module "service" {
  count  = local.paperclip_image_ready && var.paperclip_public_url != "" ? 1 : 0
  source = "../../modules/service"

  project_id            = var.project_id
  region                = var.region
  image                 = local.paperclip_image
  service_account_email = google_service_account.paperclip_runtime.email
  network               = module.network.network_id
  subnet                = module.network.subnet_id
  secret_ids            = module.secrets.secret_ids
  public_url            = var.paperclip_public_url
  allowed_hostnames     = var.paperclip_allowed_hostnames != "" ? var.paperclip_allowed_hostnames : local.paperclip_hostname
  storage_bucket        = module.storage.bucket_name
  storage_region        = module.storage.bucket_location
  cpu                   = var.paperclip_cpu
  memory                = var.paperclip_memory
  auth_disable_sign_up  = var.paperclip_auth_disable_sign_up
  labels                = local.labels

  depends_on = [
    module.database,
    module.secrets,
    module.storage,
    module.network,
    google_project_iam_member.paperclip_sql_client,
  ]
}

module "jobs" {
  count  = local.paperclip_image_ready && var.paperclip_public_url != "" ? 1 : 0
  source = "../../modules/jobs"

  project_id            = var.project_id
  region                = var.region
  image                 = local.paperclip_image
  service_account_email = google_service_account.paperclip_runtime.email
  network               = module.network.network_id
  subnet                = module.network.subnet_id
  secret_ids            = module.secrets.secret_ids
  public_url            = var.paperclip_public_url
  storage_bucket        = module.storage.bucket_name
  storage_region        = module.storage.bucket_location
  labels                = local.labels

  depends_on = [
    module.database,
    module.secrets,
    module.storage,
    module.network,
    google_project_iam_member.paperclip_sql_client,
  ]
}
