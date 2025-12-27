# Phase 5 Deployment Guide - Complete Step-by-Step

Deploy AutoMarket OS with full API integrations (Mixpost, Twenty CRM, Database) in 2-3 hours.

---

## Prerequisites Checklist

Before starting Phase 5 deployment, verify Phase 1-4 are complete:

- [ ] Kubernetes cluster running (Docker Desktop, Minikube, EKS, etc.)
- [ ] n8n accessible at http://localhost:5678
- [ ] PostgreSQL pod running
- [ ] Phase 4 workflow imported and tested
- [ ] LLM configured (Claude/OpenAI/Replicate)
- [ ] Firecrawl API key configured
- [ ] Git access to repository

**Estimated Total Time**: 2-3 hours
**Complexity**: Intermediate

---

## Section 1: Database Setup (30 minutes)

### Step 1.1: Create Database Schema

Connect to PostgreSQL and create the AutoMarket schema:

```bash
# Option A: Using kubectl exec
kubectl exec -i deployment/postgres -- psql -U n8n -d n8n < src/schemas/automarket-database-schema.sql

# Option B: Direct connection
psql -h localhost -U n8n -d n8n -f src/schemas/automarket-database-schema.sql

# Option C: Manual - copy/paste in psql
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n
# Then paste entire contents of src/schemas/automarket-database-schema.sql
```

### Step 1.2: Verify Schema Creation

```bash
# Check schema exists
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c \
  "SELECT table_name FROM information_schema.tables WHERE table_schema='automarket' ORDER BY table_name;"

# Expected output:
# api_usage
# campaigns
# execution_logs
# leads
# metrics
# posts
# utm_tracking

echo "✅ Schema creation verified"
```

### Step 1.3: Create Test Data

```bash
# Insert test campaign
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c \
  "INSERT INTO automarket.campaigns (website_url, brand_title, status)
   VALUES ('https://example.com', 'Test Company', 'draft');"

# Verify
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c \
  "SELECT COUNT(*) FROM automarket.campaigns;"

echo "✅ Database ready for data"
```

### Step 1.4: Create n8n PostgreSQL Credential

In n8n UI:

1. **Settings** → **Credentials**
2. **Create New Credential**
3. **Name**: PostgreSQL Automarket
4. **Type**: PostgreSQL
5. **Fill in**:
   - Host: `postgres`
   - Port: `5432`
   - Database: `n8n`
   - Username: `n8n`
   - Password: (from k8s secret or k8s/n8n-secret.yaml)
   - SSL: `false` (for local setup)
6. **Save**

**Test connection**:
- Should show green checkmark
- If fails, verify database is running: `kubectl get pods | grep postgres`

---

## Section 2: Mixpost Setup (30 minutes)

### Step 2.1: Create Mixpost Account & Workspace

1. **Go to** https://mixpost.app
2. **Sign Up** with email
3. **Create Workspace** - Name it "AutoMarket"
4. **Note Workspace ID** from dashboard

```
Workspace ID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Save this for later!
```

### Step 2.2: Connect Social Media Accounts

For each platform, connect your business account:

**LinkedIn**:
1. Settings → Integrations → LinkedIn
2. Click "Connect Account"
3. Authorize with your LinkedIn credentials
4. **Note Account ID**: Copy the ID shown
5. Repeat for company page if different

**Twitter/X**:
1. Settings → Integrations → Twitter
2. Click "Connect Account"
3. Authorize with API credentials
4. **Note Account ID**

**Instagram**:
1. Settings → Integrations → Instagram
2. Click "Connect Account"
3. Authorize with business account
4. **Note Account ID**

**Facebook**:
1. Settings → Integrations → Facebook
2. Click "Connect Account"
3. Authorize with business page
4. **Note Account ID**

### Step 2.3: Generate Mixpost API Key

1. **Settings** → **API Keys**
2. **Create New API Key**
3. **Name**: AutoMarket n8n
4. **Permissions**: Read + Write
5. **Copy API Key** and save securely

```
Format: Typically starts with specific prefix
Store in: k8s/n8n-secret.yaml
```

