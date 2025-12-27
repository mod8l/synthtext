-- AutoMarket OS Database Schema
-- PostgreSQL Schema for storing campaigns, posts, metrics, and tracking data

-- Create schema
CREATE SCHEMA IF NOT EXISTS automarket;

-- Campaigns table - stores each campaign execution
CREATE TABLE automarket.campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Source information
  website_url TEXT NOT NULL,
  brand_title TEXT,
  brand_description TEXT,

  -- Content analysis
  brand_analysis JSONB,  -- Stores brand_analysis from LLM

  -- Quality metrics
  completeness_score INT CHECK (completeness_score >= 0 AND completeness_score <= 100),
  is_valid BOOLEAN DEFAULT FALSE,
  validation_errors TEXT[] DEFAULT '{}',
  validation_warnings TEXT[] DEFAULT '{}',

  -- Workflow integration
  mixpost_campaign_id TEXT,
  crm_campaign_id TEXT,

  -- Status tracking
  status VARCHAR(50) DEFAULT 'draft' CHECK (status IN (
    'draft',
    'validated',
    'scheduled',
    'published',
    'completed',
    'failed',
    'archived'
  )),

  -- Audit trail
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  published_at TIMESTAMP,
  completed_at TIMESTAMP,

  -- Metadata
  metadata JSONB DEFAULT '{}',

  INDEX idx_status (status),
  INDEX idx_created_at (created_at),
  INDEX idx_website_url (website_url),
  INDEX idx_updated_at (updated_at)
);

-- Posts table - stores individual posts per campaign
CREATE TABLE automarket.posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES automarket.campaigns(id) ON DELETE CASCADE,

  -- Platform info
  platform VARCHAR(50) NOT NULL CHECK (platform IN (
    'linkedin',
    'twitter',
    'instagram',
    'facebook'
  )),

  -- Content
  content TEXT NOT NULL,
  character_count INT,

  -- Scheduling
  scheduled_at TIMESTAMP,
  published_at TIMESTAMP,

  -- Mixpost integration
  mixpost_post_id TEXT,

  -- Status
  status VARCHAR(50) DEFAULT 'draft' CHECK (status IN (
    'draft',
    'scheduled',
    'published',
    'failed'
  )),

  -- Metrics
  impressions INT DEFAULT 0,
  clicks INT DEFAULT 0,
  engagements INT DEFAULT 0,

  -- Audit
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_campaign_id (campaign_id),
  INDEX idx_platform (platform),
  INDEX idx_status (status),
  INDEX idx_scheduled_at (scheduled_at)
);

-- Campaign metrics - tracks performance over time
CREATE TABLE automarket.metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID NOT NULL REFERENCES automarket.posts(id) ON DELETE CASCADE,

  -- Metric info
  metric_name VARCHAR(100) NOT NULL,
  metric_value DECIMAL(10, 2),
  metric_unit VARCHAR(50),

  -- When recorded
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_post_id (post_id),
  INDEX idx_metric_name (metric_name),
  INDEX idx_recorded_at (recorded_at)
);

-- UTM tracking - stores UTM parameters for link tracking
CREATE TABLE automarket.utm_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES automarket.campaigns(id) ON DELETE CASCADE,
  post_id UUID REFERENCES automarket.posts(id) ON DELETE SET NULL,

  -- UTM parameters
  utm_source VARCHAR(100) DEFAULT 'automarket',
  utm_medium VARCHAR(100),
  utm_campaign VARCHAR(100),
  utm_content VARCHAR(100),
  utm_term VARCHAR(100),

  -- Generated URL
  tracking_url TEXT,

  -- Tracking
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_campaign_id (campaign_id),
  INDEX idx_utm_source (utm_source),
  INDEX idx_tracking_url (tracking_url)
);

-- Leads table - tracks leads from campaigns
CREATE TABLE automarket.leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID NOT NULL REFERENCES automarket.campaigns(id) ON DELETE CASCADE,
  post_id UUID REFERENCES automarket.posts(id) ON DELETE SET NULL,

  -- Lead info
  email VARCHAR(255),
  name VARCHAR(255),
  company VARCHAR(255),

  -- Source tracking
  utm_source VARCHAR(100),
  utm_medium VARCHAR(100),
  utm_campaign VARCHAR(100),
  source_platform VARCHAR(50),

  -- Lead status
  status VARCHAR(50) DEFAULT 'new' CHECK (status IN (
    'new',
    'contacted',
    'qualified',
    'converted',
    'lost'
  )),

  -- CRM integration
  crm_lead_id TEXT,

  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  contacted_at TIMESTAMP,
  converted_at TIMESTAMP,

  INDEX idx_campaign_id (campaign_id),
  INDEX idx_email (email),
  INDEX idx_status (status),
  INDEX idx_utm_campaign (utm_campaign)
);

