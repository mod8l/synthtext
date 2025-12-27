# Phase 7: End-to-End Testing Framework

Complete testing strategy for AutoMarket OS with unit tests, integration tests, performance benchmarking, and load testing.

---

## Phase 7 Overview

Phase 7 ensures AutoMarket OS is robust, performant, and production-ready by:
- **Unit Testing**: Each n8n node in isolation
- **Integration Testing**: Full workflow execution with real APIs
- **Performance Benchmarking**: Response times, throughput, resource usage
- **Load Testing**: System behavior under stress (10, 50, 100 concurrent campaigns)
- **Data Validation**: Accuracy of generated content and database persistence
- **Security Testing**: API key handling, SQL injection prevention

**Testing Coverage**:
- Phases 1-5 (Infrastructure, LLM, Firecrawl, Workflow, Integrations)
- Phase 6 documented but not yet implemented
- Complete end-to-end workflow validation
- Failure scenarios and recovery

---

## Testing Strategy

### Test Pyramid

```
        ▲
       / \
      /   \  E2E Tests (5%)
     /─────\─────────────────
    /       \  Integration (20%)
   /─────────\───────────────
  /           \  Unit Tests (75%)
 /─────────────\
```

**Distribution**:
- **Unit Tests (75%)**: Individual nodes, functions, data transformations
- **Integration Tests (20%)**: Workflow execution, API interactions, database persistence
- **E2E Tests (5%)**: Complete user scenarios from website to published posts

### Test Environments

```
┌─────────────────────────────────────┐
│  Development (Local)                │
│  ├─ Unit tests (fastest)            │
│  ├─ Mock APIs                       │
│  ├─ Test PostgreSQL container       │
│  └─ Run before committing           │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│  Staging (Kubernetes)               │
│  ├─ Integration tests               │
│  ├─ Real (or sandbox) APIs          │
│  ├─ Test data only                  │
│  └─ Full workflow validation        │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│  Production (Kubernetes)            │
│  ├─ Smoke tests (critical path)     │
│  ├─ Real APIs                       │
│  ├─ Production data                 │
│  └─ Continuous monitoring           │
└─────────────────────────────────────┘
```

---

## Unit Tests

### 1. Firecrawl Scraper Node

**Purpose**: Verify website content extraction

**Test File**: `tests/unit/firecrawl-scraper.test.js`

