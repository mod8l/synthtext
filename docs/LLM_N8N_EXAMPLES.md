# LLM Integration Examples for n8n

Practical examples for integrating each LLM provider into n8n workflows.

## Quick Reference

| Provider | n8n Node Type | API Endpoint | Auth Header |
|----------|---------------|--------------|-------------|
| Claude | HTTP Request | https://api.anthropic.com/v1/messages | `x-api-key` |
| OpenAI | HTTP Request or ChatGPT | https://api.openai.com/v1/chat/completions | `Authorization: Bearer` |
| Replicate | HTTP Request | https://api.replicate.com/v1/predictions | `Authorization: Bearer` |

---

## 1. Anthropic Claude Example

### Simple HTTP Request Setup

**n8n Nodes:**
1. Webhook (trigger)
2. HTTP Request (call Claude)
3. Function (parse response)
4. Slack (send notification)

### HTTP Request Node Configuration

```json
{
  "name": "Call Claude API",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.anthropic.com/v1/messages",
    "method": "POST",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "x-api-key",
          "value": "={{$env.CLAUDE_API_KEY}}"
        },
        {
          "name": "anthropic-version",
          "value": "2023-06-01"
        },
        {
          "name": "content-type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "bodyParametersUiExpression": "raw",
    "body": {
      "json": {
        "model": "={{$env.AI_MODEL}}",
        "max_tokens": 2048,
        "messages": [
          {
            "role": "user",
            "content": "={{$node['Parse Website Content'].json.markdown_content}}"
          }
        ]
      }
    }
  }
}
```

### Response Parsing

```javascript
// Function node to parse Claude response
return {
  success: true,
  response: items[0].json.content[0].text,
  usage: {
    input_tokens: items[0].json.usage.input_tokens,
    output_tokens: items[0].json.usage.output_tokens
  }
};
```

### Full Request Body (Marketing Content Generation)

```json
{
  "url": "https://api.anthropic.com/v1/messages",
  "method": "POST",
  "headers": {
    "x-api-key": "sk-ant-YOUR_KEY",
    "anthropic-version": "2023-06-01",
    "content-type": "application/json"
  },
  "body": {
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 4096,
    "system": "You are an expert marketing CMO. Generate platform-specific social media posts based on the website content provided.",
    "messages": [
      {
        "role": "user",
        "content": "Create LinkedIn, Twitter, Instagram, and Facebook posts from this website content:\n\n{website_markdown}\n\nReturn as JSON with keys: linkedin, twitter, instagram, facebook"
      }
    ]
  }
}
```

### Error Handling

```javascript
// In a Function node after HTTP Request
if (items[0].json.error) {
  throw new Error(`Claude API Error: ${items[0].json.error.message}`);
}

if (items[0].json.content && items[0].json.content.length > 0) {
  return items[0].json.content[0].text;
} else {
  throw new Error("No content in Claude response");
}
```

---

## 2. OpenAI Example

### HTTP Request Setup

```json
{
  "name": "Call OpenAI API",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.openai.com/v1/chat/completions",
    "method": "POST",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer {{$env.OPENAI_API_KEY}}"
        },
        {
          "name": "content-type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "body": {
      "json": {
        "model": "={{$env.AI_MODEL}}",
        "temperature": 0.7,
        "max_tokens": 2048,
        "messages": [
          {
            "role": "system",
            "content": "You are an expert marketing CMO specializing in social media content creation."
          },
          {
            "role": "user",
            "content": "={{$node['Parse Website Content'].json.markdown_content}}"
          }
        ]
      }
    }
  }
}
```

### Response Parsing for OpenAI

```javascript
// OpenAI response structure differs from Claude
return {
  success: true,
  response: items[0].json.choices[0].message.content,
  usage: {
    input_tokens: items[0].json.usage.prompt_tokens,
    output_tokens: items[0].json.usage.completion_tokens,
    total_tokens: items[0].json.usage.total_tokens
  },
  model: items[0].json.model
};
```

### Full Request with System Prompt

