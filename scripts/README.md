# Terraform Setup Scripts

This directory contains automated scripts to set up and deploy the infrastructure.

## Scripts Overview

### Prerequisites Check
**Script:** [`prerequisites-check.sh`](prerequisites-check.sh)

Verifies that all required tools and configurations are in place:
- AWS CLI installation and configuration
- Terraform installation (>= 1.0.0)
- kubectl installation
- Docker installation
- AWS credentials and permissions
- Disk space

**Usage:**
```bash
cd terraform/scripts
chmod +x *.sh
./prerequisites-check.sh
```

### Backend Setup
**Script:** [`backend-setup.sh`](backend-setup.sh)

Creates the S3 bucket and DynamoDB table for Terraform state management:
- S3 bucket with versioning and encryption
- DynamoDB table for state locking
- Validates bucket name uniqueness
- Saves backend configuration

**Usage:**
```bash
./backend-setup.sh <environment> <project> <region>

# Example:
./backend-setup.sh dev microservices us-east-1
```

### Infrastructure Deployment
**Script:** [`infrastructure-deploy.sh`](infrastructure-deploy.sh)

Deploys the complete infrastructure:
- VPC with public and private subnets
- NAT Gateways and Internet Gateway
- EKS cluster with managed node group
- ECR repositories
- IAM roles and security groups
- Configures kubectl automatically

**Usage:**
```bash
./infrastructure-deploy.sh <environment> <project> <region>

# Example:
./infrastructure-deploy.sh dev microservices us-east-1
```

**Duration:** 15-20 minutes

### CI/CD Pipeline
**Script:** [`cicd-pipeline.sh`](cicd-pipeline.sh)

Orchestrates the complete deployment process (used by GitHub Actions):
- Runs prerequisites check
- Sets up backend
- Executes terraform plan
- Optionally applies changes
- Configures kubectl

**Usage:**
```bash
./cicd-pipeline.sh <action> <environment> <project> <region> <repos>

# Examples:
./cicd-pipeline.sh plan dev microservices us-east-1 "service1,service2"
./cicd-pipeline.sh deploy prod microservices us-east-1 "service1,service2"
```

## Quick Start

Run all scripts in sequence:

```bash
cd terraform/scripts

# Make scripts executable
chmod +x *.sh

# Step 1: Check prerequisites
./prerequisites-check.sh

# Step 2: Setup backend (run once)
./backend-setup.sh dev microservices us-east-1

# Step 3: Deploy infrastructure
./infrastructure-deploy.sh dev microservices us-east-1

# Or use the CI/CD pipeline script
./cicd-pipeline.sh deploy dev microservices us-east-1 "patient-service,application-service,order-service"
```

## Script Features

### Color-Coded Output
- 🟢 **GREEN**: Success messages and info
- 🟡 **YELLOW**: Warnings
- 🔴 **RED**: Errors
- 🔵 **BLUE**: Section headers

### Safety Features
- Confirmation prompts before destructive operations
- Validation checks before deployment
- Error handling with clear messages
- Automatic cleanup of temporary files

### Output Files

Scripts generate helpful output files:

**Backend Setup:**
- `backend-config.txt` - Backend configuration reference

**Infrastructure Deployment:**
- `deployment-info.txt` - Cluster details, ECR URLs, kubectl commands
- `infra.tfplan` - Terraform plan (temporary)

## Prerequisites

Before running the scripts, ensure:

1. **AWS CLI configured:**
   ```bash
   aws configure
   ```

2. **Terraform installed:**
   ```bash
   terraform version
   ```

3. **Unique S3 bucket name:**
   Edit `backend-setup/terraform.tfvars`:
   ```hcl
   state_bucket_name = "your-unique-bucket-name-12345"
   ```

4. **Appropriate AWS permissions:**
   - VPC management
   - EKS cluster creation
   - ECR repository management
   - IAM role/policy management

## Troubleshooting

### Script Permission Denied
```bash
chmod +x terraform/scripts/*.sh
```

### AWS Credentials Not Found
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and Region
```

### Terraform Not Found
Install Terraform from: https://www.terraform.io/downloads

### S3 Bucket Already Exists
Update the bucket name in `backend-setup/terraform.tfvars` to a unique value.

## Manual Execution

If you prefer to run commands manually instead of using scripts:

### Backend Setup
```bash
cd terraform/backend-setup
terraform init
terraform plan
terraform apply
```

### Infrastructure Deployment
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name microservices-dev-eks-cluster
kubectl get nodes
```

## Cost Estimates

Running these scripts will create resources with the following approximate monthly costs:

- **Backend (S3 + DynamoDB):** ~$0.50/month
- **Infrastructure (VPC + EKS + EC2):** ~$259/month

Total: ~$260/month

## Cleanup

To destroy all resources:

```bash
# Destroy main infrastructure
cd terraform
terraform destroy

# Destroy backend (only after destroying main infrastructure)
cd backend-setup
terraform destroy
```

**Warning:** This will delete all resources including data. Backup important data first.

## Support

For issues or questions:
1. Check the main [Terraform README](../README.md)
2. Review AWS CloudWatch logs
3. Validate configuration: `terraform validate`
4. Check Terraform state: `terraform show`
