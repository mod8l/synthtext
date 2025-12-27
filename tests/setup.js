// Jest Setup File for AutoMarket OS Tests
// Runs before all tests to configure environment

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'debug';

// Extend Jest timeout for integration tests
jest.setTimeout(60000);

// Global test utilities
global.testUtils = {
  /**
   * Wait for a specified duration
   */
  wait: (ms) => new Promise(resolve => setTimeout(resolve, ms)),

  /**
   * Create a mock LLM response
   */
  mockLLMResponse: (platform = 'claude', includeAnalysis = true) => {
    const response = {
      posts: {
        linkedin: 'Professional LinkedIn post about our product',
        twitter: 'Catchy tweet with hashtags #tech #marketing',
        instagram: 'Visual Instagram post with emoji 🚀',
        facebook: 'Community-focused Facebook post'
      }
    };

    if (includeAnalysis) {
      response.brand_analysis = {
        title: 'Test Company',
        key_usps: ['Feature 1', 'Feature 2'],
        target_audience: 'Businesses',
        brand_voice: 'Professional'
      };
    }

    if (platform === 'claude') {
      return {
        content: [{
          type: 'text',
          text: JSON.stringify(response)
        }],
        usage: {
          input_tokens: 500,
          output_tokens: 200
        }
      };
    } else if (platform === 'openai') {
      return {
        choices: [{
          message: {
            content: JSON.stringify(response)
          }
        }],
        usage: {
          prompt_tokens: 500,
          completion_tokens: 200
        }
      };
    }

    return response;
  },

  /**
   * Create a mock Firecrawl response
   */
  mockFirecrawlResponse: () => ({
    success: true,
    data: {
      markdown: '# Test Company\n\nWe provide marketing automation solutions.',
      metadata: {
        title: 'Test Company',
        description: 'Marketing automation platform',
        sourceURL: 'https://test.example.com'
      }
    }
  }),

  /**
   * Create a mock database record
   */
  mockDatabaseRecord: () => ({
    id: 'c4a3e8f0-9c7b-4a3f-8e5d-2f1c3b4a5d6e',
    website_url: 'https://test.example.com',
    brand_title: 'Test Company',
    completeness_score: 95,
    is_valid: true,
    validation_errors: [],
    validation_warnings: [],
    status: 'validated',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  }),

  /**
   * Create a mock Mixpost response
   */
  mockMixpostResponse: () => ({
    success: true,
    scheduled_posts: 4,
    scheduled_ids: [
      'post-linkedin-123',
      'post-twitter-456',
      'post-instagram-789',
      'post-facebook-012'
    ]
  }),

  /**
   * Create a mock CRM response
   */
  mockCRMResponse: () => ({
    campaign_id: 'crm-campaign-12345',
    name: 'AutoMarket Campaign',
    status: 'active',
    created_at: new Date().toISOString()
  })
};

// Mock console methods to reduce noise
const originalLog = console.log;
const originalWarn = console.warn;
const originalError = console.error;

// Only show errors in tests
if (process.env.QUIET_LOGS === 'true') {
  console.log = jest.fn();
  console.warn = jest.fn();
  console.error = jest.fn((msg) => originalError(msg));
}

// Cleanup after all tests
afterAll(() => {
  jest.restoreAllMocks();
  if (process.env.QUIET_LOGS === 'true') {
    console.log = originalLog;
    console.warn = originalWarn;
    console.error = originalError;
  }
});
