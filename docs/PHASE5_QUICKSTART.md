# Phase 5: API Integrations - Quick Start

Get Mixpost, Twenty CRM, and database persistence running in 2-3 hours.

---

## Prerequisites

✅ Phase 1-4 complete (n8n deployed, workflow running)
✅ LLM configured (Claude/OpenAI/Replicate)
✅ Firecrawl configured
✅ Basic workflow imported and tested

---

## Step 1: Setup Database (15 minutes)

### Create Database Schema

```bash
# Connect to PostgreSQL
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n

# Paste the schema from:
# src/schemas/automarket-database-schema.sql

# Or run directly:
kubectl exec -i deployment/postgres -- psql -U n8n -d n8n < src/schemas/automarket-database-schema.sql

# Verify tables created
SELECT table_name FROM information_schema.tables WHERE table_schema='automarket';
```

### Create n8n Database Connection

In n8n:
1. **Settings** → **Credentials**
2. **New Credential**
3. **Type**: PostgreSQL
4. **Host**: postgres
5. **Port**: 5432
6. **Database**: n8n
7. **Username**: n8n
8. **Password**: (from k8s-secret)
9. **Save**

---

## Step 2: Setup Mixpost (20 minutes)

### 1. Create Mixpost Account

- Go to https://mixpost.app
- Sign up
- Create workspace
- Note the Workspace ID

### 2. Connect Social Media Accounts

In Mixpost:
1. **Settings** → **Integrations**
2. Connect LinkedIn, Twitter, Instagram, Facebook
3. Note the Account IDs for each platform

### 3. Generate API Key

In Mixpost:
1. **Settings** → **API Keys**
2. **Create New Key**
3. Copy the key

### 4. Update Kubernetes Secret

```bash
vi k8s/n8n-secret.yaml

# Add:
MIXPOST_API_KEY: "your_key_here"
MIXPOST_API_URL: "https://api.mixpost.app/v1"
MIXPOST_WORKSPACE_ID: "your_workspace_id"
MIXPOST_LINKEDIN_ACCOUNT_ID: "account_id"
MIXPOST_TWITTER_ACCOUNT_ID: "account_id"
MIXPOST_INSTAGRAM_ACCOUNT_ID: "account_id"
MIXPOST_FACEBOOK_ACCOUNT_ID: "account_id"

# Apply
kubectl apply -f k8s/n8n-secret.yaml
kubectl rollout restart deployment/n8n
```

### 5. Test Mixpost Connection

```bash
curl -X POST https://api.mixpost.app/v1/posts \
  -H "Authorization: Bearer $MIXPOST_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "workspace_id": "'$MIXPOST_WORKSPACE_ID'",
    "posts": [{
      "content": "Test from AutoMarket",
      "accounts": ["'$MIXPOST_TWITTER_ACCOUNT_ID'"],
      "publish_now": false,
      "scheduled_at": "'$(date -d '+1 day' -I)'"
    }]
  }'
```

---

## Step 3: Setup Twenty CRM (20 minutes)

### 1. Create/Access Twenty CRM

Option A: Use existing instance
```bash
# If already deployed
docker-compose ps | grep twenty
```

Option B: Deploy Twenty (if needed)
```bash
# Follow Twenty documentation for deployment
```

### 2. Create API Token

