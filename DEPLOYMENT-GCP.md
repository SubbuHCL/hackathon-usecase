# GCP Deployment Guide

This guide provides step-by-step instructions for deploying the Healthcare Application microservices to Google Cloud Platform (GCP) using GKE.

## Prerequisites

- GCP Account with billing enabled
- `gcloud` CLI installed and configured
- `kubectl` installed (version 1.20+)
- `terraform` installed (version 1.4.0+)
- Docker installed
- Git repository access

## Architecture Overview

The deployment consists of:
- **Google Kubernetes Engine (GKE)**: Container orchestration platform
- **Google Container Registry (GCR)**: Private container image repository
- **Google Cloud Storage**: Terraform state backend
- **Google Cloud Monitoring**: Application and infrastructure monitoring
- **Google Cloud Logging**: Centralized logging

## Step 1: Prerequisites Setup

### 1.1 Set GCP Project Variables

```bash
export PROJECT_ID="adept-insight-477609-p5"
export REGION="us-central1"
export ZONE="us-central1-a"
export BILLING_ACCOUNT_ID="0163ED-2B355E-F443D0"
```

### 1.2 Create Service Account for Terraform

```bash
# Create service account
gcloud iam service-accounts create tf-provisioner \
  --project=$PROJECT_ID \
  --display-name="Terraform Provisioner"

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:tf-provisioner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/owner"

# Create and download key
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=tf-provisioner@${PROJECT_ID}.iam.gserviceaccount.com
```

### 1.3 Create GCS Bucket for Terraform State

```bash
# Create bucket
gsutil mb -p $PROJECT_ID -l $REGION gs://${PROJECT_ID}-terraform-state

# Enable versioning
gsutil versioning set on gs://${PROJECT_ID}-terraform-state

# Enable object lock (optional, for production)
gsutil retention set 30d gs://${PROJECT_ID}-terraform-state
```

### 1.4 Update Terraform Configuration

Edit `gke-terraform/terraform.tfvars`:

```hcl
project_id = "adept-insight-477609-p5"
billing_account_id = "0163ED-2B355E-F443D0"
region = "us-central1"
zone = "us-central1-a"
cluster_name = "gke-cluster"
node_count = 3
```

Edit `gke-terraform/main.tf` and uncomment the GCS backend:

```hcl
terraform {
  backend "gcs" {
    bucket  = "adept-insight-477609-p5-terraform-state"
    prefix  = "gke/prod"
  }
}
```

## Step 2: Deploy Infrastructure with Terraform

### 2.1 Initialize Terraform

```bash
cd gke-terraform

# Set credentials
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/../terraform-key.json"

# Initialize terraform
terraform init
```

### 2.2 Plan Deployment

```bash
terraform plan -out=tfplan
```

### 2.3 Apply Terraform Configuration

```bash
terraform apply tfplan
```

### 2.4 Verify Cluster Creation

```bash
# Get cluster credentials
gcloud container clusters get-credentials gke-cluster \
  --region us-central1 \
  --project $PROJECT_ID

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

## Step 3: Build and Push Docker Images

### 3.1 Configure Docker Authentication

```bash
gcloud auth configure-docker gcr.io
```

### 3.2 Build Patient Service

```bash
cd patient-service

docker build -t gcr.io/${PROJECT_ID}/patient-service:latest .

docker push gcr.io/${PROJECT_ID}/patient-service:latest

cd ..
```

### 3.3 Build Appointment Service

```bash
cd application-service

docker build -t gcr.io/${PROJECT_ID}/appointment-service:latest .

docker push gcr.io/${PROJECT_ID}/appointment-service:latest

cd ..
```

### 3.4 Build Order Service

```bash
cd order-service

docker build -t gcr.io/${PROJECT_ID}/order-service:latest .

docker push gcr.io/${PROJECT_ID}/order-service:latest

cd ..
```

### 3.5 Verify Images in GCR

```bash
gcloud container images list --project=$PROJECT_ID
gcloud container images list-tags gcr.io/${PROJECT_ID}/patient-service
gcloud container images list-tags gcr.io/${PROJECT_ID}/appointment-service
gcloud container images list-tags gcr.io/${PROJECT_ID}/order-service
```

## Step 4: Deploy Applications to GKE

### 4.1 Update Kubernetes Manifests

Replace `PROJECT_ID` placeholders in the manifest files:

```bash
# Replace in all manifests
sed -i "s/PROJECT_ID/${PROJECT_ID}/g" k8s/patient-service.yaml
sed -i "s/PROJECT_ID/${PROJECT_ID}/g" k8s/appointment-service.yaml
sed -i "s/PROJECT_ID/${PROJECT_ID}/g" k8s/order-service.yaml
sed -i "s/PROJECT_ID/${PROJECT_ID}/g" k8s/ingress.yaml
```

### 4.2 Create Namespace

```bash
kubectl apply -f k8s/namespace.yaml
```

### 4.3 Deploy Services

```bash
# Deploy patient service
kubectl apply -f k8s/patient-service.yaml

# Deploy appointment service
kubectl apply -f k8s/appointment-service.yaml

# Deploy order service
kubectl apply -f k8s/order-service.yaml

