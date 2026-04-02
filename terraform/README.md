# Terraform AWS Infrastructure for Microservices

This Terraform configuration creates a complete AWS infrastructure for deploying microservices on EKS (Elastic Kubernetes Service).

## Infrastructure Components

### 1. **VPC (Virtual Private Cloud)**
- Custom VPC with configurable CIDR block (default: 10.0.0.0/16)
- DNS hostnames and DNS support enabled
- Spans across 3 availability zones

### 2. **Subnets**
- **Public Subnets**: 3 subnets across different AZs (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24)
  - Auto-assign public IPs
  - Tagged for EKS external load balancers
- **Private Subnets**: 3 subnets across different AZs (10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24)
  - Tagged for EKS internal load balancers
  - Worker nodes deployed here

### 3. **Internet Gateway & NAT Gateways**
- Internet Gateway for public subnet internet access
- NAT Gateways (one per AZ by default) for private subnet outbound traffic
- Elastic IPs for NAT Gateways

### 4. **Route Tables**
- Public route table with route to Internet Gateway
- Private route tables with routes to NAT Gateways

### 5. **ECR (Elastic Container Registry)**
- Three repositories for microservices:
  - `microservices-patient-service`
  - `microservices-application-service`
  - `microservices-order-service`
- Image scanning on push enabled
- AES256 encryption
- Lifecycle policies:
  - Keep last 10 tagged images
  - Remove untagged images after 7 days

### 6. **EKS Cluster**
- Kubernetes version 1.28
- Control plane in both public and private subnets
- Cluster logging enabled (API, audit, authenticator, controller manager, scheduler)
- OIDC provider for IAM roles for service accounts

### 7. **EKS Managed Node Group**
- **Instance Type**: t3.medium
- **Scaling Configuration**:
  - Desired: 3 nodes
  - Minimum: 3 nodes
  - Maximum: 5 nodes
- **Disk Size**: 20 GB per node
- **Capacity Type**: ON_DEMAND
- Deployed in private subnets
- Auto-scaling enabled

### 8. **IAM Roles & Policies**
- EKS Cluster Role with required policies
- Node Group Role with required policies
- ECR access policies for pulling images

## Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```

2. **Terraform** installed (version >= 1.0)
   ```bash
   terraform version
   ```

3. **kubectl** installed for Kubernetes management
   ```bash
   kubectl version --client
   ```

4. **AWS Credentials** with appropriate permissions:
   - VPC management
   - EKS cluster creation
   - ECR repository management
   - IAM role/policy management

## Usage

### 1. Initialize Terraform

```bash
cd terraform
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 4. Configure kubectl

After the infrastructure is created, configure kubectl to connect to your EKS cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name microservices-eks-cluster
```

Or use the output command:

```bash
terraform output -raw configure_kubectl | bash
```

### 5. Verify Cluster Access

```bash
kubectl get nodes
kubectl get namespaces
```

## Configuration Variables

Key variables can be customized in [`terraform.tfvars`](terraform.tfvars):

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | us-east-1 |
| `environment` | Environment name | dev |
| `project_name` | Project name | microservices |
| `vpc_cidr` | VPC CIDR block | 10.0.0.0/16 |
| `cluster_name` | EKS cluster name | microservices-eks-cluster |
| `cluster_version` | Kubernetes version | 1.28 |
| `node_desired_size` | Desired number of nodes | 3 |
| `node_min_size` | Minimum number of nodes | 3 |
| `node_max_size` | Maximum number of nodes | 5 |
| `node_instance_types` | EC2 instance types | ["t3.medium"] |
| `single_nat_gateway` | Use single NAT gateway | false |

## Outputs

After applying, Terraform provides useful outputs:

```bash
# View all outputs
terraform output

# View specific output
terraform output eks_cluster_endpoint
terraform output ecr_repository_urls
```

Key outputs include:
- VPC and subnet IDs
- ECR repository URLs
- EKS cluster endpoint and name
- kubectl configuration command
- ECR login command