-- Execution logs - audit trail for workflow execution
CREATE TABLE automarket.execution_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id UUID REFERENCES automarket.campaigns(id) ON DELETE CASCADE,

  -- Execution info
  workflow_name VARCHAR(255),
  workflow_id TEXT,
  execution_id TEXT,

  -- Status
  status VARCHAR(50) CHECK (status IN (
    'started',
    'in_progress',
    'success',
    'failed',
    'error'
  )),

  -- Details
  error_message TEXT,
  duration_ms INT,

  -- Timestamps
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,

  INDEX idx_campaign_id (campaign_id),
  INDEX idx_status (status),
  INDEX idx_started_at (started_at)
);

-- API usage tracking - monitor costs
CREATE TABLE automarket.api_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Service info
  service_name VARCHAR(100) NOT NULL,
  endpoint VARCHAR(255),

  -- Usage metrics
  request_count INT DEFAULT 1,
  token_count INT,
  cost_cents DECIMAL(10, 2),

  -- Time period
  usage_date DATE DEFAULT CURRENT_DATE,

  -- Details
  metadata JSONB DEFAULT '{}',

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_service_name (service_name),
  INDEX idx_usage_date (usage_date)
);

-- ============================================================
-- Views for common queries
-- ============================================================

-- View: Recent campaigns
CREATE VIEW automarket.v_recent_campaigns AS
SELECT
  c.id,
  c.website_url,
  c.brand_title,
  c.status,
  c.completeness_score,
  COUNT(p.id) as post_count,
  c.created_at
FROM automarket.campaigns c
LEFT JOIN automarket.posts p ON c.id = p.campaign_id
GROUP BY c.id
ORDER BY c.created_at DESC
LIMIT 100;

-- View: Campaign performance
CREATE VIEW automarket.v_campaign_performance AS
SELECT
  c.id,
  c.brand_title,
  COUNT(DISTINCT p.id) as total_posts,
  SUM(p.impressions) as total_impressions,
  SUM(p.clicks) as total_clicks,
  SUM(p.engagements) as total_engagements,
  COUNT(DISTINCT l.id) as total_leads,
  c.created_at
FROM automarket.campaigns c
LEFT JOIN automarket.posts p ON c.id = p.campaign_id
LEFT JOIN automarket.leads l ON c.id = l.campaign_id
GROUP BY c.id;

-- View: Platform breakdown
CREATE VIEW automarket.v_platform_stats AS
SELECT
  p.platform,
  COUNT(*) as post_count,
  SUM(p.impressions) as total_impressions,
  SUM(p.clicks) as total_clicks,
  AVG(p.character_count) as avg_length,
  COUNT(CASE WHEN p.status = 'published' THEN 1 END) as published_count
FROM automarket.posts p
GROUP BY p.platform;

-- ============================================================
-- Triggers for automated updates
-- ============================================================

-- Auto-update campaign timestamp
CREATE OR REPLACE FUNCTION automarket.update_campaign_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_campaign_update_timestamp
BEFORE UPDATE ON automarket.campaigns
FOR EACH ROW
EXECUTE FUNCTION automarket.update_campaign_timestamp();

-- Auto-update post timestamp
CREATE OR REPLACE FUNCTION automarket.update_post_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_post_update_timestamp
BEFORE UPDATE ON automarket.posts
FOR EACH ROW
EXECUTE FUNCTION automarket.update_post_timestamp();

-- ============================================================
-- Indexes for optimal performance
-- ============================================================

CREATE INDEX idx_campaigns_status_created
  ON automarket.campaigns(status, created_at DESC);

CREATE INDEX idx_posts_campaign_platform
  ON automarket.posts(campaign_id, platform);

CREATE INDEX idx_leads_campaign_status
  ON automarket.leads(campaign_id, status);

CREATE INDEX idx_utm_campaign_utm_source
  ON automarket.utm_tracking(campaign_id, utm_source);

CREATE INDEX idx_execution_logs_campaign_status
  ON automarket.execution_logs(campaign_id, status);

CREATE INDEX idx_api_usage_service_date
  ON automarket.api_usage(service_name, usage_date);

-- ============================================================
-- Grant permissions (run as superuser)
-- ============================================================

-- GRANT USAGE ON SCHEMA automarket TO n8n_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA automarket TO n8n_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA automarket TO n8n_user;

-- ============================================================
-- Notes for maintenance
-- ============================================================

-- Archive old campaigns (keep ~1 year)
-- DELETE FROM automarket.campaigns
-- WHERE created_at < CURRENT_DATE - INTERVAL '1 year';

-- Vacuum and analyze (run monthly)
-- VACUUM ANALYZE automarket.*;

-- Backup recommendations
-- PostgreSQL native: pg_dump automarket
-- Or use pg_basebackup for physical backup

