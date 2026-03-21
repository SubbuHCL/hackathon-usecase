provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
  # If using user credentials, you can omit credentials block.
  # If using a service account key file:
  # credentials = file(var.credentials_file)
}

# google-beta provider (used only when needed)
provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

