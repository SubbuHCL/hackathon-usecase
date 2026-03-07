output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.gke.name
}

output "gke_endpoint" {
  description = "GKE endpoint (private cluster master may not be publicly accessible)"
  value       = google_container_cluster.gke.endpoint
}

output "node_service_account" {
  description = "GKE Node Service Account email"
  value       = google_service_account.gke_node_sa.email
}

output "repository_id" {
    value = google_artifact_registry_repository.hcl.repository_id
}

output "repository_resource_name" {
    value = google_artifact_registry_repository.hcl.name
}

output "docker_push_url" {
    value = "${var.location}-docker.pkg.dev/${var.project != "" ? var.project : "<PROJECT>"}${"/"}${lower(var.repo_name)}"
    description = "URL to use for docker push/pull: <location>-docker.pkg.dev/<project>/<repository>"
}