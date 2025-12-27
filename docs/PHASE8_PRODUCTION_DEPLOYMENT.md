# Phase 8: Production Deployment & Security Hardening

Complete guide to deploying AutoMarket OS to production with TLS/HTTPS, advanced RBAC, monitoring, backup, and incident response.

---

## Phase 8 Overview

Phase 8 hardens and deploys AutoMarket OS to production by:
- **Security**: TLS/HTTPS, API key rotation, network policies
- **Access Control**: Advanced RBAC, service accounts, pod security policies
- **Monitoring**: Prometheus, Grafana, alerting
- **Backup & Recovery**: Automated backups, disaster recovery testing
- **Incident Response**: Runbooks, escalation procedures, on-call setup
- **Operations**: Health checks, auto-scaling, rolling updates

**Timeline**: 2-3 hours
**Complexity**: Advanced
**Prerequisites**: Phases 1-7 complete, test validation passed

---

## 1. Security Hardening

### 1.1 TLS/HTTPS Configuration

#### Generate Self-Signed Certificate (Testing)

```bash
# Create certificate for testing/staging
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=automarket.example.com"

# Create Kubernetes secret
kubectl create secret tls automarket-tls \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Use Let's Encrypt Certificate (Production)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

#### Update Ingress with TLS

**File**: `k8s/ingress-tls.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: automarket-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - automarket.example.com
    secretName: automarket-tls
  rules:
  - host: automarket.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: n8n
            port:
              number: 5678
      - path: /db
        pathType: Prefix
        backend:
          service:
            name: postgres
            port:
              number: 5432

---
apiVersion: v1
kind: Service
metadata:
  name: n8n
spec:
  selector:
    app: n8n
  ports:
  - port: 5678
    targetPort: 5678
  type: ClusterIP

---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

#### HSTS Headers Configuration

```yaml
# In Ingress annotations
annotations:
  nginx.ingress.kubernetes.io/configuration-snippet: |
    more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
    more_set_headers "X-Content-Type-Options: nosniff";
    more_set_headers "X-Frame-Options: DENY";
    more_set_headers "X-XSS-Protection: 1; mode=block";
    more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
```

### 1.2 Network Policies

**File**: `k8s/network-policies.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: automarket-network-policy
spec:
  podSelector:
    matchLabels:
      app: n8n
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: default
    - podSelector:
        matchLabels:
          app: nginx-ingress
    ports:
    - protocol: TCP
      port: 5678
  egress:
  # Allow DNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  # Allow external APIs
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
  # Allow PostgreSQL
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
  # Deny all other traffic
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 0

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-network-policy
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: n8n
    ports:
    - protocol: TCP
      port: 5432
```

### 1.3 Pod Security Policies

**File**: `k8s/pod-security-policies.yaml`

```yaml
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: automarket-psp
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
  - ALL
  allowedCapabilities: []
  volumes:
  - 'configMap'
  - 'emptyDir'
  - 'projected'
  - 'secret'
  - 'downwardAPI'
  - 'persistentVolumeClaim'
  hostNetwork: false
  hostIPC: false
  hostPID: false
  runAsUser:
    rule: 'MustRunAsNonRoot'
  seLinux:
    rule: 'MustRunAs'
    seLinuxOptions:
      level: "s0:c123,c456"
  supplementalGroups:
    rule: 'MustRunAs'
    ranges:
    - min: 100
      max: 65535
  fsGroup:
    rule: 'MustRunAs'
    ranges:
    - min: 100
      max: 65535
  readOnlyRootFilesystem: false

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: automarket-psp-role
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs: ['use']
  resourceNames:
  - automarket-psp

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: automarket-psp-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: automarket-psp-role
subjects:
- kind: ServiceAccount
  name: automarket
  namespace: default
```

### 1.4 API Key Rotation

**Rotation Schedule**:
- 90-day rotation for production keys
- 30-day rotation for test/staging keys
- Immediate rotation on suspected compromise

**Rotation Procedure**:

```bash
#!/bin/bash
# rotate-api-keys.sh - Automated API key rotation

# 1. Generate new API keys
NEW_FIRECRAWL_KEY=$(curl -s https://api.firecrawl.dev/generate-key)
NEW_CLAUDE_KEY=$(aws secretsmanager create-secret --name claude-key-$(date +%s) | jq -r .ARN)

# 2. Update Kubernetes secrets
kubectl patch secret n8n-secret -p \
  "{\"data\":{\"FIRECRAWL_API_KEY\":\"$(echo -n $NEW_FIRECRAWL_KEY | base64)\"}}"

# 3. Restart n8n pods
kubectl rollout restart deployment/n8n

# 4. Verify new keys work
bash scripts/test-llm-connection.sh claude

# 5. Audit log
echo "API Keys rotated at $(date)" >> /var/log/automarket/rotation.log
```

---

## 2. Advanced RBAC Configuration

### 2.1 Service Accounts

**File**: `k8s/service-accounts.yaml`

```yaml
---
# n8n Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: n8n-sa
  namespace: default

---
# PostgreSQL Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: postgres-sa
  namespace: default

---
# Application Service Account (for webhooks)
apiVersion: v1
kind: ServiceAccount
metadata:
  name: automarket-api
  namespace: default

---
# CI/CD Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cicd-sa
  namespace: default
```

### 2.2 Role-Based Access Control

**File**: `k8s/rbac.yaml`

```yaml
---
# n8n Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: n8n-role
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]

---
# n8n RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: n8n-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: n8n-role
subjects:
- kind: ServiceAccount
  name: n8n-sa
  namespace: default

---
# PostgreSQL Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: postgres-role
rules:
- apiGroups: [""]
  resources: ["persistentvolumeclaims"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get"]

---
# PostgreSQL RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: postgres-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: postgres-role
subjects:
- kind: ServiceAccount
  name: postgres-sa
  namespace: default

---
# API Role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: automarket-api-role
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get"]

---
# API RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: automarket-api-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: automarket-api-role
subjects:
- kind: ServiceAccount
  name: automarket-api
  namespace: default

---
# CI/CD Role (read-only)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cicd-role
rules:
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods", "pods/logs"]
  verbs: ["get", "list"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "list"]

---
# CI/CD RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cicd-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cicd-role
subjects:
- kind: ServiceAccount
  name: cicd-sa
  namespace: default
```

---

## 3. Monitoring & Alerting

### 3.1 Prometheus Configuration

**File**: `k8s/prometheus-deployment.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__

    - job_name: 'n8n'
      static_configs:
      - targets: ['n8n:9100']

    - job_name: 'postgres'
      static_configs:
      - targets: ['postgres-exporter:9187']

    alerting:
      alertmanagers:
      - static_configs:
        - targets: ['alertmanager:9093']

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
          - '--config.file=/etc/prometheus/prometheus.yml'
          - '--storage.tsdb.path=/prometheus'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: storage
          mountPath: /prometheus
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: storage
        emptyDir: {}

---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
```

### 3.2 Alert Rules

**File**: `k8s/alert-rules.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: automarket-alerts
spec:
  groups:
  - name: automarket
    interval: 30s
    rules:
    # n8n Alerts
    - alert: N8NHighErrorRate
      expr: rate(n8n_errors_total[5m]) > 0.1
      for: 5m
      annotations:
        summary: "n8n high error rate ({{ $value | humanize }}%)"
        description: "n8n error rate exceeds 10% over 5 minutes"

    - alert: N8NPodRestarts
      expr: rate(kube_pod_container_status_restarts_total{pod=~"n8n-.*"}[15m]) > 0
      for: 5m
      annotations:
        summary: "n8n pod restarting"
        description: "n8n pod has restarted {{ $value }} times in 15 minutes"

    - alert: N8NMemoryUsage
      expr: container_memory_usage_bytes{pod=~"n8n-.*"} / 1024 / 1024 > 700
      for: 5m
      annotations:
        summary: "n8n high memory usage"
        description: "n8n pod memory usage {{ $value }}MB exceeds 700MB"

    # PostgreSQL Alerts
    - alert: PostgreSQLDown
      expr: up{job="postgres"} == 0
      for: 2m
      annotations:
        summary: "PostgreSQL down"
        description: "PostgreSQL instance is down"

    - alert: PostgreSQLConnectionsHigh
      expr: pg_stat_activity_count > 80
      for: 5m
      annotations:
        summary: "PostgreSQL high connection count"
        description: "PostgreSQL has {{ $value }} connections (max 100)"

    # API Alerts
    - alert: HighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 5
      for: 5m
      annotations:
        summary: "High API latency"
        description: "95th percentile latency is {{ $value }}s"

    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 5m
      annotations:
        summary: "High error rate"
        description: "5xx error rate exceeds 5%"
```