```javascript
describe('Firecrawl Scraper Node', () => {
  const mockApiKey = 'test_key_12345';
  const testUrls = [
    'https://example-marketing.com',
    'https://saas-product.com',
    'https://ecommerce-site.com'
  ];

  beforeEach(() => {
    process.env.FIRECRAWL_API_KEY = mockApiKey;
  });

  test('should extract markdown from valid URL', async () => {
    const mockResponse = {
      success: true,
      data: {
        markdown: '# Example Company\n\nWe provide marketing solutions...',
        metadata: {
          title: 'Example Company',
          description: 'Marketing automation',
          sourceURL: 'https://example.com'
        }
      }
    };

    // Mock HTTP request to Firecrawl
    nock('https://api.firecrawl.dev')
      .post('/v0/scrape')
      .reply(200, mockResponse);

    const result = await scrapeWebsite('https://example.com');

    expect(result.success).toBe(true);
    expect(result.data.markdown).toContain('Example Company');
    expect(result.data.metadata.title).toBeDefined();
  });

  test('should handle timeout errors', async () => {
    nock('https://api.firecrawl.dev')
      .post('/v0/scrape')
      .delayConnection(16000) // Timeout after 15s
      .reply(504);

    await expect(scrapeWebsite('https://example.com'))
      .rejects
      .toThrow('Firecrawl timeout');
  });

  test('should extract only main content', async () => {
    const mockResponse = {
      success: true,
      data: {
        markdown: '# Main Content Only\n\nNot sidebars or nav',
        metadata: { title: 'Page' }
      }
    };

    nock('https://api.firecrawl.dev')
      .post('/v0/scrape', body => {
        return body.onlyMainContent === true;
      })
      .reply(200, mockResponse);

    const result = await scrapeWebsite('https://example.com', {
      onlyMainContent: true
    });

    expect(result.data.markdown).not.toContain('sidebar');
  });

  test('should respect rate limits', async () => {
    const startTime = Date.now();
    const requests = 10;

    for (let i = 0; i < requests; i++) {
      await scrapeWebsite(`https://example${i}.com`);
    }

    const duration = Date.now() - startTime;
    // Free tier: 5 req/min = 12 seconds minimum
    expect(duration).toBeGreaterThanOrEqual(12000);
  });
});
```

### 2. LLM Call Node

**Purpose**: Verify LLM API integration and response parsing

**Test File**: `tests/unit/llm-call.test.js`

```javascript
describe('LLM Call Node', () => {
  const mockPrompt = 'Generate marketing posts from this content...';
  const mockWebsiteContent = '# SaaS Product\n\nWe solve X problem...';

  test('should call Claude API correctly', async () => {
    const mockResponse = {
      content: [{
        type: 'text',
        text: JSON.stringify({
          posts: {
            linkedin: 'Professional LinkedIn post',
            twitter: 'Concise tweet',
            instagram: 'Visual story',
            facebook: 'Community post'
          }
        })
      }],
      usage: { input_tokens: 500, output_tokens: 200 }
    };

    nock('https://api.anthropic.com')
      .post('/v1/messages')
      .reply(200, mockResponse);

    const result = await callLLM({
      model: 'claude-opus-4-5-20251101',
      systemPrompt: mockPrompt,
      userContent: mockWebsiteContent
    });

    expect(result.posts).toBeDefined();
    expect(result.posts.linkedin).toContain('Professional');
    expect(result.usage.input_tokens).toBe(500);
  });

  test('should parse OpenAI response format', async () => {
    const mockResponse = {
      choices: [{
        message: {
          content: JSON.stringify({
            posts: {
              linkedin: 'Post 1',
              twitter: 'Post 2',
              instagram: 'Post 3',
              facebook: 'Post 4'
            }
          })
        }
      }],
      usage: { prompt_tokens: 400, completion_tokens: 150 }
    };

    nock('https://api.openai.com')
      .post('/v1/chat/completions')
      .reply(200, mockResponse);

    const result = await callLLM({
      model: 'gpt-4',
      provider: 'openai',
      systemPrompt: mockPrompt,
      userContent: mockWebsiteContent
    });

    expect(result.posts.linkedin).toBe('Post 1');
  });

  test('should handle token limit errors', async () => {
    nock('https://api.anthropic.com')
      .post('/v1/messages')
      .reply(400, {
        error: {
          type: 'invalid_request_error',
          message: 'Request exceeds max tokens'
        }
      });

    await expect(callLLM({
      model: 'claude-opus-4-5-20251101',
      systemPrompt: mockPrompt,
      userContent: mockWebsiteContent
    })).rejects.toThrow('Token limit');
  });

  test('should retry on rate limit', async () => {
    let callCount = 0;

    nock('https://api.anthropic.com')
      .post('/v1/messages')
      .times(3)
      .reply(() => {
        callCount++;
        if (callCount < 3) {
          return [429, { error: 'rate_limit_exceeded' }];
        }
        return [200, {
          content: [{ type: 'text', text: '{}' }],
          usage: { input_tokens: 100, output_tokens: 50 }
        }];
      });

    const result = await callLLM(
      { model: 'claude-opus-4-5-20251101' },
      { maxRetries: 3, retryDelay: 100 }
    );

    expect(callCount).toBe(3);
  });

  test('should validate JSON response format', async () => {
    const mockResponse = {
      content: [{
        type: 'text',
        text: 'This is not valid JSON'
      }]
    };

    nock('https://api.anthropic.com')
      .post('/v1/messages')
      .reply(200, mockResponse);

    await expect(callLLM({
      model: 'claude-opus-4-5-20251101'
    })).rejects.toThrow('Invalid JSON response');
  });
});
```

### 3. Post Validation Node

**Purpose**: Verify content quality checks and guardrails

**Test File**: `tests/unit/validate-posts.test.js`

```javascript
describe('Post Validation Node', () => {
  test('should reject banned phrases', async () => {
    const posts = {
      linkedin: 'In today\'s fast-paced world, we are a game-changer',
      twitter: 'Check this out!',
      instagram: 'Amazing product',
      facebook: 'Join our community'
    };

    const result = validatePosts(posts);

    expect(result.is_valid).toBe(false);
    expect(result.errors).toContain('linkedin: Banned phrase');
  });

  test('should enforce character limits', async () => {
    const posts = {
      linkedin: 'A'.repeat(3001), // Exceeds 3000 limit
      twitter: 'Tweet',
      instagram: 'Post',
      facebook: 'Post'
    };

    const result = validatePosts(posts);

    expect(result.is_valid).toBe(false);
    expect(result.warnings).toContain('linkedin: Too long');
  });

  test('should reject empty posts', async () => {
    const posts = {
      linkedin: '',
      twitter: 'Tweet',
      instagram: 'Post',
      facebook: 'Post'
    };

    const result = validatePosts(posts);

    expect(result.is_valid).toBe(false);
    expect(result.errors).toContain('linkedin: Missing');
  });

  test('should calculate completeness score', async () => {
    const posts = {
      linkedin: 'Valid LinkedIn post with good content',
      twitter: 'Valid tweet with hashtags #marketing',
      instagram: 'Valid Instagram post with emoji 🚀',
      facebook: 'Valid Facebook post for community'
    };

    const result = validatePosts(posts);

    expect(result.completeness_score).toBe(100);
    expect(result.is_valid).toBe(true);
  });

  test('should detect low quality content', async () => {
    const posts = {
      linkedin: 'Post',  // Too short
      twitter: 'tweet',
      instagram: 'photo',
      facebook: 'status'
    };

    const result = validatePosts(posts);

    expect(result.completeness_score).toBeLessThan(50);
    expect(result.errors.length).toBeGreaterThan(0);
  });
});
```

### 4. Database Insert Node

**Purpose**: Verify database operations

**Test File**: `tests/unit/database-insert.test.js`

```javascript
describe('Database Insert Node', () => {
  let pgClient;

  beforeAll(async () => {
    pgClient = new Pool({
      host: 'localhost',
      port: 5432,
      database: 'test_n8n',
      user: 'test_user',
      password: 'test_pass'
    });
  });

  afterEach(async () => {
    await pgClient.query('DELETE FROM automarket.campaigns WHERE website_url LIKE \'%test%\'');
  });

  afterAll(async () => {
    await pgClient.end();
  });

  test('should insert campaign record', async () => {
    const campaignData = {
      website_url: 'https://test-website.com',
      brand_title: 'Test Brand',
      completeness_score: 95,
      is_valid: true,
      validation_errors: [],
      validation_warnings: []
    };

    const result = await insertCampaign(pgClient, campaignData);

    expect(result.id).toBeDefined();
    expect(result.created_at).toBeDefined();

    // Verify in database
    const dbRecord = await pgClient.query(
      'SELECT * FROM automarket.campaigns WHERE id = $1',
      [result.id]
    );

    expect(dbRecord.rows[0].brand_title).toBe('Test Brand');
    expect(dbRecord.rows[0].completeness_score).toBe(95);
  });

  test('should insert posts with campaign reference', async () => {
    const campaignId = await insertCampaign(pgClient, {
      website_url: 'https://test.com',
      brand_title: 'Test'
    });

    const postsData = [
      {
        campaign_id: campaignId.id,
        platform: 'linkedin',
        content: 'LinkedIn post content',
        character_count: 20
      },
      {
        campaign_id: campaignId.id,
        platform: 'twitter',
        content: 'Tweet content',
        character_count: 13
      }
    ];

    const results = await insertPosts(pgClient, postsData);

    expect(results.length).toBe(2);

    const dbPosts = await pgClient.query(
      'SELECT * FROM automarket.posts WHERE campaign_id = $1',
      [campaignId.id]
    );

    expect(dbPosts.rows.length).toBe(2);
    expect(dbPosts.rows[0].platform).toBe('linkedin');
  });

  test('should enforce data constraints', async () => {
    const invalidData = {
      website_url: 'https://test.com',
      completeness_score: 150 // Exceeds max (100)
    };

    await expect(insertCampaign(pgClient, invalidData))
      .rejects
      .toThrow('CHECK constraint');
  });
});
```

---

## Integration Tests

### 1. Complete Workflow Execution

**Purpose**: Test full workflow from website to database

**Test File**: `tests/integration/workflow.test.js`

```javascript
describe('Complete Workflow Integration', () => {
  const testWebsite = 'https://automarket-test.example.com';
  let workflowId;

  beforeAll(async () => {
    // Import test workflow to n8n
    workflowId = await importTestWorkflow();
  });

  test('should execute complete workflow successfully', async () => {
    const execution = await executeWorkflow(workflowId, {
      website_url: testWebsite
    });

    expect(execution.status).toBe('success');
    expect(execution.duration).toBeLessThan(60000); // Less than 60 seconds

    // Verify execution nodes
    expect(execution.nodeData.firecrawl.success).toBe(true);
    expect(execution.nodeData.llm.posts).toBeDefined();
    expect(execution.nodeData.validation.is_valid).toBe(true);
    expect(execution.nodeData.database.campaign_id).toBeDefined();
  });

  test('should store campaign in database', async () => {
    const execution = await executeWorkflow(workflowId, {
      website_url: testWebsite
    });

    const campaignId = execution.nodeData.database.campaign_id;
    const dbCampaign = await getFromDatabase(
      'SELECT * FROM automarket.campaigns WHERE id = $1',
      [campaignId]
    );

    expect(dbCampaign).toBeDefined();
    expect(dbCampaign.website_url).toBe(testWebsite);
    expect(dbCampaign.status).toBe('validated');
  });

  test('should schedule posts to Mixpost', async () => {
    const execution = await executeWorkflow(workflowId, {
      website_url: testWebsite
    });

    const mixpostResponse = execution.nodeData.mixpost;

    expect(mixpostResponse.success).toBe(true);
    expect(mixpostResponse.scheduled_posts).toBe(4); // LinkedIn, Twitter, Instagram, Facebook
  });

  test('should create CRM campaign record', async () => {
    const execution = await executeWorkflow(workflowId, {
      website_url: testWebsite
    });

    const crmResponse = execution.nodeData.crm;

    expect(crmResponse.campaign_id).toBeDefined();
    expect(crmResponse.status).toBe('active');
  });

  test('should send Slack notification', async () => {
    const execution = await executeWorkflow(workflowId, {
      website_url: testWebsite
    });

    const slackMessage = execution.nodeData.slack;

    expect(slackMessage.channel).toBe('#marketing-automation');
    expect(slackMessage.text).toContain('Campaign Generated');
  });

  test('should handle workflow failure gracefully', async () => {
    const execution = await executeWorkflow(workflowId, {
      website_url: 'https://invalid-url-that-does-not-exist-12345.com'
    });

    expect(execution.status).toBe('error');
    expect(execution.error).toContain('Unable to reach website');
    expect(execution.nodeData.slack.color).toBe('#ff0000'); // Red error notification
  });
});
```

### 2. API Integration Tests

**Purpose**: Test integration with external APIs

**Test File**: `tests/integration/api-integration.test.js`

```javascript
describe('API Integrations', () => {
  const testData = {
    posts: {
      linkedin: 'Test LinkedIn post #marketing',
      twitter: 'Test tweet #automarket',
      instagram: 'Test Instagram post 🚀',
      facebook: 'Test Facebook post'
    },
    brand_title: 'Test Brand'
  };

  describe('Firecrawl Integration', () => {
    test('should scrape real website', async () => {
      const result = await scrapeWebsite('https://www.example.com');

      expect(result.success).toBe(true);
      expect(result.data.markdown).toBeTruthy();
      expect(result.data.markdown.length).toBeGreaterThan(100);
    });

    test('should handle unavailable websites', async () => {
      await expect(
        scrapeWebsite('https://this-domain-definitely-does-not-exist-12345.com')
      ).rejects.toThrow();
    });
  });

  describe('LLM Integration', () => {
    test('should call real LLM API', async () => {
      const result = await callLLM({
        model: process.env.AI_MODEL,
        systemPrompt: 'Generate a marketing post',
        userContent: 'Product: Software tools for marketing'
      });

      expect(result.posts).toBeDefined();
      expect(result.posts.linkedin).toBeTruthy();
      expect(result.posts.linkedin.length).toBeGreaterThan(20);
    });
  });

  describe('Mixpost Integration', () => {
    test('should schedule posts successfully', async () => {
      const result = await scheduleToMixpost({
        workspace_id: process.env.MIXPOST_WORKSPACE_ID,
        posts: testData.posts
      });

      expect(result.success).toBe(true);
      expect(result.scheduled_ids.length).toBe(4);
    });
  });

  describe('Twenty CRM Integration', () => {
    test('should create campaign record', async () => {
      const result = await createCampaignInCRM({
        name: `Test Campaign ${Date.now()}`,
        description: 'Integration test campaign'
      });

      expect(result.campaign_id).toBeDefined();
      expect(result.status).toBe('draft');
    });
  });
});
```

---

## Performance Benchmarking

### 1. Response Time Benchmarks

**Purpose**: Measure execution time of each component

**Test File**: `tests/performance/benchmarks.js`

```javascript
const Benchmark = require('benchmark');
const suite = new Benchmark.Suite;

