# Phase 4: n8n Workflow Creation

Complete guide for creating the AutoMarket OS n8n workflow that orchestrates content generation, validation, and publishing.

---

## Workflow Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AutoMarket OS n8n Workflow                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 1. TRIGGER: Cron (hourly) or Webhook (on-demand)             │   │
│  │    Input: Website URL, brand context                          │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 2. FIRECRAWL: Extract website content as markdown             │   │
│  │    Output: Clean markdown, metadata, title, description       │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 3. PREPARE: Combine markdown + master prompt                  │   │
│  │    Create system message with brand guidelines                │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 4. LLM: Call Claude/OpenAI/Replicate                          │   │
│  │    Generate platform-specific posts (LinkedIn, Twitter, etc)  │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 5. PARSE: Extract JSON from LLM response                      │   │
│  │    Parse LinkedIn, Twitter, Instagram, Facebook posts         │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 6. VALIDATE: Check guardrails and content quality             │   │
│  │    ✓ No hallucinations  ✓ Brand voice  ✓ Platform rules      │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 7. DATABASE: Store campaign draft in PostgreSQL               │   │
│  │    Save for manual review or auto-publish                     │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 8. MIXPOST: Schedule posts to social media (or stage)         │   │
│  │    Manual review mode: Stage for 24h review + 1-click publish │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 9. CRM: Create campaign tracking records in Twenty CRM        │   │
│  │    Track UTM parameters, lead sources, expected metrics       │   │
│  └─────────────────────┬────────────────────────────────────────┘   │
│                        ↓                                              │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │ 10. SLACK: Send team notification                             │   │
│  │    Alert with campaign summary, posts, and metrics            │   │
│  └────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Workflow Node Breakdown

### Node 1: Trigger (Cron or Webhook)

**Purpose**: Start workflow on schedule or on-demand

**Type**: Cron or Webhook node

**Cron Configuration** (Hourly):
```
Rule: Every hour at minute 0
Expression: 0 * * * *
Timezone: UTC
```

**Webhook Configuration** (On-demand):
```
HTTP Method: POST
Path: /automarket/campaign
Authentication: Bearer token (from env.WEBHOOK_TOKEN)
```

**Output**:
```json
{
  "website_url": "https://example.com",
  "campaign_mode": "manual_review",
  "triggered_by": "webhook"
}
```

---

### Node 2: Firecrawl HTTP Request

**Purpose**: Extract website content as clean markdown

**Type**: HTTP Request

**Configuration**:
```json
{
  "url": "https://api.firecrawl.dev/v0/scrape",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.FIRECRAWL_API_KEY}}",
    "Content-Type": "application/json"
  },
  "body": {
    "url": "{{$node['trigger'].json.website_url}}",
    "formats": ["markdown"],
    "onlyMainContent": true,
    "timeout": 15000
  }
}
```

**Output**:
```json
{
  "success": true,
  "data": {
    "markdown": "# Company Name\n\nCompany description...",
    "metadata": {
      "title": "Company Name",
      "description": "Company tagline",
      "language": "en"
    }
  }
}
```

---

### Node 3: Prepare Prompt

**Purpose**: Combine website content with master prompt

**Type**: Function Node (JavaScript)

**Code**:
```javascript
// Load master prompt from file system or hardcoded
const masterPrompt = `You are an expert CMO specializing in multi-channel marketing...`;

const websiteContent = items[0].json.data.markdown;
const metadata = items[0].json.data.metadata;

return {
  system_prompt: masterPrompt,
  website_content: websiteContent,
  brand_title: metadata.title,
  brand_description: metadata.description,
  timestamp: new Date().toISOString()
};
```

---

### Node 4: LLM Call (Choose One)

**Type**: HTTP Request

#### Option A: Claude (Recommended)
```json
{
  "url": "https://api.anthropic.com/v1/messages",
  "method": "POST",
  "headers": {
    "x-api-key": "{{$env.CLAUDE_API_KEY}}",
    "anthropic-version": "2023-06-01",
    "content-type": "application/json"
  },
  "body": {
    "model": "{{$env.AI_MODEL}}",
    "max_tokens": 4096,
    "system": "{{$node['prepare'].json.system_prompt}}",
    "messages": [
      {
        "role": "user",
        "content": "Generate marketing posts from this website:\n\n{{$node['prepare'].json.website_content}}\n\nReturn as JSON with keys: linkedin, twitter, instagram, facebook"
      }
    ]
  }
}
```

