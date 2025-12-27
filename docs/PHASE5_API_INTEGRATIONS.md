# Phase 5: API Integrations - Mixpost, Twenty CRM, Database

Complete guide for integrating Mixpost (social scheduling), Twenty CRM (campaign tracking), and database persistence into AutoMarket OS.

---

## Phase 5 Overview

Phase 5 extends the n8n workflow to add:

1. **Mixpost Integration**: Schedule posts to LinkedIn, Twitter, Instagram, Facebook
2. **Twenty CRM Integration**: Track campaigns and leads in CRM
3. **Database Persistence**: Store campaign data in PostgreSQL
4. **Updated Workflow**: Connect all components end-to-end

```
Previous Flow (Phase 4):
Website → Firecrawl → LLM → Validate → Slack → Response

New Flow (Phase 5):
Website → Firecrawl → LLM → Validate → Database ↘
                                                  → Mixpost (schedule posts)
                                                  → Twenty CRM (create campaign)
                                                  → Slack (notify team)
                                                  → Response
```

---

## 1. Mixpost Integration

### What is Mixpost?

Mixpost is a multi-platform social media scheduling tool that allows scheduling posts to:
- LinkedIn
- Twitter/X
- Instagram
- Facebook
- TikTok
- YouTube

### Setup: Get Mixpost API Credentials

1. **Create Mixpost Account**
   - Go to https://mixpost.app
   - Sign up or log in
   - Workspace ID will be visible in settings

2. **Create API Key**
   - Settings → API Keys
   - Create new API key
   - Copy the key (format: starts with specific prefix)

3. **Connect Social Media Accounts**
   - Settings → Integrations
   - Connect each platform (LinkedIn, Twitter, Instagram, Facebook)
   - Authorize with your account credentials
   - Note the account IDs

4. **Update Kubernetes Secret**
   ```bash
   vi k8s/n8n-secret.yaml

   # Add/update:
   MIXPOST_API_KEY: "your_mixpost_api_key"
   MIXPOST_API_URL: "https://api.mixpost.app/v1"
   MIXPOST_WORKSPACE_ID: "your_workspace_id"

   # Also update with account IDs:
   MIXPOST_LINKEDIN_ACCOUNT_ID: "your_account_id"
   MIXPOST_TWITTER_ACCOUNT_ID: "your_account_id"
   MIXPOST_INSTAGRAM_ACCOUNT_ID: "your_account_id"
   MIXPOST_FACEBOOK_ACCOUNT_ID: "your_account_id"

   kubectl apply -f k8s/n8n-secret.yaml
   kubectl rollout restart deployment/n8n
   ```

### Mixpost API Integration in n8n

#### Node: Schedule Posts to Mixpost

**Type**: HTTP Request

**Configuration**:
```json
{
  "url": "https://api.mixpost.app/v1/posts",
  "method": "POST",
  "authentication": "genericCredentialType",
  "headers": {
    "Authorization": "Bearer {{$env.MIXPOST_API_KEY}}",
    "Content-Type": "application/json"
  },
  "body": {
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
}
```

#### Response Parsing

```javascript
// Function node after Mixpost call
const response = items[0].json;

if (!response.success && response.error) {
  throw new Error(`Mixpost error: ${response.error.message}`);
}

return {
  mixpost_status: 'posts_scheduled',
  posts_scheduled: response.data?.posts?.length || 4,
  scheduled_at: $now.add(1, 'day').toISOString(),
  mixpost_post_ids: response.data?.posts?.map(p => p.id) || []
};
```

### Mixpost Configuration Tips

**Manual Review Mode** (Recommended):
```json
{
  "publish_now": false,
  "scheduled_at": "{{$now.add(1, 'day').toISOString()}}"
}
```
Posts are staged in Mixpost for 24-hour review before auto-publishing.

**Auto-Publish Mode**:
```json
{
  "publish_now": true
}
```
Posts publish immediately (use with caution - requires thorough validation).

### Mixpost Pricing

| Plan | Cost | Limit | Best For |
|------|------|-------|----------|
| **Free** | $0 | 10 posts/month | Testing |
| **Pro** | $19/month | Unlimited | Production |
| **Team** | $49/month | Unlimited + team | Agency |

---

## 2. Twenty CRM Integration

### What is Twenty CRM?

Twenty is an open-source, self-hosted CRM that tracks:
- Campaigns
- Leads
- Opportunities
- Customers
- UTM tracking

### Setup: Get Twenty CRM Credentials

1. **Deploy Twenty CRM** (if not already deployed)
   ```bash
   # Docker compose example
   docker-compose up -d

   # Or use your existing Twenty instance
   ```

2. **Create API Token**
   - Log into Twenty
   - Settings → API Keys
   - Create new API key
   - Copy the token

