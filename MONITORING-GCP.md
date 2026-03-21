# Monitoring and Logging Guide for GCP

This guide provides instructions for setting up comprehensive monitoring and logging for the Healthcare Application deployed on GKE.

## Architecture Overview

The monitoring stack includes:
- **Google Cloud Monitoring**: Metrics collection and dashboards
- **Google Cloud Logging**: Centralized log aggregation
- **Prometheus**: (Optional) Custom metrics collection
- **Grafana**: (Optional) Advanced visualization

## Part 1: Google Cloud Monitoring

### 1.1 Enable Monitoring Services

```bash
# Project variables
export PROJECT_ID="adept-insight-477609-p5"
export CLUSTER_NAME="gke-cluster"
export REGION="us-central1"

# Enable monitoring APIs
gcloud services enable monitoring.googleapis.com \
  --project=$PROJECT_ID

gcloud services enable logging.googleapis.com \
  --project=$PROJECT_ID
```

### 1.2 Create Monitoring Dashboard

```bash
# Create a comprehensive dashboard
gcloud monitoring dashboards create --config-from-file=- <<'EOF'
{
  "displayName": "Healthcare Application Dashboard",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "GKE Cluster CPU Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_cluster\" AND metric.type=\"kubernetes.io/container/cpu/core_usage_time\""
                  }
                },
                "plotType": "LINE"
              }
            ]
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "GKE Cluster Memory Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_cluster\" AND metric.type=\"kubernetes.io/container/memory/used_bytes\""
                  }
                },
                "plotType": "LINE"
              }
            ]
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Pod Replica Status",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/ready\""
                  }
                },
                "plotType": "LINE"
              }
            ]
          }
        }
      },
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "Network Sent Bytes",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_pod\" AND metric.type=\"kubernetes.io/pod/network/sent_bytes_count\""
                  }
                },
                "plotType": "LINE"
              }
            ]
          }
        }
      }
    ]
  }
}
EOF
```

### 1.3 View Metrics in Console

```bash
# Open Cloud Monitoring console
gcloud compute instances list  # Or open in browser
# https://console.cloud.google.com/monitoring/dashboards
```

## Part 2: Google Cloud Logging

### 2.1 View Logs from Command Line

```bash
# View recent logs
gcloud logging read "resource.type=k8s_container AND resource.labels.namespace_name=healthcare-app" \
  --limit 50 \
  --format json

# View logs for specific pod
gcloud logging read "resource.type=k8s_pod AND resource.labels.pod_name=patient-service*" \
  --limit 20 \
  --format json
```

### 2.2 Create Log Sink for Analysis

```bash
# Create BigQuery dataset for logs
bq mk --dataset --location=$REGION ${PROJECT_ID}:application_logs

# Create log sink
gcloud logging sinks create healthcare-logs-sink \
  bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/application_logs \
  --log-filter='resource.type="k8s_container" AND resource.labels.namespace_name="healthcare-app"'
```

### 2.3 Query Logs with BigQuery

```sql
-- Query logs for errors
SELECT
  timestamp,
  jsonPayload.severity,
  jsonPayload.message,
  resource.labels.pod_name,
  resource.labels.namespace_name
FROM
  `PROJECT_ID.application_logs.events_*`
WHERE
  jsonPayload.severity = 'ERROR'
  AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY
  timestamp DESC
LIMIT 100;
```

## Part 3: Setting up Alerts

### 3.1 Create Alert Policies

```bash
# Alert for high CPU usage
gcloud alpha monitoring policies create \
  --display-name="High CPU Usage Alert" \
  --condition-display-name="CPU > 80%" \
  --condition-threshold-value=0.8 \
  --condition-threshold-duration=300s \
  --condition-threshold-filter='resource.type="k8s_container" AND metric.type="kubernetes.io/container/cpu/core_usage_time"'

# Alert for pod not ready
gcloud alpha monitoring policies create \
  --display-name="Pod Not Ready Alert" \
  --condition-display-name="Pod Ready < 1" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=300s \
  --condition-threshold-filter='resource.type="k8s_pod" AND metric.type="kubernetes.io/pod/ready"' \
  --condition-threshold-comparison-type=COMPARISON_LT
```

### 3.2 Create Notification Channels

```bash
# Create email notification channel
gcloud alpha monitoring channels create \
  --display-name="Team Email" \
  --type=email \
  --channel-labels=email_address=devops-team@example.com

# Create Slack notification channel
gcloud alpha monitoring channels create \
  --display-name="Slack DevOps" \
  --type=slack \
  --channel-labels=channel_name="#alerts"
```

