// AutoMarket OS - LLM Response Parser Unit Tests
// Tests response parsing for Claude, OpenAI, and Replicate

const parseLLMResponse = (response, provider = 'claude') => {
  let content = '';

  // Extract text content based on provider format
  if (provider === 'claude') {
    if (response.content && response.content[0]) {
      content = response.content[0].text;
    }
  } else if (provider === 'openai') {
    if (response.choices && response.choices[0]) {
      content = response.choices[0].message.content;
    }
  } else if (provider === 'replicate') {
    if (Array.isArray(response)) {
      content = response.join('');
    } else if (response.output) {
      content = response.output;
    }
  }

  // Try to extract JSON from content
  let jsonStr = content;

  // Check for markdown code blocks
  const codeBlockMatch = content.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlockMatch) {
    jsonStr = codeBlockMatch[1];
  }

  // Try to find raw JSON object
  const jsonMatch = jsonStr.match(/(\{[\s\S]*\})/);
  if (jsonMatch) {
    jsonStr = jsonMatch[1];
  }

  // Parse JSON
  let parsed;
  try {
    parsed = JSON.parse(jsonStr);
  } catch (e) {
    throw new Error(`Failed to parse LLM response as JSON: ${e.message}`);
  }

  // Validate structure
  if (!parsed.posts) {
    throw new Error('Response missing "posts" field');
  }

  const requiredPlatforms = ['linkedin', 'twitter', 'instagram', 'facebook'];
  const missingPlatforms = requiredPlatforms.filter(p => !parsed.posts[p]);

  if (missingPlatforms.length > 0) {
    throw new Error(`Response missing platforms: ${missingPlatforms.join(', ')}`);
  }

  return {
    posts: parsed.posts,
    brand_analysis: parsed.brand_analysis,
    raw_response: content,
    parse_success: true,
    provider,
    token_count: {
      input: response.usage?.input_tokens || response.usage?.prompt_tokens || 0,
      output: response.usage?.output_tokens || response.usage?.completion_tokens || 0
    }
  };
};

