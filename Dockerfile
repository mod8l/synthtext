# Multi-stage build for n8n with AutoMarket OS customizations

# Stage 1: Base image with dependencies
# Using Node.js base to avoid Docker Hub authentication issues with n8n:latest
FROM node:20-slim AS base

# Set working directory
WORKDIR /app

# Install additional dependencies for AutoMarket integrations and n8n
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    python3 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install n8n globally
RUN npm install -g n8n

# Stage 2: Development image with all tools
FROM base AS development

# Install development tools for debugging
RUN apt-get update && apt-get install -y \
    vim \
    nano \
    less \
    net-tools \
    iputils-ping \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY . /app/

# Make startup script executable
RUN chmod +x /app/scripts/start-railway.sh

# Set environment for development
ENV NODE_ENV=development
ENV N8N_INSECURE_FRONTEND_ALLOWLIST=true
ENV PORT=5678
ENV N8N_PORT=5678
ENV N8N_HOST=0.0.0.0

EXPOSE 5678

CMD ["/bin/sh", "/app/scripts/start-railway.sh"]

# Stage 3: Production image (optimized)
FROM base AS production

# Security: Don't run as root
# node:20-slim already has 'node' user with UID 1000, so we use UID 1001
RUN useradd -m -u 1001 n8n-user

# Copy only necessary files
COPY src/ /app/src/
COPY .env.example /app/.env.example
COPY scripts/start-railway.sh /app/start-railway.sh

# Copy any custom nodes if they exist
COPY --chown=1001:1001 . /app/

# Make startup script executable
RUN chmod +x /app/start-railway.sh

# Set ownership (using UID/GID explicitly to avoid name lookup issues)
RUN chown -R 1001:1001 /app

# Switch to non-root user (UID 1001)
USER n8n-user

# Set environment for production
ENV NODE_ENV=production
ENV N8N_INSECURE_FRONTEND_ALLOWLIST=false
ENV PORT=5678
ENV N8N_PORT=5678
ENV N8N_HOST=0.0.0.0

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

EXPOSE 5678

CMD ["n8n", "start"]
