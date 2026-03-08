
terraform {
 backend "gcs" {
  bucket  = "healthcare-terraform-state"
  prefix  = "terraform/dev"
 }
}