### 3.3 Grafana Dashboards

**Dashboard: AutoMarket OS Overview**

```json
{
  "dashboard": {
    "title": "AutoMarket OS - Production",
    "panels": [
      {
        "title": "Workflow Executions",
        "targets": [{
          "expr": "rate(n8n_workflow_executions_total[5m])"
        }]
      },
      {
        "title": "Error Rate",
        "targets": [{
          "expr": "rate(n8n_errors_total[5m]) / rate(n8n_workflow_executions_total[5m])"
        }]
      },
      {
        "title": "Average Response Time",
        "targets": [{
          "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
        }]
      },
      {
        "title": "Pod Memory Usage",
        "targets": [{
          "expr": "container_memory_usage_bytes{pod=~\"n8n-.*\"} / 1024 / 1024"
        }]
      },
      {
        "title": "Pod CPU Usage",
        "targets": [{
          "expr": "rate(container_cpu_usage_seconds_total{pod=~\"n8n-.*\"}[5m])"
        }]
      },
      {
        "title": "Database Connections",
        "targets": [{
          "expr": "pg_stat_activity_count"
        }]
      }
    ]
  }
}
```

---

## 4. Backup & Recovery

### 4.1 PostgreSQL Backup Strategy

**File**: `scripts/backup-database.sh`

```bash
#!/bin/bash
# Automated PostgreSQL backup script

BACKUP_DIR="/backups/postgresql"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/automarket_${TIMESTAMP}.sql.gz"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Perform backup
kubectl exec -it deployment/postgres -- pg_dump -U n8n n8n | gzip > "${BACKUP_FILE}"

# Verify backup
if gzip -t "${BACKUP_FILE}"; then
  echo "✓ Backup successful: ${BACKUP_FILE}"

  # Upload to S3
  aws s3 cp "${BACKUP_FILE}" s3://automarket-backups/postgresql/

  # Cleanup old backups
  find "${BACKUP_DIR}" -name "automarket_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

  echo "✓ Old backups cleaned up"
else
  echo "✗ Backup verification failed"
  exit 1
fi
```

### 4.2 Kubernetes Persistent Volume Backup

