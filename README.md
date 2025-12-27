# AutoMarket OS: Autonomous Marketing System

A production-ready system for autonomous multi-channel marketing campaign generation, execution, and ROI tracking. This system combines AI-driven content strategy with workflow automation to convert website content into targeted social media campaigns across LinkedIn, X, Instagram, and Facebook.

## System Overview

```
Website Content (Firecrawl)
         ↓
    AI Analysis (Master System Prompt)
         ↓
    Campaign Generation (Multi-Channel)
         ↓
    Visual & Copy Optimization
         ↓
    CRM & Analytics Integration
         ↓
    Automated Publishing (Mixpost)
```

## Core Components

### 1. **Master System Prompt** (`/src/system-prompts/master.md`)
The chief CMO persona that:
- Analyzes website Markdown content
- Extracts value propositions and USPs
- Identifies brand voice and tone
- Generates platform-specific content
- Creates visual briefs for image generation
- Tracks campaign ROI through CRM integration

### 2. **Platform Templates** (`/src/templates/`)
- `linkedin.json` - Professional thought leadership
- `twitter.json` - Punchy hooks and threads
- `instagram.json` - Visual storytelling with image prompts
- `facebook.json` - Community engagement and CTAs

### 3. **n8n Workflow** (`/src/workflows/automarket-campaign.json`)
Orchestrates the entire pipeline:
- Cron/Webhook triggers
- Firecrawl content extraction
- AI prompt execution
- Response parsing
- Image generation coordination
- Campaign scheduling
- CRM tracking

### 4. **CRM Integration** (`/src/schemas/twenty-crm-schema.json`)
Twenty CRM data structure for:
- Campaign tracking
- Lead categorization
- UTM parameter mapping
- Expected traffic metrics
- Conversion funnels

### 5. **Validation & Guardrails** (`/src/validators/`)
- Content authenticity checks
- Data completeness validation
- Platform-specific constraint enforcement
- No-hallucination rules

## Quick Start

### Prerequisites
- n8n instance (self-hosted or cloud)
- OpenAI/Claude API key for AI prompt execution
- Firecrawl API key for web scraping
- Twenty CRM instance
- Mixpost account for scheduling

### Setup Steps

1. **Configure Environment**
   ```bash
   cp .env.example .env
   # Fill in API keys and workspace IDs
   ```

2. **Deploy n8n Workflow**
   - Import workflow from `/src/workflows/automarket-campaign.json`
   - Configure credentials for Firecrawl, OpenAI, Twenty CRM, Mixpost

3. **Customize Master Prompt**
   - Edit `/src/system-prompts/master.md` for your brand voice
   - Adjust platform constraints in `/src/templates/`

4. **Set Trigger**
   - Schedule daily/weekly Cron
   - Or use Webhook for on-demand campaigns

## Configuration

### Input: Website Content
```markdown
# Your Website Content (from Firecrawl)
- Product descriptions
- Value propositions
- Pricing information
- Recent blog posts
- Team information
```

### Output: Campaign JSON
```json
{
  "campaign_id": "uuid",
  "brand_analysis": {...},
  "posts": {
    "linkedin": {...},
    "twitter": {...},
    "instagram": {...},
    "facebook": {...}
  },
  "crm_tracking": {...},
  "status": "ready_for_approval"
}
```

## Platform-Specific Guidelines

### LinkedIn (3,000 chars max)
- Industry insights and thought leadership
- Data-driven perspectives
- Professional pain point solutions
- Executive-level positioning
- 5-7 day content calendar

### X/Twitter (280 chars max)
- Viral hooks and thread starters
- Controversial takes (brand-appropriate)
- Real-time reactions
- Educational micro-content
- Engagement-first mentality

### Instagram (2,200 chars max)
- Visual storytelling
- Behind-the-scenes content
- User testimonials
- Infographic concepts
- Detailed image generation briefs

### Facebook (No strict limit)
- Community building
- Direct CTAs
- Event announcements
- Long-form narratives
- Discussion prompts

## Creative Brief Structure

Every post includes a Creative Brief for image/video generation:

```json
{
  "subject": "What should be in the frame?",
  "style": "Minimalist|3D Render|Cinematic|Candid",
  "overlay_text": "3-5 high-impact keywords",
  "color_palette": "Primary colors",
  "dimensions": "1200x630 (LinkedIn), 1024x1024 (Instagram), etc.",
  "mood": "Emotional tone"
}
```

## CRM Tracking Strategy

All campaigns use UTM parameters and pre-categorized CTAs:

```
?utm_source=automarket
&utm_medium=linkedin
&utm_campaign={campaign_id}
&utm_content={post_id}
&lead_source=social_{platform}
```

Twenty CRM automatically:
- Creates Lead records with traffic source
- Tags prospects by interest (Product A, Feature X, Pricing Interest)
- Tracks click-through and conversion metrics
- Builds historical ROI reports

## Content Guardrails

✅ **Approved:**
- Facts from website Markdown
- Brand voice consistency
- Platform-specific optimizations
- Call-to-action variety
- Engagement-first thinking

❌ **Prohibited:**
- Hallucinated features/pricing
- Generic fluff ("In today's fast-paced world")
- Inconsistent brand voice
- Misleading CTAs
- Outdated information

## Status Indicators

- **Ready**: All data ≥80% complete, safe to publish
- **Pending Review**: Visual briefs need approval
- **Blocked**: Missing critical data (requires human intervention)

## Autonomous vs. Manual Modes

### Autonomous (Full Auto-Publish)
- All guardrails pass
- Data completeness >95%
- No critical missing data
- Posts scheduled automatically

### Manual Review (Recommended for Launch)
- All posts staged in Mixpost
- Human review 24 hours pre-publish
- Approval via Twenty CRM dashboard
- One-click batch publishing

## Metrics & ROI

Track in Twenty CRM:
- **Impressions**: Via platform APIs
- **Engagement Rate**: Likes, comments, shares
- **Click-Through Rate**: UTM parameter tracking
- **Lead Conversion Rate**: Form submissions → opportunities
- **Cost Per Lead**: Marketing spend ÷ leads generated
- **Customer Acquisition Cost**: Pipeline → closed deals

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│         n8n Workflow Orchestration                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Trigger         Content          AI Analysis      │
│  (Cron/          (Firecrawl)       (Master         │
│   Webhook)  →         →      Prompt)  →           │
│                                                     │
│          ↓                                          │
│  ┌──────────────────────────────────────┐          │
│  │  Platform-Specific Post Generation   │          │
│  ├──────────────────────────────────────┤          │
│  │ LinkedIn | Twitter | Instagram       │          │
│  │ Facebook | Visual Briefs             │          │
│  └──────────────────────────────────────┘          │
│          ↓                                          │
│  ┌──────────────────────────────────────┐          │
│  │   Validation & Guardrails            │          │
│  │   (No hallucinations, brand voice)   │          │
│  └──────────────────────────────────────┘          │
│          ↓                                          │
│  ┌──────────────────────────────────────┐          │
│  │   CRM Integration                    │          │
│  │   (Twenty CRM tracking setup)        │          │
│  └──────────────────────────────────────┘          │
│          ↓                                          │
│  ┌──────────────────────────────────────┐          │
│  │   Mixpost Scheduling                 │          │
│  │   (Auto-publish or manual review)    │          │
│  └──────────────────────────────────────┘          │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## File Structure

```
/synthtext/
├── README.md (this file)
├── .env.example
├── src/
│   ├── system-prompts/
│   │   └── master.md
│   ├── templates/
│   │   ├── linkedin.json
│   │   ├── twitter.json
│   │   ├── instagram.json
│   │   ├── facebook.json
│   │   └── creative-brief.json
│   ├── workflows/
│   │   └── automarket-campaign.json
│   ├── schemas/
│   │   ├── twenty-crm-schema.json
│   │   └── campaign-output-schema.json
│   ├── validators/
│   │   ├── content-validator.ts
│   │   ├── platform-constraints.ts
│   │   └── guardrails.ts
│   └── utils/
│       ├── utm-builder.ts
│       └── brand-analyzer.ts
└── docs/
    ├── PLATFORM_GUIDELINES.md
    ├── CRM_INTEGRATION.md
    ├── TROUBLESHOOTING.md
    └── EXAMPLES.md
```

## Next Steps

1. Review and customize Master System Prompt
2. Configure n8n workflow with your API credentials
3. Test with a sample website URL
4. Set up Mixpost staging and approval workflow
5. Configure Twenty CRM campaign tracking
6. Deploy and monitor first campaign cycle

## Support & Maintenance

- **Updates**: Monitor platform API changes quarterly
- **Guardrails**: Review hallucination log monthly
- **Performance**: Track ROI metrics in Twenty CRM dashboard
- **Customization**: Extend system prompts for niche industries

---

**Version**: 1.0
**Last Updated**: 2025-12-27
**Status**: Production Ready