## Part 4: Custom Metrics (Using Prometheus)

### 4.1 Install Prometheus Stack

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --values - <<'EOF'
prometheus:
  prometheusSpec:
    retention: 7d
    serviceMonitorSelectorNilUsesHelmValues: false
    
grafana:
  adminPassword: admin
  persistence:
    enabled: true
    size: 10Gi

alertmanager:
  enabled: true
EOF
```

### 4.2 Verify Prometheus Installation

```bash
# Check pods
kubectl get pods -n monitoring

# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Port-forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Access Prometheus at http://localhost:9090
# Access Grafana at http://localhost:3000
```

### 4.3 Configure Service Monitoring

```bash
# Create ServiceMonitor for patient-service
kubectl apply -f - <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: patient-service
  namespace: healthcare-app
  labels:
    app: patient-service
spec:
  selector:
    matchLabels:
      app: patient-service
  endpoints:
  - port: http
    interval: 30s
    path: /metrics
EOF
```

## Part 5: Log Aggregation with Fluentd

### 5.1 Deploy Fluentd DaemonSet

```bash
kubectl create namespace logging

kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: logging
spec:
  selector:
    matchLabels:
      k8s-app: fluentd
  template:
    metadata:
      labels:
        k8s-app: fluentd
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch
        env:
          - name: FLUENT_ELASTICSEARCH_HOST
            value: "elasticsearch.logging"
          - name: FLUENT_ELASTICSEARCH_PORT
            value: "9200"
          - name: FLUENTD_SYSTEMD_CONF
            value: disable
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
EOF
```

## Part 6: Accessing Monitoring Dashboards

### 6.1 Cloud Console Access

```bash
# Open Cloud Monitoring
open "https://console.cloud.google.com/monitoring?project=${PROJECT_ID}"

# Open Cloud Logging
open "https://console.cloud.google.com/logs?project=${PROJECT_ID}"

# Open GKE Cluster Details
open "https://console.cloud.google.com/kubernetes/clusters?project=${PROJECT_ID}"
```

### 6.2 Grafana Access (if using Prometheus)

```bash
# Port-forward to Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Default credentials: admin / admin
# Open browser: http://localhost:3000
```

## Part 7: Performance Metrics to Monitor

### Key Metrics:

1. **Pod Metrics**
   - CPU Usage (cores)
   - Memory Usage (bytes)
   - Network In/Out
   - Disk I/O

2. **Container Metrics**
   - Restart Count
   - Ready Status
   - Image Pull Errors

3. **Cluster Metrics**
   - Node CPU/Memory Utilization
   - Pod Density
   - Network Throughput

4. **Application Metrics**
   - Request Latency
   - Error Rate
   - Throughput

### Example Queries:

```bash
# CPU per pod
gcloud logging read "resource.type=k8s_pod" \
  --format="table(resource.labels.pod_name, metric.cpu)" \
  --limit=10

# Memory per pod
gcloud logging read "resource.type=k8s_pod" \
  --format="table(resource.labels.pod_name, metric.memory)" \
  --limit=10
```

## Troubleshooting

### Issue: No metrics showing

```bash
# Verify monitoring is enabled on cluster
gcloud container clusters describe $CLUSTER_NAME --region=$REGION | grep monitoring

# If GKE monitoring is not enabled, enable it
gcloud container clusters update $CLUSTER_NAME \
  --region=$REGION \
  --enable-cloud-logging \
  --enable-cloud-monitoring
```

### Issue: Logs not appearing

```bash
# Check if logging is enabled
gcloud container clusters describe $CLUSTER_NAME --region=$REGION | grep logging

# Verify service account permissions
gcloud projects get-iam-policy $PROJECT_ID
```

## Best Practices

1. **Retention**: Set appropriate log retention based on compliance requirements
2. **Alerts**: Configure alerts for critical metrics with proper notification channels
3. **Dashboards**: Create team-specific dashboards for different roles
4. **Custom Metrics**: Instrument applications to export business metrics
5. **Analysis**: Use BigQuery for long-term trend analysis
6. **Documentation**: Document alert thresholds and runbooks

## Additional Resources

- [Google Cloud Monitoring Documentation](https://cloud.google.com/monitoring/docs)
- [Google Cloud Logging Documentation](https://cloud.google.com/logging/docs)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana vs Cloud Monitoring](https://grafana.com/docs/grafana/latest/datasources/cloud-monitoring/)
