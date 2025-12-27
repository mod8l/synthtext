# Phase 2: LLM Integration Setup

Complete guide for integrating OpenAI, Anthropic Claude, or Replicate with AutoMarket OS.

## Overview

AutoMarket OS requires one LLM provider for generating marketing content. Choose based on your needs:

| Provider | Cost | Speed | Quality | Context | Best For |
|----------|------|-------|---------|---------|----------|
| **Anthropic Claude 3.5** | $3/1M input tokens | Medium | Excellent | 200K tokens | ⭐ Recommended - Best for long content analysis |
| **OpenAI GPT-4o** | $5/1M input tokens | Fast | Excellent | 128K tokens | Fast processing, proven reliability |
| **Replicate** | Variable (pay-per-use) | Slow | Good | Varies | Cost-sensitive, experimental |

## Decision Matrix

### Use Anthropic Claude 3.5 if:
✅ You need to analyze long website content (200K token context window)
✅ You want excellent quality without premium pricing
✅ You prioritize creative copy generation
✅ You need strong guardrail compliance
✅ **RECOMMENDED FOR THIS PROJECT**

### Use OpenAI GPT-4o if:
✅ You need fastest inference times
✅ You have existing OpenAI infrastructure
✅ You want the most proven model
✅ You prefer simple integration

### Use Replicate if:
✅ You want to minimize costs per request
✅ You're experimenting with different models
✅ You need custom/open-source model options
✅ You have time flexibility (slower inference)

---

## 1. Anthropic Claude Setup (RECOMMENDED)

### Step 1: Create Anthropic Account

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign up with email
3. Click "API keys" in sidebar
4. Click "Create Key"
5. Copy the key (starts with `sk-ant-`)

### Step 2: Set Usage Limits (Optional but Recommended)

