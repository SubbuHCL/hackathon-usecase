# Terraform State Management - Environment-Specific Configuration

## Overview

This project uses **environment-specific S3 buckets** for Terraform state management. Each environment (dev, uat, prod) has its own dedicated S3 bucket to ensure complete isolation of infrastructure state.

## Naming Patterns

### State Buckets
```
microservices-terraform-state-bucket-{environment}
```

### DynamoDB Lock Tables
```
microservices-terraform-state-lock-{environment}
```

### Environment-Specific Resources

| Environment | S3 Bucket | DynamoDB Table |
|-------------|-----------|----------------|
| **dev** | `microservices-terraform-state-bucket-dev` | `microservices-terraform-state-lock-dev` |
| **uat** | `microservices-terraform-state-bucket-uat` | `microservices-terraform-state-lock-uat` |
| **prod** | `microservices-terraform-state-bucket-prod` | `microservices-terraform-state-lock-prod` |

## How It Works

### 1. Backend Configuration Files

Each environment has a dedicated backend configuration file:

- [`terraform/backend-dev.hcl`](terraform/backend-dev.hcl) - Dev environment
- [`terraform/backend-uat.hcl`](terraform/backend-uat.hcl) - UAT environment
- [`terraform/backend-prod.hcl`](terraform/backend-prod.hcl) - Prod environment

**Example (`backend-dev.hcl`):**
```hcl
bucket = "microservices-terraform-state-bucket-dev"
```

### 2. Main Terraform Configuration

The main Terraform configuration ([`terraform/main.tf`](terraform/main.tf)) defines the backend with partial configuration:

```hcl
terraform {
  backend "s3" {
    # Bucket name provided via backend config file
    key            = "microservices/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "microservices-terraform-state-lock"
  }
}
```

### 3. Pipeline Integration

The CI/CD pipeline automatically selects the correct backend configuration based on the environment input:

**Terraform Deploy Workflow** ([`.github/workflows/terraform-deploy.yml`](.github/workflows/terraform-deploy.yml)):
```yaml
inputs:
  environment:
    description: 'Environment to deploy'
    required: true
    type: choice
    options:
      - dev
      - uat
      - prod
```

**Pipeline Script** ([`scripts/cicd-pipeline.sh`](scripts/cicd-pipeline.sh)):
```bash
BACKEND_CONFIG_FILE="backend-${ENVIRONMENT}.hcl"
terraform init -backend-config="$BACKEND_CONFIG_FILE" -reconfigure
```

## Creating State Buckets

### Automated Setup (Recommended)

The backend setup script automatically creates environment-specific buckets:

```bash
# Run via CI/CD pipeline
# The pipeline will automatically use the correct environment

# Or run manually
cd scripts
./backend-setup.sh dev    # Creates microservices-terraform-state-bucket-dev
./backend-setup.sh uat    # Creates microservices-terraform-state-bucket-uat
./backend-setup.sh prod   # Creates microservices-terraform-state-bucket-prod
```

### Manual Setup

If you need to create buckets manually:

```bash
cd terraform/backend-setup

# For dev environment
terraform init
terraform apply \
  -var="environment=dev" \
  -var="state_bucket_name=microservices-terraform-state-bucket" \
  -var="state_bucket_suffix=dev"

# For uat environment
terraform apply \
  -var="environment=uat" \
  -var="state_bucket_name=microservices-terraform-state-bucket" \
  -var="state_bucket_suffix=uat"

# For prod environment
terraform apply \
  -var="environment=prod" \
  -var="state_bucket_name=microservices-terraform-state-bucket" \
  -var="state_bucket_suffix=prod"
```

## State Bucket Features

Each state bucket is configured with:

✅ **Versioning** - Enabled for state file history  
✅ **Encryption** - AES256 server-side encryption  
✅ **Public Access Block** - All public access blocked  
✅ **Lifecycle Policy** - Old versions deleted after 90 days  
✅ **DynamoDB Locking** - Prevents concurrent state modifications  

## DynamoDB State Lock Table

A **single DynamoDB table** is shared across all environments for state locking:

```
microservices-terraform-state-lock
```

This table prevents concurrent Terraform operations and ensures state consistency.

## Deployment Flow

### 1. First-Time Setup