In Twenty:
1. **Settings** → **API & Development**
2. **Create API Key**
3. Copy the token
4. Note the Base URL (e.g., https://crm.example.com)

### 3. Get Workspace ID

In Twenty:
1. **Settings** → **Workspace**
2. Note the Workspace ID

### 4. Update Kubernetes Secret

```bash
vi k8s/n8n-secret.yaml

# Add:
TWENTY_CRM_URL: "https://your-crm.com"
TWENTY_CRM_TOKEN: "your_api_token"
TWENTY_CRM_WORKSPACE_ID: "your_workspace_id"
TWENTY_CMO_USER_ID: "user_id"  # Optional: for assigning tasks

# Apply
kubectl apply -f k8s/n8n-secret.yaml
kubectl rollout restart deployment/n8n
```

### 5. Test Twenty Connection

```bash
curl -X POST $TWENTY_CRM_URL/api/graphql \
  -H "Authorization: Bearer $TWENTY_CRM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ workspaceCurrentUser { id email } }"
  }'
```

---

## Step 4: Add Nodes to n8n Workflow (30 minutes)

### Add Database Insert Node

After "Validate Posts" node:

1. **Node**: Execute Query
2. **Credential**: PostgreSQL (created above)
3. **Query**:
```sql
INSERT INTO automarket.campaigns (
  website_url,
  brand_title,
  brand_description,
  completeness_score,
  is_valid,
  validation_errors,
  validation_warnings,
  status
) VALUES (
  '={{$json.source_url}}',
  '={{$json.brand_analysis?.title || "Unknown"}}',
  '={{$json.brand_analysis?.description || ""}}',
  {{$json.completeness_score}},
  {{$json.is_valid}},
  '{{$json.errors | json}}',
  '{{$json.warnings | json}}',
  '{{$json.is_valid ? "validated" : "review_needed"}}'
)
RETURNING id;
```

### Add Mixpost Node

1. **Node**: HTTP Request
2. **URL**: `https://api.mixpost.app/v1/posts`
3. **Method**: POST
4. **Headers**:
   - Authorization: `Bearer {{$env.MIXPOST_API_KEY}}`
   - Content-Type: `application/json`
5. **Body**:
```json
{
  "workspace_id": "={{$env.MIXPOST_WORKSPACE_ID}}",
  "posts": [
    {
      "content": "={{$json.posts.linkedin}}",
      "accounts": ["={{$env.MIXPOST_LINKEDIN_ACCOUNT_ID}}"],
      "publish_now": false,
      "scheduled_at": "={{$now.add(1, 'day').toISOString()}}"
    },
    {
      "content": "={{$json.posts.twitter}}",
      "accounts": ["={{$env.MIXPOST_TWITTER_ACCOUNT_ID}}"],
      "publish_now": false,
      "scheduled_at": "={{$now.add(1, 'day').toISOString()}}"
    },
    {
      "content": "={{$json.posts.instagram}}",
      "accounts": ["={{$env.MIXPOST_INSTAGRAM_ACCOUNT_ID}}"],
      "publish_now": false,
      "scheduled_at": "={{$now.add(1, 'day').toISOString()}}"
    },
    {
      "content": "={{$json.posts.facebook}}",
      "accounts": ["={{$env.MIXPOST_FACEBOOK_ACCOUNT_ID}}"],
      "publish_now": false,
      "scheduled_at": "={{$now.add(1, 'day').toISOString()}}"
    }
  ]
}
```

### Add Twenty CRM Node

1. **Node**: HTTP Request
2. **URL**: `{{$env.TWENTY_CRM_URL}}/api/graphql`
3. **Method**: POST
4. **Headers**:
   - Authorization: `Bearer {{$env.TWENTY_CRM_TOKEN}}`
   - Content-Type: `application/json`
5. **Body**:
```json
{
  "query": "mutation CreateCampaign($input: CreateCampaignInput!) { createCampaign(input: $input) { id name } }",
  "variables": {
    "input": {
      "name": "AutoMarket: {{$json.brand_analysis?.title}} - {{$now.format('YYYY-MM-DD')}}",
      "description": "Auto-generated social campaign",
      "status": "{{$json.is_valid ? 'active' : 'draft'}}",
      "workspace_id": "={{$env.TWENTY_CRM_WORKSPACE_ID}}"
    }
  }
}
```

### Update Slack Node

Modify the Slack notification to include:
- Database campaign ID
- Mixpost status
- CRM campaign ID

---

## Step 5: Test Phase 5 (30 minutes)

### Test 1: Database Storage

```bash
# Check if campaign was stored
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n -c \
  "SELECT COUNT(*) FROM automarket.campaigns;"
```

### Test 2: Mixpost Scheduling

```bash
# Check Mixpost dashboard
# https://mixpost.app/workspace/posts

# Should see scheduled posts for next 24 hours
```

### Test 3: Twenty CRM Recording

```bash
# Check Twenty CRM
# https://your-crm.com/campaigns

# Should see new campaign records
```

### Test 4: End-to-End Workflow

```bash
# Trigger workflow
WEBHOOK_TOKEN=$(kubectl get secret n8n-secret -o jsonpath='{.data.WEBHOOK_TOKEN}' | base64 -d)

curl -X POST http://localhost:5678/webhook/automarket/webhook \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"website_url": "https://example.com"}'

# Monitor each step in n8n UI
# Check database: psql
# Check Mixpost: https://mixpost.app
# Check CRM: https://crm.example.com
```

---

## Verification Checklist

- [ ] Database schema created
- [ ] PostgreSQL connection working in n8n
- [ ] Mixpost API key configured
- [ ] Social media accounts connected in Mixpost
- [ ] Twenty CRM API token configured
- [ ] All environment variables updated
- [ ] Database insert node created and tested
- [ ] Mixpost scheduling node created and tested
- [ ] Twenty CRM node created and tested
- [ ] Full workflow tested end-to-end
- [ ] Campaign data stored in PostgreSQL
- [ ] Posts visible in Mixpost dashboard
- [ ] Campaign record created in Twenty CRM

---

## Troubleshooting

### "Database connection failed"
```bash
# Check PostgreSQL is running
kubectl get pods | grep postgres

# Check credentials in n8n
# Settings → Credentials → PostgreSQL
```

### "Mixpost authentication error"
```bash
# Verify API key
echo $MIXPOST_API_KEY

# Check in Mixpost settings
# https://mixpost.app/settings/api-keys
```

### "Twenty CRM GraphQL error"
```bash
# Test GraphQL endpoint
curl -X POST $TWENTY_CRM_URL/api/graphql \
  -H "Authorization: Bearer $TWENTY_CRM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "{workspaceCurrentUser{id}}"}'
```

### "Posts not scheduled in Mixpost"
- Check account IDs are correct
- Verify social media authorization is current
- Check scheduled_at date is in future

---

## Next Steps

After Phase 5 is complete:

1. **Monitor Metrics**: Track post performance
2. **Review Posts**: Check quality before publishing
3. **Phase 6**: Add native social media APIs
4. **Phase 7**: End-to-end testing
5. **Phase 8**: Production deployment

---

## Commands Reference

```bash
# Database
kubectl exec -it deployment/postgres -- psql -U n8n -d n8n

# n8n logs
kubectl logs -f deployment/n8n

# Restart n8n
kubectl rollout restart deployment/n8n

# Test LLM
bash scripts/test-llm-connection.sh claude

# View secrets
kubectl get secret n8n-secret -o yaml | grep MIXPOST
```

---

**Time to Complete**: 2-3 hours
**Complexity**: Medium
**Status**: Ready to start
