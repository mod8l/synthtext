# Railway Deployment UID Fix

## Problem
When deploying to Railway, the Docker build failed with:
```
ERROR: failed to build: failed to solve: process "/bin/sh -c useradd -m -u 1000 n8n-user" did not complete successfully: exit code: 4
useradd: UID 1000 is not unique
```

## Root Cause
The `node:20-slim` base Docker image already contains a user (`node`) with UID 1000. When the Dockerfile attempted to create a second user (`n8n-user`) with the same UID 1000, Linux rejected it due to UID uniqueness constraints.

## Solution Applied
Changed the n8n-user creation to use UID 1001 instead of 1000:

### Changes Made to Dockerfile:
1. **Line 57**: Changed `useradd -m -u 1000 n8n-user` to `useradd -m -u 1001 n8n-user`
2. **Line 65**: Changed `COPY --chown=n8n-user:n8n-user` to `COPY --chown=1001:1001` for compatibility
3. **Line 71**: Changed `chown -R n8n-user:n8n-user /app` to `chown -R 1001:1001 /app` for consistency

### Why This Works
- UID 1001 is typically unused in the `node:20-slim` image
- All file ownership operations use explicit UIDs (1001:1001) instead of usernames for reliability
- The security requirement (non-root user) is maintained
- Railway's container runtime accepts the unique UID

## Testing
Deploy to Railway with the updated Dockerfile. The production build should now complete successfully without UID conflicts.

## Related Files
- [`Dockerfile`](../Dockerfile) - Updated with UID 1001
- [`docs/RAILWAY_DEPLOYMENT.md`](./RAILWAY_DEPLOYMENT.md) - General Railway deployment guide
