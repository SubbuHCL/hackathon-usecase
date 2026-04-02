# Quick Start: Terraform State Bucket Setup

## Prerequisites

Before deploying infrastructure, you must create the Terraform state bucket for each environment.

## Step-by-Step Setup

### 1. Setup Dev Environment State Bucket

```bash
cd scripts
./backend-setup.sh dev
```

This creates:
- S3 Bucket: `microservices-terraform-state-bucket-dev`
- DynamoDB Table: `microservices-terraform-state-lock-dev`

### 2. Setup UAT Environment State Bucket

```bash
cd scripts
./backend-setup.sh uat
```

This creates:
- S3 Bucket: `microservices-terraform-state-bucket-uat`
- DynamoDB Table: `microservices-terraform-state-lock-uat`

### 3. Setup Prod Environment State Bucket

```bash
cd scripts
./backend-setup.sh prod
```

This creates:
- S3 Bucket: `microservices-terraform-state-bucket-prod`
- DynamoDB Table: `microservices-terraform-state-lock-prod`

## Via GitHub Actions

Alternatively, you can create state buckets via the GitHub Actions workflow:

1. Go to **Actions** → **Terraform Deploy**
2. Click **Run workflow**
3. Select environment: `dev`, `uat`, or `prod`
4. The workflow will automatically create the state bucket if it doesn't exist

## Verify Setup

```bash
# List all state buckets
aws s3 ls | grep microservices-terraform-state-bucket

# Expected output:
# microservices-terraform-state-bucket-dev
# microservices-terraform-state-bucket-uat
# microservices-terraform-state-bucket-prod

# Check DynamoDB tables
aws dynamodb list-tables | grep microservices-terraform-state-lock

# Expected output:
# microservices-terraform-state-lock-dev
# microservices-terraform-state-lock-uat
# microservices-terraform-state-lock-prod

# Describe a specific table
aws dynamodb describe-table --table-name microservices-terraform-state-lock-dev
```

## What Happens Next?

Once state buckets are created:

1. **Terraform Deploy** workflow will use the correct bucket based on environment
2. Each environment's infrastructure state is stored separately
3. State files are encrypted, versioned, and locked during operations

## Bucket Configuration

Each bucket is automatically configured with:
- ✅ Versioning enabled
- ✅ Encryption (AES256)
- ✅ Public access blocked
- ✅ Lifecycle policy (90-day retention for old versions)

## Important Notes

⚠️ **One-Time Setup**: You only need to create each state bucket once
⚠️ **Order Matters**: Create state buckets BEFORE deploying infrastructure
⚠️ **Environment Isolation**: Each environment has its own S3 bucket AND DynamoDB lock table
⚠️ **Bucket Names**: Must be globally unique (default pattern handles this)

## Troubleshooting

### Bucket already exists error

If you see "bucket already exists", it means the bucket was created previously. You can proceed with infrastructure deployment.

### Access denied error

Ensure your AWS credentials have permissions to:
- Create S3 buckets
- Create DynamoDB tables
- Enable S3 versioning and encryption

### State lock timeout

If Terraform operations timeout due to state lock:
```bash
# Check for stuck locks in specific environment
aws dynamodb scan --table-name microservices-terraform-state-lock-dev
aws dynamodb scan --table-name microservices-terraform-state-lock-uat
aws dynamodb scan --table-name microservices-terraform-state-lock-prod

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

## Next Steps

After creating state buckets, proceed with:

1. **Infrastructure Deployment**: Run Terraform Deploy workflow
2. **Docker Build**: Build and push container images
3. **Kubernetes Deployment**: Deploy microservices to EKS

See [CICD_SETUP_GUIDE.md](CICD_SETUP_GUIDE.md) for complete deployment instructions.