### Step 2.4: Test Mixpost Connection

```bash
# Set environment variables
export MIXPOST_API_KEY="your_api_key"
export MIXPOST_WORKSPACE_ID="your_workspace_id"
export MIXPOST_TWITTER_ACCOUNT_ID="your_account_id"

# Test API connection
curl -X GET https://api.mixpost.app/v1/workspace \
  -H "Authorization: Bearer $MIXPOST_API_KEY" \
  -H "Content-Type: application/json"

# Expected response: Workspace details
# If error, check API key and workspace ID

echo "✅ Mixpost connection verified"
```

### Step 2.5: Update Kubernetes Secret

```bash
# Edit secret file
vi k8s/n8n-secret.yaml

# Add/update Mixpost configuration:
MIXPOST_API_KEY: "your_api_key_here"
MIXPOST_API_URL: "https://api.mixpost.app/v1"
MIXPOST_WORKSPACE_ID: "your_workspace_id_here"
MIXPOST_LINKEDIN_ACCOUNT_ID: "linkedin_account_id"
MIXPOST_TWITTER_ACCOUNT_ID: "twitter_account_id"
MIXPOST_INSTAGRAM_ACCOUNT_ID: "instagram_account_id"
MIXPOST_FACEBOOK_ACCOUNT_ID: "facebook_account_id"

# Apply the secret
kubectl apply -f k8s/n8n-secret.yaml

# Restart n8n to pick up new variables
kubectl rollout restart deployment/n8n

# Wait for restart to complete
kubectl rollout status deployment/n8n

echo "✅ Mixpost secrets configured"
```

---

## Section 3: Twenty CRM Setup (30 minutes)

### Step 3.1: Access Twenty CRM Instance

**Option A: Using Existing Instance**
```bash
# If already deployed
docker-compose ps | grep twenty

# Get URL and credentials
# Typically: http://localhost:3000 or your custom domain
```

**Option B: Deploy Twenty (if needed)**
```bash
# Follow Twenty documentation
# https://docs.twenty.com/deployment

# Or use Docker:
docker-compose -f twenty-docker-compose.yml up -d
```

### Step 3.2: Create Twenty API Token

1. **Log into Twenty** at your instance URL
2. **Settings** → **API & Development** (or similar)
3. **Create API Key / Token**
4. **Name**: AutoMarket n8n
5. **Permissions**: Create campaigns, create leads, read/write
6. **Copy Token** and save securely

### Step 3.3: Get Workspace Information

```bash
# Method 1: From UI
# Settings → Workspace → Copy Workspace ID and URL

# Method 2: Via API
curl -X POST https://your-twenty-instance.com/api/graphql \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ workspaceCurrentUser { workspace { id name } } }"
  }'

# Save:
# - Twenty CRM URL
# - API Token
# - Workspace ID
```

### Step 3.4: Update Kubernetes Secret

```bash
# Edit secret file
vi k8s/n8n-secret.yaml

# Add/update Twenty configuration:
TWENTY_CRM_URL: "https://your-twenty-instance.com"
TWENTY_CRM_TOKEN: "your_api_token_here"
TWENTY_CRM_WORKSPACE_ID: "your_workspace_id_here"
TWENTY_CMO_USER_ID: "user_id_of_cmo"  # Optional: for task assignment

# Apply the secret
kubectl apply -f k8s/n8n-secret.yaml

# Restart n8n
kubectl rollout restart deployment/n8n
kubectl rollout status deployment/n8n

echo "✅ Twenty CRM secrets configured"
```

### Step 3.5: Test Twenty CRM Connection

```bash
# Test API connection
curl -X POST $TWENTY_CRM_URL/api/graphql \
  -H "Authorization: Bearer $TWENTY_CRM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ workspaceCurrentUser { id email } }"
  }'

# Expected: Returns your user ID and email
# If error, check token and URL

echo "✅ Twenty CRM connection verified"
```

---

## Section 4: n8n Workflow Configuration (45 minutes)

### Step 4.1: Import Complete Workflow

