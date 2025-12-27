# Phase 6: Social Media Native APIs - LinkedIn, Twitter, Instagram, Facebook

Complete guide for integrating native platform APIs for direct publishing, analytics, and engagement tracking.

---

## Phase 6 Overview

Phase 6 extends AutoMarket OS with native social media API integrations, allowing:
- **Direct Publishing** to platforms (bypass Mixpost if desired)
- **Native Analytics** (impressions, clicks, engagement)
- **Platform Features** (rich media, hashtag suggestions, trends)
- **Lead Tracking** (click-through, share tracking)
- **Engagement Monitoring** (comments, mentions, DMs)

```
Phase 5 Flow (Mixpost Staging):
Posts → Mixpost (24h review) → Publish

Phase 6 Flow (Direct + Monitoring):
Posts → Direct Publish (when ready) → Monitor Analytics
            ↓
         Mixpost (optional staging)
```

---

## 1. LinkedIn Native API Integration

### Setup: Create LinkedIn App

**1. Create LinkedIn Developer Account**
- Go to https://www.linkedin.com/developers/
- Sign in with LinkedIn account
- Accept Developer Agreement

**2. Create New App**
1. Dashboard → "Create app"
2. **App name**: AutoMarket OS
3. **LinkedIn Page**: Create or select
4. **App logo**: Upload logo
5. **Legal agreement**: Check
6. **Create app**

**3. Get Credentials**
- Go to **Auth** tab
- Copy **Client ID**
- Copy **Client Secret**
- Set **Redirect URLs**: `http://localhost:5678/callback` (and production URL)

**4. Request Access**
- Go to **Products** tab
- Request: Sign in with LinkedIn
- Request: Share on LinkedIn
- Request: Organization Lookup (for analytics)
- Wait for approval (usually 1-2 hours)

### LinkedIn API Configuration

**Environment Variables**:
```bash
LINKEDIN_CLIENT_ID: "your_client_id"
LINKEDIN_CLIENT_SECRET: "your_client_secret"
LINKEDIN_ACCESS_TOKEN: "your_access_token"
LINKEDIN_REFRESH_TOKEN: "your_refresh_token"
LINKEDIN_ORG_ID: "your_organization_id"
```

**Token Acquisition - OAuth 2.0 Flow**:

1. Redirect user to:
```
https://www.linkedin.com/oauth/v2/authorization?
  response_type=code&
  client_id=YOUR_CLIENT_ID&
  redirect_uri=http://localhost:5678/callback&
  scope=w_member_social,r_organization_social
```

2. User authorizes
3. Redirected to callback with `code`
4. Exchange code for token:
```bash
curl -X POST https://www.linkedin.com/oauth/v2/accessToken \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=authorization_code&code=$CODE&client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&redirect_uri=$REDIRECT_URI"
```

5. Response includes access_token and refresh_token

### LinkedIn API: Create Post

**n8n Node Configuration**:
```json
{
  "url": "https://api.linkedin.com/v2/ugcPosts",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.LINKEDIN_ACCESS_TOKEN}}",
    "LinkedIn-Version": "202401",
    "Content-Type": "application/json"
  },
  "body": {
    "author": "urn:li:person:{{$env.LINKEDIN_PERSON_ID}}",
    "lifecycleState": "PUBLISHED",
    "specificContent": {
      "com.linkedin.ugc.PublishText": {
        "text": "={{$json.posts.linkedin}}"
      }
    },
    "visibility": {
      "com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"
    }
  }
}
```

### LinkedIn API: Get Analytics

**Endpoint**: GET `/v2/organizationalEntityAcls?q=roleAssignee&role=ADMIN&state=APPROVED`

Track post performance:
```json
{
  "url": "https://api.linkedin.com/v2/socialActions?q=object&object=urn:li:ugcPost:{{$json.linkedin_post_id}}",
  "method": "GET",
  "headers": {
    "Authorization": "Bearer {{$env.LINKEDIN_ACCESS_TOKEN}}"
  }
}
```

Returns: impressions, clicks, engagements

