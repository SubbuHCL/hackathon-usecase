#!/bin/bash

# CI/CD Pipeline Script for Terraform Infrastructure
# This script orchestrates the complete infrastructure deployment process

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

# Parse command-line arguments
ACTION="${1:-plan}"  # plan or deploy
ENVIRONMENT="${2:-dev}"
PROJECT_NAME="${3:-microservices}"
AWS_REGION="${4:-us-east-1}"
ECR_REPOS="${5:-patient-service,application-service,order-service}"

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

print_header "Terraform CI/CD Pipeline"
echo ""
print_info "Configuration:"
echo "  Action: $ACTION"
echo "  Environment: $ENVIRONMENT"
echo "  Project: $PROJECT_NAME"
echo "  Region: $AWS_REGION"
echo "  ECR Repos: $ECR_REPOS"
echo ""

# Set environment variables for scripts
export CI=true
export TF_VAR_environment="$ENVIRONMENT"
export TF_VAR_project_name="$PROJECT_NAME"
export TF_VAR_aws_region="$AWS_REGION"
export TF_VAR_ecr_repositories="$ECR_REPOS"

# Step 1: Prerequisites Check
print_header "Step 1: Prerequisites Check"
if [ -f "$SCRIPT_DIR/prerequisites-check.sh" ]; then
    bash "$SCRIPT_DIR/prerequisites-check.sh" || {
        print_warning "Some prerequisites checks failed, continuing anyway (CI environment)"
    }
else
    print_warning "Prerequisites check script not found, skipping"
fi
echo ""

# Step 2: Backend Setup
print_header "Step 2: Backend Setup"
if [ -f "$SCRIPT_DIR/backend-setup.sh" ]; then
    bash "$SCRIPT_DIR/backend-setup.sh" "$ENVIRONMENT" "$PROJECT_NAME" "$AWS_REGION"
else
    print_error "Backend setup script not found"
    exit 1
fi
echo ""

# Step 3: Terraform Plan
print_header "Step 3: Terraform Plan"
cd "$SCRIPT_DIR/../terraform"

print_info "Initializing Terraform with environment-specific backend..."
BACKEND_CONFIG_FILE="backend-${ENVIRONMENT}.hcl"

if [ -f "$BACKEND_CONFIG_FILE" ]; then
    print_info "Using backend config: $BACKEND_CONFIG_FILE"
    terraform init -input=false -backend-config="$BACKEND_CONFIG_FILE" -reconfigure
else
    print_error "Backend config file not found: $BACKEND_CONFIG_FILE"
    exit 1
fi

print_info "Validating configuration..."
terraform validate

print_info "Creating plan..."
terraform plan -input=false -out=tfplan -no-color | tee plan-output.txt

print_success "Plan created successfully"
echo ""

# Step 4: Terraform Apply (if action is deploy)
if [ "$ACTION" == "deploy" ]; then
    print_header "Step 4: Terraform Apply"
    
    print_info "Applying infrastructure changes..."
    terraform apply -auto-approve -input=false tfplan
    
    print_success "Infrastructure deployed successfully"
    echo ""
    
    # Step 5: Post-Deployment
    print_header "Step 5: Post-Deployment"
    
    print_info "Retrieving outputs..."
    terraform output > outputs.txt
    terraform output -json ecr_repository_urls > ecr_repos.json 2>/dev/null || echo "{}" > ecr_repos.json
    
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
    
    if [ -n "$CLUSTER_NAME" ]; then
        print_info "Configuring kubectl..."
        aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" 2>/dev/null || {
            print_warning "kubectl configuration will be available once cluster is fully ready"
        }
        
        print_info "Checking cluster nodes..."
        kubectl get nodes 2>/dev/null || print_warning "Nodes not ready yet, may take a few minutes"
    fi
    
    # Create deployment summary
    cat > deployment-summary.md << EOF
# Deployment Summary

**Environment:** $ENVIRONMENT
**Region:** $AWS_REGION
**Deployed At:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Commit:** ${GITHUB_SHA:-local}

## Infrastructure Details

**EKS Cluster Name:** $CLUSTER_NAME
**Cluster Endpoint:** $(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "N/A")

## Configure kubectl
\`\`\`bash
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
kubectl get nodes
\`\`\`

## Terraform Outputs
\`\`\`
$(cat outputs.txt)
\`\`\`
EOF
    
    print_success "Deployment summary saved to deployment-summary.md"
    echo ""
    
    print_header "Deployment Complete"
    print_success "Infrastructure successfully deployed to $ENVIRONMENT environment"
    echo ""
    print_info "Next steps:"
    echo "  1. Configure kubectl: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
    echo "  2. Verify cluster: kubectl get nodes"
    echo "  3. Deploy applications"
    
else
    print_header "Plan Complete"
    print_success "Terraform plan completed successfully"
    print_info "Review the plan output above"
    print_info "To deploy, run: $0 deploy $ENVIRONMENT $PROJECT_NAME $AWS_REGION"
fi

echo ""
print_success "Pipeline execution completed!"
