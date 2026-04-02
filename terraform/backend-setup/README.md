# Terraform Backend Setup

This directory contains the Terraform configuration to create the S3 bucket and DynamoDB table required for remote state management.

## What This Creates

1. **S3 Bucket** - Stores Terraform state files
   - Versioning enabled
   - Server-side encryption (AES256)
   - Public access blocked
   - Lifecycle policy (delete old versions after 90 days)

2. **DynamoDB Table** - Provides state locking
   - Pay-per-request billing
   - LockID as hash key

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform installed

## Setup Instructions

### Step 1: Update the Bucket Name

Edit [`terraform.tfvars`](terraform.tfvars) and change the `state_bucket_name` to a globally unique name:

```hcl
state_bucket_name = "your-unique-bucket-name-12345"
```

### Step 2: Initialize and Apply

```bash
cd terraform/backend-setup
terraform init
terraform plan
terraform apply
```

Type `yes` when prompted.

### Step 3: Note the Outputs

After successful creation, note the output values:

```bash
terraform output
```

You'll see:
- S3 bucket name
- DynamoDB table name
- Backend configuration snippet

### Step 4: Update Main Terraform Configuration

The backend configuration is already set in the main [`terraform/main.tf`](../main.tf) file. Update it with your actual bucket name if you changed it:

```hcl
backend "s3" {
  bucket         = "your-unique-bucket-name-12345"
  key            = "microservices/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "microservices-terraform-state-lock"
}
```

### Step 5: Initialize Main Terraform with Backend

```bash
cd ../  # Go back to main terraform directory
terraform init
```

Terraform will now use the S3 backend for state storage.

## Important Notes

- **Run this ONCE** before running the main infrastructure
- The S3 bucket name must be globally unique across all AWS accounts
- Keep the backend-setup state file safe (it's stored locally)
- Don't delete the S3 bucket or DynamoDB table while using them for state

## Cleanup

To destroy the backend resources (only do this when you're completely done):

```bash
cd terraform/backend-setup
terraform destroy
```

**Warning**: Only destroy these resources after destroying all infrastructure that uses them for state storage.