#### Option B: OpenAI
```json
{
  "url": "https://api.openai.com/v1/chat/completions",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.OPENAI_API_KEY}}",
    "Content-Type": "application/json"
  },
  "body": {
    "model": "{{$env.AI_MODEL}}",
    "temperature": 0.8,
    "max_tokens": 4096,
    "messages": [
      {
        "role": "system",
        "content": "{{$node['prepare'].json.system_prompt}}"
      },
      {
        "role": "user",
        "content": "Generate marketing posts from this website:\n\n{{$node['prepare'].json.website_content}}"
      }
    ]
  }
}
```

---

### Node 5: Parse LLM Response

**Purpose**: Extract JSON posts from LLM output

**Type**: Function Node

**Code**:
```javascript
const response = items[0].json;

// Handle different response formats
let content = '';
if (response.content && response.content[0]) {
  // Claude format
  content = response.content[0].text;
} else if (response.choices && response.choices[0]) {
  // OpenAI format
  content = response.choices[0].message.content;
}

// Extract JSON from response
const jsonMatch = content.match(/\{[\s\S]*\}/);
if (!jsonMatch) {
  throw new Error('Could not extract JSON from LLM response');
}

const posts = JSON.parse(jsonMatch[0]);

return {
  posts: posts,
  linkedin_post: posts.linkedin || '',
  twitter_post: posts.twitter || '',
  instagram_post: posts.instagram || '',
  facebook_post: posts.facebook || '',
  raw_response: content
};
```

---

### Node 6: Validate Posts

**Purpose**: Check guardrails, brand voice, platform constraints

**Type**: Function Node

**Code**:
```javascript
const posts = items[0].json.posts;
const banList = [
  "in today's fast-paced world",
  "game-changer",
  "synergy",
  "leverage",
  "paradigm shift"
];

const errors = [];
const warnings = [];

// Check each post
Object.keys(posts).forEach(platform => {
  const post = posts[platform];
  if (!post) return;

  // Check for banned phrases
  const lowerPost = post.toLowerCase();
  banList.forEach(phrase => {
    if (lowerPost.includes(phrase)) {
      errors.push(`${platform}: Contains banned phrase: "${phrase}"`);
    }
  });

  // Check character limits
  const limits = {
    linkedin: 3000,
    twitter: 280,
    instagram: 2200,
    facebook: 63206
  };

  if (post.length > limits[platform]) {
    warnings.push(`${platform}: Exceeds recommended length (${post.length}/${limits[platform]})`);
  }

  // Check for minimum content
  if (post.length < 20) {
    errors.push(`${platform}: Post too short (${post.length} chars)`);
  }
});

const isValid = errors.length === 0;
const completenessScore = Math.round(((Object.keys(posts).length - errors.length) / Object.keys(posts).length) * 100);

return {
  is_valid: isValid,
  completeness_score: completenessScore,
  errors: errors,
  warnings: warnings,
  can_publish: completenessScore >= 80,
  posts: posts
};
```

---

### Node 7: Store in Database

**Purpose**: Save campaign draft for review

**Type**: Execute Query (PostgreSQL)

**Query**:
```sql
INSERT INTO campaigns (
  id,
  website_url,
  brand_title,
  linkedin_post,
  twitter_post,
  instagram_post,
  facebook_post,
  validation_status,
  completeness_score,
  created_at,
  status
) VALUES (
  {{$node['trigger'].json.campaign_id || uuid()}},
  {{$node['trigger'].json.website_url}},
  {{$node['prepare'].json.brand_title}},
  {{$node['validate'].json.posts.linkedin}},
  {{$node['validate'].json.posts.twitter}},
  {{$node['validate'].json.posts.instagram}},
  {{$node['validate'].json.posts.facebook}},
  {{$node['validate'].json.is_valid}},
  {{$node['validate'].json.completeness_score}},
  NOW(),
  'draft'
) RETURNING id;
```

---

### Node 8: Schedule to Mixpost

**Purpose**: Push posts to Mixpost for scheduling

