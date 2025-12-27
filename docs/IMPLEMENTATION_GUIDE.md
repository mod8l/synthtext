# AutoMarket OS: Implementation Guide

## Quick Start (15 minutes)

### 1. Prerequisites
- n8n instance (self-hosted or cloud at n8n.io)
- OpenAI/Claude API key
- Firecrawl account (firecrawl.dev)
- Twenty CRM instance (for lead tracking)
- Mixpost account (for scheduling)
- Social media platform credentials

### 2. Environment Setup

```bash
# Clone or create repository
cp .env.example .env

# Fill in all API keys and credentials
nano .env
```

**Required API Keys**:
- `FIRECRAWL_API_KEY`: For web content extraction
- `CLAUDE_API_KEY` (or `OPENAI_API_KEY`): For AI prompt execution
- `MIXPOST_API_KEY`: For post scheduling
- `TWENTY_CRM_TOKEN`: For CRM integration
- Social media tokens (LinkedIn, Twitter, Instagram, Facebook)
- `SLACK_WEBHOOK_URL`: For notifications

### 3. Import n8n Workflow

1. Open your n8n instance
2. Click "New Workflow"
3. Click "Import from file"
4. Select `/src/workflows/automarket-campaign.json`
5. Configure credentials for each platform
6. Enable the workflow

### 4. Test the Workflow

**Via Webhook (Recommended)**:
```bash
curl -X POST http://localhost:5678/webhook/automarket/webhook \
  -H "Authorization: Bearer YOUR_WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"website_url": "https://example.com"}'
```

**Via Cron**:
- Workflow will run hourly automatically

### 5. Monitor Results

- Check n8n execution history for successful runs
- View Twenty CRM for generated campaigns and leads
- Check Slack for notifications

---

## Detailed Configuration

### Firecrawl Setup

1. **Create API Key**:
   - Go to https://firecrawl.dev
   - Sign up and create API key
   - Add to `.env` as `FIRECRAWL_API_KEY`

2. **Test Extraction**:
```bash
curl -X POST https://api.firecrawl.dev/v0/scrape \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com", "formats": ["markdown"]}'
```

### Claude/OpenAI Setup

**Using Claude**:
```bash
# In .env
CLAUDE_API_KEY=sk-ant-...
AI_MODEL=claude-opus-4-5-20251101
```

**Using OpenAI**:
```bash
# In .env
OPENAI_API_KEY=sk-...
AI_MODEL=gpt-4-turbo
```

### Mixpost Configuration

1. **Get API Key**:
   - Log into Mixpost
   - Settings → API → Create New Token
   - Scope: `posts.create`, `posts.schedule`, `accounts.read`

2. **Connect Social Accounts**:
   - Settings → Connected Accounts
   - Add LinkedIn, Twitter, Instagram, Facebook
   - Grant necessary permissions

3. **Configure n8n**:
   - Create Mixpost credentials in n8n
   - Test API connection

### Twenty CRM Setup

1. **Create API Token**:
   - Settings → API Keys
   - Create new token with scope: `campaigns.create`, `leads.create`, `tasks.create`

2. **Configure Database**:
   - Import schema from `/src/schemas/twenty-crm-schema.json`
   - Create Campaign, Lead, and CampaignPost objects

3. **Set Up Views**:
   - Campaign Dashboard
   - Lead Pipeline
   - Campaign Performance

### LinkedIn Integration

1. **Create Developer App**:
   - https://www.linkedin.com/developers/apps
   - Create new application
   - Get Client ID & Secret

2. **OAuth Setup**:
   - Redirect URI: `https://your-n8n-instance/rest/oauth2/callback`
   - Get access token

3. **Get Page ID**:
   ```bash
   curl -X GET "https://api.linkedin.com/v2/me" \
     -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
   ```

### Twitter/X Integration

1. **Create API Credentials**:
   - https://developer.twitter.com/en/portal/dashboard
   - Create new application
   - Get API Key, API Secret, Bearer Token

2. **Required Permissions**:
   - `tweet.read`
   - `tweet.write`
   - `users.read`

### Instagram Integration

1. **Create Business Account**:
   - Convert personal account to business account
   - Link to Facebook Page

2. **Get Access Token**:
   - Facebook App → Settings → Basic
   - Generate access token with `instagram_basic` permission

### Facebook Integration

1. **Create App**:
   - https://developers.facebook.com/apps
   - Select "Business"
   - Add Facebook Login product

2. **Get Credentials**:
   - App ID, App Secret
   - Create access token with `pages_manage_posts` permission

### Slack Integration

1. **Create Webhook**:
   - https://api.slack.com/apps
   - Create New App
   - Enable Incoming Webhooks
   - Add Webhook URL for channel: `#marketing-automation`

2. **Configure n8n**:
   - Add webhook URL to `.env` as `SLACK_WEBHOOK_URL`

---

## Workflow Execution Flow

