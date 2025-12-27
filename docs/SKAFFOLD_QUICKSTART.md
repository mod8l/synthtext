# Skaffold Quick Start Guide

Get AutoMarket OS running locally in 10 minutes with Skaffold and Kubernetes.

## Prerequisites

- Kubernetes cluster (Docker Desktop, Minikube, or cloud K8s)
- Skaffold CLI
- Docker (for building images)
- kubectl
- 2GB free disk space + 2GB RAM

## 1. Install Skaffold (2 minutes)

```bash
# macOS
brew install skaffold

# Linux
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
chmod +x skaffold && sudo mv skaffold /usr/local/bin

# Verify
skaffold version
```

## 2. Start Local Kubernetes (2 minutes)

**Docker Desktop:**
- Open Docker Desktop settings
- Go to Kubernetes tab
- Enable Kubernetes checkbox
- Wait for "Kubernetes is running"

**Minikube:**
```bash
minikube start --cpus 4 --memory 4096
eval $(minikube docker-env)  # Use Minikube's Docker daemon
```

**Cloud K8s (EKS/GKE/AKS):**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name my-cluster --region us-east-1
# or
gcloud container clusters get-credentials my-cluster --zone us-central1-a
```

## 3. Clone/Navigate to Project

```bash
cd /home/user/synthtext

# Verify project structure
ls -la
# Should show: k8s/, src/, skaffold.yaml, Dockerfile, etc.
```

## 4. Update Secrets (2 minutes)

Edit the n8n and PostgreSQL secrets with your API keys:

```bash
# Edit n8n secrets
vi k8s/n8n-secret.yaml

# Required fields to update:
# - CLAUDE_API_KEY or OPENAI_API_KEY (choose ONE LLM)
# - FIRECRAWL_API_KEY
# - MIXPOST_API_KEY
# - Social media tokens (LinkedIn, Twitter, Instagram, Facebook)
# - TWENTY_CRM_URL and TWENTY_CRM_TOKEN
# - SLACK_WEBHOOK_URL

# Edit PostgreSQL password
vi k8s/postgres-secret.yaml
```

## 5. Deploy with Skaffold (3 minutes)

```bash
# Start Skaffold dev mode
# This builds, deploys, and watches for code changes
skaffold dev --profile=dev

# Or one-time build and deploy:
# skaffold run --profile=dev
```

**Expected output:**
```
Deployments:
Checking for deletions...
Cleaning up...
Building images...
Building [synthtext-n8n]...
...
✓ Artifacts built successfully
✓ Kubernetes deployment completed
✓ Watching for code changes...
Port forwarded to 5678 (n8n)
Port forwarded to 5432 (postgres)
```

## 6. Access n8n (30 seconds)

Open your browser:
```
http://localhost:5678
```

**Login:**
- First time: Create email + password
- Subsequent times: Use your credentials

## 7. Test the Setup (1 minute)

1. **Check Status**
   ```bash
   # In another terminal
   kubectl get pods
   # Should show: n8n-xxx and postgres-xxx running
   ```

2. **View Logs**
   ```bash
   # Follow n8n logs
   kubectl logs -f deployment/n8n

   # Or PostgreSQL
   kubectl logs -f deployment/postgres
   ```

3. **Access n8n Dashboard**
   - Visit http://localhost:5678
   - Should see n8n UI loading
   - Create your account

## 8. Stop Development Server

```bash
# Stop Skaffold (Ctrl+C)
# Kubernetes resources remain deployed

# Clean up (delete all resources)
skaffold delete --profile=dev
```

## Common Tasks

### View Pod Logs
```bash
kubectl logs -f deployment/n8n
kubectl logs -f deployment/postgres
```

### Access PostgreSQL
```bash
kubectl port-forward svc/postgres 5432:5432

# In another terminal
psql -h localhost -U n8n -d n8n
# Password: n8n_secure_password_change_me (from postgres-secret.yaml)
```

### Rebuild Images
```bash
# Skaffold dev automatically rebuilds on file changes
# Manual rebuild:
skaffold build --profile=dev
```

### Deploy to Staging
```bash
# Update kubeconfig to staging cluster
kubectl config use-context staging-cluster

