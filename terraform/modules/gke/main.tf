
resource "google_container_cluster" "primary" {
 name     = "healthcare-cluster"
 location = "asia-south1"

 remove_default_node_pool = true
 initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
 name       = "node-pool"
 cluster    = google_container_cluster.primary.name
 node_count = 2

 node_config {
   machine_type = "e2-medium"
 }
}
