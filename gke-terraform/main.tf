###############################################
# main.tf - GKE setup in existing GCP project #
###############################################

# Configure Terraform with GCS backend for state management
# Replace the bucket name with your actual GCS bucket
terraform {
  required_version = ">= 1.4.0"
  
  # Use GCS for remote state storage
  # Uncomment the backend block for production use
  # For local development, comment it out
  backend "gcs" {
    bucket  = "hackathon-terraform-state"
    prefix  = "gke/prod"
  }
  
  # Alternatively, for local testing use:
  # backend "local" {
  #   path = "terraform.tfstate"
  # }
}


