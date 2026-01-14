# Railway Deployment Guide for AutoMarket OS

This guide explains how to deploy AutoMarket OS to Railway using GitHub Actions for continuous deployment.

## Overview

The deployment setup includes:
- **GitHub Actions workflow** (`.github/workflows/railway-deploy.yml`) - Automated deployment on push
- **Railway configuration** (`railway.json` and `railway.toml`) - Platform-specific settings
- **Dockerfile** - Multi-stage build for n8n with AutoMarket customizations
- **Environment variables** - Managed through Railway dashboard

## Prerequisites

### 1. Railway Account Setup

1. Sign up at [Railway.app](https://railway.app)
2. Create a new project for AutoMarket OS
3. Note your **Project ID** (found in project settings)

### 2. Railway CLI (Optional, for local testing)

```bash
# Install Railway CLI
curl -fsSL https://railway.app/install.sh | sh

# Login to Railway
railway login

# Link to your project
railway link
```

### 3. GitHub Repository Secrets

Add the following secrets to your GitHub repository:
- Go to **Settings** → **Secrets and variables** → **Actions**
- Click **New repository secret**

#### Required Secrets:

| Secret Name | Description | How to Get |
|------------|-------------|------------|
| `RAILWAY_TOKEN` | Railway API token | Railway Dashboard → Account Settings → Tokens → Create Token |
| `RAILWAY_PROJECT_ID` | Your Railway project ID | Railway Project → Settings → Project ID |
| `RAILWAY_ENVIRONMENT` | Deployment environment (optional) | Default: `production`, or use `staging` |

#### Example Secret Values:
```
RAILWAY_TOKEN=xxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
RAILWAY_PROJECT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
RAILWAY_ENVIRONMENT=production
```

## Configuration Files

### 1. railway.json

Located at: `/railway.json`

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "numReplicas": 1,
    "healthcheckPath": "/healthz",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE"
  }
}
```

**Key settings:**
- Uses Dockerfile for building
- Health check endpoint: `/healthz`
- Auto-restart on failure
- Single replica (n8n doesn't support horizontal scaling by default)

### 2. railway.toml

Alternative configuration format:

```toml
[build]
builder = "dockerfile"
dockerfilePath = "Dockerfile"

[deploy]
startCommand = "n8n start"
healthcheckPath = "/healthz"
healthcheckTimeout = 100
restartPolicyType = "ON_FAILURE"
numReplicas = 1
```

## Environment Variables Setup

### Required Environment Variables on Railway

Add these in **Railway Dashboard** → **Your Project** → **Variables**:

#### Core n8n Configuration
```bash
NODE_ENV=production
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=${{RAILWAY_PUBLIC_DOMAIN}}
N8N_INSECURE_FRONTEND_ALLOWLIST=false
EXECUTIONS_PROCESS=main
EXECUTIONS_MODE=regular
GENERIC_TIMEZONE=UTC
N8N_METRICS=true
N8N_LOG_LEVEL=info
```

#### Database Configuration (PostgreSQL from Railway)
```bash
# Railway automatically provides these when you add PostgreSQL service
DATABASE_TYPE=postgresdb
DB_POSTGRESDB_HOST=${{POSTGRES.RAILWAY_PRIVATE_DOMAIN}}
DB_POSTGRESDB_PORT=${{POSTGRES.PORT}}
DB_POSTGRESDB_DATABASE=${{POSTGRES.PGDATABASE}}
DB_POSTGRESDB_USER=${{POSTGRES.PGUSER}}
DB_POSTGRESDB_PASSWORD=${{POSTGRES.PGPASSWORD}}
```

#### API Keys (from your .env)
```bash
FIRECRAWL_API_KEY=your_firecrawl_api_key
OPENAI_API_KEY=your_openai_api_key
CLAUDE_API_KEY=your_claude_api_key
MIXPOST_API_KEY=your_mixpost_api_key
TWENTY_CRM_TOKEN=your_twenty_api_token
# ... add all other API keys from .env.example
```

#### Security
```bash
N8N_ENCRYPTION_KEY=<generate-random-32-char-string>
JWT_SECRET=<generate-random-32-char-string>
```

### Generate Secure Keys

```bash
# Generate encryption key
openssl rand -hex 32

# Generate JWT secret
openssl rand -hex 32
```

## GitHub Actions Workflow

### Workflow File: `.github/workflows/railway-deploy.yml`

**Triggers:**
- Push to `main` branch
- Push to feature branches (e.g., `claude/railway-github-actions-deploy-*`)
- Pull requests to `main`
- Manual trigger via `workflow_dispatch`

**Jobs:**

1. **deploy** - Main deployment job
   - Checks out code
   - Installs Railway CLI
   - Links to Railway project
   - Deploys using `railway up --detach`

2. **verify-deployment** - Health check job
   - Waits for deployment to stabilize
   - Verifies application health

### Deployment Flow

```
GitHub Push
     ↓
GitHub Actions Triggered
     ↓
Checkout Repository
     ↓
Install Railway CLI
     ↓
Link Railway Project
     ↓
Deploy to Railway (railway up)
     ↓
Railway builds Docker image
     ↓
Railway deploys container
     ↓
Health check verification
     ↓
Deployment Complete ✅
```

## Setting Up Railway Project

### Step 1: Create Railway Project

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Click **New Project**
3. Choose **Empty Project**
4. Name it: `automarket-os-production`

### Step 2: Add PostgreSQL Database

1. In your project, click **New Service**
2. Choose **Database** → **PostgreSQL**
3. Railway will automatically provision and configure it
4. Note: Database credentials are auto-injected as environment variables

### Step 3: Configure Environment Variables

1. Click on your main service
2. Go to **Variables** tab
3. Add all required environment variables (see section above)
4. Use `${{POSTGRES.RAILWAY_PRIVATE_DOMAIN}}` for database references

### Step 4: Set Up Domain

1. Go to **Settings** tab
2. Click **Generate Domain** under Public Networking
3. Your app will be available at: `https://your-project.up.railway.app`
4. Optionally, add a custom domain

