#!/bin/bash
# Railway deployment startup script for n8n

# Log environment for debugging
echo "[Railway Start] NODE_ENV=$NODE_ENV"
echo "[Railway Start] PORT=$PORT"
echo "[Railway Start] N8N_PORT=$N8N_PORT"
echo "[Railway Start] N8N_HOST=$N8N_HOST"

# Ensure PORT is set (Railway requirement)
if [ -z "$PORT" ]; then
  echo "[Railway Start] ERROR: PORT not set! Setting to default 5678"
  export PORT=5678
fi

# Ensure N8N_PORT matches PORT
if [ -z "$N8N_PORT" ]; then
  export N8N_PORT=$PORT
fi

# Ensure N8N_HOST is set to accept external connections
if [ -z "$N8N_HOST" ]; then
  export N8N_HOST=0.0.0.0
fi

echo "[Railway Start] Starting n8n with PORT=$PORT N8N_PORT=$N8N_PORT N8N_HOST=$N8N_HOST"

# Start n8n
exec n8n start
