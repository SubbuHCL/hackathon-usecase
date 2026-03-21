# list of APIs we will enable
locals {
  apis = [
    "container.googleapis.com",        # GKE
    "compute.googleapis.com",          # VPC, subnets, nodes
    "iam.googleapis.com",              # IAM
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",     # manage services
    "cloudbilling.googleapis.com",
    "containerregistry.googleapis.com", # optional: Container Registry
    "artifactregistry.googleapis.com",  # recommended: Artifact Registry
    "cloudkms.googleapis.com",         # if using CMEK
    "servicenetworking.googleapis.com" # for private service connections (if needed)
  ]
}

resource "google_project_service" "enabled" {
  for_each = toset(local.apis)
  project  = var.project_id
  service  = each.value

  # sometimes enabling services can require a few minutes
  disable_on_destroy = false
}