// Firecrawl scraping benchmark
suite
  .add('Firecrawl scrape', {
    defer: true,
    fn: async (deferred) => {
      await scrapeWebsite('https://example.com');
      deferred.resolve();
    }
  })
  .add('LLM call (Claude)', {
    defer: true,
    fn: async (deferred) => {
      await callLLM({
        model: 'claude-opus-4-5-20251101',
        userContent: 'Test content'
      });
      deferred.resolve();
    }
  })
  .add('Post validation', {
    defer: true,
    fn: async (deferred) => {
      validatePosts({
        linkedin: 'Test post',
        twitter: 'Tweet',
        instagram: 'Post',
        facebook: 'Post'
      });
      deferred.resolve();
    }
  })
  .add('Database insert', {
    defer: true,
    fn: async (deferred) => {
      await insertCampaign(pgClient, {
        website_url: 'https://test.com',
        brand_title: 'Test'
      });
      deferred.resolve();
    }
  })
  .add('Mixpost scheduling', {
    defer: true,
    fn: async (deferred) => {
      await scheduleToMixpost({
        workspace_id: process.env.MIXPOST_WORKSPACE_ID,
        posts: samplePosts
      });
      deferred.resolve();
    }
  })
  .on('complete', function() {
    console.log('Benchmark Results:');
    this.forEach(benchmark => {
      console.log(`${benchmark.name}: ${benchmark.times.period.toFixed(3)}s`);
    });
  })
  .run();

