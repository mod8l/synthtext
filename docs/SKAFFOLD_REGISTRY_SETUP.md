# Skaffold Container Registry Setup

This guide explains how to configure container registry options for building and pushing Docker images with Skaffold.

## Registry Options Overview

| Registry | Local Dev | Staging | Production | Cost | Setup |
|----------|-----------|---------|-----------|------|-------|
| **Docker Hub** | Push required | ✅ | ✅ | Free tier + paid | Simple |
| **AWS ECR** | Push required | ✅ | ✅ | Pay-per-use | Moderate |
| **Google GCR** | Push required | ✅ | ✅ | Pay-per-use | Moderate |
| **Azure ACR** | Push required | ✅ | ✅ | Pay-per-use | Moderate |
| **Local Registry** | ✅ No push | Limited | ❌ | Free | Complex |
| **GitHub Container Registry** | Push required | ✅ | ✅ | Free tier + paid | Simple |

## Quick Start (Development)

### Option 1: Use Local Kubernetes Registry (No Push)

For **Docker Desktop Kubernetes** or **Minikube** with local image storage:

```bash
# Edit skaffold.yaml
cd /home/user/synthext

# Uncomment the local configuration:
# local:
#   useDockerForBuild: true
#   push: false

# Run Skaffold
skaffold dev --profile=dev --default-repo=""
```

This builds locally and deploys without pushing to a remote registry.

### Option 2: Docker Hub (Free Account)

1. **Create Docker Hub Account**
   ```bash
   # Visit https://hub.docker.com and create free account
   # Username: your-docker-username
   ```

2. **Login Locally**
   ```bash
   docker login
   # Enter username and password
   ```

3. **Update skaffold.yaml**
   ```yaml
   build:
     artifacts:
       - image: synthext-n8n
         docker:
           dockerfile: Dockerfile

   deploy:
     kubectl: {}
   ```

4. **Set Default Repo**
   ```bash
   skaffold dev --profile=dev --default-repo=docker.io/your-docker-username
   ```

5. **Or Update skaffold.yaml Directly**
   ```yaml
   build:
     artifacts:
       - image: your-docker-username/synthext-n8n
         docker:
           dockerfile: Dockerfile
   ```

## Production Registry Setup

### AWS ECR (Recommended for AWS)

1. **Create ECR Repository**
   ```bash
   aws ecr create-repository \
     --repository-name synthext-n8n \
     --region us-east-1
   ```

2. **Get Login Token**
   ```bash
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin \
     123456789.dkr.ecr.us-east-1.amazonaws.com
   ```

3. **Update skaffold.yaml**
   ```yaml
   build:
     artifacts:
       - image: 123456789.dkr.ecr.us-east-1.amazonaws.com/synthext-n8n
         docker:
           dockerfile: Dockerfile
   ```

4. **Deploy**
   ```bash
   skaffold run --profile=prod \
     --default-repo=123456789.dkr.ecr.us-east-1.amazonaws.com
   ```

### Google Cloud Registry (GCR)

1. **Create Project & Enable API**
   ```bash
   gcloud auth login
   gcloud config set project MY_PROJECT_ID
   gcloud services enable containerregistry.googleapis.com
   ```

2. **Configure Docker Access**
   ```bash
   gcloud auth configure-docker gcr.io
   ```

3. **Build & Push**
   ```bash
   docker build -t gcr.io/MY_PROJECT_ID/synthext-n8n:latest .
   docker push gcr.io/MY_PROJECT_ID/synthext-n8n:latest
   ```

4. **Update skaffold.yaml**
   ```yaml
   build:
     artifacts:
       - image: gcr.io/MY_PROJECT_ID/synthext-n8n
         docker:
           dockerfile: Dockerfile
   ```

### Azure Container Registry (ACR)

1. **Create ACR**
   ```bash
   az acr create \
     --resource-group myResourceGroup \
     --name myregistry \
     --sku Basic
   ```

2. **Get Login Credentials**
   ```bash
   az acr login --name myregistry
   ```

3. **Build & Push**
   ```bash
   docker build -t myregistry.azurecr.io/synthext-n8n:latest .
   docker push myregistry.azurecr.io/synthext-n8n:latest
   ```

4. **Update skaffold.yaml**
   ```yaml
   build:
     artifacts:
       - image: myregistry.azurecr.io/synthext-n8n
         docker:
           dockerfile: Dockerfile
   ```

## Kubernetes Image Pull Configuration

### Private Registry Credentials

For private registries, create a Kubernetes secret:

```bash
# Create secret for Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=<your-registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  --docker-email=<email>
```

