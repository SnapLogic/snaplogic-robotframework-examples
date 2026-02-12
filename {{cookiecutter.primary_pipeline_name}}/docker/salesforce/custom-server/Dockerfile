# =============================================================================
# Salesforce Custom API Mock Server - Dockerfile
# =============================================================================
# Lightweight Node.js server that replaces WireMock + JSON Server
# Image size: ~80MB (vs ~450MB for WireMock + JSON Server)
# Startup time: ~1-2s (vs ~10-15s for WireMock)
#
# WHY THIS DOCKERFILE EXISTS:
# - Unlike WireMock which has a pre-built image on Docker Hub (wiremock/wiremock:3.3.1),
#   there is no pre-built image for our custom server. We build our own.
# - This Dockerfile:
#   1. Starts from a base Node.js image (node:18-alpine)
#   2. Installs the Express dependency (npm install)
#   3. Copies our application code (server.js, lib/, schemas/)
# - Without this Dockerfile, Docker wouldn't know how to assemble the container.
# - To eliminate this Dockerfile, you could publish a pre-built image to a
#   Docker registry (Docker Hub, ECR, etc.) and reference it with "image:"
#   in docker-compose, just like WireMock does. But for a local development/
#   testing tool, building from a Dockerfile is the standard approach.
#
# HTTPS Certificates:
# - Reuses the SAME PKCS12 keystore (custom-keystore.p12) as WireMock
# - The P12 file is mounted at runtime via docker-compose volume
# - Node.js loads the P12 file directly (pfx option) — no conversion needed
# - This means Groundplex trusts the custom server with ZERO cert changes
# =============================================================================

FROM node:18-alpine

WORKDIR /app

# Install wget for health check
RUN apk add --no-cache wget

# Copy package files and install dependencies
COPY package.json ./
RUN npm install --production && npm cache clean --force

# Copy application code
COPY server.js ./
COPY lib/ ./lib/
COPY schemas/ ./schemas/

# Create certs directory for mounted P12 keystore
RUN mkdir -p /app/certs

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=5s \
  CMD wget -q --spider http://localhost:8080/health || exit 1

# Expose HTTP and HTTPS ports
EXPOSE 8080 8443

# Run as non-root user for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup && \
    chown -R appuser:appgroup /app
USER appuser

CMD ["node", "server.js"]
