# AWS Region
aws_region = "us-east-1"

# Environment
environment = "dev"

# Project Name
project_name = "microservices"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# NAT Gateway Configuration
enable_nat_gateway = true
single_nat_gateway = false  # Set to true to use single NAT gateway (cost savings)

# EKS Cluster Configuration
cluster_version = "1.28"

# EKS Node Group Configuration
node_instance_types = ["t3.medium"]
node_desired_size   = 3
node_min_size       = 3
node_max_size       = 5
node_disk_size      = 20

# ECR Repositories
ecr_repositories = ["patient-service", "application-service", "order-service"]

# Additional Tags
tags = {
  Terraform   = "true"
  Owner       = "DevOps Team"
  CostCenter  = "Engineering"
}