**File**: `k8s/backup-cronjob.yaml`

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-cronjob
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: backup-sa
          containers:
          - name: backup
            image: postgres:15
            command:
            - /bin/bash
            - -c
            - |
              #!/bin/bash
              TIMESTAMP=$(date +%Y%m%d_%H%M%S)
              BACKUP_FILE="/backups/automarket_${TIMESTAMP}.sql.gz"

              mkdir -p /backups

              pg_dump -h postgres -U n8n n8n | gzip > "${BACKUP_FILE}"

              if [ $? -eq 0 ]; then
                echo "Backup successful: ${BACKUP_FILE}"

                # Upload to S3
                aws s3 cp "${BACKUP_FILE}" s3://automarket-backups/

                echo "Backup uploaded to S3"
              else
                echo "Backup failed"
                exit 1
              fi
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: password
            volumeMounts:
            - name: backups
              mountPath: /backups
          volumes:
          - name: backups
            persistentVolumeClaim:
              claimName: backup-pvc
          restartPolicy: OnFailure

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: backup-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ServiceAccount
metadata:
  name: backup-sa

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: backup-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["create", "get", "list"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: backup-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: backup-role
subjects:
- kind: ServiceAccount
  name: backup-sa
```

### 4.3 Disaster Recovery Testing

**File**: `scripts/test-recovery.sh`

```bash
#!/bin/bash
# Test database recovery procedure

echo "=== AutoMarket OS - Disaster Recovery Test ==="

# 1. Get latest backup
LATEST_BACKUP=$(aws s3 ls s3://automarket-backups/ | tail -1 | awk '{print $4}')
echo "Using backup: ${LATEST_BACKUP}"

# 2. Create test namespace
kubectl create namespace dr-test

# 3. Deploy test PostgreSQL
kubectl apply -f k8s/postgres-deployment.yaml -n dr-test

# 4. Wait for pod to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n dr-test --timeout=300s

# 5. Restore backup
aws s3 cp s3://automarket-backups/${LATEST_BACKUP} /tmp/
gunzip /tmp/${LATEST_BACKUP}
RESTORED_FILE=$(echo ${LATEST_BACKUP} | sed 's/.gz//')

kubectl exec -it -n dr-test deployment/postgres -- psql -U n8n < /tmp/${RESTORED_FILE}

# 6. Verify restoration
RESTORED_COUNT=$(kubectl exec -n dr-test deployment/postgres -- psql -U n8n -t -c \
  "SELECT COUNT(*) FROM automarket.campaigns;")

echo "Campaigns in restored database: ${RESTORED_COUNT}"

# 7. Run smoke tests
bash scripts/run-tests.sh smoke

# 8. Cleanup
kubectl delete namespace dr-test

echo "✓ Disaster recovery test completed"
```

---

## 5. Incident Response

### 5.1 Incident Response Playbook

#### High Error Rate

**Trigger**: Error rate > 10% for 5 minutes
**Impact**: Customer-facing issues
**Resolution Time**: 15 minutes

**Steps**:
1. Acknowledge alert (Page on-call)
2. Check error logs: `kubectl logs -f deployment/n8n --tail=100`
3. Check API status:
   ```bash
   bash scripts/test-llm-connection.sh claude
   bash scripts/test-firecrawl.sh
   ```
4. If API issue:
   - Wait for API recovery
   - Monitor error rate decline
   - Restart n8n if needed: `kubectl rollout restart deployment/n8n`
5. If code issue:
   - Rollback to previous version: `kubectl rollout undo deployment/n8n`
   - Investigate root cause
   - Deploy fix on staging first
6. Post-incident: Review logs, update runbooks

#### Database Connection Failure

**Trigger**: PostgreSQL pod down or unresponsive
**Impact**: Campaign data loss risk
**Resolution Time**: 10 minutes

**Steps**:
1. Acknowledge alert
2. Check PostgreSQL status: `kubectl get pods -l app=postgres`
3. Check logs: `kubectl logs deployment/postgres --tail=50`
4. Attempt restart: `kubectl rollout restart deployment/postgres`
5. If restart fails:
   - Check PVC status: `kubectl get pvc`
   - Verify disk space: `kubectl exec -it deployment/postgres -- df -h`
   - Restore from backup (see Disaster Recovery section)
6. Monitor recovery metrics

#### High Memory Usage

**Trigger**: n8n memory > 700MB
**Impact**: OOMKilled pods, workflow failures
**Resolution Time**: 5 minutes

**Steps**:
1. Acknowledge alert
2. Check memory usage: `kubectl top pod -l app=n8n`
3. Check for memory leaks: `kubectl logs deployment/n8n | grep "heap" | tail -20`
4. Increase memory limits:
   ```bash
   kubectl patch deployment n8n --type='json' \
     -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"1Gi"}]'
   ```
5. Monitor memory trend over next 30 minutes
6. If still high: Investigate and fix memory leak

### 5.2 On-Call Escalation

**Primary On-Call**: Team lead (respond within 5 minutes)
**Secondary On-Call**: Senior engineer (respond within 15 minutes)
**Escalation Manager**: CTO (if not resolved in 30 minutes)

**Contact**:
- Slack: #automarket-incidents
- PagerDuty: automarket-prod-incidents

### 5.3 Change Management

**Deployment Checklist**:
- [ ] Code review approved
- [ ] Tests passing (unit + integration)
- [ ] No secrets in code
- [ ] Database migrations tested
- [ ] Rollback plan prepared
- [ ] On-call notified
- [ ] Runbooks updated

**Deployment Procedure**:
```bash
# 1. Build and test
npm run test -- --coverage
docker build -t synthtext-n8n:v1.2.0 .

# 2. Push to registry
docker push your-registry/synthtext-n8n:v1.2.0

# 3. Deploy to staging
kubectl set image deployment/n8n n8n=synthtext-n8n:v1.2.0 -n staging

# 4. Run smoke tests
bash scripts/run-tests.sh smoke -n staging