### Trigger
- **Cron**: Every hour (configurable)
- **Webhook**: On-demand via POST request
- **Manual**: Click "Execute" in n8n UI

### Step 1: Content Extraction (Firecrawl)
```
Input: Website URL
Output: Markdown content
Time: 5-10 seconds
```

### Step 2: AI Analysis & Campaign Generation
```
Input: Markdown + Master System Prompt
Output: Campaign JSON
Time: 30-60 seconds
```

### Step 3: Validation & Parsing
```
Input: Campaign JSON
Output: Flattened post array
Check: Autonomy status, guardrails, completeness
```

### Step 4: Post Scheduling (Mixpost)
```
For each post:
  - Send to Mixpost API
  - Set platform + schedule time
  - Attach UTM parameters
Time: 2-5 seconds per post
```

### Step 5: CRM Integration
```
- Create Campaign record in Twenty CRM
- Add tracking links
- Assign review task to CMO
Time: 3-5 seconds
```

### Step 6: Notifications
```
- Send Slack message with campaign summary
- If blocked, alert team of missing data
```

### Total Execution Time: 2-3 minutes

---

## Campaign JSON Output Example

```json
{
  "metadata": {
    "campaign_id": "2025-01-15-abc123",
    "generated_at": "2025-01-15T10:30:00Z",
    "website_url": "https://example.com",
    "data_completeness_score": 95,
    "autonomy_status": "ready",
    "review_required": false
  },
  "brand_analysis": {
    "value_proposition": "Simplify SaaS marketing with AI-driven content",
    "primary_usps": [
      "Multi-channel content generation",
      "Zero hallucinations guarantee",
      "Built-in CRM tracking"
    ],
    "brand_voice": {
      "tone": "professional_but_approachable",
      "personality": "Expert guide, not corporate robot"
    }
  },
  "posts": {
    "linkedin": [
      {
        "post_id": "linkedin-001",
        "type": "thought_leadership",
        "content": "...",
        "creative_brief": {...},
        "cta_text": "Link in comments",
        "utm_link": "https://example.com/?utm_source=automarket&utm_medium=linkedin&utm_campaign=2025-01-15&utm_content=linkedin-001"
      }
    ],
    "twitter": [...],
    "instagram": [...],
    "facebook": [...]
  },
  "crm_tracking": {
    "campaign_record": {...},
    "utm_strategy": {...},
    "expected_metrics": {
      "estimated_impressions": 50000,
      "estimated_leads": 25,
      "estimated_conversion_rate": 0.05
    }
  }
}
```

---

## Customization

### 1. Adjust Master System Prompt

Edit `/src/system-prompts/master.md` for:
- Brand voice & tone
- Content pillars
- Platform-specific strategies
- Guardrails

### 2. Modify Platform Templates

Edit `/src/templates/platform-templates.json` for:
- Content types
- CTA strategies
- Forbidden patterns
- Emoji/hashtag rules

### 3. Configure Scheduling

In n8n workflow:
- Change Cron frequency (hourly, daily, weekly)
- Adjust post distribution across platforms
- Set auto-publish time (stagger posts)

### 4. Brand Customization

Update in multiple places:
- Master prompt brand voice section
- Platform templates
- Creative brief style preferences
- UTM campaign prefix

---

## Monitoring & Metrics

### n8n Execution Monitoring
- Check execution history for success/failure
- Monitor execution time (target: 2-3 min)
- Review error logs

### Twenty CRM Dashboard
- **Campaign Performance**: ROI, leads, conversions
- **Lead Pipeline**: By source, intent, stage
- **UTM Attribution**: Traffic by campaign

### Mixpost Analytics
- Impressions & reach by platform
- Engagement rates
- Click-through rates
- Best-performing posts

### Slack Notifications
- Campaign generation alerts
- Blocked campaign warnings
- Daily summary report

---

## Troubleshooting

### Issue: Firecrawl Extraction Fails

**Symptoms**: "Error extracting website content"