```json
{
  "model": "gpt-4o",
  "temperature": 0.8,
  "max_tokens": 4096,
  "system": {
    "role": "system",
    "content": "You are an expert CMO specializing in multi-channel marketing. Generate unique, platform-optimized content. For each platform, ensure:\n- LinkedIn: Professional, thought-leadership focused\n- Twitter: Viral hooks, engagement-first\n- Instagram: Visual storytelling, emojis appropriate\n- Facebook: Community building, CTAs"
  },
  "messages": [
    {
      "role": "user",
      "content": "Website content: {website_markdown}\n\nGenerate posts as JSON with linkedin, twitter, instagram, facebook keys"
    }
  ]
}
```

### Using n8n's Native ChatGPT Node (Alternative)

If available in your n8n version:

```json
{
  "name": "Ask ChatGPT",
  "type": "n8n-nodes-base.openAi",
  "parameters": {
    "authentication": "predefined",
    "resource": "message",
    "operation": "create",
    "model": "gpt-4o",
    "messages": {
      "values": [
        {
          "messageType": "system",
          "textInput": "You are a marketing expert..."
        },
        {
          "messageType": "user",
          "textInput": "={{$node['trigger'].json.content}}"
        }
      ]
    }
  }
}
```

---

## 3. Replicate Example

### HTTP Request Setup

```json
{
  "name": "Call Replicate API",
  "type": "n8n-nodes-base.httpRequest",
  "parameters": {
    "url": "https://api.replicate.com/v1/predictions",
    "method": "POST",
    "sendHeaders": true,
    "headerParameters": {
      "parameters": [
        {
          "name": "Authorization",
          "value": "Bearer {{$env.REPLICATE_API_TOKEN}}"
        },
        {
          "name": "content-type",
          "value": "application/json"
        }
      ]
    },
    "sendBody": true,
    "body": {
      "json": {
        "version": "2c1608e18606feda752c7d6d27d9974e5f36bada1301c8b3b287f15985f373a6",
        "input": {
          "prompt": "Generate marketing content: {{$node['Parse Website'].json.content}}"
        }
      }
    }
  }
}
```

### Polling for Async Results

Replicate returns async predictions, so you need to poll for results:

```javascript
// Workflow: Predict → Wait → Poll for Status → Get Results

// Node 1: Start Prediction
// (HTTP POST as above)

// Node 2: Extract Prediction ID
return {
  prediction_id: items[0].json.id,
  status: items[0].json.status
};

// Node 3: Wait (delay node)
// Set to wait 30-60 seconds

// Node 4: Check Status (HTTP GET)
const prediction_id = items[0].json.prediction_id;
// GET https://api.replicate.com/v1/predictions/{prediction_id}

// Node 5: Parse Output
if (items[0].json.status === "succeeded") {
  return items[0].json.output;
} else if (items[0].json.status === "failed") {
  throw new Error(`Prediction failed: ${items[0].json.error}`);
} else {
  // Still processing - may need another poll
  return { status: items[0].json.status, prediction_id };
}
```

### Complete Async Workflow

```json
{
  "name": "Replicate Marketing Content - Async",
  "nodes": [
    {
      "id": "webhook",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "marketing-content",
        "method": "POST"
      }
    },
    {
      "id": "start_prediction",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://api.replicate.com/v1/predictions",
        "method": "POST",
        "headers": {
          "Authorization": "Bearer {{$env.REPLICATE_API_TOKEN}}"
        },
        "body": {
          "version": "2c1608e18606feda752c7d6d27d9974e5f36bada1301c8b3b287f15985f373a6",
          "input": {
            "prompt": "{{$node.webhook.json.content}}"
          }
        }
      }
    },
    {
      "id": "extract_id",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "return items[0].json.id"
      }
    },
    {
      "id": "wait",
      "type": "n8n-nodes-base.wait",
      "parameters": {
        "waitType": "duration",
        "duration": 60
      }
    },
    {
      "id": "poll_result",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://api.replicate.com/v1/predictions/{{$node.extract_id.json}}",
        "method": "GET",
        "headers": {
          "Authorization": "Bearer {{$env.REPLICATE_API_TOKEN}}"
        }
      }
    },
    {
      "id": "parse_output",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "if (items[0].json.status === 'succeeded') { return items[0].json.output; } else { throw new Error(items[0].json.status); }"
      }
    }
  ]
}
```

---

## 4. Conditional Provider Selection

If you want to support multiple providers, use a conditional node:

```javascript
// Function node to route to correct LLM
const provider = $env.AI_MODEL.includes('claude') ? 'claude' :
                 $env.AI_MODEL.includes('gpt') ? 'openai' :
                 'replicate';

return {
  provider: provider,
  model: $env.AI_MODEL
};
```

Then add conditional branches in your workflow:
- If claude → Call Claude API
- If openai → Call OpenAI API
- If replicate → Call Replicate API

---

## 5. Error Handling Patterns

### Retry with Exponential Backoff

```javascript
// In a Function node after HTTP Request
const MAX_RETRIES = 3;
const BASE_DELAY = 1000; // 1 second

async function callWithRetry(fn, retryCount = 0) {
  try {
    return await fn();
  } catch (error) {
    if (retryCount < MAX_RETRIES && error.statusCode >= 500) {
      const delay = BASE_DELAY * Math.pow(2, retryCount);
      await new Promise(resolve => setTimeout(resolve, delay));
      return callWithRetry(fn, retryCount + 1);
    }
    throw error;
  }
}
```

### Graceful Fallback

```javascript
// Try primary LLM, fallback to secondary
if ($env.AI_MODEL === 'claude-opus-4-5-20251101') {
  // Try Claude
  try {
    // Call Claude
  } catch (error) {
    // Fall back to GPT-3.5
    // Call OpenAI with gpt-3.5-turbo
  }
}
```

---

## 6. Token Counting and Cost Estimation

### Claude Token Estimation

```javascript
// Rough token estimation (1 token ≈ 4 characters)
const inputLength = items[0].json.input.length;
const outputLength = 2000; // Average output

const inputTokens = Math.ceil(inputLength / 4);
const outputTokens = Math.ceil(outputLength / 4);

const inputCost = (inputTokens / 1000000) * 3; // $3 per 1M
const outputCost = (outputTokens / 1000000) * 15; // $15 per 1M

return {
  estimated_input_tokens: inputTokens,
  estimated_output_tokens: outputTokens,
  estimated_cost: (inputCost + outputCost).toFixed(4)
};
```

### OpenAI Token Usage (from response)

```javascript
const tokenUsage = items[0].json.usage;

const inputCost = (tokenUsage.prompt_tokens / 1000000) * 5; // $5 per 1M
const outputCost = (tokenUsage.completion_tokens / 1000000) * 15; // $15 per 1M

return {
  actual_input_tokens: tokenUsage.prompt_tokens,
  actual_output_tokens: tokenUsage.completion_tokens,
  actual_cost: (inputCost + outputCost).toFixed(4)
};
```

---

## 7. Testing in n8n UI

### Create a Simple Test Workflow

1. **Create Workflow**
   - New → Blank Workflow

2. **Add Webhook Trigger**
   - Node Type: Webhook
   - HTTP Method: POST
   - Path: `/test-llm`

3. **Add HTTP Request Node**
   - Choose your provider
   - Copy configuration from above
   - Test with sample content

4. **Add Function Node to Parse**
   - Copy response parsing code from above

5. **Test**
   - Click "Listen for Webhook"
   - Use curl to test:
   ```bash
   curl -X POST http://localhost:5678/webhook/test-llm \
     -H "Content-Type: application/json" \
     -d '{"content": "Test marketing content"}'
   ```

---

## 8. Rate Limiting

### Implement Rate Limiting in n8n

```javascript
// Store last request time in workflow
const lastRequestTime = $workflowData.lastRequestTime || 0;
const currentTime = Date.now();
const minInterval = 1000; // Minimum 1 second between requests

if (currentTime - lastRequestTime < minInterval) {
  const waitTime = minInterval - (currentTime - lastRequestTime);
  // Queue request for later
  return { queued: true, waitTime };
}

$workflowData.lastRequestTime = currentTime;
return { ready: true };
```

---

## Summary Table

| Feature | Claude | OpenAI | Replicate |
|---------|--------|--------|-----------|
| **n8n Node Type** | HTTP Request | HTTP Request / ChatGPT | HTTP Request |
| **Async** | No | No | Yes |
| **Response Format** | `.content[0].text` | `.choices[0].message.content` | `.output` (after polling) |
| **Auth** | x-api-key header | Authorization header | Authorization header |
| **Cost Estimation** | Manual calc | From `.usage` | Variable |
| **Retry Logic** | Simple | Simple | Polling required |

---

**Last Updated**: 2025-12-27
**Version**: 1.0
