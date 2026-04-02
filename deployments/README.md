# Kubernetes Deployments

This directory contains Kubernetes manifests for deploying all microservices to Amazon EKS with environment-specific image configurations.

## Directory Structure

```
deployments/
├── images.yaml              # Central image configuration for all environments
├── deploy.sh                # Deployment script
├── base/                    # Base Kubernetes manifests
│   ├── patient-service.yaml
│   ├── application-service.yaml
│   ├── order-service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
└── README.md
```

## Image Configuration

All environment-specific images are defined in [`images.yaml`](images.yaml):

```yaml
dev:
  patient-service:
    repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/microservices-dev-patient-service
    tag: latest
  # ... other services

uat:
  patient-service:
    repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/microservices-uat-patient-service
    tag: v1.0.0
  # ... other services

prod:
  patient-service:
    repository: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/microservices-prod-patient-service
    tag: v1.0.0
  # ... other services
```

## Prerequisites

1. **EKS Cluster** deployed via Terraform
2. **kubectl** configured to access the cluster
3. **yq** installed for YAML parsing
4. **AWS Load Balancer Controller** installed in the cluster
5. **Docker images** pushed to ECR

## Quick Start

### 1. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name microservices-dev-eks-cluster
kubectl get nodes
```

### 2. Update images.yaml

Replace `<ACCOUNT_ID>` with your AWS account ID in [`images.yaml`](images.yaml):

```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Update images.yaml
sed -i "s/<ACCOUNT_ID>/$ACCOUNT_ID/g" deployments/images.yaml
```

### 3. Deploy to Environment

```bash
cd deployments

# Make deploy script executable
chmod +x deploy.sh

# Deploy to dev
./deploy.sh dev apply

# Deploy to uat
./deploy.sh uat apply

# Deploy to prod
./deploy.sh prod apply
```

## Deployment Script Usage

```bash
./deploy.sh <environment> <action> [aws-account-id]
```

**Parameters:**
- `environment`: dev, uat, or prod (default: dev)
- `action`: apply or delete (default: apply)
- `aws-account-id`: Optional, auto-detected if not provided

**Examples:**

```bash
# Deploy to development
./deploy.sh dev apply

# Deploy to UAT
./deploy.sh uat apply

# Deploy to production
./deploy.sh prod apply

# Delete from development
./deploy.sh dev delete

# Deploy with explicit account ID
./deploy.sh prod apply 123456789012
```

## Updating Image Tags

### For Development (uses latest tag)

Development automatically uses the `latest` tag. Just push new images:

```bash
# Images are automatically tagged as 'latest' in dev
# No changes needed to images.yaml
```

### For UAT/Production (uses version tags)

Update the tag in [`images.yaml`](images.yaml):

```yaml
uat:
  patient-service:
    tag: v1.1.0  # Update this
```

Then redeploy:

```bash
./deploy.sh uat apply
```

## Manual Deployment (without script)

If you prefer to deploy manually:

```bash
# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Update images in manifests
sed -e "s|image: patient-service:latest|image: $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/microservices-dev-patient-service:latest|g" \
    base/patient-service.yaml | kubectl apply -f -

# Repeat for other services...
```

## Verify Deployment

```bash
# Check deployments
kubectl get deployments

# Check pods
kubectl get pods

# Check services
kubectl get services

# Check ingress
kubectl get ingress

# Get load balancer URL
kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Access the Services

```bash
# Get the ALB DNS name
LB_URL=$(kubectl get ingress microservices-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test endpoints
curl http://$LB_URL/patients
curl http://$LB_URL/appointments
curl http://$LB_URL/orders
```

## Scaling

```bash
# Scale manually
kubectl scale deployment patient-service --replicas=3

# Or update the deployment YAML and reapply
```

## Rolling Updates

When you update the image tag in `images.yaml` and redeploy:

```bash
# Update images.yaml with new tag
# Then redeploy
./deploy.sh prod apply

# Check rollout status
kubectl rollout status deployment/patient-service
kubectl rollout status deployment/application-service
kubectl rollout status deployment/order-service
```

## Rollback

```bash
# Rollback to previous version
kubectl rollout undo deployment/patient-service

# Rollback to specific revision
kubectl rollout undo deployment/patient-service --to-revision=2

# View rollout history
kubectl rollout history deployment/patient-service
```

## Monitoring

### View Logs

```bash
# View logs for a specific pod
kubectl logs <pod-name>

# Follow logs
kubectl logs -f <pod-name>

# View logs for all pods of a service
kubectl logs -l app=patient-service --tail=100
```

### Describe Resources

```bash
# Describe deployment
kubectl describe deployment patient-service

# Describe pod
kubectl describe pod <pod-name>

# Describe ingress
kubectl describe ingress microservices-ingress
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods

# Describe pod to see events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>
```

### Image Pull Errors

```bash
# Verify image exists in ECR
aws ecr describe-images \
  --repository-name microservices-dev-patient-service \
  --region us-east-1

# Check if nodes can pull from ECR
kubectl describe pod <pod-name> | grep -A 5 "Events"
```

### Load Balancer Not Created

```bash
# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify controller is running
kubectl get deployment -n kube-system aws-load-balancer-controller
```

## Environment Differences

### Development
- **Replicas**: 2
- **Image Tag**: latest
- **Resources**: Lower limits (128Mi-256Mi memory)
- **Auto-deploy**: On PR merge

### UAT
- **Replicas**: 3
- **Image Tag**: Specific version (e.g., v1.0.0)
- **Resources**: Medium limits (256Mi-512Mi memory)
- **Deploy**: Manual with version tag

### Production
- **Replicas**: 5
- **Image Tag**: Specific version (e.g., v1.0.0)
- **Resources**: Higher limits (512Mi-1Gi memory)
- **Deploy**: Manual with version tag

## Clean Up

```bash
# Delete all resources
./deploy.sh dev delete

# Or manually
kubectl delete -f base/
```

## Best Practices

1. **Always use specific tags** in UAT/Prod (never `latest`)
2. **Test in dev first** before promoting to UAT
3. **Test in UAT** before deploying to production
4. **Update images.yaml** before deploying
5. **Monitor rollout status** after deployment
6. **Keep rollout history** for easy rollbacks
7. **Use same image tag** across UAT and Prod for consistency

## CI/CD Integration

The deploy script can be integrated into CI/CD pipelines:

```yaml
# GitHub Actions example
- name: Deploy to EKS
  run: |
    cd deployments
    ./deploy.sh ${{ inputs.environment }} apply
```

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