**Solutions**:
1. Verify website is publicly accessible
2. Check URL format (include https://)
3. Increase timeout (adjust in n8n node)
4. Check Firecrawl API quota

```bash
curl -X GET "https://api.firecrawl.dev/v0/quota" \
  -H "Authorization: Bearer YOUR_API_KEY"
```

### Issue: AI Generation Times Out

**Symptoms**: "OpenAI API timeout" or "Claude API timeout"

**Solutions**:
1. Reduce website content size (trim to <50KB markdown)
2. Increase n8n node timeout (default 60s)
3. Use faster model (gpt-3.5-turbo instead of gpt-4)
4. Check API rate limits

### Issue: Campaign Blocked (< 80% Completeness)

**Symptoms**: `"status": "BLOCKED"` in campaign JSON

**Solution**: Check `missing_data` array in response
- Add missing information to website
- Re-run workflow
- Or manually provide data to AI prompt

**Common Issues**:
- Missing recent blog posts or updates
- Unclear value proposition
- No customer testimonials
- Pricing information outdated

### Issue: Posts Not Appearing in Mixpost

**Symptoms**: Campaign JSON shows success, but Mixpost is empty

**Solutions**:
1. Verify Mixpost API key in n8n
2. Check social media account connections in Mixpost
3. Verify post status in n8n → Mixpost node output
4. Check Mixpost API limits

### Issue: CRM Records Not Creating

**Symptoms**: No Campaign record in Twenty CRM

**Solutions**:
1. Verify Twenty CRM API token
2. Check token has `campaigns.create` scope
3. Verify Twenty CRM schema is imported
4. Check n8n error logs for API response

### Issue: UTM Parameters Not Tracking

**Symptoms**: Clicks not attributed in Google Analytics/CRM

**Solutions**:
1. Verify UTM parameters are in links
2. Check Google Analytics event tracking setup
3. Verify Twenty CRM webhook for lead capture
4. Test link in browser to verify parameters appear

---

## Best Practices

### 1. Weekly Review Cadence

**Monday Morning**:
- Review previous week's campaign performance
- Check lead quality and conversion rates
- Adjust next week's content strategy based on ROI

### 2. Content Strategy

**80/20 Rule**:
- 80% valuable content (thought leadership, education)
- 20% promotional (product updates, CTAs)

**Avoid**:
- Posting same content on all platforms
- Hard-selling every post
- Ignoring brand voice guidelines

### 3. CRM Hygiene

**Weekly Tasks**:
- Clean up duplicate leads
- Update lead status as they move through pipeline
- Remove test records from Mixpost

### 4. API Management

**Monthly**:
- Check API usage and quotas
- Review rate limits
- Renew expiring tokens
- Archive old campaigns in Twenty CRM

---

## Advanced Configuration

### Image Generation (Stable Diffusion)

For automatic image generation from creative briefs:

1. **Local Setup** (CPU):
```bash
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI
python main.py  # Runs on http://localhost:8188
```

2. **API Service**:
- Use Replicate API
- Use Stability AI API
- Use RunwayML

3. **n8n Integration**:
- Image Generation node will generate images
- Store in `creative_brief.prompt_for_ai`
- Attach to Mixpost posts

### Custom Lead Scoring

In Twenty CRM, create automation:
```
On Lead Created:
  If utm_term = "high_intent" → Add tag "hot_lead"
  If utm_term = "pricing_inquiry" → Set pipeline_stage = "Negotiation"
  If utm_term = "general_inquiry" → Set pipeline_stage = "Awareness"
```

### Approval Workflow

**Recommended**: Manual review before publishing

1. Campaign generated → Task assigned to CMO
2. CMO reviews posts in Mixpost (staged, not published)
3. CMO approves or requests changes
4. Approved posts auto-publish at scheduled time

**Configuration**:
- Set `CAMPAIGN_AUTO_PUBLISH=false`
- Set `CAMPAIGN_REVIEW_REQUIRED=true`
- Create CMO review task in n8n

---

## Security Considerations

### API Key Management

- Use environment variables (never hardcode)
- Rotate keys monthly
- Use different keys for dev/staging/production
- Restrict API key permissions to minimum needed

### OAuth Tokens

- Use refresh tokens where available
- Implement token expiration handling
- Monitor token usage

### Webhook Security

- Use `WEBHOOK_TOKEN` for authorization
- Only accept POST requests
- Validate webhook signature
- Rate limit webhook endpoint

### Data Privacy

- Don't store PII in campaign descriptions
- Use UTM `utm_term` for generic interest (not email/phone)
- Comply with GDPR/CCPA when capturing leads
- Review Twenty CRM data retention policies

---

## Performance Optimization

### Reduce Execution Time

1. **Firecrawl**:
   - Only scrape changed content
   - Cache Markdown output
   - Use `onlyMainContent: true`

2. **AI Generation**:
   - Use faster model (gpt-3.5-turbo) for drafts
   - Batch multiple websites
   - Cache brand analysis

3. **Mixpost**:
   - Schedule posts in bulk
   - Stagger publishing to avoid API rate limits

### Cost Optimization

**Typical Monthly Costs** (for 100 campaigns/month):

| Service | Volume | Cost |
|---------|--------|------|
| Firecrawl | 100 scrapes | $20-50 |
| Claude/OpenAI | 100 campaigns | $100-200 |
| Mixpost | Unlimited posts | $50-100 |
| Twenty CRM | 1,000 leads | $50-100 |
| Total | | ~$220-450 |

**Cost Reduction**:
- Use gpt-3.5-turbo instead of gpt-4
- Cache brand analysis (reuse for similar websites)
- Batch content generation
- Use free tier of tools where available

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-12-27 | Initial release |

## Support

- **Documentation**: See `/docs` directory
- **Issues**: GitHub Issues (project repository)
- **Community**: n8n Community Forum
- **Commercial Support**: Available with enterprise license

---

**Last Updated**: 2025-12-27
