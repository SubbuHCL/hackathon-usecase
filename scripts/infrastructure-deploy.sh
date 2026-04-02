#!/bin/bash

# Infrastructure Deployment Script
# Deploys VPC, EKS, ECR, and all related resources

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
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Parse command-line arguments or use environment variables
ENVIRONMENT="${TF_VAR_environment:-${1:-dev}}"
PROJECT_NAME="${TF_VAR_project_name:-${2:-microservices}}"
AWS_REGION="${TF_VAR_aws_region:-${3:-us-east-1}}"
ECR_REPOS="${TF_VAR_ecr_repositories:-patient-service,application-service,order-service}"

print_header "Infrastructure Deployment"
echo ""

# Navigate to terraform directory
cd "$TERRAFORM_DIR"

print_info "Working directory: $(pwd)"
echo ""

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

# Convert comma-separated repos to Terraform list format
IFS=',' read -ra REPO_ARRAY <<< "$ECR_REPOS"
REPO_LIST="["
for i in "${!REPO_ARRAY[@]}"; do
    if [ $i -gt 0 ]; then
        REPO_LIST+=", "
    fi
    REPO_LIST+="\"${REPO_ARRAY[$i]}\""
done
REPO_LIST+="]"

cat > terraform.tfvars << EOF
# Auto-generated configuration
# Generated: $(date)

# AWS Configuration
aws_region = "$AWS_REGION"