Update deployment to use the secret:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
spec:
  template:
    spec:
      imagePullSecrets:
        - name: regcred
      containers:
        - name: n8n
          image: <your-registry>/synthext-n8n:latest
```

## Skaffold Configuration Examples

### Development (Local Registry)

```yaml
# skaffold.yaml
apiVersion: skaffold/v4beta6
kind: Config
metadata:
  name: synthext-automarket

build:
  artifacts:
    - image: synthext-n8n
      docker:
        dockerfile: Dockerfile
      sync:
        manual:
          - src: "src/**/*"
            dest: /app/src

local:
  useDockerForBuild: true
  push: false  # Don't push to registry

deploy:
  kubectl: {}
```

**Run:**
```bash
skaffold dev --profile=dev
```

### Staging (Docker Hub)

```yaml
# skaffold.yaml - staging section
profiles:
  - name: staging
    build:
      artifacts:
        - image: your-docker-username/synthext-n8n:staging
          docker:
            dockerfile: Dockerfile
    deploy:
      kubectl:
        defaultNamespace: synthext-staging
        manifests:
          - k8s/namespace.yaml
          - k8s/*.yaml
```

**Run:**
```bash
skaffold run --profile=staging
```

### Production (AWS ECR)

```yaml
# skaffold.yaml - prod section
profiles:
  - name: prod
    build:
      artifacts:
        - image: 123456789.dkr.ecr.us-east-1.amazonaws.com/synthext-n8n:latest
          docker:
            dockerfile: Dockerfile
    deploy:
      kubectl:
        defaultNamespace: synthext-prod
        manifests:
          - k8s/namespace.yaml
          - k8s/*.yaml
```

**Run:**
```bash
# Authenticate to ECR first
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

# Deploy
skaffold run --profile=prod
```

## Image Tagging Strategy

### Semantic Versioning
```bash
# Development (short SHA)
docker tag synthext-n8n:$(git rev-parse --short HEAD)

# Staging (version)
docker tag synthext-n8n:v1.0.0-staging

# Production (stable)
docker tag synthext-n8n:v1.0.0
docker tag synthext-n8n:latest

# Rollback capability
docker tag synthext-n8n:v1.0.0-rollback
```

### Skaffold Tag Template
```yaml
build:
  tagPolicy:
    envTemplate:
      template: "{{ .IMAGE_NAME }}:{{ .KUBE_NAMESPACE }}-{{ .BUILD_ID }}"
  artifacts:
    - image: synthext-n8n
      docker:
        dockerfile: Dockerfile
```

## Image Scanning & Security

### Before Pushing to Production

1. **Scan with Trivy**
   ```bash
   # Install Trivy
   brew install aquasecurity/trivy/trivy

   # Scan image
   trivy image synthext-n8n:latest
   ```

2. **Scan with Docker Scout**
   ```bash
   docker scout cves synthext-n8n:latest
   ```

3. **Registry-Native Scanning**
   - ECR: Automatic vulnerability scanning
   - GCR: Binary Authorization
   - ACR: Microsoft Defender for Containers

## Troubleshooting

### Image Pull Errors

```bash
# Check image exists in registry
docker pull your-registry/synthext-n8n:latest

# Check Kubernetes can access registry
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Verify imagePullSecrets
kubectl get secret regcred --output=yaml
```

### Registry Authentication

```bash
# Docker login issues
docker logout && docker login

# Kubernetes secret sync
kubectl delete secret regcred
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<pass>
```

### Skaffold Build Issues

```bash
# Debug Skaffold build
skaffold debug --verbosity=debug

# Check Dockerfile
docker build -t synthext-n8n:test .

# Check docker daemon
docker ps
docker info
```

## Best Practices

✅ **Do:**
- Use specific tags (not `latest` for production)
- Scan images for vulnerabilities
- Store credentials in CI/CD secrets, not in code
- Use private registries for internal images
- Enable image signing/verification
- Implement pull-through cache registries

❌ **Don't:**
- Hardcode registry credentials in Dockerfile
- Push secrets or API keys in images
- Use `latest` tag in production
- Mix public and private images without validation
- Ignore security scanning results
- Use default Docker credentials

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Push to ECR

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: synthext-n8n
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
```

## Next Steps

1. **Choose your registry** based on your infrastructure
2. **Configure authentication** with your Kubernetes cluster
3. **Update skaffold.yaml** with your registry URL
4. **Test locally** with `skaffold dev`
5. **Deploy to staging** with `skaffold run --profile=staging`
6. **Enable image scanning** in your CI/CD pipeline

---

**Last Updated**: 2025-12-27
**Version**: 1.0