```bash
# Step 1: Create state bucket for dev
cd scripts
./backend-setup.sh dev

# Step 2: Deploy infrastructure to dev
# Via GitHub Actions: Terraform Deploy → Select 'dev'
```

### 2. Subsequent Deployments

```bash
# The pipeline automatically:
# 1. Reads environment input (dev/uat/prod)
# 2. Selects correct backend config file
# 3. Initializes Terraform with environment-specific bucket
# 4. Deploys infrastructure
```

### 3. Environment Isolation

```
┌─────────────────────────────────────────────────┐
│  Dev Environment                                │
│  ├─ State: microservices-terraform-state-bucket-dev  │
│  ├─ EKS Cluster: microservices-dev-cluster     │
│  └─ ECR Repos: *-dev                            │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  UAT Environment                                │
│  ├─ State: microservices-terraform-state-bucket-uat  │
│  ├─ EKS Cluster: microservices-uat-cluster     │
│  └─ ECR Repos: *-uat                            │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  Prod Environment                               │
│  ├─ State: microservices-terraform-state-bucket-prod │
│  ├─ EKS Cluster: microservices-prod-cluster    │
│  └─ ECR Repos: *-prod                           │
└─────────────────────────────────────────────────┘
```

## Switching Between Environments

When you run Terraform commands, the environment is determined by the backend config file:

```bash
# Initialize for dev
terraform init -backend-config=backend-dev.hcl -reconfigure

# Initialize for uat
terraform init -backend-config=backend-uat.hcl -reconfigure

# Initialize for prod
terraform init -backend-config=backend-prod.hcl -reconfigure
```

The `-reconfigure` flag ensures Terraform switches to the correct backend.

## Verifying State Configuration

### Check Current Backend

```bash
cd terraform
terraform init -backend-config=backend-dev.hcl
terraform show
```

### List State Buckets

```bash
aws s3 ls | grep microservices-terraform-state-bucket
```

Expected output:
```
microservices-terraform-state-bucket-dev
microservices-terraform-state-bucket-uat
microservices-terraform-state-bucket-prod
```

### View State File

```bash
# Dev environment
aws s3 ls s3://microservices-terraform-state-bucket-dev/microservices/

# UAT environment
aws s3 ls s3://microservices-terraform-state-bucket-uat/microservices/

# Prod environment
aws s3 ls s3://microservices-terraform-state-bucket-prod/microservices/
```

## Troubleshooting

### Issue: Backend initialization fails

**Solution:** Ensure the state bucket exists for the environment:

```bash
# Check if bucket exists
aws s3 ls s3://microservices-terraform-state-bucket-dev

# If not, create it
cd scripts
./backend-setup.sh dev
```

### Issue: Wrong environment state

**Solution:** Reinitialize with correct backend config:

```bash
cd terraform
terraform init -backend-config=backend-{correct-env}.hcl -reconfigure
```

### Issue: State lock error

**Solution:** Check DynamoDB table and release lock if needed:

```bash
# List locks
aws dynamodb scan --table-name microservices-terraform-state-lock

# If stuck, manually delete the lock item (use with caution!)
```

## Best Practices

1. ✅ **Always specify environment** when running Terraform commands
2. ✅ **Use CI/CD pipelines** for production deployments
3. ✅ **Never manually edit** state files
4. ✅ **Enable MFA delete** on production state bucket
5. ✅ **Regular backups** of state files (versioning handles this)
6. ✅ **Separate AWS accounts** for prod (recommended)

## Security Considerations

- State buckets are **private** with all public access blocked
- State files are **encrypted** at rest (AES256)
- State files may contain **sensitive data** - restrict access
- Use **IAM policies** to control who can access state buckets
- Enable **CloudTrail** logging for state bucket access

## Cost Estimation

Per environment:
- **S3 Bucket**: ~$0.023/GB/month (minimal for state files)
- **DynamoDB Table**: Pay-per-request (shared, ~$0.25/month)
- **Total**: ~$0.30/month per environment

## Related Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [CI/CD Setup Guide](CICD_SETUP_GUIDE.md)
- [Docker Instructions](DOCKER_INSTRUCTIONS.md)
- [GitHub Secrets Setup](GITHUB_SECRETS_SETUP.md)