---

## 2. Twitter/X Native API Integration

### Setup: Create Twitter Developer Account

**1. Create Developer Account**
- Go to https://developer.twitter.com/
- Apply for access with your use case
- Wait for approval (1-7 days)

**2. Create App**
1. Developer Portal → Projects & Apps
2. **Create app** in your project
3. **Name**: AutoMarket OS
4. Accept terms

**3. Get API Credentials**
- Go to **Keys and tokens** tab
- Copy **API Key** (Consumer Key)
- Copy **API Secret Key** (Consumer Secret)
- Copy **Bearer Token**
- Generate **Access Token & Secret**

**4. Set Permissions**
- App settings → Permissions
- Set to **Read and Write + Direct Messages** (if needed)

### Twitter API v2 Configuration

**Environment Variables**:
```bash
TWITTER_API_KEY: "your_api_key"
TWITTER_API_SECRET: "your_api_secret"
TWITTER_BEARER_TOKEN: "your_bearer_token"
TWITTER_ACCESS_TOKEN: "your_access_token"
TWITTER_ACCESS_SECRET: "your_access_secret"
```

### Twitter API: Create Tweet

**n8n Node Configuration**:
```json
{
  "url": "https://api.twitter.com/2/tweets",
  "method": "POST",
  "headers": {
    "Authorization": "Bearer {{$env.TWITTER_BEARER_TOKEN}}",
    "Content-Type": "application/json"
  },
  "body": {
    "text": "={{$json.posts.twitter}}",
    "reply_settings": "everyone"
  }
}
```

### Twitter API: Get Metrics

Track tweet performance:
```json
{
  "url": "https://api.twitter.com/2/tweets/{{$json.twitter_tweet_id}}?tweet.fields=public_metrics,created_at",
  "method": "GET",
  "headers": {
    "Authorization": "Bearer {{$env.TWITTER_BEARER_TOKEN}}"
  }
}
```

Returns: impression_count, like_count, reply_count, retweet_count

---

## 3. Instagram Graph API Integration

### Setup: Create Meta Developer Account

**1. Create Meta Developer Account**
- Go to https://developers.facebook.com/
- Sign in with Facebook/Instagram account
- Create app

**2. Add Instagram Product**
1. My Apps → App → Add Product
2. Select Instagram Graph API
3. Accept terms

**3. Get Business Account**
- Must have Instagram Business Account (not Personal)
- Convert at Instagram Settings → Account Type

**4. Get Credentials**
- App → Settings → Basic
- Copy **App ID**
- Copy **App Secret**
- Generate **Instagram Business Account ID**

### Instagram API Configuration

**Environment Variables**:
```bash
INSTAGRAM_BUSINESS_ACCOUNT_ID: "your_account_id"
INSTAGRAM_ACCESS_TOKEN: "your_access_token"
INSTAGRAM_APP_ID: "your_app_id"
INSTAGRAM_APP_SECRET: "your_app_secret"
```

**Get Access Token**:
1. Go to Graph API Explorer
2. Select: "App Tokens"
3. Generate long-lived access token
4. Save token (valid 60 days)

### Instagram API: Create Post

**n8n Node Configuration**:
```json
{
  "url": "https://graph.instagram.com/{{$env.INSTAGRAM_BUSINESS_ACCOUNT_ID}}/media",
  "method": "POST",
  "body": {
    "image_url": "https://example.com/image.jpg",
    "caption": "={{$json.posts.instagram}}",
    "access_token": "{{$env.INSTAGRAM_ACCESS_TOKEN}}"
  }
}
```

Then publish:
```json
{
  "url": "https://graph.instagram.com/{{$json.instagram_media_id}}/publish",
  "method": "POST",
  "body": {
    "access_token": "{{$env.INSTAGRAM_ACCESS_TOKEN}}"
  }
}
```

### Instagram API: Get Insights

Track post performance:
```json
{
  "url": "https://graph.instagram.com/{{$json.instagram_media_id}}/insights?metric=impressions,engagement,reach",
  "method": "GET",
  "body": {
    "access_token": "{{$env.INSTAGRAM_ACCESS_TOKEN}}"
  }
}
```

