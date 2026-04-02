variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state (will be suffixed with environment)"
  type        = string
  default     = "microservices-terraform-state-bucket"
}

variable "state_bucket_suffix" {
  description = "Suffix for state bucket name (typically the environment)"
  type        = string
  default     = ""
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking (will be suffixed with environment)"
  type        = string
  default     = "microservices-terraform-state-lock"
}

variable "dynamodb_table_suffix" {
  description = "Suffix for DynamoDB table name (typically the environment)"
  type        = string
  default     = ""
}