1. **Open n8n UI** at http://localhost:5678
2. **Workflows** in left sidebar
3. **Click Import**
4. **Select File**: `src/workflows/automarket-workflow-with-integrations.json`
5. **Click Import**
6. **Workflow imported successfully** ✅

### Step 4.2: Verify Node Credentials

Each HTTP Request and PostgreSQL node needs credentials:

**PostgreSQL Node** (Database Insert):
1. Click the node
2. **Credential** dropdown
3. Select: "PostgreSQL Automarket" (created in Section 1.4)
4. **Verify connected** ✅

**Mixpost Node** (HTTP Request):
1. Click the node
2. **Headers** section
3. Should show: `Authorization: Bearer {{$env.MIXPOST_API_KEY}}`
4. **Verify** all Mixpost environment variables present ✅

**CRM Node** (HTTP Request):
1. Click the node
2. **Headers** section
3. Should show: `Authorization: Bearer {{$env.TWENTY_CRM_TOKEN}}`
4. **Verify** all CRM environment variables present ✅

### Step 4.3: Test Individual Nodes

Test each critical node:

**Test Firecrawl**:
1. Click "Firecrawl Scraper" node
2. Click "Test Node" (play icon)
3. Should show website content extracted
4. Verify markdown output ✅

**Test LLM**:
1. Click "Call LLM" node
2. Click "Test Node"
3. Should show LLM response with posts
4. Verify JSON structure ✅

**Test Validation**:
1. Click "Validate Posts" node
2. Should show completeness_score and is_valid
3. Verify all 4 posts present ✅

**Test Database**:
1. Click "Database Insert" node
2. Click "Test Node"
3. Should show SQL executed successfully
4. Verify campaign ID returned ✅

**Test Mixpost**:
1. Click "Mixpost Scheduler" node
2. Click "Test Node"
3. Should show posts scheduled
4. Check Mixpost dashboard for scheduled posts ✅

**Test CRM**:
1. Click "CRM Campaign" node
2. Click "Test Node"
3. Should show campaign created in CRM
4. Verify in Twenty CRM dashboard ✅

### Step 4.4: Full Workflow Test

Execute complete workflow:

1. **Click "Save"** to save all configurations
2. **Click "Execute Workflow"**
3. **Monitor each node**:
   - Cron/Webhook trigger
   - Firecrawl extraction
   - LLM generation
   - Validation
   - Parallel: Database, Mixpost, CRM
   - Slack notification
   - Response

### Step 4.5: Verify Results

Check results in each system:

**Database**:
```bash
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c \
  "SELECT COUNT(*) as campaign_count, MAX(created_at) as latest FROM automarket.campaigns;"
```

**Mixpost**:
- Go to https://mixpost.app/workspace/posts
- Should see scheduled posts for next 24 hours

**Twenty CRM**:
- Go to your Twenty instance
- Check Campaigns section
- Should see new campaign record

**Slack**:
- Check #marketing-automation channel
- Should see notification with campaign summary

---

## Section 5: Webhook Testing (30 minutes)

### Step 5.1: Get Webhook Token

```bash
# Extract from secret
WEBHOOK_TOKEN=$(kubectl get secret n8n-secret -o jsonpath='{.data.WEBHOOK_TOKEN}' | base64 -d)

# Verify it's not empty
echo $WEBHOOK_TOKEN

# Save for testing
echo "Webhook Token: $WEBHOOK_TOKEN"
```

### Step 5.2: Get n8n URL

```bash
# For port-forward
N8N_URL="http://localhost:5678"

# For LoadBalancer
N8N_IP=$(kubectl get svc n8n -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
N8N_URL="http://$N8N_IP"

# For NodePort
NODE_PORT=$(kubectl get svc n8n -o jsonpath='{.spec.ports[0].nodePort}')
N8N_URL="http://localhost:$NODE_PORT"

echo "n8n URL: $N8N_URL"
```

### Step 5.3: Test Webhook Trigger

**Example 1: GitHub Website**
```bash
curl -X POST $N8N_URL/webhook/automarket/webhook \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "website_url": "https://github.com"
  }'
```