describe('LLM Response Parser', () => {
  describe('Claude Response Parsing', () => {
    test('should parse Claude API response format', () => {
      const claudeResponse = {
        content: [{
          type: 'text',
          text: JSON.stringify({
            brand_analysis: {
              title: 'Tech Startup',
              key_usps: ['Fast', 'Reliable'],
              target_audience: 'Developers',
              brand_voice: 'Technical'
            },
            posts: {
              linkedin: 'Excited to announce our new platform for developers',
              twitter: 'New dev platform launches today #tech',
              instagram: 'Meet the future of development 🚀',
              facebook: 'Join our tech community'
            }
          })
        }],
        usage: {
          input_tokens: 500,
          output_tokens: 200
        }
      };

      const result = parseLLMResponse(claudeResponse, 'claude');

      expect(result.posts.linkedin).toBeDefined();
      expect(result.parse_success).toBe(true);
      expect(result.provider).toBe('claude');
      expect(result.token_count.input).toBe(500);
      expect(result.token_count.output).toBe(200);
    });

    test('should parse Claude response with markdown code blocks', () => {
      const claudeResponse = {
        content: [{
          type: 'text',
          text: 'Here are the marketing posts:\n\n```json\n' +
                JSON.stringify({
                  posts: {
                    linkedin: 'Post 1',
                    twitter: 'Post 2',
                    instagram: 'Post 3',
                    facebook: 'Post 4'
                  }
                }) +
                '\n```\n\nThese are optimized for each platform.'
        }],
        usage: { input_tokens: 400, output_tokens: 150 }
      };

      const result = parseLLMResponse(claudeResponse, 'claude');

      expect(result.posts.linkedin).toBe('Post 1');
      expect(result.parse_success).toBe(true);
    });

    test('should extract brand_analysis from Claude response', () => {
      const claudeResponse = {
        content: [{
          type: 'text',
          text: JSON.stringify({
            brand_analysis: {
              title: 'SaaS Company',
              key_usps: ['Scalable', 'Secure', 'Simple'],
              target_audience: 'Enterprises',
              brand_voice: 'Professional and innovative'
            },
            posts: {
              linkedin: 'Enterprise solutions',
              twitter: 'SaaS innovation',
              instagram: 'Modern tech',
              facebook: 'Join us'
            }
          })
        }],
        usage: { input_tokens: 300, output_tokens: 100 }
      };

      const result = parseLLMResponse(claudeResponse, 'claude');

      expect(result.brand_analysis.title).toBe('SaaS Company');
      expect(result.brand_analysis.key_usps).toContain('Scalable');
    });
  });

  describe('OpenAI Response Parsing', () => {
    test('should parse OpenAI API response format', () => {
      const openaiResponse = {
        choices: [{
          message: {
            content: JSON.stringify({
              posts: {
                linkedin: 'OpenAI post 1',
                twitter: 'OpenAI post 2',
                instagram: 'OpenAI post 3',
                facebook: 'OpenAI post 4'
              }
            })
          }
        }],
        usage: {
          prompt_tokens: 450,
          completion_tokens: 180
        }
      };

      const result = parseLLMResponse(openaiResponse, 'openai');

      expect(result.posts.linkedin).toBe('OpenAI post 1');
      expect(result.parse_success).toBe(true);
      expect(result.provider).toBe('openai');
      expect(result.token_count.input).toBe(450);
      expect(result.token_count.output).toBe(180);
    });

    test('should parse OpenAI response with markdown code blocks', () => {
      const openaiResponse = {
        choices: [{
          message: {
            content: 'Here are the posts:\n\n```\n' +
                    JSON.stringify({
                      posts: {
                        linkedin: 'GPT Post 1',
                        twitter: 'GPT Post 2',
                        instagram: 'GPT Post 3',
                        facebook: 'GPT Post 4'
                      }
                    }) +
                    '\n```'
          }
        }],
        usage: { prompt_tokens: 350, completion_tokens: 120 }
      };

      const result = parseLLMResponse(openaiResponse, 'openai');

      expect(result.posts.linkedin).toBe('GPT Post 1');
    });
  });

  describe('Replicate Response Parsing', () => {
    test('should parse Replicate array response format', () => {
      const replicateResponse = [
        JSON.stringify({
          posts: {
            linkedin: 'Replicate post 1',
            twitter: 'Replicate post 2',
            instagram: 'Replicate post 3',
            facebook: 'Replicate post 4'
          }
        })
      ];

      const result = parseLLMResponse(replicateResponse, 'replicate');

      expect(result.posts.linkedin).toBe('Replicate post 1');
      expect(result.parse_success).toBe(true);
      expect(result.provider).toBe('replicate');
    });

    test('should parse Replicate output object format', () => {
      const replicateResponse = {
        output: JSON.stringify({
          posts: {
            linkedin: 'Replicate output 1',
            twitter: 'Replicate output 2',
            instagram: 'Replicate output 3',
            facebook: 'Replicate output 4'
          }
        })
      };

      const result = parseLLMResponse(replicateResponse, 'replicate');

      expect(result.posts.linkedin).toBe('Replicate output 1');
    });
  });

  describe('Error Handling', () => {
    test('should throw on missing posts field', () => {
      const invalidResponse = {
        content: [{
          type: 'text',
          text: JSON.stringify({
            brand_analysis: { title: 'Test' }
            // Missing posts field
          })
        }]
      };

      expect(() => {
        parseLLMResponse(invalidResponse, 'claude');
      }).toThrow('Response missing "posts" field');
    });

    test('should throw on missing required platforms', () => {
      const incompleteResponse = {
        content: [{
          type: 'text',
          text: JSON.stringify({
            posts: {
              linkedin: 'Post 1',
              twitter: 'Post 2'
              // Missing instagram and facebook
            }
          })
        }]
      };

      expect(() => {
        parseLLMResponse(incompleteResponse, 'claude');
      }).toThrow('Response missing platforms: instagram, facebook');
    });

    test('should throw on invalid JSON', () => {
      const invalidJsonResponse = {
        content: [{
          type: 'text',
          text: 'This is not valid JSON at all!'
        }]
      };

      expect(() => {
        parseLLMResponse(invalidJsonResponse, 'claude');
      }).toThrow('Failed to parse LLM response as JSON');
    });

    test('should throw on malformed response', () => {
      const malformedResponse = {
        content: [{
          type: 'text',
          text: 'No JSON here, just plain text'
        }]
      };

      expect(() => {
        parseLLMResponse(malformedResponse, 'claude');
      }).toThrow();
    });
  });

  describe('Token Counting', () => {
    test('should count Claude tokens correctly', () => {
      const response = {
        content: [{
          type: 'text',
          text: JSON.stringify({
            posts: {
              linkedin: 'Post 1',
              twitter: 'Post 2',
              instagram: 'Post 3',
              facebook: 'Post 4'
            }
          })
        }],
        usage: {
          input_tokens: 750,
          output_tokens: 350
        }
      };

      const result = parseLLMResponse(response, 'claude');

      expect(result.token_count.input).toBe(750);
      expect(result.token_count.output).toBe(350);
    });

    test('should count OpenAI tokens correctly', () => {
      const response = {
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
        usage: {
          prompt_tokens: 600,
          completion_tokens: 250
        }
      };

      const result = parseLLMResponse(response, 'openai');

      expect(result.token_count.input).toBe(600);
      expect(result.token_count.output).toBe(250);
    });

    test('should handle missing token counts', () => {
      const response = {
        content: [{
          type: 'text',
          text: JSON.stringify({
            posts: {
              linkedin: 'Post 1',
              twitter: 'Post 2',
              instagram: 'Post 3',
              facebook: 'Post 4'
            }
          })
        }]
        // No usage field
      };

      const result = parseLLMResponse(response, 'claude');

      expect(result.token_count.input).toBe(0);
      expect(result.token_count.output).toBe(0);
    });
  });
});

module.exports = { parseLLMResponse };
