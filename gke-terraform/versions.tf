terraform {
  required_version = ">= 1.4.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      # pin a recent stable provider version you trust
      version = ">= 4.50.0"
    }
  }
}