**Example 2: Stripe Website**
```bash
curl -X POST $N8N_URL/webhook/automarket/webhook \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "website_url": "https://stripe.com"
  }'
```

**Expected Response**:
```json
{
  "success": true,
  "campaign_id": "uuid",
  "completeness_score": 95,
  "posts_generated": 4
}
```

### Step 5.4: Monitor Execution

After webhook trigger:

1. **n8n UI**:
   - Click "Executions" tab
   - Should see latest execution
   - All nodes should be green

2. **Database**:
   ```bash
   kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c \
     "SELECT * FROM automarket.campaigns ORDER BY created_at DESC LIMIT 5;"
   ```

3. **Mixpost**:
   - https://mixpost.app/workspace/posts
   - Should see new scheduled posts

4. **Twenty CRM**:
   - Check Campaigns section
   - Should see new campaign

5. **Slack**:
   - Check #marketing-automation
   - Should see notification

---

## Section 6: Production Configuration (15 minutes)

### Step 6.1: Update Environment Variables

Ensure all production values are set:

```bash
# Check all Phase 5 variables are configured
kubectl get secret n8n-secret -o yaml | grep -E "MIXPOST|TWENTY|WEBHOOK"

# Should show all values (not empty)
```

### Step 6.2: Configure Auto-Publish Settings

**For Manual Review (Recommended)**:
```yaml
# In k8s/n8n-configmap.yaml
CAMPAIGN_AUTO_PUBLISH: "false"
CAMPAIGN_REVIEW_REQUIRED: "true"
CAMPAIGN_DATA_COMPLETENESS_THRESHOLD: "80"

# Apply
kubectl apply -f k8s/n8n-configmap.yaml
kubectl rollout restart deployment/n8n
```

**For Auto-Publish (Production)**:
```yaml
# Only enable after thorough testing
CAMPAIGN_AUTO_PUBLISH: "true"
CAMPAIGN_REVIEW_REQUIRED: "false"
```

### Step 6.3: Set Database Retention

```bash
# Keep campaigns for 1 year
# Monthly maintenance:
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c \
  "DELETE FROM automarket.campaigns
   WHERE created_at < CURRENT_DATE - INTERVAL '1 year';"

# Or set up as cron job in Kubernetes
```

### Step 6.4: Enable Logging

```yaml
# Update n8n-configmap.yaml
LOG_LEVEL: "info"  # or "debug" for troubleshooting

# Apply
kubectl apply -f k8s/n8n-configmap.yaml
kubectl rollout restart deployment/n8n
```

---

## Section 7: Verification Checklist

Complete this checklist to confirm Phase 5 deployment:

### Database ✅
- [ ] Schema created in PostgreSQL
- [ ] 7 tables present (campaigns, posts, metrics, utm_tracking, leads, execution_logs, api_usage)
- [ ] n8n PostgreSQL credential configured
- [ ] Test data inserted and retrieved

### Mixpost ✅
- [ ] Account created
- [ ] API key generated
- [ ] 4 social platforms connected (LinkedIn, Twitter, Instagram, Facebook)
- [ ] All account IDs noted
- [ ] API connection tested
- [ ] Kubernetes secret updated

### Twenty CRM ✅
- [ ] Instance accessible
- [ ] API token created
- [ ] Workspace ID noted
- [ ] GraphQL API tested
- [ ] Kubernetes secret updated

### n8n Workflow ✅
- [ ] Workflow imported successfully
- [ ] All nodes visible and connected
- [ ] PostgreSQL credential configured
- [ ] Environment variables present in all HTTP nodes
- [ ] Each node tested individually
- [ ] Full workflow executed successfully

### Results Verification ✅
- [ ] Campaign stored in database
- [ ] Posts visible in Mixpost (scheduled)
- [ ] Campaign record created in Twenty CRM
- [ ] Slack notification received
- [ ] No errors in execution logs

### Webhook Testing ✅
- [ ] Webhook token obtained
- [ ] Webhook trigger tested with sample website
- [ ] Campaign created from webhook
- [ ] All systems updated (database, Mixpost, CRM, Slack)

