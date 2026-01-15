# Railway Environment Variables Setup Guide

Railway doesn't automatically read environment variables from `railway.json`. You need to set them manually through the Railway Dashboard or CLI.

## Method 1: Railway Dashboard (Recommended)

1. Go to your Railway project: https://railway.app/project/[your-project-id]
2. Click on your n8n service
3. Go to the **Variables** tab
4. Click **+ New Variable** for each variable below

### Required Environment Variables

Copy these into Railway (one at a time or use bulk add):

```
NODE_ENV=production
N8N_PORT=$PORT
N8N_PROTOCOL=https
N8N_HOST=0.0.0.0
WEBHOOK_URL=https://$RAILWAY_PUBLIC_DOMAIN
N8N_EDITOR_BASE_URL=https://$RAILWAY_PUBLIC_DOMAIN
N8N_INSECURE_FRONTEND_ALLOWLIST=false
EXECUTIONS_PROCESS=main
EXECUTIONS_MODE=regular
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_TIMEOUT_MAX=7200
GENERIC_TIMEZONE=UTC
N8N_METRICS=true
N8N_METRICS_INCLUDE_API_ENDPOINTS=true
N8N_METRICS_INCLUDE_DEFAULT_METRICS=true
N8N_METRICS_INCLUDE_WORKFLOW_ID_LABEL=true
N8N_METRICS_INCLUDE_NODE_TYPE_LABEL=true
N8N_DIAGNOSTICS_ENABLED=true
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=console
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=$PGHOST
DB_POSTGRESDB_PORT=$PGPORT
DB_POSTGRESDB_DATABASE=$PGDATABASE
DB_POSTGRESDB_USER=$PGUSER
DB_POSTGRESDB_PASSWORD=$PGPASSWORD
DB_POSTGRESDB_SCHEMA=public
N8N_USER_MANAGEMENT_DISABLED=false
N8N_PUBLIC_API_DISABLED=false
N8N_COMMUNITY_NODES_ENABLED=true
N8N_PAYLOAD_SIZE_MAX=16
```

### Using Bulk Add (Faster Method)

Railway supports bulk adding variables:

1. Go to Variables tab
2. Click **Raw Editor** or **Bulk Add**
3. Paste all variables at once (format shown above)
4. Click **Add Variables**

## Method 2: Railway CLI

If you prefer using the command line:

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login to Railway
railway login

# Link to your project
railway link

# Run the setup script
chmod +x setup-railway-env.sh
./setup-railway-env.sh
```

The script will output all the commands you need to run.

## Important Notes

### PostgreSQL Variables

The PostgreSQL variables (`$PGHOST`, `$PGPORT`, etc.) are **automatically provided by Railway** when you add a PostgreSQL database service. These reference the Railway-managed PostgreSQL instance.

**Steps:**
1. Add PostgreSQL service first: **New Service** → **Database** → **PostgreSQL**
2. Railway automatically creates: `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, `PGPASSWORD`
3. Your n8n service references these with `$PGHOST`, `$PGDATABASE`, etc.

### Railway-Specific Variables

Railway provides these automatically:
- `$PORT` - Dynamic port assignment (required for healthcheck)
- `$RAILWAY_PUBLIC_DOMAIN` - Your app's public domain
- `$PGHOST`, `$PGPORT`, `$PGDATABASE`, `$PGUSER`, `$PGPASSWORD` - PostgreSQL connection (when you add Postgres service)

### Critical Variables for Healthcheck

These are **REQUIRED** for the `/healthz` endpoint to work:

```
N8N_METRICS=true
N8N_METRICS_INCLUDE_API_ENDPOINTS=true
```

Without these, the healthcheck will fail!

## Verification

After setting all variables:

1. Go to **Variables** tab in Railway
2. Verify all variables are listed
3. Check that PostgreSQL variables show correct values
4. Deploy your service
5. Wait for healthcheck to pass (up to 10 minutes on first deploy)

## Troubleshooting

### "Suggested Variables" in Railway

If you see "Suggested Variables" instead of your configured variables, it means:
- Variables haven't been set in Railway dashboard yet
- Railway is scanning your code and suggesting what it finds
- You need to manually add the variables listed above

### Variables Not Showing

If variables aren't working:
1. Make sure you're in the correct Railway environment (production/staging)
2. Verify PostgreSQL service is deployed and healthy
3. Check that variable names match exactly (case-sensitive)
4. Redeploy after adding variables

### PostgreSQL Connection Fails

If n8n can't connect to PostgreSQL:
1. Verify PostgreSQL service is running (check Railway dashboard)
2. Ensure both services are in the same Railway project
3. Check that `DB_TYPE=postgresdb` (not `postgres` or `postgresql`)
4. Verify the database schema exists (default is `public`)

## Next Steps

After setting up all environment variables:

1. ✅ Variables configured in Railway
2. ✅ PostgreSQL service running
3. ✅ Deploy your n8n service
4. ✅ Wait for healthcheck to pass
5. ✅ Visit your Railway domain and create admin user

Your n8n instance should now be fully functional! 🚀