---

## 4. Facebook Graph API Integration

### Setup: Create Meta App

**1. Follow Same Steps as Instagram**
- https://developers.facebook.com/
- Create App
- Add Facebook Product

**2. Get Credentials**
- App ID
- App Secret
- Page Access Token (from your business page)

**3. Get Page ID**
- Go to Facebook Page Settings → Page ID
- Copy the ID

### Facebook API Configuration

**Environment Variables**:
```bash
FACEBOOK_PAGE_ID: "your_page_id"
FACEBOOK_ACCESS_TOKEN: "your_page_access_token"
FACEBOOK_APP_ID: "your_app_id"
FACEBOOK_APP_SECRET: "your_app_secret"
```

### Facebook API: Create Post

**n8n Node Configuration**:
```json
{
  "url": "https://graph.facebook.com/v18.0/{{$env.FACEBOOK_PAGE_ID}}/feed",
  "method": "POST",
  "body": {
    "message": "={{$json.posts.facebook}}",
    "link": "https://yourdomain.com",
    "access_token": "{{$env.FACEBOOK_ACCESS_TOKEN}}"
  }
}
```

### Facebook API: Get Analytics

Track post performance:
```json
{
  "url": "https://graph.facebook.com/v18.0/{{$json.facebook_post_id}}/insights?metric=post_impressions,post_clicks,post_engaged_users",
  "method": "GET",
  "body": {
    "access_token": "{{$env.FACEBOOK_ACCESS_TOKEN}}"
  }
}
```

---

## Phase 6 Architecture

### Enhanced Workflow with Native APIs

```
Content Generated
    ↓
┌─────────────────────────────────────┐
│  Publishing Options                 │
├─────────────────────────────────────┤
│  ✓ Mixpost (staging + review)       │
│  ✓ Native APIs (direct publish)     │
│  ✓ Hybrid (schedule + monitor)      │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Direct Publishing (Phase 6)         │
├─────────────────────────────────────┤
│  ├→ LinkedIn API                    │
│  ├→ Twitter API                     │
│  ├→ Instagram API                   │
│  └→ Facebook API                    │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│  Analytics & Monitoring             │
├─────────────────────────────────────┤
│  ├→ Impressions                     │
│  ├→ Engagement                      │
│  ├→ Click-through                   │
│  └→ Lead Attribution                │
└─────────────────────────────────────┘
```

---

## n8n Workflow: Phase 6 Integration

### New Nodes to Add

**Conditional Logic** (Choose publishing method):
```javascript
// Function node
if ($json.publish_method === 'direct') {
  return { use_native_apis: true };
} else if ($json.publish_method === 'staging') {
  return { use_mixpost: true };
} else {
  return { use_both: true };
}
```

**LinkedIn Publish Node**:
- Conditional: Only if direct publishing enabled
- Publishes directly to LinkedIn
- Returns post ID

**Twitter Publish Node**:
- Conditional: Only if direct publishing enabled
- Publishes directly to Twitter
- Returns tweet ID

**Instagram Publish Node**:
- Conditional: Only if direct publishing enabled
- Creates and publishes post
- Returns media ID

**Facebook Publish Node**:
- Conditional: Only if direct publishing enabled
- Publishes to page
- Returns post ID

**Analytics Collection Node** (Runs daily):
- Queries each platform API
- Gets metrics for each post
- Stores in database
- Updates CRM

---

## Rate Limits & Quotas

| Platform | Limit | Reset |
|----------|-------|-------|
| LinkedIn | 300 calls/minute | Per minute |
| Twitter | 300 tweets/15 min | Per 15 minutes |
| Instagram | 200 calls/hour | Per hour |
| Facebook | 10 calls/second | Per second |

