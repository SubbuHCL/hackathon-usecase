variable "project_id" {
  type        = string
  description = "GCP project id to create/use for this GKE cluster"
}

variable "organization_id" {
  type        = string
  description = "Optional: Organization ID if creating project via Terraform"
  default     = ""
}

variable "billing_account_id" {
  type        = string
  description = "Billing Account ID (e.g. 012345-ABCDEF-...); required to attach billing when creating project"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP zone"
  default     = "us-central1-a"
}

variable "network_name" {
  type        = string
  default     = "gke-network"
}

variable "subnet_name" {
  type        = string
  default     = "gke-subnet"
}

variable "subnet_cidr" {
  type        = string
  default     = "10.10.0.0/16"
}

variable "cluster_name" {
  type        = string
  default     = "gke-cluster"
}

variable "node_pool_name" {
  type        = string
  default     = "primary-pool"
}

variable "node_count" {
  type        = number
  default     = 3
}

variable "node_machine_type" {
  type        = string
  default     = "e2-medium"
}

