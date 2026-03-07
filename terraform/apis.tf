resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",           # VPC, subnets, NAT
    "container.googleapis.com",         # GKE
    "containerregistry.googleapis.com", # GCR
    "iam.googleapis.com",
    "servicenetworking.googleapis.com", # required for private services & peering
    "storage.googleapis.com",
    "artifactregistry.googleapis.com"
  ])
  project = var.project_id
  service = each.key
  disable_on_destroy = false
}
