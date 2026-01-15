# Use n8n Debian variant as base
# Note: We use debian variant to allow future extensions if needed
FROM n8nio/n8n:latest-debian

# n8n uses /home/node/.n8n for data storage by default
# No need to change working directory or copy files during build
# Custom workflows should be imported via n8n UI or API after startup

# The PORT environment variable is set by Railway and used by n8n via N8N_PORT
