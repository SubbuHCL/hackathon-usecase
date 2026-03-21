# Overview
Welcome to the DevOps Hackathon Challenge! In this hackathon, you will demonstrate your skills in containerization, Infrastructure as Code (IaC), CI/CD, and cloud deployment using Azure / GCP services. You will be working with a simple healthcare application consisting of two microservices.

# Common Requirements
Regardless of the track you choose, you will be working with the following common elements:

## Microservices: 
You will be provided with two Node.js microservices - a Patient Service and an Appointment Service or Java based Microservice (order-service).
The code for these services can be found in the Sample Microservices Code file.

Order-service Java microservice.

## What we are looking for
### CI Pipeline
1. Build microservices on local
2. Docker build microservice
3. Create Kubernetes YAML files. (Internal - helm charts)
3. Push to GCR / ACR / ECR
### CD Deployment
1. Pull from GCR / ACR / ECR
2. Deploy on GKE / AKS / EKS

### Secrets
1. Azure KeyVault / AWS Secret Manager

For Containternization use Docker, Terraform for IaC, Github Action / Azure DevOps for CI/CD pipelines.

### Monitoring and Logging: 
Set up basic monitoring and logging using Azure Monitor and other services / GCP / AWS Services.

### Containerization: 
You need to containerize these microservices using Docker.

### Infrastructure as Code (Terraform):

Set up a Terraform project structure supporting multiple environments (dev, staging, prod).
Provision the following in Azure / GCP / AWS resources:
VPC with public and private subnets across two availability zones
IAM roles and security groups
Storage for Terraform state storage
State locking
(Other resources specific to your chosen track)
Terraform State Management:

Implement remote state storage using Blob Storage / GCP Files / AWS S3
Set up state locking
Configure workspace separation for different environments

### GitHub Actions / Azure DevOps for IaC:
Create workflows for:
1. CI/CD: Implement a CI/CD pipeline using GitHub Actions for your application code.
2. Terraform fmt and validate on all PRs
3. Terraform plan on pull requests
4. Terraform apply on merges to main branch
