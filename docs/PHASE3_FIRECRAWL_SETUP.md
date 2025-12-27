# Phase 3: Firecrawl API Setup

Complete guide for setting up Firecrawl web scraping API for extracting website content.

## What is Firecrawl?

Firecrawl is a web scraping API that extracts content from websites and converts it to clean markdown. It's essential for AutoMarket OS to analyze website content before generating marketing campaigns.

**Key Features:**
- Extracts website content as clean markdown
- Handles JavaScript-rendered content
- Removes ads, navigation, boilerplate
- Structured data extraction
- LLM-friendly output format

---

## Step 1: Create Firecrawl Account

### Free Tier (Limited)
1. Go to [firecrawl.dev](https://firecrawl.dev)
2. Click "Get Started" or "Sign Up"
3. Sign up with email
4. Verify email address
5. Dashboard opens - copy API key from "API Keys" section

### Pricing Tiers

| Tier | Monthly Cost | Credits | Per URL |
|------|-------------|---------|---------|
| **Starter** | Free | 100 credits | ~$0.10-0.50 |
| **Pro** | $99 | 10,000 credits | ~$0.01 |
| **Enterprise** | Custom | Unlimited | Negotiated |

### Recommended for AutoMarket OS
- **Development**: Use free tier (100 requests)
- **Staging**: Pro tier ($99/month, 10,000 requests)
- **Production**: Pro tier or Enterprise

---

## Step 2: Get Your API Key

1. Log into [firecrawl.dev/dashboard](https://firecrawl.dev/dashboard)
2. Navigate to "Settings" → "API Keys"
3. Click "Create API Key"
4. Copy the key (format: `fc_xxxxx`)
5. Store securely - you'll need it for n8n

---

## Step 3: Update Kubernetes Secret

Edit the n8n secret with your Firecrawl API key:

```bash
vi k8s/n8n-secret.yaml
```

Find and update:
```yaml
# Firecrawl API
FIRECRAWL_API_KEY: "fc_your_actual_api_key_here"
FIRECRAWL_API_URL: "https://api.firecrawl.dev/v0"
```

### Apply Changes

```bash
# Update the secret
kubectl apply -f k8s/n8n-secret.yaml

# Restart n8n
kubectl rollout restart deployment/n8n

# Verify
kubectl logs -f deployment/n8n | grep -i firecrawl
```

---

## Step 4: Test Firecrawl Connectivity

### Using Test Script

```bash
# Test direct API call
curl -X POST https://api.firecrawl.dev/v0/scrape \
  -H "Authorization: Bearer fc_your_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "formats": ["markdown"]
  }'
```

### Expected Response

```json
{
  "success": true,
  "data": {
    "markdown": "# Website Title\n\nWebsite content here...",
    "metadata": {
      "title": "Website Title",
      "description": "Website description",
      "language": "en",
      "sourceURL": "https://example.com"
    }
  }
}
```

### Error Response

```json
{
  "success": false,
  "error": "Unauthorized: Invalid API key"
}
```

---

## Step 5: Configure in n8n Workflow

### HTTP Request Node Setup

Create an HTTP Request node in your n8n workflow:

```
Node: HTTP Request
├── URL: https://api.firecrawl.dev/v0/scrape
├── Method: POST
├── Headers:
│   ├── Authorization: Bearer {{env.FIRECRAWL_API_KEY}}
│   └── Content-Type: application/json
└── Body:
    {
      "url": "{{$node['trigger'].json.website_url}}",
      "formats": ["markdown"],
      "onlyMainContent": true,
      "waitFor": 3000
    }
```

### Node Configuration (JSON)

```json
{
  "name": "Scrape Website Content",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.firecrawl.dev/v0/scrape",
    "method": "POST",
    "authentication": "genericCredentialType",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer {{$env.FIRECRAWL_API_KEY}}"
        },
        {
          "name": "Content-Type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "body": {
      "json": {
        "url": "{{$node['trigger'].json.url}}",
        "formats": ["markdown"],
        "onlyMainContent": true,
        "timeout": 10000
      }
    }
  }
}
```

---

## Firecrawl Parameters

### Core Parameters

| Parameter | Type | Required | Description | Example |
|-----------|------|----------|-------------|---------|
| `url` | string | ✅ | Website URL to scrape | `"https://example.com"` |
| `formats` | array | ❌ | Output formats | `["markdown", "html"]` |
| `onlyMainContent` | boolean | ❌ | Extract main content only | `true` |
| `waitFor` | number | ❌ | Wait for JS rendering (ms) | `3000` |
| `timeout` | number | ❌ | Request timeout (ms) | `10000` |

### Advanced Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `removeBase64Images` | boolean | Remove base64 encoded images |
| `parseMetadata` | boolean | Extract metadata (title, description) |
| `pageOptions` | object | Advanced page options (headers, cookies) |

### Recommended Settings for AutoMarket OS

```json
{
  "url": "{{website_url}}",
  "formats": ["markdown"],
  "onlyMainContent": true,
  "waitFor": 5000,
  "timeout": 15000,
  "parseMetadata": true,
  "removeBase64Images": true
}
```

---

## Response Parsing

### Extract Markdown Content

```javascript
// Function node to parse response
const response = items[0].json;

if (!response.success) {
  throw new Error(`Firecrawl error: ${response.error}`);
}

return {
  markdown_content: response.data.markdown,
  title: response.data.metadata?.title || "",
  description: response.data.metadata?.description || "",
  url: response.data.metadata?.sourceURL || "",
  language: response.data.metadata?.language || "en"
};
```

### Store Extracted Content

```javascript
// In a subsequent node
return {
  website_id: items[0].json.url,
  content: items[0].json.markdown_content,
  metadata: {
    title: items[0].json.title,
    description: items[0].json.description,
    language: items[0].json.language
  },
  extracted_at: new Date().toISOString(),
  ready_for_ai: true
};
```

---

## Error Handling

### Handle Common Errors

```javascript
// Function node error handling
const response = items[0].json;

if (!response.success) {
  const error = response.error;

  if (error.includes("Unauthorized")) {
    throw new Error("Invalid Firecrawl API key - check k8s/n8n-secret.yaml");
  }

  if (error.includes("timeout") || error.includes("Timeout")) {
    throw new Error("Website took too long to load - increase waitFor timeout");
  }

  if (error.includes("not found") || error.includes("404")) {
    throw new Error(`Website not found: ${items[0].json.url}`);
  }

  throw new Error(`Firecrawl error: ${error}`);
}

if (!response.data?.markdown) {
  throw new Error("No content extracted - website may be blocked or empty");
}

return response.data;
```

---

## Rate Limiting

### Firecrawl Rate Limits

| Tier | Requests/Minute | Daily Limit |
|------|-----------------|-------------|
| Free | 5 | 100 |
| Pro | 60 | 10,000 |
| Enterprise | Unlimited | Unlimited |

### Implement Rate Limiting in n8n

```javascript
// In a Function node
const MIN_INTERVAL = 12000; // 12 seconds for free tier (5 req/min)
const LAST_REQUEST = $workflowData.last_firecrawl_request || 0;
const CURRENT_TIME = Date.now();

if (CURRENT_TIME - LAST_REQUEST < MIN_INTERVAL) {
  const WAIT_TIME = MIN_INTERVAL - (CURRENT_TIME - LAST_REQUEST);
  return {
    status: "rate_limited",
    wait_ms: WAIT_TIME,
    next_request_at: new Date(CURRENT_TIME + WAIT_TIME)
  };
}

$workflowData.last_firecrawl_request = CURRENT_TIME;
return { status: "ready", can_request: true };
```

---

## Common Issues & Solutions

### Issue: "Unauthorized: Invalid API key"

**Solution:**
```bash
# Verify API key
echo $FIRECRAWL_API_KEY

# Check in Kubernetes
kubectl get secret n8n-secret -o yaml | grep FIRECRAWL_API_KEY

# Get fresh key from dashboard
# https://firecrawl.dev/dashboard → Settings → API Keys
```

### Issue: "Timeout - Website took too long"

**Solution:**
```json
{
  "waitFor": 10000,  // Increase wait time
  "timeout": 20000   // Increase overall timeout
}
```

### Issue: "No content extracted"

**Solution:**
```bash
# Test URL directly
curl "https://example.com" -I  # Check if accessible

# Try with onlyMainContent: false to debug
{
  "url": "https://example.com",
  "onlyMainContent": false
}

# Check if website blocks scrapers
```

### Issue: "Rate limit exceeded"

**Solution:**
```bash
# Upgrade plan
# Free: 5 req/min → Pro: 60 req/min

# Implement delay between requests
# Add Wait node in n8n workflow
```

---

## Cost Analysis

### For 100 websites/month

**Free Tier:**
- Cost: $0
- Limit: 100 requests/month
- Perfect for: Testing, small deployments

**Pro Tier:**
- Cost: $99/month
- Limit: 10,000 requests/month
- Per request cost: ~$0.01
- Perfect for: Production, 100-1000 campaigns/month

**Calculation:**
```
100 websites × 1 scrape each = 100 credits/month
Free tier covers this perfectly

But if scaling:
1000 websites × 1 scrape = 1000 credits/month
1000 × $0.01 = $10/month (within Pro tier)
```

---

## Integration with AutoMarket OS Workflow

### Full Workflow:

```
Trigger (Webhook)
    ↓
Firecrawl: Scrape Website
    ↓
Parse Content (Markdown + Metadata)
    ↓
Claude/OpenAI: Generate Posts (using markdown)
    ↓
Parse Posts (JSON extraction)
    ↓
Validate Guardrails
    ↓
Store in CRM
    ↓
Mixpost: Schedule Posts
    ↓
Slack Notification
```

### Firecrawl Node in this Workflow:

```json
{
  "url": "{{$node['trigger'].json.website_url}}",
  "formats": ["markdown"],
  "onlyMainContent": true,
  "timeout": 15000
}
```

Output flows to:
- LLM prompt (for content generation)
- Metadata storage (for campaign tracking)
- CRM record (for audit trail)

---

## Advanced: Batch Processing

### Process Multiple URLs

```javascript
// Function node
const urls = items[0].json.website_urls; // Array of URLs

return urls.map(url => ({
  url: url,
  formats: ["markdown"],
  onlyMainContent: true,
  timeout: 15000
}));
```

Then use **Firecrawl node in Loop** to process each URL.

### Parallel Processing with Rate Limiting

```javascript
// Schedule requests with delays
const urls = items[0].json.urls;
const DELAY_BETWEEN_REQUESTS = 12000; // 12 seconds (free tier: 5 req/min)

const requests = urls.map((url, index) => ({
  url: url,
  delay_ms: index * DELAY_BETWEEN_REQUESTS
}));

return requests;
```

---

## Testing Checklist

- [ ] API key obtained from firecrawl.dev
- [ ] Kubernetes secret updated with API key
- [ ] n8n pod restarted (`kubectl rollout restart deployment/n8n`)
- [ ] Test HTTP request returns success
- [ ] Markdown content extracts correctly
- [ ] Error handling works for invalid URLs
- [ ] Rate limiting respected (free tier: 5 req/min)
- [ ] Cost tracking: Monitor usage at firecrawl.dev/dashboard

---

## Next Steps

Once Firecrawl is working:

1. **Verify in n8n UI**
   - Create test workflow
   - Add Firecrawl HTTP Request node
   - Test with real website URL
   - Verify markdown output

2. **Connect to LLM**
   - Pass markdown to Claude/OpenAI
   - Generate marketing content
   - See Phase 4 for full workflow

3. **Monitor Usage**
   - Check firecrawl.dev/dashboard regularly
   - Track costs and API usage
   - Plan for plan upgrade if needed

---

## Security

✅ **Best Practices:**
- Store API key in Kubernetes Secrets (not in code)
- Use separate keys for dev/staging/prod
- Rotate keys quarterly
- Monitor usage for suspicious activity
- Set spending alerts in Firecrawl dashboard

❌ **Don't:**
- Commit API keys to Git
- Share keys in Slack/email
- Use production keys in development
- Log API requests with key in them

---

## Resources

- [Firecrawl Documentation](https://docs.firecrawl.dev)
- [Firecrawl API Reference](https://docs.firecrawl.dev/api-reference)
- [Firecrawl Pricing](https://firecrawl.dev/pricing)
- [n8n HTTP Request Node](https://docs.n8n.io/nodes/n8n-nodes-base.http-request/)

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Time to Setup**: 5 minutes