// Expected results (baseline):
// Firecrawl scrape: ~2-5s
// LLM call: ~3-8s
// Post validation: ~0.05s
// Database insert: ~0.1s
// Mixpost scheduling: ~1-2s
// Total workflow: ~8-18s
```

### 2. Resource Usage Monitoring

**Purpose**: Monitor CPU, memory, and network during execution

**Test File**: `tests/performance/resource-monitoring.js`

```javascript
const os = require('os');
const pidusage = require('pidusage');

async function monitorResourceDuringWorkflow() {
  const stats = [];
  const monitoringInterval = setInterval(async () => {
    const usage = await pidusage(process.pid);
    stats.push({
      timestamp: Date.now(),
      cpu: usage.cpu,
      memory: usage.memory,
      cputime: usage.cputime
    });
  }, 100); // Sample every 100ms

  // Execute workflow
  const execution = await executeWorkflow(workflowId, testData);

  clearInterval(monitoringInterval);

  // Analyze statistics
  const avgCpu = stats.reduce((sum, s) => sum + s.cpu, 0) / stats.length;
  const peakMemory = Math.max(...stats.map(s => s.memory));
  const avgMemory = stats.reduce((sum, s) => sum + s.memory, 0) / stats.length;

  console.log('Resource Usage During Workflow:');
  console.log(`Average CPU: ${avgCpu.toFixed(2)}%`);
  console.log(`Peak Memory: ${(peakMemory / 1024 / 1024).toFixed(2)}MB`);
  console.log(`Average Memory: ${(avgMemory / 1024 / 1024).toFixed(2)}MB`);

  // Assertions
  expect(avgCpu).toBeLessThan(80); // Should use less than 80% CPU
  expect(peakMemory).toBeLessThan(500 * 1024 * 1024); // Less than 500MB
}
```

---

## Load Testing

### 1. Concurrent Execution Test

**Purpose**: Test system under load with multiple simultaneous campaigns

**Test File**: `tests/load/concurrent-campaigns.test.js`

```javascript
describe('Load Testing - Concurrent Campaigns', () => {
  test('should handle 10 concurrent campaigns', async () => {
    const campaigns = Array.from({ length: 10 }, (_, i) => ({
      website_url: `https://test-site-${i}.example.com`,
      campaign_id: `campaign-${i}`
    }));

    const startTime = Date.now();
    const results = await Promise.allSettled(
      campaigns.map(c => executeWorkflow(workflowId, c))
    );
    const duration = Date.now() - startTime;

    const successful = results.filter(r => r.status === 'fulfilled');
    const failed = results.filter(r => r.status === 'rejected');

    console.log(`10 Concurrent Campaigns:`);
    console.log(`  Success: ${successful.length}/10`);
    console.log(`  Failed: ${failed.length}/10`);
    console.log(`  Duration: ${duration}ms`);
    console.log(`  Avg per campaign: ${(duration / 10).toFixed(0)}ms`);

    expect(successful.length).toBeGreaterThanOrEqual(8); // At least 80% success
    expect(duration).toBeLessThan(180000); // Less than 3 minutes total
  });

  test('should handle 50 concurrent campaigns', async () => {
    const campaigns = Array.from({ length: 50 }, (_, i) => ({
      website_url: `https://test-site-${i}.example.com`
    }));

    const startTime = Date.now();
    const results = await Promise.allSettled(
      campaigns.map(c => executeWorkflow(workflowId, c))
    );
    const duration = Date.now() - startTime;

    const successful = results.filter(r => r.status === 'fulfilled');

    console.log(`50 Concurrent Campaigns:`);
    console.log(`  Success rate: ${(successful.length / 50 * 100).toFixed(1)}%`);
    console.log(`  Duration: ${duration}ms`);

    expect(successful.length / 50).toBeGreaterThanOrEqual(0.7); // 70% success rate
  });

  test('should handle 100 concurrent campaigns with graceful degradation', async () => {
    const campaigns = Array.from({ length: 100 }, (_, i) => ({
      website_url: `https://test-site-${i}.example.com`
    }));

    const startTime = Date.now();
    const results = await Promise.allSettled(
      campaigns.map(c => executeWorkflow(workflowId, c, { timeout: 30000 }))
    );
    const duration = Date.now() - startTime;

    const successful = results.filter(r => r.status === 'fulfilled');
    const successRate = successful.length / 100;

    console.log(`100 Concurrent Campaigns:`);
    console.log(`  Success rate: ${(successRate * 100).toFixed(1)}%`);
    console.log(`  Duration: ${duration}ms`);

    // System should handle graceful degradation
    expect(successRate).toBeGreaterThanOrEqual(0.5); // At least 50%
  });
});
```

### 2. Kubernetes Pod Resource Test

**Purpose**: Verify Kubernetes Pod resource allocation

**Test File**: `tests/load/kubernetes-resources.test.js`

```javascript
describe('Kubernetes Resource Allocation', () => {
  test('should verify n8n Pod resource requests', async () => {
    const pod = await getKubernetesPod('n8n');

    const requests = pod.spec.containers[0].resources.requests;
    const limits = pod.spec.containers[0].resources.limits;

    // Verify minimum resources
    expect(requests.memory).toBeDefined();
    expect(requests.cpu).toBeDefined();
    expect(limits.memory).toBeDefined();
    expect(limits.cpu).toBeDefined();

    // Verify limits are higher than requests
    expect(parseResource(limits.memory))
      .toBeGreaterThan(parseResource(requests.memory));
    expect(parseResource(limits.cpu))
      .toBeGreaterThan(parseResource(requests.cpu));
  });

  test('should verify PostgreSQL Pod has persistent volume', async () => {
    const pod = await getKubernetesPod('postgres');

    const hasVolume = pod.spec.volumes.some(v =>
      v.persistentVolumeClaim || v.emptyDir
    );

    expect(hasVolume).toBe(true);
  });

  test('should monitor actual resource usage during load', async () => {
    // Execute 50 concurrent workflows
    await executeMultipleWorkflows(50);

    const metrics = await getKubernetesMetrics('n8n');

    console.log('n8n Pod Resource Usage:');
    console.log(`  Current CPU: ${metrics.cpu.currentUtilization}%`);
    console.log(`  Current Memory: ${metrics.memory.currentUtilization}%`);
    console.log(`  Peak CPU: ${metrics.cpu.peakUtilization}%`);
    console.log(`  Peak Memory: ${metrics.memory.peakUtilization}%`);

    // Should stay within limits
    expect(metrics.cpu.peakUtilization).toBeLessThan(100);
    expect(metrics.memory.peakUtilization).toBeLessThan(100);
  });
});
```

---

## Test Data Generation

### 1. Sample Websites for Testing

**File**: `tests/fixtures/sample-websites.json`

```json
{
  "websites": [
    {
      "url": "https://automarket-test-1.example.com",
      "title": "SaaS Product Company",
      "content": "We provide marketing automation software...",
      "expectedScore": 95
    },
    {
      "url": "https://automarket-test-2.example.com",
      "title": "E-commerce Store",
      "content": "Shop for premium goods online...",
      "expectedScore": 85
    },
    {
      "url": "https://automarket-test-3.example.com",
      "title": "Service Agency",
      "content": "Professional consulting services...",
      "expectedScore": 90
    }
  ]
}
```

### 2. Mock API Responses

**File**: `tests/fixtures/mock-responses.js`

```javascript
const mockResponses = {
  firecrawl: {
    success: {
      success: true,
      data: {
        markdown: '# Test Company\n\nWe provide solutions...',
        metadata: {
          title: 'Test Company',
          description: 'Test description',
          sourceURL: 'https://test.com'
        }
      }
    },
    error: {
      success: false,
      error: 'Failed to scrape website'
    }
  },

  llm: {
    claude: {
      content: [{
        type: 'text',
        text: JSON.stringify({
          brand_analysis: {
            title: 'Test Brand',
            key_usps: ['Feature 1', 'Feature 2'],
            target_audience: 'Businesses',
            brand_voice: 'Professional'
          },
          posts: {
            linkedin: 'Professional LinkedIn post...',
            twitter: 'Concise tweet...',
            instagram: 'Visual Instagram post...',
            facebook: 'Community Facebook post...'
          }
        })
      }],
      usage: {
        input_tokens: 500,
        output_tokens: 200
      }
    }
  },

  database: {
    insertSuccess: {
      id: 'c4a3e8f0-9c7b-4a3f-8e5d-2f1c3b4a5d6e',
      created_at: new Date().toISOString(),
      status: 'validated'
    }
  }
};