1. Go to [console.anthropic.com/account/billing/overview](https://console.anthropic.com/account/billing/overview)
2. Set monthly budget limit (e.g., $100)
3. Enable email alerts

### Step 3: Update Configuration

**Option A: Direct Update**
```bash
# Edit the secret
vi k8s/n8n-secret.yaml

# Find and update:
CLAUDE_API_KEY: "sk-ant-YOUR_KEY_HERE"
AI_MODEL: "claude-opus-4-5-20251101"

# Comment out OpenAI and Replicate sections
```

**Option B: Environment Variable (Development)**
```bash
export CLAUDE_API_KEY="sk-ant-YOUR_KEY_HERE"
export AI_MODEL="claude-opus-4-5-20251101"
```

### Step 4: Test Connection

```bash
# Run test script (once deployed)
kubectl exec -it deployment/n8n -- curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Say hello"}]
  }'
```

### Anthropic Models Available

```
claude-opus-4-5-20251101    # Latest, most capable (RECOMMENDED)
claude-3-5-sonnet-20241022  # Fast, good quality
claude-3-5-haiku-20241022   # Fastest, lightweight
```

### Pricing

```
Opus 4.5:
- Input: $3 per 1M tokens
- Output: $15 per 1M tokens

Sonnet 3.5:
- Input: $3 per 1M tokens
- Output: $15 per 1M tokens

Haiku 3.5:
- Input: $0.80 per 1M tokens
- Output: $4 per 1M tokens
```

---

## 2. OpenAI Setup

### Step 1: Create OpenAI Account

1. Go to [platform.openai.com](https://platform.openai.com)
2. Sign up or log in
3. Go to "API keys" → "Create new secret key"
4. Copy the key (starts with `sk-`)

### Step 2: Add Payment Method

1. Go to "Billing" → "Overview"
2. Add credit card
3. Set usage limits (recommended: $20/month)

### Step 3: Update Configuration

```bash
# Edit secret
vi k8s/n8n-secret.yaml

# Update:
OPENAI_API_KEY: "sk-YOUR_KEY_HERE"
AI_MODEL: "gpt-4o"

# Comment out Claude and Replicate sections
```

### Step 4: Test Connection

```bash
kubectl exec -it deployment/n8n -- curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 10
  }'
```

### OpenAI Models Available

```
gpt-4o              # Latest, most capable (RECOMMENDED)
gpt-4-turbo         # Faster, cheaper than gpt-4
gpt-4               # Standard GPT-4
gpt-3.5-turbo       # Fast, budget-friendly
```

### Pricing

```
GPT-4o:
- Input: $5 per 1M tokens
- Output: $15 per 1M tokens

GPT-4 Turbo:
- Input: $10 per 1M tokens
- Output: $30 per 1M tokens

GPT-3.5 Turbo:
- Input: $0.50 per 1M tokens
- Output: $1.50 per 1M tokens
```

---

## 3. Replicate Setup

### Step 1: Create Replicate Account

1. Go to [replicate.com](https://replicate.com)
2. Sign up (can use GitHub)
3. Go to "Account" → "API tokens"
4. Copy the token

### Step 2: Update Configuration

```bash
# Edit secret
vi k8s/n8n-secret.yaml

# Update:
REPLICATE_API_TOKEN: "r8_YOUR_TOKEN_HERE"
AI_MODEL: "replicate"
# Also set which model to use
REPLICATE_MODEL: "meta/llama-2-70b-chat"

# Comment out Claude and OpenAI sections
```

### Step 3: Test Connection

```bash
kubectl exec -it deployment/n8n -- curl -X POST https://api.replicate.com/v1/predictions \
  -H "Authorization: Bearer $REPLICATE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "2c1608e18606feda752c7d6d27d9974e5f36bada1301c8b3b287f15985f373a6",
    "input": {
      "prompt": "Say hello"
    }
  }'
```

### Popular Replicate Models

```
meta/llama-2-70b-chat          # Open source, good quality
meta/llama-2-13b-chat          # Smaller, faster
mistralai/mistral-7b-instruct  # Fast, lightweight
bigcode/starcoder              # Code generation
```

### Pricing

Variable based on model. Example (Llama 2 70B):
- $0.00065 per second (fairly fast)
- ~$0.02-0.05 per marketing post

---

## Configuration in Kubernetes

### Update n8n-secret.yaml

Edit the secret file with your chosen provider:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: n8n-secret
  namespace: default
type: Opaque
stringData:
  # ===== CHOOSE ONE PROVIDER =====

  # Option 1: Anthropic Claude (RECOMMENDED)
  CLAUDE_API_KEY: "sk-ant-YOUR_KEY_HERE"
  AI_MODEL: "claude-opus-4-5-20251101"

  # Option 2: OpenAI (uncomment to use)
  # OPENAI_API_KEY: "sk-YOUR_KEY_HERE"
  # AI_MODEL: "gpt-4o"

  # Option 3: Replicate (uncomment to use)
  # REPLICATE_API_TOKEN: "r8_YOUR_TOKEN_HERE"
  # AI_MODEL: "replicate"
  # REPLICATE_MODEL: "meta/llama-2-70b-chat"

  # ... rest of secrets
```

### Apply Changes

```bash
# Update the secret in Kubernetes
kubectl apply -f k8s/n8n-secret.yaml

# Verify
kubectl get secret n8n-secret -o yaml | grep -A 2 "AI_MODEL"

# Restart n8n to pick up new secrets
kubectl rollout restart deployment/n8n

# Watch logs
kubectl logs -f deployment/n8n
```

---

## Environment Variables in n8n-configmap.yaml

```yaml
# LLM Configuration (from secret)
CLAUDE_API_KEY: (from secret)
OPENAI_API_KEY: (from secret)
REPLICATE_API_TOKEN: (from secret)
AI_MODEL: (from secret - e.g., "claude-opus-4-5-20251101")

# System prompt location
MASTER_PROMPT_PATH: "/app/src/system-prompts/master.md"

# Fallback (optional)
LLM_FALLBACK_MODEL: "gpt-3.5-turbo"  # If primary fails
LLM_TIMEOUT: "60"  # seconds
LLM_MAX_RETRIES: "3"
```

---

## Testing LLM Integration in n8n

### Method 1: n8n HTTP Request Node

Create a test workflow with HTTP Request node:

```
HTTP Request
├── URL: https://api.anthropic.com/v1/messages (for Claude)
├── Method: POST
├── Headers:
│   ├── x-api-key: {{env.CLAUDE_API_KEY}}
│   ├── anthropic-version: 2023-06-01
│   └── content-type: application/json
└── Body:
    {
      "model": "claude-opus-4-5-20251101",
      "max_tokens": 1024,
      "messages": [
        {
          "role": "user",
          "content": "Test message: Say 'Hello from AutoMarket OS'"
        }
      ]
    }
```

### Method 2: CLI Test (Direct Pod)

```bash
# Login to n8n pod
kubectl exec -it deployment/n8n -- /bin/sh

# Test Claude
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 100,
    "messages": [{"role": "user", "content": "Hello"}]
  }' \
  | jq .
```

### Method 3: Create n8n Test Workflow

1. Open n8n at http://localhost:5678
2. Create new workflow
3. Add "Webhook" trigger
4. Add "HTTP Request" node
5. Test with your LLM provider API
6. Check response format

---

## Cost Estimation

### For 100 marketing posts/month

**Anthropic Claude:**
```
Average input: 5,000 tokens (website content)
Average output: 2,000 tokens (generated posts)

Cost per request:
  Input: 5,000 × $3/1M = $0.015
  Output: 2,000 × $15/1M = $0.030
  Total: $0.045 per post

Monthly: $0.045 × 100 = $4.50
```

**OpenAI GPT-4o:**
```
Cost per request:
  Input: 5,000 × $5/1M = $0.025
  Output: 2,000 × $15/1M = $0.030
  Total: $0.055 per post

Monthly: $0.055 × 100 = $5.50
```

**Replicate (Llama 2 70B):**
```
Estimated cost: ~$0.02-0.05 per post
Monthly: $2-5
(Note: Slower inference, ~30-60 seconds per post)
```

---

## Troubleshooting

### "Unauthorized" Error

```bash
# Check API key is correct
echo $CLAUDE_API_KEY
# Should start with: sk-ant- (Claude) or sk- (OpenAI) or r8_ (Replicate)

# Verify secret was created
kubectl get secret n8n-secret -o yaml

# Check environment variable in pod
kubectl exec deployment/n8n -- env | grep API_KEY
```

### "Rate limit exceeded"

```bash
# Implement exponential backoff in n8n workflow
# Add delay between requests
# Check quota limits in provider console
```

### "Connection timeout"

```bash
# Check network connectivity from pod
kubectl exec deployment/n8n -- ping api.anthropic.com

# Check firewall rules
# Verify no egress restrictions in cluster
```

### "Invalid model name"

```bash
# Verify exact model name
# Claude: claude-opus-4-5-20251101 (not claude-opus-4)
# OpenAI: gpt-4o (not gpt-4-o)
# Replicate: check replicate.com/models for exact versions
```

---

## Implementation Steps

### 1. Choose Provider
- Review the decision matrix above
- **Recommendation**: Start with Anthropic Claude (best for marketing content)

### 2. Create Account & Get API Key
- Follow steps in the appropriate section above
- Copy your API key

### 3. Update Kubernetes Secret
```bash
vi k8s/n8n-secret.yaml
# Update with your API key and chosen model
```

### 4. Deploy/Update
```bash
# Option A: Redeploy everything
skaffold run --profile=dev

# Option B: Update just the secret
kubectl apply -f k8s/n8n-secret.yaml
kubectl rollout restart deployment/n8n
```

### 5. Verify
```bash
# Check logs
kubectl logs -f deployment/n8n | grep -i "claude\|openai\|llm"

# Test via n8n UI at http://localhost:5678
# Create test workflow with HTTP Request node
```

### 6. Monitor Usage
- Go to provider dashboard (console.anthropic.com, platform.openai.com, etc.)
- Monitor API usage and costs
- Adjust rate limits if needed

---

## Next: Integrating with n8n Workflows

Once LLM is configured, you'll use it in n8n workflows:

1. **HTTP Request Node** - Call LLM API directly
2. **AI Node** (if available) - Use n8n's native AI integration
3. **Function Node** - Custom JavaScript for complex logic

See Phase 3 documentation for workflow integration details.

---

## Security Best Practices

✅ **Do:**
- Store API keys in Kubernetes Secrets (not in code)
- Use separate API keys for dev/staging/prod
- Rotate keys quarterly
- Monitor usage for suspicious activity
- Set spending limits in provider console
- Use Secrets Manager for production (Vault, AWS Secrets)

❌ **Don't:**
- Commit API keys to Git
- Share API keys in Slack/email
- Use production keys in development
- Leave high spending limits on test accounts
- Hardcode credentials in Docker images

---

## Provider Comparison Table

| Aspect | Claude | OpenAI | Replicate |
|--------|--------|--------|-----------|
| **Setup Time** | 5 min | 5 min | 5 min |
| **Cost** | $ | $$ | $-$$ |
| **Speed** | Medium | Fast | Slow |
| **Quality** | Excellent | Excellent | Good |
| **Context** | 200K | 128K | Varies |
| **Guardrails** | Strong | Good | Varies |
| **Availability** | 99.9% | 99.9% | 99.5% |
| **Learning Curve** | Easy | Easy | Moderate |

---

## Summary

**For AutoMarket OS, we recommend:**

1. **Primary**: Anthropic Claude 3.5 (best quality/cost for marketing content)
2. **Fallback**: OpenAI GPT-4o (proven reliability)
3. **Experimental**: Replicate (cost-sensitive/research)

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Time to Setup**: 10 minutes
