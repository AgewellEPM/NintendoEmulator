# Multi-stage Dockerfile for Nintendo Emulator Backend Services
# Supports both OAuth proxy and authentication service

FROM node:18-alpine AS base

# Install security updates
RUN apk update && apk upgrade && \
    apk add --no-cache dumb-init

# Create app user for security (non-root)
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY oauth-proxy.js auth-service.js ./

# Change ownership to app user
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose ports
# 3000: OAuth proxy
# 3001: Auth service
EXPOSE 3000 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Default command (can be overridden)
CMD ["node", "oauth-proxy.js"]