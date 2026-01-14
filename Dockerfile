# Multi-stage build for n8n with AutoMarket OS customizations

# Stage 1: Base image with dependencies
# Using debian variant because latest is distroless (no package manager)
FROM n8nio/n8n:latest-debian AS base

# Set working directory
WORKDIR /app

# Install additional dependencies for AutoMarket integrations
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

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

# Set environment for development
ENV NODE_ENV=development
ENV N8N_INSECURE_FRONTEND_ALLOWLIST=true

EXPOSE 5678

CMD ["n8n", "start"]

# Stage 3: Production image (optimized)
FROM base AS production

# Security: Don't run as root
RUN useradd -m -u 1000 n8n-user

# Copy only necessary files
COPY src/ /app/src/
COPY .env.example /app/.env.example

# Copy any custom nodes if they exist
COPY --chown=n8n-user:n8n-user . /app/

# Set ownership
RUN chown -R n8n-user:n8n-user /app

# Switch to non-root user
USER n8n-user

# Set environment for production
ENV NODE_ENV=production
ENV N8N_INSECURE_FRONTEND_ALLOWLIST=false

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5678/healthz || exit 1

EXPOSE 5678

CMD ["n8n", "start"]
