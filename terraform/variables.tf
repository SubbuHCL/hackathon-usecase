variable "project_id" {
  type        = string
  description = "hcl-hackathon"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "network_name" {
  type    = string
  default = "HCL-hackathon"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.10.0.0/20"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.10.16.0/20"
}

variable "pods_secondary_range" {
  type    = string
  default = "pods-range"
}

variable "services_secondary_range" {
  type    = string
  default = "services-range"
}

variable "repo_name" {
    description = "Repository name. Will be lowercased to meet GCP naming rules."
    type        = string
    default     = "hclhackathon"
}

variable "pods_secondary_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "services_secondary_cidr" {
  type    = string
  default = "10.21.0.0/20"
}

variable "gke_cluster_name" {
  type    = string
  default = "HCLhackathon-gke-cluster"
}

variable "gke_node_count" {
  type    = number
  default = 3
}

variable "credentials_path" {
  type = string
  default = "C:\Users\Admin\Downloads\skmpolo11-7993fe8aaa3f.json"
}