### Step 5: Enable GitHub Integration (Alternative to GitHub Actions)

**Option A: GitHub Actions (Recommended)**
- Follow the setup in this guide
- More control over deployment process
- Can add custom steps (tests, migrations, etc.)

**Option B: Railway's Built-in GitHub Integration**
1. In Railway project, go to **Settings**
2. Connect GitHub repository
3. Select branch to deploy
4. Railway will auto-deploy on every push

## Deployment Commands

### Manual Deployment (Local)

```bash
# Login to Railway
railway login

# Link to project
railway link

# Deploy
railway up

# View logs
railway logs

# Open in browser
railway open
```

### Automated Deployment (GitHub Actions)

```bash
# Push to main branch
git add .
git commit -m "Your changes"
git push origin main

# GitHub Actions will automatically deploy
# Check status: https://github.com/your-repo/actions
```

## Monitoring & Logs

### View Logs in Railway

1. Go to Railway Dashboard
2. Select your project
3. Click on the service
4. Go to **Deployments** tab
5. Click on latest deployment
6. View **Logs** tab

### View Logs via CLI

```bash
# Real-time logs
railway logs --follow

# Last 100 lines
railway logs --tail 100
```

### Health Check

Your app includes a health check endpoint:

```bash
# Check app health
curl https://your-project.up.railway.app/healthz

# Expected response: 200 OK
```

## Troubleshooting

### Common Issues

#### 1. Deployment Fails with "Failed to link project"

**Solution:**
- Verify `RAILWAY_TOKEN` is valid
- Check `RAILWAY_PROJECT_ID` is correct
- Ensure token has permissions for the project

#### 2. Database Connection Errors

**Solution:**
- Verify PostgreSQL service is running
- Check database environment variables are set
- Use Railway's internal networking: `${{POSTGRES.RAILWAY_PRIVATE_DOMAIN}}`

#### 3. Health Check Fails

**Solution:**
- Ensure n8n is running on port 5678
- Verify `/healthz` endpoint is accessible
- Check firewall/network settings

#### 4. Environment Variables Not Loading

**Solution:**
- Redeploy after adding variables
- Verify variable names match exactly
- Check for syntax errors in variable values

### Getting Help

- **Railway Docs**: https://docs.railway.app
- **Railway Discord**: https://discord.gg/railway
- **n8n Docs**: https://docs.n8n.io
- **GitHub Actions Logs**: Check workflow runs in your repository

## Security Best Practices

### 1. API Keys
- ✅ Store all API keys in Railway environment variables
- ❌ Never commit API keys to Git
- ✅ Use GitHub Secrets for Railway tokens
- ✅ Rotate keys regularly

### 2. Database
- ✅ Use Railway's internal networking for PostgreSQL
- ✅ Enable automatic backups in Railway
- ✅ Use strong passwords (auto-generated by Railway)

### 3. n8n Security
- ✅ Set `N8N_INSECURE_FRONTEND_ALLOWLIST=false` in production
- ✅ Use HTTPS (automatic with Railway)
- ✅ Set strong encryption keys
- ✅ Enable authentication in n8n settings

### 4. Network
- ✅ Use Railway's private networking between services
- ✅ Enable CORS properly for your domain
- ✅ Set up rate limiting in n8n

## Cost Estimation

Railway pricing is based on:
- **Resource usage** (CPU, RAM, Network)
- **Free tier**: $5 of usage credits per month
- **Pro plan**: $20/month + usage

**Estimated costs for AutoMarket OS:**
- **Starter Plan** (1 replica, 512MB RAM): ~$5-10/month
- **Production Plan** (1 replica, 1GB RAM): ~$15-25/month
- **With PostgreSQL**: Add ~$5-10/month

**Note**: Actual costs depend on traffic and resource usage.

## CI/CD Pipeline

### Current Setup

```
Code Push → GitHub → GitHub Actions → Railway → Deployed App
```

### Future Enhancements

Consider adding:
- **Pre-deployment tests** (Jest, integration tests)
- **Database migrations** (automatic schema updates)
- **Slack notifications** (deployment status alerts)
- **Rollback mechanism** (auto-rollback on health check failure)
- **Staging environment** (test before production)

### Example Enhanced Workflow

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Run tests
        run: npm test

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    steps:
      - name: Deploy to staging
        run: railway up --environment staging

  deploy-production:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to production
        run: railway up --environment production
```

## Next Steps

1. ✅ Set up Railway account and project
2. ✅ Add GitHub secrets (RAILWAY_TOKEN, RAILWAY_PROJECT_ID)
3. ✅ Configure environment variables in Railway
4. ✅ Add PostgreSQL database service
5. ✅ Push code to trigger deployment
6. ✅ Verify deployment in Railway dashboard
7. ✅ Import n8n workflows from `/src/workflows/`
8. ✅ Test end-to-end campaign generation
9. ✅ Set up monitoring and alerts
10. ✅ Configure custom domain (optional)

## Support

For deployment issues:
1. Check Railway logs first
2. Review GitHub Actions workflow logs
3. Verify all environment variables are set
4. Consult Railway documentation
5. Open an issue in this repository

---

**Last Updated**: 2026-01-04
**Railway CLI Version**: Latest
**n8n Version**: Latest (from Docker image)