# 5. If successful, deploy to prod
kubectl set image deployment/n8n n8n=synthtext-n8n:v1.2.0 -n production

# 6. Monitor for 30 minutes
kubectl logs -f deployment/n8n -n production
```

---

## 6. Operational Runbooks

### 6.1 Health Check Procedure

**Weekly Health Check** (Monday 10 AM):

```bash
#!/bin/bash
# Health check script

echo "=== AutoMarket OS Weekly Health Check ==="

# 1. Kubernetes cluster health
echo "Cluster Health:"
kubectl get nodes
kubectl get componentstatuses

# 2. Pod status
echo "Pod Status:"
kubectl get pods

# 3. Volume status
echo "Volume Status:"
kubectl get pvc

# 4. Recent errors
echo "Recent Errors (last 24h):"
kubectl logs deployment/n8n --tail=100 --timestamps=true | grep -i error

# 5. Database stats
echo "Database Stats:"
kubectl exec deployment/postgres -- psql -U n8n -c \
  "SELECT COUNT(*) as campaigns, MAX(created_at) as latest FROM automarket.campaigns;"

# 6. API connectivity
echo "API Health:"
bash scripts/test-llm-connection.sh claude
bash scripts/test-firecrawl.sh

# 7. Certificate expiry
echo "Certificate Expiry:"
kubectl get secret automarket-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -enddate
```

### 6.2 Scaling Procedures

**Horizontal Scaling** (Increase replicas):

```bash
# Scale n8n to 3 replicas for high load
kubectl scale deployment n8n --replicas=3

# Monitor scaling
kubectl get pods -w

# Check resource usage
kubectl top pods -l app=n8n

# After load decreases, scale down
kubectl scale deployment n8n --replicas=1
```

**Vertical Scaling** (Increase resources):

```bash
# Update resource limits
kubectl patch deployment n8n --type='json' \
  -p='[
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"1Gi"},
    {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value":"2Gi"}
  ]'

# Monitor restart
kubectl get pods -w
```

---

## 7. Compliance & Audit

### 7.1 Audit Logging

**File**: `k8s/audit-policy.yaml`

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# All requests at RequestResponse level
- level: RequestResponse
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
  omitStages:
  - RequestReceived

# Log pod exec at RequestResponse level
- level: RequestResponse
  verbs: ["create"]
  resources:
  - group: ""
    resources: ["pods/exec"]

# Log all other requests at Metadata level
- level: Metadata
  resources:
  - group: ""
    resources: ["pods"]
```

### 7.2 Compliance Checklist

- [ ] Data encryption at rest (etcd encryption)
- [ ] Data encryption in transit (TLS)
- [ ] RBAC configured and tested
- [ ] Network policies enforced
- [ ] Audit logging enabled
- [ ] API key rotation schedule (90 days)
- [ ] Backup and recovery tested
- [ ] Incident response plan in place
- [ ] Security scanning in CI/CD
- [ ] Penetration testing completed

---

## Deployment Checklist

Pre-Production Validation:
- [ ] All Phase 7 tests passing (unit, integration, load)
- [ ] Security scan completed (OWASP, CVE)
- [ ] TLS certificate configured
- [ ] RBAC configured
- [ ] Network policies applied
- [ ] Monitoring dashboards created
- [ ] Backup strategy tested
- [ ] Incident response runbooks written
- [ ] On-call rotation configured
- [ ] Documentation complete

Go-Live Steps:
1. [ ] Final security audit
2. [ ] Load test with production-like data
3. [ ] Dry-run of incident response procedures
4. [ ] On-call team briefing
5. [ ] Deploy to production during low-traffic period
6. [ ] Monitor closely for first 24 hours
7. [ ] Post-deployment review after 1 week

---

## Support & Maintenance

**Regular Maintenance Schedule**:
- Daily: Monitor metrics, check alerts
- Weekly: Health check, log review
- Monthly: Security updates, dependency patches
- Quarterly: Disaster recovery testing, capacity planning
- Annually: Security audit, compliance review

**Contact Information**:
- On-Call: #automarket-incidents (Slack)
- Security Issues: security@example.com
- General Support: support@example.com

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Status**: Ready for implementation
**Estimated Time**: 2-3 hours
**Complexity**: Advanced
