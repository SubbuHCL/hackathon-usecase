
resource "google_compute_network" "vpc" {
 name = "healthcare-vpc"
 auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
 name          = "public-subnet"
 ip_cidr_range = "10.0.1.0/24"
 region        = "asia-south1"
 network       = google_compute_network.vpc.id
}