# Deploy
skaffold run --profile=staging
```

### Deploy to Production
```bash
# Update kubeconfig to production cluster
kubectl config use-context prod-cluster

# Deploy
skaffold run --profile=prod
```

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check resource availability
kubectl top nodes
kubectl top pods
```

### Database connection issues

```bash
# Test connectivity
kubectl run -it --rm debug --image=alpine --restart=Never -- nc -zv postgres 5432

# Check database logs
kubectl logs deployment/postgres
```

### Port forwarding issues

```bash
# Kill existing port-forward processes
lsof -ti:5678 | xargs kill -9

# Manual port-forward
kubectl port-forward svc/n8n 5678:80
kubectl port-forward svc/postgres 5432:5432
```

### Image build failures

```bash
# Check Docker
docker ps
docker images | grep synthtext

# Manual build
docker build -t synthtext-n8n:latest .

# Check Dockerfile
cat Dockerfile
```

## Next Steps

1. **Import n8n Workflow**
   - Visit n8n Dashboard
   - Import workflow from `/src/workflows/automarket-campaign.json`
   - Configure credentials (Firecrawl, OpenAI/Claude, etc.)

2. **Configure Integrations**
   - Set up Firecrawl API key
   - Connect social media accounts (LinkedIn, Twitter, Instagram, Facebook)
   - Configure Twenty CRM
   - Set up Slack notifications

3. **Test a Campaign**
   - Trigger workflow with a test website URL
   - Review generated content
   - Publish to social channels

4. **Set Up Production**
   - Switch to prod cluster
   - Use production secrets
   - Enable TLS/HTTPS
   - Set up monitoring and backups

## Environment Variables

All configuration is in:
- `k8s/n8n-configmap.yaml` - Non-sensitive config
- `k8s/n8n-secret.yaml` - API keys & credentials
- `k8s/postgres-secret.yaml` - Database credentials

## Useful Commands

```bash
# Get cluster info
kubectl cluster-info
kubectl get nodes

# Get all resources
kubectl get all

# Describe resource
kubectl describe pod <pod-name>
kubectl describe deployment n8n
kubectl describe svc n8n

# Port forward
kubectl port-forward svc/n8n 5678:80

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/sh

# Delete resources
kubectl delete deployment n8n
kubectl delete pvc n8n-pvc
kubectl delete pvc postgres-pvc

# Watch resources
kubectl get pods -w
kubectl rollout status deployment/n8n
```

## Advanced: Registry Configuration

By default, Skaffold uses local Docker for building (no push). For staging/production:

```bash
# Configure Docker Hub
docker login
skaffold dev --default-repo=your-docker-username

# Or AWS ECR
aws ecr get-login-password | docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
skaffold run --default-repo=123456789.dkr.ecr.us-east-1.amazonaws.com

# See docs/SKAFFOLD_REGISTRY_SETUP.md for detailed options
```

## Performance Tips

```bash
# Reduce Skaffold verbosity
skaffold dev -v=info

# Skip unnecessary tests
skaffold dev --skip-tests

# Use fast build mode
skaffold dev --build-concurrency=0

# Minikube: Use nodelocaldns
minikube start --extra-config=apiserver.dns-policy=NodeLocalDNS
```

## Security Note

⚠️ **Before Production:**
1. Change all default passwords in secrets
2. Use external secrets manager (Vault, AWS Secrets Manager)
3. Enable TLS/HTTPS on Ingress
4. Set up RBAC properly
5. Scan Docker image for vulnerabilities
6. Enable pod security policies

See `k8s/README.md` for security best practices.

## Support

- **Skaffold Docs**: https://skaffold.dev/
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **n8n Docs**: https://docs.n8n.io/
- **Docker Docs**: https://docs.docker.com/

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Time to Complete**: ~10 minutes
