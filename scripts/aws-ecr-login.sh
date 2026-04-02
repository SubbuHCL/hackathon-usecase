#!/bin/bash

# AWS Authentication and ECR Login Script for CI/CD
# This script handles AWS authentication via Secrets Manager and ECR login

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Parse arguments
ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"

print_info "AWS Authentication and ECR Login"
print_info "Environment: $ENVIRONMENT"
print_info "Region: $AWS_REGION"
echo ""

# Step 1: Retrieve credentials from AWS Secrets Manager
print_info "Retrieving credentials from AWS Secrets Manager..."
SECRET_NAME="github-actions/${ENVIRONMENT}/aws-credentials"

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "$SECRET_NAME" \
  --region "$AWS_REGION" \
  --query SecretString \
  --output text 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Failed to retrieve secrets from Secrets Manager"
    print_error "Secret: $SECRET_NAME"
    exit 1
fi

# Parse credentials
export AWS_ACCESS_KEY_ID=$(echo $SECRET_JSON | jq -r '.aws_access_key_id')
export AWS_SECRET_ACCESS_KEY=$(echo $SECRET_JSON | jq -r '.aws_secret_access_key')

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ "$AWS_ACCESS_KEY_ID" == "null" ]; then
    print_error "Failed to parse AWS_ACCESS_KEY_ID from secret"
    exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ "$AWS_SECRET_ACCESS_KEY" == "null" ]; then
    print_error "Failed to parse AWS_SECRET_ACCESS_KEY from secret"
    exit 1
fi

# Mask credentials in CI logs (GitHub Actions specific)
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "::add-mask::$AWS_ACCESS_KEY_ID"
    echo "::add-mask::$AWS_SECRET_ACCESS_KEY"
fi

# Export to environment file for GitHub Actions
if [ -n "$GITHUB_ENV" ]; then
    echo "AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> $GITHUB_ENV
    echo "AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> $GITHUB_ENV
    echo "AWS_DEFAULT_REGION=$AWS_REGION" >> $GITHUB_ENV
fi

print_success "Credentials retrieved successfully"
echo ""

# Step 2: Verify AWS authentication
print_info "Verifying AWS authentication..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Failed to verify AWS authentication"
    exit 1
fi

print_success "Authenticated to AWS Account: $ACCOUNT_ID"
echo ""

# Step 3: Login to ECR
print_info "Logging in to Amazon ECR..."
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

if [ $? -ne 0 ]; then
    print_error "Failed to login to ECR"
    exit 1
fi

print_success "Successfully logged in to ECR: $ECR_REGISTRY"
echo ""

# Export ECR registry for use in subsequent steps
if [ -n "$GITHUB_ENV" ]; then
    echo "ECR_REGISTRY=$ECR_REGISTRY" >> $GITHUB_ENV
fi

if [ -n "$GITHUB_OUTPUT" ]; then
    echo "ecr_registry=$ECR_REGISTRY" >> $GITHUB_OUTPUT
    echo "account_id=$ACCOUNT_ID" >> $GITHUB_OUTPUT
fi

print_success "AWS authentication and ECR login completed successfully"
