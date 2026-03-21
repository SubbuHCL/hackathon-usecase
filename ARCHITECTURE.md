# Healthcare Application Architecture - GCP

## High-Level Architecture

This document describes the architecture of the Healthcare Application deployed on Google Cloud Platform (GCP).

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                               │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Cloud Load Balancer   │
                    │   (SSL/TLS Termination) │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │  Kubernetes Ingress     │
                    │  healthcare-app-ingress │
                    └────┬───────────┬────────┘
                         │           │
         ┌───────────────┼───────────┼───────────────┐
         │               │           │               │
    ┌────▼─────┐  ┌─────▼──┐  ┌────▼──┐  ┌─────▼────┐
    │ Patient  │  │Patient │  │Order  │  │Appointment
    │Service   │  │Service │  │Service│  │Service
    │Pod       │  │Pod     │  │Pod    │  │Pod
    │Port:3000 │  │Port:3000│  │Port:8080│ │Port:3001│
    └┬─────────┘  └┬───────┘  └──┬────┘  └────┬─────┘
     │            │            │            │
     └────────────┴────────────┴────────────┘
                  │
    ┌─────────────▼──────────────┐
    │  GKE Cluster               │
    │  - 3 Nodes (e2-small)      │
    │  - GKE High Availability   │
    │  - Auto-scaling enabled    │
    │  - Workload Identity ready │
    └──────────────┬─────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
    ┌───▼───┐  ┌───▼───┐  ┌──▼────┐
    │Node 1 │  │Node 2 │  │Node 3 │
    │Zone A │  │Zone A │  │Zone A │
    └───────┘  └───────┘  └───────┘
```

## Components Architecture

### 1. Network Layer

```
┌────────────────────────────────────────────────┐
│  Google Cloud VPC (gke-network)                │
│  CIDR: 10.10.0.0/16                            │
│                                                 │
│  ┌──────────────────────────────────────────┐  │
│  │  Subnet (us-central1)                    │  │
│  │  CIDR: 10.10.0.0/16                      │  │
│  │                                           │  │
│  │  ┌────────────────────────────────────┐ │  │
│  │  │  GKE Cluster                       │ │  │
│  │  │  - Master Control Plane (managed)  │ │  │
│  │  │  - Worker Nodes (3 nodes)          │ │  │
│  │  └────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  Firewall Rules:                                │
│  - Allow internal traffic (0-65535 TCP/UDP)    │
│  - Allow SSH from admin IPs                    │
│  - Allow ingress on ports 80, 443              │
└────────────────────────────────────────────────┘
```

### 2. Storage and Container Registry

```
┌──────────────────────────────────────────────────────┐
│  Google Cloud Storage                                │
│                                                      │
│  ┌─────────────────────────────────────────────┐   │
│  │  GCR Bucket (${PROJECT_ID}-gcr)             │   │
│  │  - patient-service:latest                   │   │
│  │  - appointment-service:latest               │   │
│  │  - order-service:latest                     │   │
│  │  - Versioned images by SHA                  │   │
│  └─────────────────────────────────────────────┘   │
│                                                      │
│  ┌─────────────────────────────────────────────┐   │
│  │  Terraform State Bucket                     │   │
│  │  (${PROJECT_ID}-terraform-state)            │   │
│  │  - Versioning enabled                       │   │
│  │  - State locking configured                 │   │
│  │  - Backup retention: 30 days                │   │
│  └─────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘
```

### 3. Kubernetes Cluster Architecture

```
┌───────────────────────────────────────────────────────────────┐
│  GKE Cluster (gke-cluster)                                    │
│  Control Plane: Managed by Google                             │
│  Location: us-central1                                         │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Node Pool: primary-pool                                │ │
│  │  - Node Count: 3                                        │ │
│  │  - Machine Type: e2-small                              │ │
│  │  - Disk: 30GB (pd-standard)                            │ │
│  │  - Auto-scaling: 1-3 nodes                             │ │
│  │  - Auto-repair: Enabled                                │ │
│  │  - Auto-upgrade: Enabled                               │ │
│  │  - Service Account: gke-node-pool-sa                   │ │
│  │                                                         │ │
│  │  ┌───────────────────────────────────────────────┐    │ │
│  │  │  Workloads Namespace: healthcare-app         │    │ │
│  │  │                                               │    │ │
│  │  │  Deployments:                                │    │ │
│  │  │  • patient-service (2 replicas, Node.js)    │    │ │
│  │  │  • appointment-service (2 replicas, Node.js)│    │ │
│  │  │  • order-service (2 replicas, Spring Boot)  │    │ │
│  │  │                                               │    │ │
│  │  │  Services:                                   │    │ │
│  │  │  • patient-service (ClusterIP:80→3000)      │    │ │
│  │  │  • appointment-service (ClusterIP:80→3001)  │    │ │
│  │  │  • order-service (ClusterIP:80→8080)        │    │ │
│  │  │                                               │    │ │
│  │  │  Ingress:                                    │    │ │
│  │  │  • healthcare-app-ingress                    │    │ │
│  │  │  • Type: GCE (Google Cloud Load Balancer)   │    │ │
│  │  │  • SSL/TLS: Managed Certificate              │    │ │
│  │  │  • Global Static IP                          │    │ │
│  │  └───────────────────────────────────────────────┘    │ │
│  │                                                         │ │
│  │  System Components:                                    │ │
│  │  • kube-system namespace (system components)           │ │
│  │  • kube-node-lease (node heartbeats)                  │ │
│  │  • kube-public (public resources)                     │ │
│  │  • monitoring (optional metrics collection)            │ │
│  └─────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────┘
```

### 4. Service Mesh (Optional)

```
Each Pod includes:
├── Application Container
│   ├── Liveness Probe: /health
│   ├── Readiness Probe: /ready
│   ├── Resource Requests: CPU/Memory
│   └── Resource Limits: CPU/Memory
├── Security Context
│   ├── allowPrivilegeEscalation: false
│   ├── readOnlyRootFilesystem: false
│   └── runAsNonRoot: false
└── Service Account
    └── RBAC Policies