**Implement Rate Limiting**:
```javascript
// Function node
const RATE_LIMITS = {
  linkedin: { calls: 300, period: 60 },
  twitter: { calls: 300, period: 900 },
  instagram: { calls: 200, period: 3600 },
  facebook: { calls: 10, period: 1 }
};

// Check before publishing
const platform = items[0].json.platform;
const limit = RATE_LIMITS[platform];
// Implement queue/delay logic
```

---

## Security Considerations

✅ **Best Practices**:
- Store tokens in Kubernetes Secrets (not code)
- Use service accounts with minimal permissions
- Rotate tokens every 30-60 days
- Enable OAuth 2.0 for user-based tokens
- Monitor API usage for suspicious activity
- Implement token refresh logic
- Log all publishing events

❌ **Don't**:
- Hardcode API keys in workflow
- Share tokens in messages
- Commit tokens to git
- Use personal account tokens in production
- Ignore rate limits
- Skip request validation

---

## Analytics & Reporting

### Metrics to Track

Per platform:
- Impressions (reach)
- Clicks (engagement)
- Shares/Retweets (virality)
- Comments (conversation)
- Saves/Bookmarks
- Click-through to website

### Database Schema Extension

```sql
ALTER TABLE automarket.posts ADD COLUMN (
  linkedin_post_id TEXT,
  linkedin_impressions INT,
  linkedin_clicks INT,
  linkedin_engagement INT,

  twitter_tweet_id TEXT,
  twitter_impressions INT,
  twitter_engagement INT,

  instagram_media_id TEXT,
  instagram_impressions INT,
  instagram_engagement INT,

  facebook_post_id TEXT,
  facebook_impressions INT,
  facebook_engagement INT
);
```

---

## Comparative: Phase 5 vs Phase 6

| Feature | Phase 5 (Mixpost) | Phase 6 (Native) |
|---------|---|---|
| **Setup Complexity** | Simple (1 service) | Complex (4 APIs) |
| **Approval Process** | None (staging) | Built-in review |
| **Rich Media** | Limited | Full support |
| **Analytics** | Via platform | Direct from API |
| **Cost** | $19/month | Free |
| **Risk** | Low (sandbox) | Higher (live) |
| **Flexibility** | Limited | Full control |
| **Time to implement** | 30 min per platform | 2-3 hours per API |

**Recommendation**: Use both
- Mixpost for review and staging
- Native APIs for insights and direct publishing

---

## Implementation Timeline

| API | Setup | Integration | Testing |
|-----|-------|-------------|---------|
| LinkedIn | 1-2 hours | 2 hours | 1 hour |
| Twitter | 30 min | 1 hour | 30 min |
| Instagram | 1 hour | 1.5 hours | 1 hour |
| Facebook | 1 hour | 1.5 hours | 1 hour |
| **Total** | **4-5 hours** | **6 hours** | **3.5 hours** |

**Phase 6 Total Time**: 13-14 hours (estimated)

---

## Next Steps

1. **Prepare API Credentials**
   - Create developer accounts
   - Request API access
   - Generate tokens

2. **Build n8n Nodes**
   - Add conditional logic
   - Add publishing nodes
   - Add analytics nodes

3. **Test Each Platform**
   - Test direct publishing
   - Verify analytics collection
   - Monitor rate limits

4. **Production Deployment**
   - Setup token refresh
   - Configure monitoring
   - Document procedures

---

## Resources

**LinkedIn**:
- https://learn.microsoft.com/en-us/linkedin/marketing/
- https://learn.microsoft.com/en-us/linkedin/shared/api-reference/ugc-post-api

**Twitter**:
- https://developer.twitter.com/en/docs/twitter-api
- https://developer.twitter.com/en/docs/twitter-api/tweets/manage-tweets/integrate/publish-tweets

**Instagram**:
- https://developers.facebook.com/docs/instagram-api
- https://developers.facebook.com/docs/instagram-api/reference/ig-media

**Facebook**:
- https://developers.facebook.com/docs/facebook-api/overview
- https://developers.facebook.com/docs/graph-api/reference/page-post

---

**Last Updated**: 2025-12-27
**Version**: 1.0
**Time to Implement**: 13-14 hours (estimated)
**Complexity**: Advanced
