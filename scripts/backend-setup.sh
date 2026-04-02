#!/bin/bash

# Backend Setup Script
# Creates S3 bucket and DynamoDB table for Terraform state management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$SCRIPT_DIR/../terraform/backend-setup"

# Parse command-line arguments or use environment variables
ENVIRONMENT="${TF_VAR_environment:-${1:-dev}}"
PROJECT_NAME="${TF_VAR_project_name:-${2:-microservices}}"
AWS_REGION="${TF_VAR_aws_region:-${3:-us-east-1}}"

# Generate bucket name and DynamoDB table with environment-specific pattern
BUCKET_NAME="${TF_VAR_state_bucket_name:-microservices-terraform-state-bucket-${ENVIRONMENT}}"
DYNAMODB_TABLE="${TF_VAR_dynamodb_table_name:-microservices-terraform-state-lock-${ENVIRONMENT}}"

print_header "Terraform Backend Setup"
echo ""

print_info "Parameters:"
echo "  Environment: $ENVIRONMENT"
echo "  Project: $PROJECT_NAME"
echo "  Region: $AWS_REGION"
echo ""

# Check if backend-setup directory exists
if [ ! -d "$BACKEND_DIR" ]; then
    print_error "Backend setup directory not found: $BACKEND_DIR"
    exit 1
fi

# Navigate to backend-setup directory
cd "$BACKEND_DIR"

print_info "Working directory: $(pwd)"
echo ""

print_info "Configuration:"
echo "  S3 Bucket: $BUCKET_NAME"
echo "  DynamoDB Table: $DYNAMODB_TABLE"
echo ""

# Warning about bucket name uniqueness
# Check if running in CI/CD (non-interactive mode)
CI_MODE="${CI:-false}"
if [ "$CI_MODE" = "true" ] || [ -n "$TF_VAR_environment" ]; then
    print_info "Running in CI/CD mode (non-interactive)"
    SKIP_PROMPTS=true
else
    SKIP_PROMPTS=false
fi

# Create or update terraform.tfvars with parameters
print_info "Generating terraform.tfvars..."
cat > terraform.tfvars << EOF
# Auto-generated configuration
# Generated: $(date)

aws_region = "$AWS_REGION"
environment = "$ENVIRONMENT"
state_bucket_name = "microservices-terraform-state-bucket"
state_bucket_suffix = "$ENVIRONMENT"
dynamodb_table_name = "microservices-terraform-state-lock"
dynamodb_table_suffix = "$ENVIRONMENT"
EOF

print_success "Configuration file created"
echo ""

if [ "$SKIP_PROMPTS" = false ]; then
    print_warning "IMPORTANT: S3 bucket names must be globally unique!"
    print_warning "Bucket name: $BUCKET_NAME"
    echo ""
    
    read -p "Do you want to proceed with this bucket name? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_error "Deployment cancelled"
        exit 1
    fi
    echo ""
fi

# Initialize Terraform
print_info "Initializing Terraform..."
if terraform init -input=false; then
    print_success "Terraform initialized successfully"
else
    print_error "Terraform initialization failed"
    exit 1
fi

echo ""

# Validate configuration
print_info "Validating Terraform configuration..."
if terraform validate; then
    print_success "Configuration is valid"
else
    print_error "Configuration validation failed"
    exit 1
fi

echo ""

# Plan
print_info "Creating Terraform plan..."
if terraform plan -out=backend.tfplan -input=false; then
    print_success "Plan created successfully"
else
    print_error "Plan creation failed"
    exit 1
fi

echo ""

# Show what will be created
print_header "Resources to be Created"
echo ""
terraform show -no-color backend.tfplan | grep -A 5 "will be created" || true
echo ""

# Confirm before applying
print_warning "This will create the following AWS resources:"
echo "  - S3 Bucket: $BUCKET_NAME"
echo "  - DynamoDB Table: $DYNAMODB_TABLE"
echo ""
print_warning "Estimated cost: ~\$0.50/month (minimal)"
echo ""

if [ "$SKIP_PROMPTS" = false ]; then
    read -p "Do you want to proceed with creating these resources? (yes/no): " apply_confirm
    if [ "$apply_confirm" != "yes" ]; then
        print_warning "Backend creation cancelled"
        rm -f backend.tfplan
        exit 0
    fi
    echo ""
fi

# Apply
print_info "Creating backend resources..."
if terraform apply -auto-approve backend.tfplan; then
    print_success "Backend resources created successfully!"
    rm -f backend.tfplan
else
    print_error "Failed to create backend resources"
    rm -f backend.tfplan
    exit 1
fi

echo ""

# Display outputs
print_header "Backend Configuration"
echo ""
terraform output

echo ""

# Save backend config for reference
print_info "Saving backend configuration..."
cat > backend-config.txt << EOF
# Backend Configuration
# Add this to your main Terraform configuration

terraform {
  backend "s3" {
    bucket         = "$BUCKET_NAME"
    key            = "microservices/terraform.tfstate"
    region         = "$(terraform output -raw s3_bucket_name | xargs aws s3api get-bucket-location --bucket | grep -o 'us-[a-z]*-[0-9]' || echo 'us-east-1')"
    encrypt        = true
    dynamodb_table = "$DYNAMODB_TABLE"
  }
}
EOF

print_success "Backend configuration saved to: backend-config.txt"
echo ""

# Check if main.tf needs updating
MAIN_TF="../main.tf"
if [ -f "$MAIN_TF" ]; then
    if grep -q "bucket.*=.*\"$BUCKET_NAME\"" "$MAIN_TF"; then
        print_success "Main Terraform configuration already uses this backend"
    else
        print_warning "Main Terraform configuration may need to be updated"
        echo "  File: $MAIN_TF"
        echo "  Update the backend block with:"
        echo "    bucket = \"$BUCKET_NAME\""
        echo "    dynamodb_table = \"$DYNAMODB_TABLE\""
    fi
fi

echo ""

print_header "Next Steps"
echo ""
print_info "1. Verify the backend configuration in ../main.tf"
print_info "2. Run the infrastructure deployment script:"
print_info "   cd $SCRIPT_DIR"
print_info "   ./2-infrastructure-deploy.sh"
echo ""

print_success "Backend setup completed successfully!"