**Type**: HTTP Request

**Configuration**:
```json
{
  "url": "https://api.mixpost.app/v1/posts",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.MIXPOST_API_KEY}}",
    "Content-Type": "application/json"
  },
  "body": {
    "workspace_id": "{{$env.MIXPOST_WORKSPACE_ID}}",
    "content": "{{$node['validate'].json.posts}}",
    "schedule_mode": "{{$node['trigger'].json.campaign_mode}}",
    "scheduled_at": "{{$now.add(1, 'day').format('YYYY-MM-DD HH:mm:ss')}}",
    "utm_tracking": true
  }
}
```

---

### Node 9: Create CRM Campaign

**Purpose**: Track campaign in Twenty CRM

**Type**: HTTP Request

**Configuration**:
```json
{
  "url": "{{$env.TWENTY_CRM_URL}}/api/graphql",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.TWENTY_CRM_TOKEN}}",
    "Content-Type": "application/json"
  },
  "body": {
    "query": "mutation CreateCampaign($input: CreateCampaignInput!) { createCampaign(input: $input) { id name status } }",
    "variables": {
      "input": {
        "name": "{{$node['prepare'].json.brand_title}} - {{$now.format('YYYY-MM-DD')}}",
        "description": "Auto-generated social media campaign",
        "source": "automarket",
        "utm_source": "automarket",
        "utm_campaign": "{{$node['trigger'].json.campaign_id}}",
        "status": "active"
      }
    }
  }
}
```

---

### Node 10: Slack Notification

**Purpose**: Alert team about new campaign

**Type**: Slack Node or HTTP Request

**Slack Message**:
```json
{
  "text": "🚀 New AutoMarket Campaign Generated",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*AutoMarket Campaign Created*\n\n🌐 *Website:* {{$node['trigger'].json.website_url}}\n✅ *Status:* {{$node['validate'].json.is_valid ? 'Valid' : 'Needs Review'}}\n📊 *Completeness:* {{$node['validate'].json.completeness_score}}%"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "📱 *LinkedIn:*\n```{{$node['validate'].json.posts.linkedin}}```"
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "🐦 *Twitter:*\n```{{$node['validate'].json.posts.twitter}}```"
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": {
            "type": "plain_text",
            "text": "Review in n8n"
          },
          "url": "http://localhost:5678"
        },
        {
          "type": "button",
          "text": {
            "type": "plain_text",
            "text": "View in Mixpost"
          },
          "url": "https://mixpost.app"
        }
      ]
    }
  ]
}
```

---

## Workflow Conditional Logic

### Decision: Is Content Valid?

```
If completeness_score >= 80:
  → Auto-publish (optional - requires CAMPAIGN_AUTO_PUBLISH=true)
  → OR stage in Mixpost for manual review (recommended)

Else:
  → Send to review queue
  → Flag for CMO approval
  → Notify team in Slack
```

---

## Error Handling Strategy

### Retry Logic

```javascript
// Add retry node after HTTP requests
const MAX_RETRIES = 3;
const RETRY_DELAY = 5000; // 5 seconds

if (items[0].executionStatus === 'error') {
  if (items[0].retryCount < MAX_RETRIES) {
    // Retry after delay
    return {
      status: 'retrying',
      retry_count: items[0].retryCount + 1,
      next_attempt: Date.now() + RETRY_DELAY
    };
  } else {
    // Give up, send alert
    return {
      status: 'failed',
      error: items[0].error,
      notify_slack: true
    };
  }
}
```

### Error Notifications

```javascript
// Send detailed error to Slack
const errorMessage = {
  text: `❌ AutoMarket Campaign Failed`,
  blocks: [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": `*Error Details*\n\`\`\`${items[0].error.message}\`\`\``
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": `*Website:* ${items[0].json.website_url}\n*Timestamp:* ${new Date().toISOString()}`
      }
    }
  ]
};
```

---

## Environment Variables Required

```bash
# LLM (choose one)
CLAUDE_API_KEY=sk-ant-...          # OR
OPENAI_API_KEY=sk-...              # OR
REPLICATE_API_TOKEN=r8_...

# Web Scraping
FIRECRAWL_API_KEY=fc_...

