resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  remove_default_node_pool = true
  initial_node_count       = 1

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Basic cluster features

  # Enable master authorized networks? (Optional)
  # master_authorized_networks_config { ... }

  # Kubernetes version (optional) - let GCP choose the default or specify
  # initial_cluster_version = "1.27.*/*"

  # Enable logging/monitoring (default true)
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Binary authorization, shielded nodes or private cluster settings could be added here for prod
}

resource "google_container_node_pool" "primary_pool" {
  name       = var.node_pool_name
  cluster    = google_container_cluster.primary.name
  location   = var.region
  project    = var.project_id

  node_count = var.node_count

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 30  # 🔽 Reduce from 100 → 50 (or 30)
    disk_type     = "pd-standard"  # 🔽 Optional: use cheaper non-SSD disk
    oauth_scopes  = ["https://www.googleapis.com/auth/cloud-platform"]

    # Use the dedicated node service account
    service_account = google_service_account.node_sa.email
    
    # Labels for better organization
    labels = {
      environment = "prod"
      managed-by  = "terraform"
    }
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

