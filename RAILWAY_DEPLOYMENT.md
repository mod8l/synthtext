# Railway Deployment Guide for n8n

This guide explains how to deploy n8n on Railway with PostgreSQL.

## Prerequisites

1. A Railway account
2. A PostgreSQL database provisioned in Railway (via "Add Service" → "Database" → "PostgreSQL")

## Environment Variables

All necessary environment variables are configured in `railway.json`. Railway will automatically use these when deploying.

### Key Configuration Points

#### Database Configuration
- **DB_TYPE**: Set to `postgresdb` for PostgreSQL
- Railway's PostgreSQL service provides these variables automatically:
  - `${PGHOST}` - Database host
  - `${PGPORT}` - Database port (usually 5432)
  - `${PGDATABASE}` - Database name
  - `${PGUSER}` - Database user
  - `${PGPASSWORD}` - Database password

#### Health Check Configuration
- **healthcheckPath**: `/healthz` (enabled via `N8N_METRICS_INCLUDE_API_ENDPOINTS`)
- **healthcheckTimeout**: 600 seconds (10 minutes for first startup)
- n8n needs time to initialize, run database migrations, and start the web server

#### Metrics & Monitoring
- **N8N_METRICS**: `true` - Enables metrics collection
- **N8N_METRICS_INCLUDE_API_ENDPOINTS**: `true` - **REQUIRED** to enable `/healthz` endpoint
- **N8N_METRICS_INCLUDE_DEFAULT_METRICS**: `true` - Includes default Node.js metrics
- **N8N_METRICS_INCLUDE_WORKFLOW_ID_LABEL**: `true` - Adds workflow IDs to metrics
- **N8N_METRICS_INCLUDE_NODE_TYPE_LABEL**: `true` - Adds node types to metrics

#### User Management
- **N8N_USER_MANAGEMENT_DISABLED**: `false` - User management is **enabled**
- You'll need to create an admin user on first startup

#### Port Configuration
- **N8N_PORT**: `${PORT}` - Uses Railway's dynamic port assignment
- **N8N_HOST**: `0.0.0.0` - Listens on all interfaces

## Deployment Steps

### 1. Add PostgreSQL Database
In your Railway project:
1. Click "New Service"
2. Select "Database"
3. Choose "PostgreSQL"
4. Railway will automatically provision the database and set up environment variables

### 2. Deploy n8n
1. Push your code to GitHub
2. In Railway, connect your GitHub repository
3. Railway will automatically:
   - Detect the `Dockerfile`
   - Read configuration from `railway.json`
   - Build and deploy the container
   - Link to the PostgreSQL database

### 3. Configure Domain
1. In Railway, go to your n8n service settings
2. Click "Generate Domain" to get a public URL
3. The `WEBHOOK_URL` and `N8N_EDITOR_BASE_URL` will automatically use `${RAILWAY_PUBLIC_DOMAIN}`

### 4. First Login
After successful deployment:
1. Visit your Railway domain (e.g., `https://your-app.railway.app`)
2. Create your admin user account
3. Start building workflows!

## Environment Variables Reference

See `.env.railway` for a complete reference of all environment variables used.

### Production vs Staging

Both environments are configured in `railway.json`:

**Production**:
- `N8N_LOG_LEVEL`: `info`
- `N8N_INSECURE_FRONTEND_ALLOWLIST`: `false`

**Staging**:
- `N8N_LOG_LEVEL`: `debug` (more verbose logging)
- `N8N_INSECURE_FRONTEND_ALLOWLIST`: `true` (allows insecure connections for testing)

## Troubleshooting

### Healthcheck Failures
If the deployment fails with healthcheck errors:

1. **Check Deploy Logs** (not Build Logs) for n8n startup errors
2. **Verify PostgreSQL is running** and connected
3. **Wait longer** - First startup can take 5-10 minutes for:
   - Database schema creation
   - Initial migrations
   - Workflow engine initialization
4. **Verify environment variables** are set correctly in Railway dashboard

### Database Connection Issues
If n8n can't connect to PostgreSQL:

1. Ensure PostgreSQL service is deployed and healthy
2. Verify the n8n service is in the same Railway project
3. Check that PostgreSQL environment variables (`PGHOST`, `PGPORT`, etc.) are available
4. Railway automatically creates a private network between services

### Port Issues
If you see "EADDRINUSE" or port errors:

1. Ensure `N8N_PORT` is set to `${PORT}` (Railway's dynamic port)
2. Don't hardcode port 5678
3. Railway assigns a random port that your app must use

## Monitoring

Access monitoring endpoints:
- **Health Check**: `https://your-domain.railway.app/healthz`
- **Metrics**: `https://your-domain.railway.app/metrics` (Prometheus format)

## Security Considerations

1. **Encryption Key**: n8n generates an encryption key on first startup
   - This is stored in the PostgreSQL database
   - Never commit `.env` files with actual secrets to Git

2. **User Management**: Enabled by default
   - Create a strong password for your admin user
   - Enable 2FA in n8n settings

3. **HTTPS**: Railway provides automatic HTTPS
   - Always use `https://` in your `WEBHOOK_URL`

## Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Railway Documentation](https://docs.railway.app/)
- [n8n Environment Variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
- [n8n Monitoring Guide](https://docs.n8n.io/hosting/logging-monitoring/monitoring/)