# Publishing
MIXPOST_API_KEY=...
MIXPOST_WORKSPACE_ID=...

# CRM
TWENTY_CRM_URL=...
TWENTY_CRM_TOKEN=...

# Notifications
SLACK_WEBHOOK_URL=...
SLACK_BOT_TOKEN=...

# Configuration
AI_MODEL=claude-opus-4-5-20251101
CAMPAIGN_AUTO_PUBLISH=false
CAMPAIGN_REVIEW_REQUIRED=true
CAMPAIGN_DATA_COMPLETENESS_THRESHOLD=80
WEBHOOK_TOKEN=...
```

---

## Workflow Testing

### Test Scenario 1: Manual Website

1. Create webhook node
2. Test with curl:
```bash
curl -X POST http://localhost:5678/webhook/automarket/campaign \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "website_url": "https://example.com",
    "campaign_mode": "manual_review"
  }'
```

3. Verify each node output
4. Check Slack notification
5. Review posts in Mixpost

### Test Scenario 2: Full Workflow

1. Run cron trigger
2. Monitor workflow execution
3. Check database for campaign record
4. Verify CRM campaign created
5. Validate Slack message received
6. Check Mixpost staging

---

## Performance Optimization

### Parallel Node Execution

Where possible, run nodes in parallel:
- Database insert and CRM creation can run simultaneously
- Slack notification doesn't need to block workflow completion
- Mixpost scheduling can be async

### Caching

Cache LLM responses to avoid re-calling on retry:
```javascript
// Store in workflow state
$workflowData.llm_cache = {
  website_url: items[0].json.url,
  response: response,
  timestamp: Date.now(),
  ttl: 3600000 // 1 hour
};
```

### Rate Limiting

Implement delay between Firecrawl requests (free tier: 5 req/min):
```javascript
const MIN_INTERVAL = 12000; // 12 seconds
const LAST_REQUEST = $workflowData.last_firecrawl_request || 0;
const WAIT_TIME = MIN_INTERVAL - (Date.now() - LAST_REQUEST);

if (WAIT_TIME > 0) {
  // Add Wait node to delay next request
}
```

---

## Monitoring & Logging

### Enable Workflow Logs

In n8n settings:
- Enable execution logs
- Set log level to "debug" for development
- Use execution history to troubleshoot

### Key Metrics to Track

```javascript
// Log important metrics
const metrics = {
  workflow_execution_time: Date.now() - items[0].startTime,
  firecrawl_response_time: ...,
  llm_response_time: ...,
  validation_score: items[0].json.completeness_score,
  posts_generated: Object.keys(items[0].json.posts).length,
  errors: items[0].json.errors.length
};
```

### Integration with External Monitoring

Send metrics to Datadog or Sentry:
```javascript
curl -X POST https://api.datadoghq.com/api/v1/series \
  -H "DD-API-KEY: $DATADOG_API_KEY" \
  -d "{
    \"series\": [{
      \"metric\": \"automarket.workflow.duration\",
      \"points\": [[Date.now(), workflow_duration]],
      \"tags\": [\"env:prod\", \"workflow:campaign_generation\"]
    }]
  }"
```

---

## Next Steps

1. **Create Workflow in n8n**
   - Open http://localhost:5678
   - Click "New Workflow"
   - Add nodes as described above

2. **Configure Each Node**
   - Set API keys from environment variables
   - Test each node individually
   - Verify responses match expected format

3. **Test End-to-End**
   - Run with test website URL
   - Verify posts generated
   - Check Slack notification
   - Confirm Mixpost scheduling

4. **Monitor in Production**
   - Enable detailed logging
   - Set up alerting for failures
   - Track metrics and costs

---

## Troubleshooting Common Issues

### Issue: Firecrawl timeout
- Increase `timeout` parameter to 20000ms
- Check website accessibility
- Verify API key has sufficient quota

### Issue: LLM returns invalid JSON
- Add JSON validation node
- Implement retry with temperature reduction
- Check prompt formatting

### Issue: Posts exceed platform limits
- Add character limit validation
- Implement truncation logic
- Add warning to Slack

### Issue: CRM record not created
- Verify Twenty CRM API key and URL
- Check GraphQL query syntax
- Ensure workspace ID is correct

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Time to Create**: 2-3 hours