module.exports = mockResponses;
```

---

## Test Execution & Reporting

### 1. Jest Configuration

**File**: `jest.config.js`

```javascript
module.exports = {
  projects: [
    {
      displayName: 'unit',
      testMatch: ['<rootDir>/tests/unit/**/*.test.js'],
      testTimeout: 10000,
      collectCoverageFrom: [
        'src/**/*.js',
        '!src/**/*.json'
      ]
    },
    {
      displayName: 'integration',
      testMatch: ['<rootDir>/tests/integration/**/*.test.js'],
      testTimeout: 60000,
      runInBand: true // Run integration tests sequentially
    },
    {
      displayName: 'load',
      testMatch: ['<rootDir>/tests/load/**/*.test.js'],
      testTimeout: 300000,
      maxWorkers: 1 // Run load tests in single worker
    }
  ],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/workflows/**'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  reporters: [
    'default',
    ['jest-junit', {
      outputDirectory: './test-results',
      outputName: 'junit.xml'
    }],
    ['jest-html-reporters', {
      publicPath: './test-results',
      filename: 'test-report.html'
    }]
  ]
};
```

### 2. Test Execution Scripts

**File**: `package.json`

```json
{
  "scripts": {
    "test": "jest --coverage",
    "test:unit": "jest --selectProjects=unit",
    "test:integration": "jest --selectProjects=integration",
    "test:load": "jest --selectProjects=load",
    "test:watch": "jest --watch",
    "test:ci": "jest --ci --coverage --reporters=default --reporters=jest-junit",
    "benchmark": "node tests/performance/benchmarks.js",
    "load-test": "k6 run tests/load/k6-script.js",
    "test:all": "npm run test:unit && npm run test:integration && npm run benchmark"
  }
}
```

### 3. GitHub Actions CI/CD Pipeline

**File**: `.github/workflows/test.yml`

```yaml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm run test:unit
      - uses: actions/upload-artifact@v3
        if: failure()
        with:
          name: unit-test-results
          path: test-results/

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: test_n8n
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm install
      - run: npm run test:integration
        env:
          DATABASE_URL: postgresql://test_user:test_pass@localhost:5432/test_n8n
          FIRECRAWL_API_KEY: ${{ secrets.FIRECRAWL_API_KEY }}
          CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
          MIXPOST_API_KEY: ${{ secrets.MIXPOST_API_KEY }}
      - uses: actions/upload-artifact@v3
        if: always()
        with:
          name: integration-test-results
          path: test-results/

  coverage:
    runs-on: ubuntu-latest
    needs: [unit-tests, integration-tests]
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: npm install
      - run: npm run test
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

---

## Validation Checklist

### Pre-Production Validation

- [ ] **Unit Tests**: All pass with 80%+ coverage
- [ ] **Integration Tests**: Full workflow succeeds 100 times consecutively
- [ ] **Performance**: Average workflow time < 20 seconds
- [ ] **Load Test**: 50 concurrent campaigns with 70%+ success rate
- [ ] **Database**: All CRUD operations verified
- [ ] **Firecrawl**: Successfully scrapes 10 different websites
- [ ] **LLM**: All three providers (Claude, OpenAI, Replicate) tested
- [ ] **Mixpost**: Posts successfully scheduled to all 4 platforms
- [ ] **CRM**: Campaign records created with correct mapping
- [ ] **Slack**: Notifications sent correctly for success and failure
- [ ] **Error Handling**: All failure scenarios handled gracefully
- [ ] **Security**: No API keys logged, secrets properly managed
- [ ] **Monitoring**: Resource usage within limits during peak load

### Production Readiness

- [ ] Code review completed
- [ ] Documentation updated
- [ ] Secrets properly rotated
- [ ] Backup procedures tested
- [ ] Monitoring/alerting configured
- [ ] Incident response plan documented
- [ ] Rollback procedure tested

---

## Troubleshooting Failed Tests

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Connection refused" | PostgreSQL not running | `docker run -d postgres:15` or verify Kubernetes pod |
| "API key invalid" | Wrong or expired credentials | Verify secrets in Kubernetes, rotate keys if needed |
| "Timeout exceeded" | LLM taking too long | Increase timeout, check LLM API status |
| "Rate limit exceeded" | Too many API calls | Implement backoff, use mock responses |
| "Database constraint violated" | Invalid test data | Verify schema matches test fixtures |
| "Webhook not triggering" | n8n not running | Restart n8n, check logs for errors |

---

## Performance Baselines

Expected performance metrics after optimization:

```
Component             | Baseline | Target | Status
---------------------|----------|--------|--------
Firecrawl scrape      | 2-5s     | 3-4s   | ✓
LLM call (Claude)     | 3-8s     | 5-6s   | ✓
Post validation       | 0.05s    | 0.05s  | ✓
Database insert       | 0.1s     | 0.1s   | ✓
Mixpost scheduling    | 1-2s     | 1-2s   | ✓
Total workflow        | 8-18s    | 10-15s | ✓
Memory peak           | <500MB   | <400MB | ✓
CPU average           | <40%     | <30%   | ✓
Throughput            | 200 campaigns/day | 500+ | pending
```

---

## Next Steps

After Phase 7 testing is complete:

1. **Review Test Results**: Analyze coverage and identify gaps
2. **Performance Optimization**: Address any slow components
3. **Security Audit**: Review secret handling and API usage
4. **Proceed to Phase 8**: Production deployment and hardening

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Estimated Implementation Time**: 2-3 hours
**Complexity**: Advanced
**Status**: Ready for implementation
