#!/bin/bash

# Prerequisites Check Script
# Verifies that all required tools are installed and configured

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

# Track overall status
ALL_CHECKS_PASSED=true

print_header "Prerequisites Check"
echo ""

# Check 1: AWS CLI
print_info "Checking AWS CLI..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | cut -d' ' -f1)
    print_success "AWS CLI is installed: $AWS_VERSION"
else
    print_error "AWS CLI is not installed"
    echo "  Install from: https://aws.amazon.com/cli/"
    ALL_CHECKS_PASSED=false
fi

echo ""

# Check 2: Terraform
print_info "Checking Terraform..."
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*' | cut -d'"' -f4)
    if [ -z "$TERRAFORM_VERSION" ]; then
        TERRAFORM_VERSION=$(terraform version | head -n1 | cut -d'v' -f2)
    fi
    print_success "Terraform is installed: v$TERRAFORM_VERSION"
    
    # Check minimum version (1.0.0)
    REQUIRED_VERSION="1.0.0"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$TERRAFORM_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
        print_success "Terraform version meets minimum requirement (>= 1.0.0)"
    else
        print_warning "Terraform version is below recommended (>= 1.0.0)"
    fi
else
    print_error "Terraform is not installed"
    echo "  Install from: https://www.terraform.io/downloads"
    ALL_CHECKS_PASSED=false
fi

echo ""

# Check 3: kubectl
print_info "Checking kubectl..."
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || kubectl version --client 2>/dev/null | grep -o 'v[0-9.]*' | head -n1)
    print_success "kubectl is installed: $KUBECTL_VERSION"
else
    print_warning "kubectl is not installed (optional but recommended for EKS management)"
    echo "  Install from: https://kubernetes.io/docs/tasks/tools/"
fi

echo ""

# Check 4: Docker
print_info "Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    print_success "Docker is installed: $DOCKER_VERSION"
    
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        print_success "Docker daemon is running"
    else
        print_warning "Docker is installed but daemon is not running"
    fi
else
    print_warning "Docker is not installed (required for building and pushing images)"
    echo "  Install from: https://docs.docker.com/get-docker/"
fi

echo ""

# Check 5: AWS Credentials
print_info "Checking AWS credentials..."
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    REGION=$(aws configure get region || echo "not set")
    
    print_success "AWS credentials are configured"
    echo "  Account ID: $ACCOUNT_ID"
    echo "  User/Role: $USER_ARN"
    echo "  Default Region: $REGION"
    
    if [ "$REGION" = "not set" ]; then
        print_warning "AWS region is not set in configuration"
        echo "  Run: aws configure set region us-east-1"
    fi
else
    print_error "AWS credentials are not configured"
    echo "  Run: aws configure"
    ALL_CHECKS_PASSED=false
fi

echo ""

# Check 6: Required AWS Permissions (basic check)
print_info "Checking AWS permissions..."
PERMISSIONS_OK=true

# Check VPC permissions
if aws ec2 describe-vpcs --max-results 1 &> /dev/null; then
    print_success "VPC permissions: OK"
else
    print_error "VPC permissions: FAILED"
    PERMISSIONS_OK=false
fi

# Check EKS permissions
if aws eks list-clusters --max-results 1 &> /dev/null; then
    print_success "EKS permissions: OK"
else
    print_error "EKS permissions: FAILED"
    PERMISSIONS_OK=false
fi

# Check ECR permissions
if aws ecr describe-repositories --max-results 1 &> /dev/null 2>&1 || [ $? -eq 254 ]; then
    print_success "ECR permissions: OK"
else
    print_error "ECR permissions: FAILED"
    PERMISSIONS_OK=false
fi

# Check IAM permissions
if aws iam list-roles --max-items 1 &> /dev/null; then
    print_success "IAM permissions: OK"
else
    print_error "IAM permissions: FAILED"
    PERMISSIONS_OK=false
fi

if [ "$PERMISSIONS_OK" = false ]; then
    ALL_CHECKS_PASSED=false
    echo ""
    print_warning "Some AWS permissions are missing. Ensure your IAM user/role has:"
    echo "  - VPC management permissions"
    echo "  - EKS cluster creation permissions"
    echo "  - ECR repository management permissions"
    echo "  - IAM role/policy management permissions"
fi

echo ""

# Check 7: Disk Space
print_info "Checking disk space..."
if command -v df &> /dev/null; then
    AVAILABLE_SPACE=$(df -h . | awk 'NR==2 {print $4}')
    print_success "Available disk space: $AVAILABLE_SPACE"
fi

echo ""

# Final Summary
print_header "Summary"
echo ""

if [ "$ALL_CHECKS_PASSED" = true ]; then
    print_success "All required prerequisites are met!"
    echo ""
    print_info "Next steps:"
    echo "  1. Run ./1-backend-setup.sh to create S3 backend and DynamoDB table"
    echo "  2. Run ./2-infrastructure-deploy.sh to deploy the infrastructure"
    exit 0
else
    print_error "Some prerequisites are missing or not configured properly"
    echo ""
    print_info "Please install/configure the missing components and run this script again"
    exit 1
fi