3. **Get Workspace ID**
   - Settings → Workspace
   - Note the Workspace ID
   - Note the Base URL (e.g., https://crm.example.com)

4. **Update Kubernetes Secret**
   ```bash
   vi k8s/n8n-secret.yaml

   # Add/update:
   TWENTY_CRM_URL: "https://your-twenty-instance.com"
   TWENTY_CRM_TOKEN: "your_api_token"
   TWENTY_CRM_WORKSPACE_ID: "your_workspace_id"
   TWENTY_CMO_USER_ID: "user_id_of_cmo"  # For assigning tasks

   kubectl apply -f k8s/n8n-secret.yaml
   kubectl rollout restart deployment/n8n
   ```

### Twenty CRM Integration in n8n

#### Node: Create Campaign in CRM

**Type**: HTTP Request (GraphQL)

**Configuration**:
```json
{
  "url": "={{$env.TWENTY_CRM_URL}}/api/graphql",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.TWENTY_CRM_TOKEN}}",
    "Content-Type": "application/json"
  },
  "body": {
    "query": "mutation CreateCampaign($input: CreateCampaignInput!) { createCampaign(input: $input) { id name status } }",
    "variables": {
      "input": {
        "name": "AutoMarket: {{$json.brand_analysis.title}} - {{$now.format('YYYY-MM-DD')}}",
        "description": "Auto-generated multi-channel social media campaign",
        "status": "{{$json.is_valid ? 'active' : 'draft'}}",
        "campaign_type": "social_media",
        "source_url": "={{$json.source_url}}",
        "workspace_id": "={{$env.TWENTY_CRM_WORKSPACE_ID}}"
      }
    }
  }
}
```

#### Node: Create Campaign Posts in CRM

Track individual posts:
```javascript
// Function node
const campaign = items[0].json.data.createCampaign;
const posts = items[1].json.posts;

const postRecords = [
  {
    platform: 'linkedin',
    content: posts.linkedin,
    character_count: posts.linkedin.length,
    campaign_id: campaign.id
  },
  {
    platform: 'twitter',
    content: posts.twitter,
    character_count: posts.twitter.length,
    campaign_id: campaign.id
  },
  {
    platform: 'instagram',
    content: posts.instagram,
    character_count: posts.instagram.length,
    campaign_id: campaign.id
  },
  {
    platform: 'facebook',
    content: posts.facebook,
    character_count: posts.facebook.length,
    campaign_id: campaign.id
  }
];

return {
  campaign_id: campaign.id,
  posts_to_create: postRecords
};
```

#### Node: Create UTM Tracking Records

```json
{
  "url": "={{$env.TWENTY_CRM_URL}}/api/graphql",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.TWENTY_CRM_TOKEN}}",
    "Content-Type": "application/json"
  },
  "body": {
    "query": "mutation CreateUTMRecord($input: CreateUTMInput!) { createUTM(input: $input) { id } }",
    "variables": {
      "input": {
        "campaign_id": "={{$json.campaign_id}}",
        "utm_source": "automarket",
        "utm_medium": "social",
        "utm_campaign": "={{$json.campaign_id}}",
        "platforms": ["linkedin", "twitter", "instagram", "facebook"],
        "workspace_id": "={{$env.TWENTY_CRM_WORKSPACE_ID}}"
      }
    }
  }
}
```

### Twenty CRM Schema

The CRM will track:

**Campaign Object**:
```json
{
  "id": "uuid",
  "name": "Campaign name",
  "description": "Description",
  "status": "active|draft|completed",
  "campaign_type": "social_media",
  "source_url": "website_url",
  "created_at": "ISO timestamp",
  "posts": [
    {
      "platform": "linkedin|twitter|instagram|facebook",
      "content": "Post content",
      "character_count": 280,
      "scheduled_at": "ISO timestamp"
    }
  ]
}
```

**UTM Tracking**:
```json
{
  "utm_source": "automarket",
  "utm_medium": "social",
  "utm_campaign": "campaign_id",
  "utm_content": "post_id",
  "platforms": ["linkedin", "twitter", "instagram", "facebook"]
}
```

---

## 3. Database Persistence

### Database Schema

Create PostgreSQL tables for campaign storage:

```sql
-- Create schema
CREATE SCHEMA IF NOT EXISTS automarket;

-- Campaigns table
CREATE TABLE automarket.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  website_url TEXT NOT NULL,
  brand_title TEXT,
  brand_description TEXT,
  status VARCHAR(50) DEFAULT 'draft',
  completeness_score INT CHECK (completeness_score >= 0 AND completeness_score <= 100),
  validation_errors TEXT[],
  validation_warnings TEXT[],
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_status (status),
  INDEX idx_created_at (created_at)
);

-- Posts table
CREATE TABLE automarket.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES automarket.campaigns(id) ON DELETE CASCADE,
  platform VARCHAR(50) NOT NULL CHECK (platform IN ('linkedin', 'twitter', 'instagram', 'facebook')),
  content TEXT NOT NULL,
  character_count INT,
  scheduled_at TIMESTAMP,
  published_at TIMESTAMP,
  status VARCHAR(50) DEFAULT 'draft',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_campaign_id (campaign_id),
  INDEX idx_platform (platform),
  INDEX idx_status (status)
);

-- Metrics table
CREATE TABLE automarket.metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES automarket.posts(id) ON DELETE CASCADE,
  metric_name VARCHAR(100),
  metric_value DECIMAL(10, 2),
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- UTM Parameters table
CREATE TABLE automarket.utm_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES automarket.campaigns(id) ON DELETE CASCADE,
  utm_source VARCHAR(100),
  utm_medium VARCHAR(100),
  utm_campaign VARCHAR(100),
  utm_content VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Database Node in n8n

**Node: Insert Campaign**

**Type**: Execute Query

**Query**:
```sql
INSERT INTO automarket.campaigns (
  website_url,
  brand_title,
  brand_description,
  status,
  completeness_score,
  validation_errors,
  validation_warnings
) VALUES (
  {{$json.source_url}},
  {{$json.brand_analysis.title}},
  {{$json.brand_analysis.description}},
  {{$json.is_valid ? 'validated' : 'review_needed'}},
  {{$json.completeness_score}},
  {{JSON.stringify($json.errors)}},
  {{JSON.stringify($json.warnings)}}
)
RETURNING id, created_at;
```

**Node: Insert Posts**

```sql
INSERT INTO automarket.posts (
  campaign_id,
  platform,
  content,
  character_count,
  status
) VALUES
  ({{$json.campaign_id}}, 'linkedin', {{$json.posts.linkedin}}, {{$json.posts.linkedin.length}}, 'draft'),
  ({{$json.campaign_id}}, 'twitter', {{$json.posts.twitter}}, {{$json.posts.twitter.length}}, 'draft'),
  ({{$json.campaign_id}}, 'instagram', {{$json.posts.instagram}}, {{$json.posts.instagram.length}}, 'draft'),
  ({{$json.campaign_id}}, 'facebook', {{$json.posts.facebook}}, {{$json.posts.facebook.length}}, 'draft')
RETURNING id, platform, status;
```

---

## Integration Flow Summary

Updated workflow with all integrations:

```
1. Trigger (Cron/Webhook)
   ↓
2. Firecrawl (extract content)
   ↓
3. LLM (generate posts)
   ↓
4. Validate (check quality)
   ↓
5. Database INSERT (save campaign)
   ↓
6. Mixpost POST (schedule posts)
   ↓
7. Twenty CRM POST (create campaign record)
   ↓
8. Slack NOTIFY (alert team)
   ↓
9. Response (success)
```

---

## Pricing Summary

### Phase 5 API Costs

| Service | Cost/Month | Volume | Estimate |
|---------|-----------|--------|----------|
| Mixpost | $19 | Unlimited | $19 |
| Twenty CRM | Free (self-hosted) | Unlimited | $0 |
| PostgreSQL | Included | Unlimited | $0 |
| **Total** | | | **$19** |

Total Phase 5 cost: $19/month for Mixpost (Twenty CRM is self-hosted and free)

---

## Testing Phase 5

### Test 1: Mixpost Connection
```bash
curl -X POST https://api.mixpost.app/v1/posts \
  -H "Authorization: Bearer $MIXPOST_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "workspace_id": "'$MIXPOST_WORKSPACE_ID'",
    "posts": [{
      "content": "Test post from AutoMarket",
      "accounts": ["'$MIXPOST_TWITTER_ACCOUNT_ID'"],
      "publish_now": false
    }]
  }'
