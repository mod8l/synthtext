# Kubernetes Deployment for AutoMarket OS with n8n

This directory contains all Kubernetes manifests for deploying AutoMarket OS (n8n-based marketing automation) to a Kubernetes cluster using Skaffold.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│           Kubernetes Cluster                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Ingress (n8n-ingress.yaml)                      │  │
│  │  - TLS termination                               │  │
│  │  - Host-based routing                            │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                     │
│  ┌────────────────▼─────────────────────────────────┐  │
│  │  n8n Service (n8n-service.yaml)                  │  │
│  │  - LoadBalancer/ClusterIP/NodePort               │  │
│  │  - Port: 5678 (HTTP)                             │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                     │
│  ┌────────────────▼─────────────────────────────────┐  │
│  │  n8n Deployment (n8n-deployment.yaml)            │  │
│  │  - Replicas: 1 (or more for HA)                  │  │
│  │  - Persistent volume for workflows               │  │
│  │  - Health checks & resource limits               │  │
│  │  - Init container: wait for PostgreSQL           │  │
│  └─────────────────────────────────────────────────┘  │
│                   │                                     │
│  ┌────────────────▼─────────────────────────────────┐  │
│  │  PostgreSQL Deployment (postgres-deployment.yaml)│  │
│  │  - Database backend for n8n                      │  │
│  │  - Persistent volume storage                     │  │
│  │  - Health checks                                 │  │
│  │  - Credentials from Secret                       │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Files Overview

### Core Files

| File | Purpose |
|------|---------|
| `namespace.yaml` | Kubernetes namespaces (dev, staging, prod) |
| `postgres-pvc.yaml` | Persistent volume claims for data storage |
| `postgres-secret.yaml` | PostgreSQL credentials |
| `postgres-deployment.yaml` | PostgreSQL database deployment |
| `postgres-service.yaml` | PostgreSQL service (ClusterIP) |
| `n8n-configmap.yaml` | n8n application configuration |
| `n8n-secret.yaml` | n8n API keys and credentials |
| `n8n-rbac.yaml` | Service account and RBAC roles |
| `n8n-deployment.yaml` | n8n workflow engine deployment |
| `n8n-service.yaml` | n8n service (LoadBalancer) |
| `n8n-ingress.yaml` | Ingress for external access (TLS optional) |

## Prerequisites

1. **Kubernetes Cluster**
   - Minikube: `minikube start`
   - Docker Desktop: Enable Kubernetes in settings
   - EKS/GKE/AKS: Use appropriate CLI

2. **Skaffold** (required for deployment)
   ```bash
   # macOS
   brew install skaffold

   # Linux
   curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
   chmod +x skaffold && sudo mv skaffold /usr/local/bin
   ```

3. **kubectl**
   ```bash
   # Already installed with most Kubernetes tools
   kubectl version --client
   ```

4. **Docker** (for building container images)

## Quick Start

### 1. Update Configuration Secrets

**IMPORTANT**: Before deploying, update all sensitive data in the secret files:

```bash
# Edit PostgreSQL credentials
kubectl apply -f k8s/postgres-secret.yaml

# Edit n8n API keys and integrations
kubectl apply -f k8s/n8n-secret.yaml
```

Or use environment-specific secret files:
```
k8s/secrets/postgres-secret-dev.yaml
k8s/secrets/n8n-secret-dev.yaml
k8s/secrets/postgres-secret-prod.yaml
k8s/secrets/n8n-secret-prod.yaml
```

### 2. Development Deployment (Local Kubernetes)

```bash
# Using Skaffold dev mode (auto-rebuild on code changes)
skaffold dev --profile=dev

# Or: One-time build and deploy
skaffold run --profile=dev
```

This will:
- Build the Docker image
- Create namespaces and persistent volumes
- Deploy PostgreSQL
- Deploy n8n
- Forward ports locally
- Watch for code changes and redeploy

### 3. Access n8n

**Local Development**:
```bash
# Automatic port-forward via Skaffold
# n8n available at http://localhost:5678
```

**Manual Port-Forward**:
```bash
kubectl port-forward svc/n8n 5678:80
# Then visit: http://localhost:5678
```

**Via Ingress** (if configured):
```
https://n8n.example.com
```

### 4. View Logs

```bash
# n8n logs
kubectl logs -f deployment/n8n

# PostgreSQL logs
kubectl logs -f deployment/postgres

# Follow all pods
kubectl logs -f -l app=n8n
```

### 5. Access PostgreSQL

```bash
# Port-forward to local machine
kubectl port-forward svc/postgres 5432:5432

# Connect via psql (from another terminal)
psql -h localhost -U n8n -d n8n -p 5432
# Password: (see k8s/postgres-secret.yaml)
```

## Deployment Scenarios

### Scenario 1: Local Development (Docker Desktop)

```bash
# 1. Ensure Docker Desktop Kubernetes is enabled
# 2. Configure secrets
vim k8s/n8n-secret.yaml
vim k8s/postgres-secret.yaml

# 3. Deploy with Skaffold
skaffold dev --profile=dev

# 4. Access
open http://localhost:5678
```

### Scenario 2: Staging Deployment (EKS/GKE/AKS)

```bash
# 1. Configure kubectl context
kubectl config use-context staging-cluster

# 2. Create staging namespace
kubectl create namespace synthext-staging

# 3. Update secrets for staging
kubectl apply -f k8s/postgres-secret.yaml -n synthext-staging
kubectl apply -f k8s/n8n-secret.yaml -n synthext-staging

# 4. Deploy
skaffold run --profile=staging -n synthext-staging

# 5. Configure Ingress with TLS
# Update k8s/n8n-ingress.yaml with your domain
kubectl apply -f k8s/n8n-ingress.yaml -n synthext-staging

# 6. Get external IP
kubectl get svc n8n -n synthext-staging
```