```

### 5. Observability Stack

```
┌─────────────────────────────────────────────────────┐
│  Google Cloud Monitoring                            │
│  - Cluster Metrics (CPU, Memory, Network)          │
│  - Container Metrics                               │
│  - Pod Status and Health                           │
│  - Custom Dashboards                               │
│  - Alert Policies                                  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Google Cloud Logging                               │
│  - Container Logs (stderr, stdout)                 │
│  - Pod Logs                                        │
│  - Cluster Audit Logs                             │
│  - Log Sink → BigQuery (for analysis)              │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  Optional: Prometheus + Grafana                     │
│  - Custom Application Metrics                       │
│  - Advanced Visualization                          │
│  - Alert Management                                │
└─────────────────────────────────────────────────────┘
```

## Data Flow

### Request Flow

```
1. Client Request
   └─→ Internet → Cloud Load Balancer (SSL/TLS)
   
2. Load Balancer Routes
   └─→ Kubernetes Ingress Controller
   
3. Ingress Controller Routes based on path
   ├─→ /api/patients/* → patient-service (Port 80)
   ├─→ /api/appointments/* → appointment-service (Port 80)
   └─→ /api/orders/* → order-service (Port 80)
   
4. Service Routes to Pod
   └─→ kube-proxy performs load balancing among pods
   
5. Pod Processes Request
   ├─→ Receives on mapped port (3000, 3001, 8080)
   ├─→ Processes request
   └─→ Returns response
   
6. Response Flow (Reverse)
   └─→ Client ← Load Balancer ← Ingress ← Service ← Pod
```

### Container Image Pull Flow

```
1. Kubernetes Scheduler assigns Pod to Node
2. Kubelet on Node attempts to pull image
3. kubelet uses node service account (gke-node-pool-sa)
4. Service account has access to GCR bucket
5. Image pulled from: gcr.io/${PROJECT_ID}/service-name:tag
6. Container runtime (containerd) runs image
7. Pod becomes Ready when container passes readiness probe
```

## Terraform Infrastructure as Code

```
gke-terraform/
├── main.tf                 # Main config + remote backend
├── providers.tf            # Provider configuration
├── versions.tf             # Required versions
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── enables_api.tf          # GCP API enabling
├── networking.tf           # VPC, subnets, firewall
├── gke.tf                  # GKE cluster & node pool
├── iam.tf                  # IAM roles & service accounts
├── gcr.tf                  # GCR setup & security
└── terraform.tfvars        # Environment-specific values
```

## CI/CD Pipeline

```
┌──────────────────────────────────────────────────┐
│  GitHub Repository                               │
└────────────────────┬─────────────────────────────┘
                     │ Push to main / PR created
         ┌───────────▼────────────┐
         │ GitHub Actions         │
         │ Workflows:             │
         ├─ Terraform Validate    │
         ├─ Docker Build & Push   │
         └─ Deploy to GKE         │
         
     ┌──────────────────────────┐
     │ Terraform Validate       │
     ├──────────────────────────┤
     │ 1. terraform fmt         │
     │ 2. terraform validate    │
     │ 3. terraform plan        │
     │ 4. Comment on PR         │
     └──────────────────────────┘
     
     ┌──────────────────────────┐
     │ Docker Build & Push      │
     ├──────────────────────────┤
     │ 1. Build patient-svc     │
     │ 2. Build appointment-svc │
     │ 3. Build order-svc       │
     │ 4. Push to GCR           │
     │ 5. Update image tags     │
     └──────────────────────────┘
     
     ┌──────────────────────────┐
     │ Deploy to GKE            │
     ├──────────────────────────┤
     │ 1. Get kubeconfig        │
     │ 2. Apply manifests       │
     │ 3. Wait for rollout      │
     │ 4. Verify deployment     │
     │ 5. Post summary          │
     └──────────────────────────┘
```

## Security Architecture

### Authentication & Authorization

```
GCP Level:
├── Service Accounts
│   ├── tf-provisioner (Terraform)
│   └── gke-node-pool-sa (Nodes)
├── IAM Roles
│   ├── Terraform needs: owner role
│   └── Nodes need: logging.logWriter, monitoring.metricWriter
└── Key Management: Service account keys

Kubernetes Level:
├── ServiceAccounts (per application)
│   ├── patient-service-sa
│   ├── appointment-service-sa
│   └── order-service-sa
├── RBAC (Role-Based Access Control)
│   ├── Roles (namespace-scoped)
│   └── ClusterRoles (cluster-scoped)
└── Network Policies (optional)
    └── Restrict traffic between pods
```

### Container Security

```
Per Container:
├── Security Context
│   ├── allowPrivilegeEscalation: false
│   ├── readOnlyRootFilesystem: false (configurable)
│   └── runAsNonRoot: false (configurable)
├── Resource Limits
│   ├── CPU limits/requests
│   └── Memory limits/requests
├── Image Registry
│   ├── GCR (private)
│   ├── Image scanning enabled
│   └── Only pull images by digest/tag
└── Health Checks
    ├── Liveness (restart on failure)
    └── Readiness (remove from LB on failure)
```

## Scalability

### Horizontal Scaling

```
GKE Features:
├── Pod Autoscaling (HPA)
│   ├── Trigger: Pod CPU/Memory > threshold
│   ├── Min replicas: 2
│   └── Max replicas: auto-determined
├── Node Autoscaling
│   ├── Min nodes: 1
│   ├── Max nodes: 3
│   ├── Trigger: Unschedulable pods
│   └── Scale-down delay: 10min
└── VPA (Vertical Pod Autoscaler - optional)
    └── Auto-adjust resource requests
```

### Load Distribution

```
Traffic Distribution:
├── Cloud Load Balancer (external)
│   ├── Round-robin across ingress nodes
│   ├── SSL/TLS termination
│   └── Health checks enabled
├── Kubernetes Ingress
│   ├── Path-based routing
│   └── Host-based routing (optional)
├── Kubernetes Service (ClusterIP)
│   ├── kube-proxy load balancing
│   └── NAT per pod
└── Pod-level
    └── Application handles concurrent requests
```

## High Availability

### Redundancy

```
Components:
├── Kubernetes Control Plane
│   ├── Managed by Google
│   ├── Multi-zone redundancy
│   └── Auto-healing
├── Worker Nodes
│   ├── Multi-zone (zone: us-central1-a)
│   ├── Auto-repair enabled
│   ├── Auto-upgrade enabled
│   └── Node pool scaling
├── Pods
│   ├── Multiple replicas per deployment
│   ├── Pod disruption budgets (optional)
│   └── Anti-affinity rules (optional)
└── Data
    ├── Cloud Storage with versioning
    ├── Terraform state backup
    └── Application data (external DB if needed)
```

### Failure Recovery

```
Scenario: Pod Crash
1. kubelet detects pod termination
2. ReplicaSet controller spawns replacement pod
3. Pod gets scheduled to available node
4. kube-proxy updates service endpoints
5. Load balancer routes to new pod

Scenario: Node Failure
1. Node status changes to NotReady
2. Pod eviction controller removes pods
3. Pods get rescheduled to healthy nodes
4. Node autoscaler may add new node

Scenario: Network Partition
1. kube-proxy uses endpoint slices
2. Traffic reroutes to healthy pods
3. Eventually consistent recovery
```

## Cost Optimization

### Resource Configuration

```
Current Setup:
├── Nodes: 3 × e2-small (cost-effective)
│   ├── 2 CPUs
│   ├── 4GB Memory
│   └── Auto-scaled 1-3
├── Storage
│   ├── Container images: Pay-per-GB stored
│   ├── Terraform state: Minimal (versioning optional)
│   └── Standard storage class
├── Networking
│   ├── VPC: No charge
│   ├── Ingress: Pay-per-rule-hour
│   └── Load Balancer: Pay-per-GB
└── Monitoring
    ├── Cloud Monitoring: Free tier covers basic
    ├── Cloud Logging: Free tier for GKE
    └── BigQuery: Pay-per-query (logs sink)
```

## Disaster Recovery

### Backup & Restore

```
Backup Components:
├── Kubernetes Manifests
│   ├── Version controlled in Git
│   ├── Infrastructure as Code
│   └── Easy to redeploy
├── Terraform State
│   ├── GCS with versioning
│   ├── State locking (prevents corruption)
│   └── Easy rollback to previous state
├── Application Data
│   ├── External database (if applicable)
│   ├── Regular snapshots recommended
│   └── Cross-region replication (optional)
└── Container Images
    ├── Stored in GCR with versioning
    ├── Can pull any previous version
    └── Tagged with git SHA for traceability
```

### Recovery Time Objectives (RTO)

```
Estimated Recovery Times:
├── Single Pod failure: < 5 minutes
├── Node failure: < 10 minutes
├── Multiple node failure: < 30 minutes
├── Full cluster rebuild: 20-30 minutes
│   (using Terraform + Helm)
└── Application data recovery: Variable
    (depends on database recovery)
```

## Compliance & Governance

### Audit & Logging

```
Audit Trail:
├── Google Cloud Audit Logs
│   ├── Admin activity (auto-enabled)
│   ├── Data access
│   └── System events
├── GKE Audit Logs
│   ├── API requests to API server
│   ├── User actions
│   └── Service account actions
└── Application Logs
    ├── Structured JSON logging
    ├── Cloud Logging sink
    └── Long-term storage in BigQuery
```

## Future Enhancements

1. **Service Mesh** (Istio/Anthos Service Mesh)
   - Advanced traffic management
   - Mutual TLS
   - Rate limiting

2. **Policy Enforcement** (OPA/Gatekeeper)
   - Pod security policies
   - Image registry validation
   - Resource quota enforcement

3. **Multi-region** Setup
   - High availability across regions
   - Disaster recovery
   - Latency optimization

4. **Advanced Monitoring**
   - Application Performance Monitoring (APM)
   - Distributed tracing
   - Custom dashboards

5. **GitOps** Integration
   - ArgoCD for continuous deployment
   - Policy-driven applications
   - Audit trail of all changes

---

## Deployment Models

### Development Environment
- Single node cluster
- Minimal resources
- Local backend (Terraform)

### Production Environment
- Multi-node cluster
- Redundancy and HA
- Remote state backend
- Comprehensive monitoring

---

**Last Updated**: March 2026
**Version**: 1.0
