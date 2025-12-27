# Phase 4: n8n Workflow Quick Start

Get the AutoMarket campaign generator workflow running in 15 minutes.

---

## Prerequisites

✅ n8n running (http://localhost:5678)
✅ LLM API key configured (Claude/OpenAI)
✅ Firecrawl API key configured
✅ Slack webhook URL (optional but recommended)

---

## Step 1: Import the Workflow

### Option A: Import JSON File (Recommended)

1. **Open n8n UI**
   - Go to http://localhost:5678
   - Create an account or log in

2. **Import Workflow**
   - Click "Workflows" in the left menu
   - Click "Import from file"
   - Select: `src/workflows/automarket-complete-workflow.json`
   - Click "Import"

### Option B: Create Manually

If the import fails, create the workflow manually:
1. Click "New Workflow"
2. Follow the node structure in `docs/PHASE4_N8N_WORKFLOW.md`
3. Configure each node as described

---

## Step 2: Configure Credentials

### LLM Credentials

In n8n, credentials are managed separately from workflows:

1. **Go to Settings** → **Credentials**
2. Create new credential for your LLM provider:

**For Claude:**
- Click "New"
- Name: "Anthropic API"
- Type: Select "HTTP Header Auth"
- Header Name: `x-api-key`
- Header Value: `sk-ant-...` (your API key)
- Save

**For OpenAI:**
- Name: "OpenAI API"
- Type: "HTTP Header Auth"
- Header Name: `Authorization`
- Header Value: `Bearer sk-...` (your API key)
- Save

### Slack Webhook (Optional)

1. Get your Slack webhook URL from:
   - Slack workspace settings → Apps → Custom Integrations → Incoming Webhooks
   - Create new webhook for #marketing-automation channel

2. In n8n:
   - Settings → Credentials
   - New credential
   - Type: "Slack"
   - Webhook URL: Paste your Slack webhook
   - Save

---

## Step 3: Set Environment Variables

n8n loads environment variables from the container/system.

**Check that these are set:**

```bash
# Inside Kubernetes pod
kubectl exec -it deployment/n8n -- env | grep -E "CLAUDE|FIRECRAWL|WEBHOOK"

# Should show:
# CLAUDE_API_KEY=sk-ant-...
# FIRECRAWL_API_KEY=fc_...
# WEBHOOK_TOKEN=...
```

If missing, update the secret:
```bash
vi k8s/n8n-secret.yaml
kubectl apply -f k8s/n8n-secret.yaml
kubectl rollout restart deployment/n8n
```

---

## Step 4: Test the Workflow

### Trigger 1: Test with Webhook

```bash
# Get webhook token from k8s secret
WEBHOOK_TOKEN=$(kubectl get secret n8n-secret -o jsonpath='{.data.WEBHOOK_TOKEN}' | base64 -d)

# Get n8n service URL
N8N_URL=$(kubectl get svc n8n -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# If loadBalancer doesn't work, use port-forward:
# kubectl port-forward svc/n8n 5678:80

# Test with example website
curl -X POST http://localhost:5678/webhook/automarket/webhook \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "website_url": "https://example.com",
    "campaign_mode": "manual_review"
  }'
```

### Trigger 2: Test with Cron

1. Open the workflow in n8n
2. Click "Cron Trigger" node
3. Change rule to "every 1 minute" (for testing)
4. Click "Save"
5. Click "Execute Workflow"
6. Monitor execution in the UI

---

## Step 5: Monitor Execution

### In n8n UI

1. After running the workflow:
   - Check each node for green checkmarks (success)
   - Check for red X marks (errors)
   - Click on each node to see input/output data

2. Common check points:
   - **Firecrawl Scraper**: Should show markdown content
   - **Prepare Prompt**: Should show system prompt + content
   - **Call LLM**: Should show API response with posts
   - **Parse LLM Response**: Should show extracted JSON
   - **Validate Posts**: Should show completeness score

### In Kubernetes Logs

```bash
# Watch n8n logs
kubectl logs -f deployment/n8n

# Watch for specific messages
kubectl logs -f deployment/n8n | grep -i "automarket\|campaign\|error"
```

### In Slack

You should receive a notification with:
- ✅ or ⚠️ status indicator
- Completeness score (0-100%)
- Sample LinkedIn and Twitter posts
- Whether it's ready to publish

---

## Node Configuration Reference

Quick lookup for common node settings:

### Firecrawl Scraper Node

| Setting | Value |
|---------|-------|
| URL | `https://api.firecrawl.dev/v0/scrape` |
| Method | POST |
| Header: Authorization | `Bearer {{$env.FIRECRAWL_API_KEY}}` |
| Body: url | `{{$json.website_url}}` |
| Body: formats | `["markdown"]` |
| Body: timeout | `15000` |

### LLM Call Node

| Setting | Value |
|---------|-------|
| URL | `https://api.anthropic.com/v1/messages` (Claude) |
| Method | POST |
| Header: x-api-key | `{{$env.CLAUDE_API_KEY}}` |
| Body: model | `{{$env.AI_MODEL}}` |
| Body: max_tokens | `4096` |
| Body: system | `{{$json.system_prompt}}` |

### Slack Node

| Setting | Value |
|---------|-------|
| Channel | `#marketing-automation` |
| Message Text | `🚀 AutoMarket Campaign Generated` |
| Attachments | Title + Posts |

---

## Troubleshooting

### Issue: "Invalid API key" Error

**Solution:**
```bash
# Check if API key is in secret
kubectl get secret n8n-secret -o yaml | grep CLAUDE_API_KEY

# Check if env variable is loaded in pod
kubectl exec deployment/n8n -- env | grep CLAUDE_API_KEY

# If missing, update secret and restart
kubectl apply -f k8s/n8n-secret.yaml
kubectl rollout restart deployment/n8n
```

### Issue: Firecrawl Returns "No content extracted"

**Solution:**
- Try with a different website (example.com works)
- Check website accessibility: `curl https://your-url.com`
- Increase timeout: Change `timeout` to `20000`

### Issue: LLM Response Parse Error

**Solution:**
- Check API response in n8n node output
- Verify model name is correct
- Try reducing prompt complexity
- Check API key validity with test script:
  ```bash
  bash scripts/test-llm-connection.sh claude
  ```

### Issue: Slack Notification Not Sent

**Solution:**
- Verify Slack webhook URL is correct
- Test webhook directly:
  ```bash
  curl -X POST $SLACK_WEBHOOK_URL \
    -H 'Content-type: application/json' \
    -d '{"text":"Test message"}'
  ```
- Check n8n Slack node configuration

### Issue: Workflow Timeout

**Solution:**
- Increase execution timeout in workflow settings
- Default is 1 hour (3600 seconds)
- Check individual node timeouts (Firecrawl: 15000ms)

---

## Testing Different Websites

Try these websites to see different content generation:

```bash
# Tech company
curl -X POST http://localhost:5678/webhook/automarket/webhook \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"website_url": "https://github.com"}'

# SaaS product
curl -X POST http://localhost:5678/webhook/automarket/webhook \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"website_url": "https://stripe.com"}'

# Blog
curl -X POST http://localhost:5678/webhook/automarket/webhook \
  -H "Authorization: Bearer $WEBHOOK_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"website_url": "https://blog.anthropic.com"}'
```

---

## Performance Checklist

- [ ] Workflow completes in < 60 seconds for typical site
- [ ] Firecrawl scraping takes 5-15 seconds
- [ ] LLM generation takes 20-40 seconds (Claude/OpenAI)
- [ ] Validation and Slack notification < 5 seconds
- [ ] All posts generated successfully (no empty posts)
- [ ] Slack notification arrives within 90 seconds of trigger

---

## Next Steps

### After Workflow Works:

1. **Monitor Real Usage**
   - Run workflow on real websites
   - Check output quality
   - Adjust guardrails if needed

2. **Add More Nodes** (Phase 5)
   - Mixpost scheduling
   - Twenty CRM integration
   - Database storage for campaigns

3. **Optimize**
   - Add conditional logic for auto-publish vs. manual review
   - Implement retry logic for transient failures
   - Add cost tracking

4. **Deploy to Production**
   - Test with real LLM API keys
   - Set up monitoring and alerting
   - Enable detailed logging

---

## Useful Commands

```bash
# List all workflows
kubectl exec -it deployment/n8n -- n8n list

# Get workflow details
curl http://localhost:5678/api/v1/workflows

# Test LLM connection
bash scripts/test-llm-connection.sh claude

# Check n8n execution logs
kubectl logs -f deployment/n8n --tail=100

# Restart n8n after config changes
kubectl rollout restart deployment/n8n

# Port forward to n8n
kubectl port-forward svc/n8n 5678:80
```

---

## Success Indicators

✅ **Workflow is working when:**
1. Firecrawl successfully extracts markdown from website
2. LLM API returns valid JSON with posts
3. Validation completes without errors
4. Slack notification is received with posts
5. Each platform (LinkedIn, Twitter, Instagram, Facebook) has a post
6. Completeness score is >= 80%
7. All 4 posts are under their character limits

---

## File Structure

```
/synthtext/
├── src/workflows/
│   └── automarket-complete-workflow.json     ← Import this into n8n
├── docs/
│   ├── PHASE4_N8N_WORKFLOW.md                ← Detailed guide
│   ├── PHASE4_N8N_QUICKSTART.md              ← This file
│   └── WORKFLOW_NODES_REFERENCE.md           ← Node details
└── k8s/
    └── n8n-secret.yaml                       ← API keys config
```

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Setup Time**: 15 minutes
**Typical Workflow Duration**: 60 seconds