### Scenario 3: Production Deployment

```bash
# 1. Set kubectl context to production
kubectl config use-context prod-cluster

# 2. Create production namespace with security policies
kubectl create namespace synthext-prod
kubectl label namespace synthext-prod pod-security.kubernetes.io/enforce=restricted

# 3. Use external secrets (Vault, sealed-secrets, etc.)
# Example with sealed-secrets:
kubeseal -f k8s/n8n-secret.yaml \
  --scope=namespace \
  --namespace=synthext-prod > k8s/n8n-secret-sealed.yaml

# 4. Deploy with Skaffold
skaffold run --profile=prod -n synthext-prod

# 5. Set up monitoring (Prometheus, Datadog, New Relic)
# Add servicemonitor.yaml, datadog-annotations, etc.

# 6. Verify deployment
kubectl get all -n synthext-prod
```

## Scaling

### Horizontal Pod Autoscaling

```bash
# Apply HPA (create k8s/n8n-hpa.yaml first)
kubectl apply -f k8s/n8n-hpa.yaml

# Monitor scaling
kubectl get hpa -w
```

Example HPA manifest:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: n8n-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: n8n
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Monitoring

### Prometheus Scraping

The n8n deployment includes annotations for Prometheus:
```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "5678"
prometheus.io/path: "/metrics"
```

Install Prometheus Operator:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack
```

### Logs & Events

```bash
# View all events
kubectl get events --sort-by='.lastTimestamp'

# Stream logs from specific pod
kubectl logs -f <pod-name>

# View previous container logs (if crashed)
kubectl logs <pod-name> --previous
```

## Troubleshooting

### n8n Pod Not Starting

```bash
# Check pod status
kubectl describe pod <n8n-pod-name>

# Check init container logs
kubectl logs <n8n-pod-name> -c wait-for-postgres

# Check deployment status
kubectl rollout status deployment/n8n
```

### PostgreSQL Connection Issues

```bash
# Verify PostgreSQL is running
kubectl get deployment postgres
kubectl get svc postgres

# Check PostgreSQL logs
kubectl logs -f deployment/postgres

# Test connectivity from n8n pod
kubectl exec -it <n8n-pod> -- psql -h postgres -U n8n -d n8n -c "SELECT version();"
```

### Storage Issues

```bash
# Check persistent volumes
kubectl get pvc

# Check storage capacity
kubectl describe pvc postgres-pvc
kubectl describe pvc n8n-pvc

# Expand volume (if needed)
kubectl patch pvc postgres-pvc -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

### Network/Connectivity

```bash
# Test DNS resolution within cluster
kubectl run -it --rm debug --image=alpine --restart=Never -- nslookup postgres

# Test port connectivity
kubectl run -it --rm debug --image=alpine --restart=Never -- nc -zv postgres 5432

# Check service endpoints
kubectl get endpoints postgres
```

## Security Best Practices

### 1. Secrets Management
- ✅ Use Kubernetes Secrets
- ✅ Rotate credentials regularly
- ✅ Use external secrets (Vault, AWS Secrets Manager)
- ✅ Implement RBAC for secret access
- ❌ Don't commit secrets to Git

### 2. Network Security
- ✅ Use NetworkPolicies to restrict traffic
- ✅ Enable TLS/HTTPS on Ingress
- ✅ Use Private Registry for images
- ✅ Scan images for vulnerabilities

### 3. Pod Security
- ✅ Run as non-root where possible
- ✅ Use read-only root filesystems
- ✅ Drop unnecessary capabilities
- ✅ Set resource limits and requests

### 4. Access Control
- ✅ Use RBAC for service accounts
- ✅ Enable audit logging
- ✅ Restrict API server access
- ✅ Use kubectl RBAC (kubeconfig permissions)

## Cleanup

### Remove All Resources

```bash
# Delete single namespace (cascades to all resources)
kubectl delete namespace default

# Or delete individual resources
skaffold delete --profile=dev

# Remove persistent volumes (WARNING: Data loss)
kubectl delete pvc --all

# Remove Kubernetes cluster
minikube delete  # For minikube
# Or via cloud provider console (EKS, GKE, AKS)
```

## Environment Variables Reference

All configuration comes from:

1. **k8s/n8n-configmap.yaml** - Non-sensitive config
2. **k8s/n8n-secret.yaml** - API keys and credentials
3. **k8s/postgres-secret.yaml** - Database credentials

Key variables:
- `N8N_HOST` - n8n instance URL
- `DB_TYPE` - Database type (postgresdb)
- `DB_POSTGRESDB_*` - PostgreSQL connection
- `CLAUDE_API_KEY` - Anthropic Claude API
- `OPENAI_API_KEY` - OpenAI API (alternative)
- `FIRECRAWL_API_KEY` - Web scraping API
- `MIXPOST_API_KEY` - Social media scheduling
- `TWENTY_CRM_URL` - CRM instance URL

## Next Steps

1. **Configure Secrets**: Update k8s/n8n-secret.yaml with your API keys
2. **Test Locally**: Run `skaffold dev --profile=dev`
3. **Deploy to Staging**: Use staging profile
4. **Set up Monitoring**: Add Prometheus and Grafana
5. **Configure Backups**: Add persistent volume backups
6. **Enable TLS**: Update Ingress and cert-manager

## Support & Documentation

- [Skaffold Documentation](https://skaffold.dev/)
- [n8n Installation](https://docs.n8n.io/hosting/installation/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Desktop Kubernetes](https://docs.docker.com/desktop/kubernetes/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/)

---

**Last Updated**: 2025-12-27
**Version**: 1.0
