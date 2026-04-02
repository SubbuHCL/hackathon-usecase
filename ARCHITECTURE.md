# Complete CI/CD Architecture Diagram

## 🏗️ Overall Architecture Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPER WORKFLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GITHUB REPOSITORY                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐                            │
│  │  patient-  │  │application-│  │   order-   │                            │
│  │  service   │  │  service   │  │  service   │                            │
│  │  (Node.js) │  │  (Node.js) │  │   (Java)   │                            │
│  └────────────┘  └────────────┘  └────────────┘                            │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    Terraform Infrastructure                         │    │
│  │  • VPC Configuration    • EKS Cluster    • ECR Repositories        │    │
│  │  • Backend Config Files (backend-dev/uat/prod.hcl)                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GITHUB ACTIONS CI/CD                                │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  0. BACKEND SETUP (One-time per environment)                         │  │
│  │     backend-setup.sh                                                 │  │
│  │     ├─ Creates S3 State Bucket per environment                       │  │
│  │     ├─ Creates DynamoDB Lock Table per environment                   │  │
│  │     └─ Enables versioning, encryption, lifecycle policies            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  1. TERRAFORM PLAN ON PR (Automatic)                                 │  │
│  │     terraform-plan-pr.yml                                            │  │
│  │     ├─ Triggers: PR to dev/uat/main                                  │  │
│  │     ├─ AWS Bootstrap Role (OIDC) → Secrets Manager                   │  │
│  │     ├─ Retrieves environment-specific credentials                    │  │
│  │     ├─ Terraform Init with backend-{env}.hcl                         │  │
│  │     ├─ Format Check & Validation                                     │  │
│  │     ├─ Plan Generation                                               │  │
│  │     └─ PR Comment with Plan Output                                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  2. TERRAFORM DEPLOY (Manual)                                        │  │
│  │     terraform-deploy.yml                                             │  │
│  │     ├─ Input: Environment (dev/uat/prod)                             │  │
│  │     ├─ AWS Bootstrap Role (OIDC) → Secrets Manager                   │  │
│  │     ├─ Retrieves environment-specific credentials                    │  │
│  │     ├─ Terraform Init with backend-{env}.hcl                         │  │
│  │     ├─ Terraform Apply                                               │  │
│  │     ├─ State stored in S3: microservices-terraform-state-bucket-{env}│  │
│  │     └─ Creates: VPC, EKS Cluster, ECR Repositories                   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  3. DOCKER BUILD & PUSH (Manual)                                     │  │
│  │     docker-build.yml                                                 │  │
│  │     ├─ Input: Environment (dev/uat/prod), Git Tag                    │  │
│  │     ├─ AWS Bootstrap Role (OIDC) → Secrets Manager                   │  │
│  │     ├─ Retrieves environment-specific credentials                    │  │
│  │     ├─ ECR Login                                                     │  │
│  │     ├─ Build Docker Images (3 services in parallel)                  │  │
│  │     ├─ Tag Images (git-tag, sha, env-timestamp)                      │  │
│  │     ├─ Push to ECR                                                   │  │
│  │     └─ Image Security Scan                                           │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  4. KUBERNETES DEPLOY/ROLLBACK (Manual)                              │  │
│  │     k8s-deploy.yml                                                   │  │
│  │     ├─ Input: Environment, Action (deploy/rollback), Image Tag       │  │
│  │     ├─ AWS Bootstrap Role (OIDC) → Secrets Manager                   │  │
│  │     ├─ Retrieves environment-specific credentials                    │  │
│  │     ├─ Configure kubectl for EKS                                     │  │
│  │     ├─ Read images.yaml                                              │  │
│  │     ├─ Deploy: Process Manifests & Deploy ALL Services               │  │
│  │     ├─ Rollback: Undo to previous or specific version                │  │
│  │     ├─ Deploy Ingress (deploy only)                                  │  │
│  │     └─ Wait for Rollout                                              │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS INFRASTRUCTURE                              │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    TERRAFORM STATE MANAGEMENT                         │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │  S3 State Buckets (Per Environment)                           │   │  │
│  │  │  • microservices-terraform-state-bucket-dev                   │   │  │
│  │  │  • microservices-terraform-state-bucket-uat                   │   │  │
│  │  │  • microservices-terraform-state-bucket-prod                  │   │  │
│  │  │  Features: Versioning, Encryption, Lifecycle (90 days)        │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │  DynamoDB Lock Tables (Per Environment)                       │   │  │
│  │  │  • microservices-terraform-state-lock-dev                     │   │  │
│  │  │  • microservices-terraform-state-lock-uat                     │   │  │
│  │  │  • microservices-terraform-state-lock-prod                    │   │  │
│  │  │  Purpose: Prevent concurrent state modifications              │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                        AWS SECRETS MANAGER                            │  │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │  │
│  │  │ github-actions/  │  │ github-actions/  │  │ github-actions/  │  │  │
│  │  │ dev/aws-         │  │ uat/aws-         │  │ prod/aws-        │  │  │
│  │  │ credentials      │  │ credentials      │  │ credentials      │  │  │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    AMAZON ECR (Container Registry)                    │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │  DEV Repositories                                             │   │  │
│  │  │  • microservices-dev-patient-service                          │   │  │
│  │  │  • microservices-dev-application-service                      │   │  │
│  │  │  • microservices-dev-order-service                            │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │  UAT Repositories                                             │   │  │
│  │  │  • microservices-uat-patient-service                          │   │  │
│  │  │  • microservices-uat-application-service                      │   │  │
│  │  │  • microservices-uat-order-service                            │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  │  ┌──────────────────────────────────────────────────────────────┐   │  │
│  │  │  PROD Repositories                                            │   │  │
│  │  │  • microservices-prod-patient-service                         │   │  │
│  │  │  • microservices-prod-application-service                     │   │  │
│  │  │  • microservices-prod-order-service                           │   │  │
│  │  └──────────────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    VPC (Per Environment)                              │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Public Subnets (2 AZs)                                         │ │  │
│  │  │  ├─ NAT Gateway 1                                               │ │  │
│  │  │  └─ NAT Gateway 2                                               │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Private Subnets (2 AZs)                                        │ │  │
│  │  │  ├─ EKS Worker Nodes                                            │ │  │
│  │  │  └─ Application Pods                                            │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    EKS CLUSTER (Per Environment)                      │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Control Plane (Managed by AWS)                                 │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Worker Nodes (Managed Node Group)                              │ │  │
│  │  │  ├─ Instance Type: t3.medium                                    │ │  │
│  │  │  ├─ Min: 3, Max: 5, Desired: 3                                  │ │  │
│  │  │  └─ IAM Role with ECR Pull Permissions                          │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  │  ┌────────────────────────────────────────────────────────────────┐ │  │
│  │  │  Kubernetes Resources                                           │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  Deployments                                              │ │ │  │
│  │  │  │  ├─ patient-service (2 replicas)                          │ │ │  │
│  │  │  │  ├─ application-service (2 replicas)                      │ │ │  │
│  │  │  │  └─ order-service (2 replicas)                            │ │ │  │
│  │  │  └──────────────────────────────────────────────────────────┘ │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  Services (ClusterIP)                                     │ │ │  │
│  │  │  │  ├─ patient-service:80 → 3000                             │ │ │  │
│  │  │  │  ├─ application-service:80 → 3000                         │ │ │  │
│  │  │  │  └─ order-service:80 → 8080                               │ │ │  │
│  │  │  └──────────────────────────────────────────────────────────┘ │ │  │
│  │  │  ┌──────────────────────────────────────────────────────────┐ │ │  │
│  │  │  │  Ingress (ALB)                                            │ │ │  │
│  │  │  │  ├─ /patients → patient-service                           │ │ │  │
│  │  │  │  ├─ /appointments → application-service                   │ │ │  │
│  │  │  │  └─ /orders → order-service                               │ │ │  │
│  │  │  └──────────────────────────────────────────────────────────┘ │ │  │
│  │  └────────────────────────────────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              END USERS                                       │
│                                                                               │
│  Internet → ALB → Ingress → Services → Pods (Containers from ECR)           │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 🔄 Complete Deployment Flow