# Deploy ingress
kubectl apply -f k8s/ingress.yaml
```

### 4.4 Verify Deployments

```bash
# Check namespace
kubectl get namespace healthcare-app

# Check deployments
kubectl get deployments -n healthcare-app

# Check pods
kubectl get pods -n healthcare-app

# Check services
kubectl get services -n healthcare-app

# Check ingress
kubectl get ingress -n healthcare-app
```

### 4.5 Monitor Rollout

```bash
# Watch deployment progress
kubectl rollout status deployment/patient-service -n healthcare-app
kubectl rollout status deployment/appointment-service -n healthcare-app
kubectl rollout status deployment/order-service -n healthcare-app
```

## Step 5: Configure Ingress and Load Balancing

### 5.1 Get Ingress IP

```bash
# Wait for external IP to be assigned
kubectl get ingress healthcare-app-ingress -n healthcare-app -w
```

### 5.2 Configure DNS

Update your DNS provider to point `healthcare-app.example.com` to the external IP:

```bash
# Get the external IP
EXTERNAL_IP=$(kubectl get ingress healthcare-app-ingress -n healthcare-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "External IP: $EXTERNAL_IP"
```

### 5.3 Test Services

```bash
# Test patient service
curl http://<EXTERNAL_IP>/api/patients/

# Test appointment service
curl http://<EXTERNAL_IP>/api/appointments/

# Test order service
curl http://<EXTERNAL_IP>/api/orders/
```

## Step 6: Setup Monitoring and Logging

### 6.1 Enable GKE Monitoring

```bash
# Create Cloud Monitoring dashboard
gcloud monitoring dashboards create --config-from-file=- <<EOF
{
  "displayName": "Healthcare App Dashboard",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "CPU Usage",
          "xyChart": {
            "dataSets": [{
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "resource.type=\\\"k8s_container\\\" AND resource.label.cluster_name=\\\"gke-cluster\\\""
                }
              }
            }]
          }
        }
      }
    ]
  }
}
EOF
```

### 6.2 View Logs

```bash
# View cluster logs
gcloud container clusters describe gke-cluster --region us-central1

# View pod logs
kubectl logs -n healthcare-app deployment/patient-service -f

# View all logs in namespace
kubectl logs -n healthcare-app -f --all-containers=true --prefix=true
```

### 6.3 Setup Alerts

```bash
# Create alert policy for deployment
gcloud alpha monitoring policies create \
  --notification-channels=CHANNEL_ID \
  --display-name="GKE Deployment Alert" \
  --condition-display-name="Pod Not Ready" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=300s
```

## Step 7: CI/CD Pipeline Setup

### 7.1 Configure GitHub Secrets

Add the following secrets to your GitHub repository:

```
GCP_PROJECT_ID: adept-insight-477609-p5
GCP_SA_KEY: (contents of terraform-key.json)
```

### 7.2 Push Code to Trigger Pipeline

```bash
git add .
git commit -m "Deploy GCP infrastructure and applications"
git push origin main
```

### 7.3 Monitor Workflow

Visit your GitHub repository > Actions to monitor workflow execution.

## Step 8: Verification and Testing

### 8.1 Verify All Components

```bash
# Check cluster
gcloud container clusters describe gke-cluster --region us-central1

# Check node pools
gcloud container node-pools list --cluster=gke-cluster --region=us-central1

# Check services are running
kubectl get all -n healthcare-app
```

### 8.2 Test Application Health

```bash
# Check deployment health
kubectl get deployments -n healthcare-app -o wide

# Check pod status
kubectl get pods -n healthcare-app

# Test service connectivity
kubectl exec -it <POD_NAME> -n healthcare-app -- curl http://patient-service/health
```

### 8.3 View Application Logs

```bash
# Stream logs
kubectl logs -n healthcare-app deployment/patient-service -f

# View previous logs if pod crashed
kubectl logs -n healthcare-app deployment/patient-service --previous
```

## Troubleshooting

### Issue: Pods stuck in ImagePullBackOff

```bash
# Check image exists in GCR
gcloud container images list-tags gcr.io/${PROJECT_ID}/patient-service

# Check service account permissions
kubectl get serviceaccount -n healthcare-app

# Re-push images
docker push gcr.io/${PROJECT_ID}/patient-service:latest
```

### Issue: Ingress not getting external IP

```bash
# Check ingress status
kubectl describe ingress healthcare-app-ingress -n healthcare-app

# Check GCP firewall rules
gcloud compute firewall-rules list

# Check load balancer
gcloud compute forwarding-rules list
```

### Issue: Helm chart validation errors

```bash
# Format terraform files
cd gke-terraform
terraform fmt -recursive

# Validate terraform
terraform validate
```

## Cleanup

To destroy all GCP resources:

```bash
# Delete Kubernetes resources
kubectl delete namespace healthcare-app

# Destroy infrastructure with terraform
cd gke-terraform
terraform destroy
```

## Monitoring and Logging

See [MONITORING-GCP.md](MONITORING-GCP.md) for detailed monitoring and logging setup.

## Additional Resources

- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [GCP Security Best Practices](https://cloud.google.com/security/best-practices)
