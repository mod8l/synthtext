# Quick Fix for "service unavailable" Healthcheck Error

## Your Error
```
Attempt #1 failed with service unavailable. Continuing to retry...
...
1/1 replicas never became healthy!
Healthcheck failed!
```

## Why It's Failing

You only have **ONE service** in Railway, but n8n requires **TWO services**:

1. ✅ n8n Application (you have this)
2. ❌ PostgreSQL Database (you're missing this!)

Additionally, critical environment variables are missing.

## Fix Steps (5 minutes)

### Step 1: Add PostgreSQL Database

1. Go to your Railway project dashboard
2. Click **"+ New"** button (top right)
3. Select **"Database"** → **"PostgreSQL"**
4. Railway will provision it automatically (takes ~1 minute)

### Step 2: Configure Environment Variables

1. Click on your **n8n service** (not the database)
2. Go to **"Variables"** tab
3. Click **"Raw Editor"** or **"Bulk Add"**
4. Copy and paste this entire block:

```bash
NODE_ENV=production
N8N_PORT=$PORT
N8N_PROTOCOL=https
N8N_HOST=0.0.0.0
WEBHOOK_URL=https://$RAILWAY_PUBLIC_DOMAIN
N8N_EDITOR_BASE_URL=https://$RAILWAY_PUBLIC_DOMAIN
N8N_METRICS=true
N8N_METRICS_INCLUDE_API_ENDPOINTS=true
N8N_METRICS_INCLUDE_DEFAULT_METRICS=true
N8N_DIAGNOSTICS_ENABLED=true
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=$PGHOST
DB_POSTGRESDB_PORT=$PGPORT
DB_POSTGRESDB_DATABASE=$PGDATABASE
DB_POSTGRESDB_USER=$PGUSER
DB_POSTGRESDB_PASSWORD=$PGPASSWORD
DB_POSTGRESDB_SCHEMA=public
EXECUTIONS_PROCESS=main
EXECUTIONS_MODE=regular
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_TIMEOUT_MAX=7200
N8N_USER_MANAGEMENT_DISABLED=false
N8N_PUBLIC_API_DISABLED=false
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=console
GENERIC_TIMEZONE=UTC
N8N_COMMUNITY_NODES_ENABLED=true
N8N_PAYLOAD_SIZE_MAX=16
```

5. Click **"Add"** or **"Save"**

### Step 3: Redeploy

1. Railway will automatically redeploy after you save the variables
2. Wait 2-5 minutes for the deployment
3. First startup takes longer (database migrations)

### Step 4: Verify

1. Go to your deployment logs
2. You should see:
   - ✅ "Database migration complete"
   - ✅ "n8n ready on port XXXX"
   - ✅ "Healthcheck passed"

3. Visit your Railway domain (e.g., `https://your-app.railway.app`)
4. You should see the n8n login/setup page

### Step 5: Test Healthcheck

Visit: `https://your-app.railway.app/healthz`

You should see:
```json
{"status":"ok"}
```

## What These Variables Do

### Critical for Healthcheck
- `N8N_METRICS=true` - Enables metrics collection
- `N8N_METRICS_INCLUDE_API_ENDPOINTS=true` - **ENABLES /healthz endpoint**
- `N8N_DIAGNOSTICS_ENABLED=true` - Enables diagnostic endpoints

### Database Connection
- `DB_TYPE=postgresdb` - Tells n8n to use PostgreSQL
- `DB_POSTGRESDB_HOST=$PGHOST` - Connects to Railway's PostgreSQL
- Other `DB_POSTGRESDB_*` variables - Database credentials (auto-provided by Railway)

### Railway Integration
- `N8N_PORT=$PORT` - Uses Railway's dynamic port
- `N8N_HOST=0.0.0.0` - Listens on all interfaces
- `WEBHOOK_URL=https://$RAILWAY_PUBLIC_DOMAIN` - Public URL for webhooks

## Still Not Working?

### Check 1: Do you have TWO services?
Railway Dashboard → You should see:
- PostgreSQL (database icon)
- Your n8n app (app icon)

### Check 2: Are variables set?
n8n Service → Variables tab → Should see ~25 variables

### Check 3: Is PostgreSQL running?
PostgreSQL service → Should show "Active" status

### Check 4: View logs
n8n Service → Deployments → Click latest → View Logs
Look for error messages

## Need More Help?

See the full deployment guide: [RAILWAY_DEPLOYMENT.md](./RAILWAY_DEPLOYMENT.md)

Or the detailed environment setup: [RAILWAY_ENV_SETUP.md](./RAILWAY_ENV_SETUP.md)