### Step 0: Backend Setup (One-time per environment)

```
Developer → Run backend-setup.sh
                    │
                    ▼
            AWS Credentials
                    │
                    ▼
            Terraform Apply
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
S3 State Bucket          DynamoDB Lock Table
(per environment)        (per environment)
        │                       │
        ├─ *-state-bucket-dev   ├─ *-state-lock-dev
        ├─ *-state-bucket-uat   ├─ *-state-lock-uat
        └─ *-state-bucket-prod  └─ *-state-lock-prod
```

### Step 1: Infrastructure Setup (Per environment)

```
Developer → GitHub Actions → Terraform Deploy
                                     │
                                     ▼
                         AWS Bootstrap Role (OIDC)
                                     │
                                     ▼
                         AWS Secrets Manager
                                     │
                                     ▼
                    Environment-Specific Credentials
                                     │
                                     ▼
                    Terraform Init -backend-config=backend-{env}.hcl
                                     │
                                     ▼
                    State loaded from S3 bucket (env-specific)
                                     │
                                     ▼
                             Terraform Apply
                                     │
                     ┌───────────────┼───────────────┐
                     ▼               ▼               ▼
                    VPC             EKS             ECR
```

### Step 2: Application Build & Push

```
Developer → GitHub Actions → Docker Build
                                     │
                                     ▼
                         AWS Bootstrap Role (OIDC)
                                     │
                                     ▼
                         AWS Secrets Manager
                                     │
                                     ▼
                    Environment-Specific Credentials
                                     │
                                     ▼
                             ECR Login
                                     │
                                     ▼
                     ┌───────────────┼───────────────┐
                     ▼               ▼               ▼
             Build Patient    Build Application  Build Order
               Service           Service          Service
              (parallel)        (parallel)       (parallel)
                     │               │               │
                     └───────────────┼───────────────┘
                                     ▼
                             Push to ECR
                                     │
                     ┌───────────────┼───────────────┐
                     ▼               ▼               ▼
             patient-service  application-service  order-service
             :git-tag         :git-tag             :git-tag
             :sha             :sha                 :sha
             :env-timestamp   :env-timestamp       :env-timestamp
```