```

### Test 2: Twenty CRM Connection
```bash
curl -X POST $TWENTY_CRM_URL/api/graphql \
  -H "Authorization: Bearer $TWENTY_CRM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query { campaigns { edges { node { id name } } } }"
  }'
```

### Test 3: Database Connection
```bash
# From inside n8n pod
kubectl exec -it deployment/n8n -- psql \
  -h postgres \
  -U n8n \
  -d n8n \
  -c "SELECT COUNT(*) FROM automarket.campaigns;"
```

---

## Security Considerations

✅ **API Keys**: Store in Kubernetes Secrets
✅ **Database**: Use strong passwords, restrict network access
✅ **Credentials**: Never log API keys or tokens
✅ **Validation**: Validate all API responses
✅ **Rate Limiting**: Respect API rate limits
✅ **Encryption**: Use HTTPS for all connections

---

## Performance Tips

⚡ **Batch Processing**: Insert multiple posts at once
⚡ **Async**: Mixpost accepts async requests (fire and forget)
⚡ **Caching**: Cache campaign IDs to avoid duplicates
⚡ **Timeout**: Set appropriate timeouts for each API call

---

## Troubleshooting

### Issue: "Invalid Mixpost API Key"
- Verify key in Twenty workspace settings
- Check key hasn't expired
- Ensure account is active and paid

### Issue: "Twenty CRM GraphQL Error"
- Check GraphQL syntax
- Verify workspace ID is correct
- Test API token with GraphQL playground

### Issue: "Database Connection Failed"
- Verify PostgreSQL pod is running
- Check network connectivity
- Verify schema exists

---

## Next Phase (Phase 6)

Phase 6 will add:
- LinkedIn API integration
- Twitter API integration
- Instagram API integration
- Facebook API integration
- Native platform features

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Time to Implement**: 3-4 hours
