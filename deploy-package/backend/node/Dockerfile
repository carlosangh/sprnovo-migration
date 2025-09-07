# Multi-stage production Dockerfile for SPRNOVO Backend
FROM node:18-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++ curl

WORKDIR /app

# Copy package files for better layer caching
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM node:18-alpine

# Install runtime dependencies
RUN apk add --no-cache curl tzdata && \
    addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set timezone
ENV TZ=America/Cuiaba

WORKDIR /app

# Copy node_modules from builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application files
COPY --chown=nodejs:nodejs . .

# Create uploads directory
RUN mkdir -p uploads/ocr && chown -R nodejs:nodejs uploads/

# Security: Run as non-root user
USER nodejs

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8090}/api/status || exit 1

# Expose port
EXPOSE ${PORT:-8090}

# Start application
CMD ["node", "spr-backend-complete-extended.js"]