## Deploying Microservices

### 1. Build and Push Docker Images to ECR

```bash
# Get ECR login command
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and tag images
docker build -t microservices-patient-service:latest ./patient-service
docker tag microservices-patient-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/microservices-patient-service:latest

docker build -t microservices-application-service:latest ./application-service
docker tag microservices-application-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/microservices-application-service:latest

docker build -t microservices-order-service:latest ./order-service
docker tag microservices-order-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/microservices-order-service:latest

# Push images
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/microservices-patient-service:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/microservices-application-service:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/microservices-order-service:latest
```

### 2. Deploy to EKS

Create Kubernetes deployment manifests and apply them:

```bash
kubectl apply -f k8s/
```

## Cost Optimization

### Reduce Costs:

1. **Use Single NAT Gateway**
   ```hcl
   single_nat_gateway = true
   ```
   Saves ~$90/month (2 NAT Gateways × $45/month)

2. **Use Spot Instances** (modify node group configuration)
   ```hcl
   capacity_type = "SPOT"
   ```

3. **Reduce Node Count**
   ```hcl
   node_desired_size = 2
   node_min_size     = 2
   ```

4. **Use Smaller Instance Types**
   ```hcl
   node_instance_types = ["t3.small"]
   ```

## Estimated Monthly Costs

- **EKS Cluster**: ~$73/month
- **EC2 Instances** (3 × t3.medium): ~$90/month
- **NAT Gateways** (3): ~$135/month
- **EBS Volumes** (3 × 20GB): ~$6/month
- **Data Transfer**: Variable
- **Total**: ~$304/month (approximate)

## Security Best Practices

1. **Enable VPC Flow Logs** (add to vpc.tf)
2. **Use AWS Secrets Manager** for sensitive data
3. **Enable Pod Security Policies**
4. **Implement Network Policies**
5. **Use IAM Roles for Service Accounts (IRSA)**
6. **Enable audit logging**
7. **Regularly update cluster version**

## Monitoring & Logging

### Enable CloudWatch Container Insights:

```bash
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml
```

### View Logs:

```bash
# Cluster logs in CloudWatch
aws logs tail /aws/eks/microservices-eks-cluster/cluster --follow

# Pod logs
kubectl logs -f <pod-name>
```

## Cleanup

To destroy all resources:

```bash
# Delete Kubernetes resources first
kubectl delete all --all

# Destroy Terraform infrastructure
terraform destroy
```

Type `yes` when prompted.

**Warning**: This will delete all resources including data. Make sure to backup any important data before destroying.

## Troubleshooting

### Issue: Cannot connect to cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name microservices-eks-cluster

# Verify AWS credentials
aws sts get-caller-identity
```

### Issue: Nodes not joining cluster

```bash
# Check node group status
aws eks describe-nodegroup --cluster-name microservices-eks-cluster --nodegroup-name microservices-node-group

# Check IAM roles
aws iam get-role --role-name microservices-dev-eks-node-group-role
```

### Issue: ECR authentication failed

```bash
# Re-authenticate
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

## File Structure

```
terraform/
├── main.tf           # Provider and backend configuration
├── variables.tf      # Variable definitions
├── terraform.tfvars  # Variable values
├── vpc.tf           # VPC, subnets, routing
├── ecr.tf           # ECR repositories
├── eks.tf           # EKS cluster and node groups
└── outputs.tf       # Output values
```

## Remote State (Optional)

To use S3 backend for remote state:

1. Create S3 bucket and DynamoDB table:
   ```bash
   aws s3 mb s3://your-terraform-state-bucket
   aws dynamodb create-table \
     --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

2. Uncomment backend configuration in [`main.tf`](main.tf)

3. Initialize backend:
   ```bash
   terraform init -migrate-state
   ```

## Additional Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)

## Support

For issues or questions:
1. Check AWS CloudWatch logs
2. Review Terraform state: `terraform show`
3. Validate configuration: `terraform validate`
4. Check AWS console for resource status
