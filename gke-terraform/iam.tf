resource "google_service_account" "terraform_sa" {
  account_id   = "tf-provisioner"
  display_name = "Terraform Provisioner SA"
  project      = var.project_id
}

# Grant rights to the SA for necessary ops (these are example roles; tighten them in production)
resource "google_project_iam_member" "sa_owner" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}

