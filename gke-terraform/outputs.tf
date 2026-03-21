output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The name of the GKE cluster"
}

output "kubernetes_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "The Kubernetes API endpoint"
  sensitive   = true
}

output "node_pool_name" {
  value       = google_container_node_pool.primary_pool.name
  description = "The name of the node pool"
}

output "project_id" {
  value       = var.project_id
  description = "The GCP project ID"
}

output "region" {
  value       = var.region
  description = "The GCP region"
}

output "network_name" {
  value       = google_compute_network.vpc.name
  description = "The name of the VPC network"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "The name of the subnet"
}

output "gcr_bucket_name" {
  value       = google_storage_bucket.gcr_bucket.name
  description = "The GCR bucket name for storing container images"
}

output "terraform_state_bucket" {
  value       = google_storage_bucket.terraform_state.name
  description = "The GCS bucket used for Terraform state storage"
}

output "node_service_account_email" {
  value       = google_service_account.node_sa.email
  description = "The email of the node pool service account"
}

output "gke_config_command" {
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${var.region} --project ${var.project_id}"
  description = "Command to configure kubectl to access the GKE cluster"
}