### Step 3: Kubernetes Deployment

```
Developer → GitHub Actions → K8s Deploy
                                     │
                                     ▼
                         AWS Bootstrap Role (OIDC)
                                     │
                                     ▼
                         AWS Secrets Manager
                                     │
                                     ▼
                    Environment-Specific Credentials
                                     │
                                     ▼
                             Configure kubectl
                                     │
                                     ▼
                             Read images.yaml
                                     │
                                     ▼
                     Process K8s Manifests
                                     │
                     ┌───────────────┼───────────────┐
                     ▼               ▼               ▼
             Deploy Patient    Deploy Application  Deploy Order
               Service           Service          Service
                     │               │               │
                     └───────────────┼───────────────┘
                                     ▼
                             Deploy Ingress
                                     │
                                     ▼
                             EKS Cluster
                                     │
                     ┌───────────────┼───────────────┐
                     ▼               ▼               ▼
             Pods Pull from ECR (using IAM role)
                     │               │               │
                     ▼               ▼               ▼
             patient-service  application-service  order-service
             containers       containers           containers
             running          running              running
```

## 🔐 Security Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions                            │
│                          │                                   │
│                          ▼                                   │
│              AWS Bootstrap Role (OIDC)                       │
│              (secrets.AWS_BOOTSTRAP_ROLE_ARN)                │
│                          │                                   │
│                          ▼                                   │
│              AWS Secrets Manager                             │
│                          │                                   │
│                          ▼                                   │
│       Retrieve: github-actions/{env}/aws-credentials         │
│                          │                                   │
│                          ▼                                   │
│              Environment-Specific Credentials                │
│              (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)      │
│                          │                                   │
│          ┌───────────────┼───────────────┐                  │
│          ▼               ▼               ▼                  │
│         Dev            UAT             Prod                 │
│      Credentials    Credentials     Credentials             │
└─────────────────────────────────────────────────────────────┘
```

## 📊 Data Flow

```
User Request
     │
     ▼
Internet
     │
     ▼
AWS ALB (Application Load Balancer)
     │
     ▼
Kubernetes Ingress
     │
     ├─ /patients → patient-service:80 → Pod:3000
     │
     ├─ /appointments → application-service:80 → Pod:3000
     │
     └─ /orders → order-service:80 → Pod:8080
```

## 🎯 Environment Isolation

```
┌──────────────────┬──────────────────┬──────────────────┐
│       DEV        │       UAT        │       PROD       │
├──────────────────┼──────────────────┼──────────────────┤
│ State Bucket:    │ State Bucket:    │ State Bucket:    │
│ *-state-*-dev    │ *-state-*-uat    │ *-state-*-prod   │
│                  │                  │                  │
│ Lock Table:      │ Lock Table:      │ Lock Table:      │
│ *-state-lock-dev │ *-state-lock-uat │ *-state-lock-prod│
│                  │                  │                  │
│ VPC (dev)        │ VPC (uat)        │ VPC (prod)       │
│ EKS (dev)        │ EKS (uat)        │ EKS (prod)       │
│ ECR (dev)        │ ECR (uat)        │ ECR (prod)       │
│ Secrets(dev)     │ Secrets(uat)     │ Secrets(prod)    │
│                  │                  │                  │
│ Backend Config:  │ Backend Config:  │ Backend Config:  │
│ backend-dev.hcl  │ backend-uat.hcl  │ backend-prod.hcl │
└──────────────────┴──────────────────┴──────────────────┘
```

## 🔄 Terraform State Management Flow

```
┌─────────────────────────────────────────────────────────────┐
│  Terraform Command Execution                                 │
│                                                               │
│  terraform init -backend-config=backend-{env}.hcl            │
│                          │                                   │
│                          ▼                                   │
│              Read backend-{env}.hcl                          │
│              (bucket name for environment)                   │
│                          │                                   │
│                          ▼                                   │
│       Connect to S3: microservices-terraform-state-bucket-{env}│
│                          │                                   │
│                          ▼                                   │
│       Acquire lock in DynamoDB: microservices-terraform-state-lock-{env}│
│                          │                                   │
│                          ▼                                   │
│       Load state from S3: microservices/terraform.tfstate    │
│                          │                                   │
│                          ▼                                   │
│              Execute Terraform Operations                    │
│                          │                                   │
│                          ▼                                   │
│       Save state to S3 (versioned, encrypted)                │
│                          │                                   │
│                          ▼                                   │
│              Release DynamoDB lock                           │
└─────────────────────────────────────────────────────────────┘
```

This architecture provides:
- ✅ Complete environment isolation with separate state buckets and lock tables
- ✅ Secure credential management via OIDC and Secrets Manager
- ✅ Environment-specific state locking to prevent concurrent modifications
- ✅ Versioned and encrypted state files
- ✅ Manual control over all deployments
- ✅ Parallel Docker builds for efficiency
- ✅ Automated PR validation with Terraform plan