### Production Settings ✅
- [ ] All secrets configured (no placeholder values)
- [ ] Auto-publish settings configured
- [ ] Logging configured
- [ ] Database retention policy set
- [ ] Backup strategy planned

---

## Section 8: Troubleshooting

### "Database connection failed in n8n"

```bash
# Check PostgreSQL is running
kubectl get pods | grep postgres

# Check credentials in n8n
# Settings → Credentials → PostgreSQL
# Verify: Host, Port, Database, Username, Password

# Test connection from pod
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c "SELECT 1;"
```

### "Mixpost API key invalid"

```bash
# Verify key in secret
kubectl get secret n8n-secret -o jsonpath='{.data.MIXPOST_API_KEY}' | base64 -d

# Test API directly
curl -X GET https://api.mixpost.app/v1/workspace \
  -H "Authorization: Bearer $(kubectl get secret n8n-secret -o jsonpath='{.data.MIXPOST_API_KEY}' | base64 -d)"

# If fails: regenerate key in Mixpost dashboard
```

### "Twenty CRM GraphQL error"

```bash
# Test GraphQL endpoint
TWENTY_URL=$(kubectl get secret n8n-secret -o jsonpath='{.data.TWENTY_CRM_URL}' | base64 -d)
TWENTY_TOKEN=$(kubectl get secret n8n-secret -o jsonpath='{.data.TWENTY_CRM_TOKEN}' | base64 -d)

curl -X POST $TWENTY_URL/api/graphql \
  -H "Authorization: Bearer $TWENTY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{workspaceCurrentUser{id}}"}'

# If fails: check token expiration and permissions
```

### "Posts not showing in Mixpost"

```bash
# Check account IDs are correct
kubectl get secret n8n-secret -o yaml | grep MIXPOST_.*_ACCOUNT_ID

# Verify accounts are connected in Mixpost Settings → Integrations

# Check scheduled_at date is in future
# Should be: $now.add(1, 'day')
```

### "Campaign not created in CRM"

```bash
# Check workspace ID is correct
kubectl get secret n8n-secret -o jsonpath='{.data.TWENTY_CRM_WORKSPACE_ID}' | base64 -d

# Verify GraphQL mutation syntax
# Check error message in n8n execution logs
```

---

## Section 9: Next Steps

After Phase 5 deployment verification:

1. **Monitor Real Usage**:
   - Run workflow on real websites
   - Check campaign quality
   - Adjust guardrails if needed

2. **Team Training**:
   - Show team how to review posts in Mixpost
   - Explain CRM campaign tracking
   - Set up approval workflows

3. **Phase 6 Planning**:
   - Prepare for native social media APIs
   - Plan direct platform integrations
   - Discuss API limitations vs Mixpost

4. **Production Preparation**:
   - Set up monitoring and alerting
   - Plan backup strategy
   - Document operational procedures

---

## Quick Reference Commands

```bash
# Check all components running
kubectl get pods

# View n8n logs
kubectl logs -f deployment/n8n

# View PostgreSQL logs
kubectl logs -f deployment/postgres

# Check secrets are set
kubectl get secret n8n-secret -o yaml

# Restart services
kubectl rollout restart deployment/n8n
kubectl rollout restart deployment/postgres

# Database commands
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n

# Test LLM
bash scripts/test-llm-connection.sh claude

# Port forward
kubectl port-forward svc/n8n 5678:80
```

---

## Success Indicators

✅ **Phase 5 is successfully deployed when**:

1. All nodes in workflow execute without errors
2. Campaign data stored in PostgreSQL
3. Posts scheduled in Mixpost for 24 hours
4. Campaign record created in Twenty CRM
5. Slack notification received with summary
6. Webhook trigger works from curl
7. All environment variables configured
8. Database backups planned

---

**Estimated Total Time**: 2-3 hours
**Difficulty**: Intermediate
**Status**: Ready for Phase 6 after completion

---

**Last Updated**: 2025-12-27
**Version**: 1.0