# Project Configuration
environment  = "$ENVIRONMENT"
project_name = "$PROJECT_NAME"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["${AWS_REGION}a", "${AWS_REGION}b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# NAT Gateway Configuration
enable_nat_gateway = true
single_nat_gateway = false

# EKS Cluster Configuration
cluster_version = "1.28"

# EKS Node Group Configuration
node_instance_types = ["t3.medium"]
node_desired_size   = 3
node_min_size       = 3
node_max_size       = 5
node_disk_size      = 20

# ECR Repositories
ecr_repositories = $REPO_LIST

# Additional Tags
tags = {
  Terraform  = "true"
  Owner      = "DevOps Team"
  CostCenter = "Engineering"
}
EOF

print_success "Configuration file created"
echo ""

print_info "Configuration:"
echo "  Project: $PROJECT_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $AWS_REGION"
echo ""

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

# Format check
print_info "Checking Terraform formatting..."
if terraform fmt -check -recursive; then
    print_success "All files are properly formatted"
else
    print_warning "Some files need formatting. Running terraform fmt..."
    terraform fmt -recursive
fi

echo ""

# Plan
print_info "Creating Terraform plan..."
if terraform plan -out=infra.tfplan -input=false; then
    print_success "Plan created successfully"
else
    print_error "Plan creation failed"
    exit 1
fi

echo ""

# Show resource summary
print_header "Deployment Summary"
echo ""

RESOURCES_TO_ADD=$(terraform show -json infra.tfplan 2>/dev/null | grep -o '"create"' | wc -l || echo "N/A")
print_info "Resources to create: $RESOURCES_TO_ADD"

echo ""
print_warning "This deployment will create:"
echo "  ✓ VPC with public and private subnets (2 AZs)"
echo "  ✓ Internet Gateway"
echo "  ✓ NAT Gateways (2)"
echo "  ✓ Route Tables"
echo "  ✓ EKS Cluster (Kubernetes 1.28)"
echo "  ✓ EKS Managed Node Group (3-5 nodes, t3.medium)"
echo "  ✓ ECR Repositories (${#REPO_ARRAY[@]})"
echo "  ✓ IAM Roles and Policies"
echo "  ✓ Security Groups"
echo ""

print_warning "Estimated Monthly Cost:"
echo "  - EKS Cluster: ~\$73/month"
echo "  - EC2 Instances (3 × t3.medium): ~\$90/month"
echo "  - NAT Gateways (2): ~\$90/month"
echo "  - EBS Volumes: ~\$6/month"
echo "  - Total: ~\$259/month (approximate)"
echo ""

print_warning "Deployment Time: 15-20 minutes"
echo ""

if [ "$SKIP_PROMPTS" = false ]; then
    read -p "Do you want to proceed with the deployment? (yes/no): " deploy_confirm
    if [ "$deploy_confirm" != "yes" ]; then
        print_warning "Deployment cancelled"
        rm -f infra.tfplan
        exit 0
    fi
    echo ""
fi

# Apply
print_info "Deploying infrastructure..."
print_warning "This will take approximately 15-20 minutes. Please be patient..."
echo ""

START_TIME=$(date +%s)

if terraform apply -auto-approve infra.tfplan; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    print_success "Infrastructure deployed successfully!"
    print_info "Deployment took: ${MINUTES}m ${SECONDS}s"
    rm -f infra.tfplan
else
    print_error "Infrastructure deployment failed"
    rm -f infra.tfplan
    exit 1
fi

echo ""

# Display outputs
print_header "Infrastructure Outputs"
echo ""
terraform output

echo ""

# Configure kubectl
print_info "Configuring kubectl..."
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")

if [ -n "$CLUSTER_NAME" ]; then
    if aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" 2>/dev/null; then
        print_success "kubectl configured successfully"
        echo ""
        print_info "Verifying cluster access..."
        if kubectl get nodes 2>/dev/null; then
            print_success "Successfully connected to EKS cluster"
        else
            print_warning "Cluster is still initializing. Nodes may take a few minutes to be ready."
        fi
    else
        print_warning "kubectl configuration will be available once cluster is fully ready"
        echo "  Run manually: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
    fi
else
    print_warning "Could not retrieve cluster name from outputs"
fi

echo ""

# Save important information
print_info "Saving deployment information..."
cat > deployment-info.txt << EOF
# Infrastructure Deployment Information
# Generated: $(date)

Project: $PROJECT_NAME
Environment: $ENVIRONMENT
Region: $AWS_REGION

## EKS Cluster
Cluster Name: $(terraform output -raw eks_cluster_name 2>/dev/null || echo "N/A")
Cluster Endpoint: $(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "N/A")
Cluster Version: $(terraform output -raw eks_cluster_version 2>/dev/null || echo "N/A")

## Configure kubectl
aws eks update-kubeconfig --region $AWS_REGION --name $(terraform output -raw eks_cluster_name 2>/dev/null || echo "CLUSTER_NAME")

## ECR Repositories
$(terraform output -json ecr_repository_urls 2>/dev/null | jq -r 'to_entries[] | "\(.key): \(.value)"' 2>/dev/null || terraform output -json ecr_repository_urls 2>/dev/null || echo "N/A")

## ECR Login Command
$(terraform output -raw ecr_login_command 2>/dev/null || echo "N/A")

## VPC Information
VPC ID: $(terraform output -raw vpc_id 2>/dev/null || echo "N/A")
VPC CIDR: $(terraform output -raw vpc_cidr 2>/dev/null || echo "N/A")
Public Subnets: $(terraform output -json public_subnet_ids 2>/dev/null || echo "N/A")
Private Subnets: $(terraform output -json private_subnet_ids 2>/dev/null || echo "N/A")

## Node Group Information
Node Group ID: $(terraform output -raw eks_node_group_id 2>/dev/null || echo "N/A")
Node Group Status: $(terraform output -raw eks_node_group_status 2>/dev/null || echo "N/A")
EOF

print_success "Deployment information saved to: deployment-info.txt"
echo ""

# Next steps
print_header "Infrastructure Setup Complete"
echo ""
print_success "All infrastructure resources have been successfully deployed!"
echo ""
print_info "Infrastructure includes:"
echo "  ✓ VPC with public and private subnets"
echo "  ✓ NAT Gateways and Internet Gateway"
echo "  ✓ EKS Cluster with managed node group"
echo "  ✓ ECR Repositories for container images"
echo "  ✓ IAM roles and security groups"
echo ""
print_info "Access Information:"
echo "  - Cluster Name: $CLUSTER_NAME"
echo "  - Region: $AWS_REGION"
echo "  - Environment: $ENVIRONMENT"
echo ""
print_info "Verify cluster status:"
echo "  kubectl get nodes"
echo "  kubectl cluster-info"
echo ""

print_success "Infrastructure deployment completed successfully!"
