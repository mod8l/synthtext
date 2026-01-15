# Use n8n Debian variant as base
# Note: We use debian variant to allow future extensions if needed
FROM n8nio/n8n:latest-debian

# Set working directory
WORKDIR /data

# Copy custom workflows and configurations
COPY src/ /data/

# Copy environment example
COPY .env.example /data/.env.example

# Expose n8n port
EXPOSE 5678

# Use default n8n startup command
CMD ["n8n"]
