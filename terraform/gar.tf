resource "google_artifact_registry_repository" "hclhackathon" {
    provider      = google
    project       = var.project
    location      = var.location
    repository_id = lower(var.repo_name)
    format        = "DOCKER"
    description   = "Docker repository for ${var.repo_name}"
}

