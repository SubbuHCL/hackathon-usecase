# GCR (Google Container Registry) setup
resource "google_storage_bucket" "gcr_bucket" {
  name          = "${var.project_id}-gcr"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }

  labels = {
    environment = "prod"
    purpose     = "container-registry"
  }
}

# Grant the node service account access to pull images from GCR
resource "google_storage_bucket_iam_member" "node_gcr_pull" {
  bucket = google_storage_bucket.gcr_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:default@cloudservices.gserviceaccount.com"
}

# Create service account for the node pool
resource "google_service_account" "node_sa" {
  account_id   = "gke-node-pool-sa"
  display_name = "GKE Node Pool Service Account"
  project      = var.project_id
}

# Grant the node pool service account necessary permissions
resource "google_project_iam_member" "node_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

resource "google_project_iam_member" "node_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

resource "google_project_iam_member" "node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.node_sa.email}"
}

resource "google_storage_bucket_iam_member" "node_pull_gcr" {
  bucket = google_storage_bucket.gcr_bucket.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.node_sa.email}"
}

# Terraform state backend bucket
resource "google_storage_bucket" "terraform_state" {
  name          = "${var.project_id}-terraform-state"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  labels = {
    environment = "prod"
    purpose     = "terraform-state"
  }
}

# Optional: Create state lock table using Firestore for advanced locking
# For now, GCS versioning provides basic protection
