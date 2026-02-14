# =============================================================================
# Salesforce Django Mock API Server - Dockerfile
# =============================================================================
# Python/Django server that replaces WireMock + JSON Server.
# Image size: ~120MB (python:3.11-slim)
# Startup time: ~2-3s
#
# Third backend option alongside WireMock and Node.js Custom Server.
# All three share the same container name, ports, and HTTPS certificate
# for zero-config drop-in replacement.
#
# Dependencies: Django only (1 Python package — uses stdlib wsgiref for serving)
#
# HTTPS Certificates:
# - Reuses the SAME PKCS12 keystore (custom-keystore.p12) as WireMock/Node.js
# - P12 is converted to PEM at container startup (Python ssl needs PEM)
# - OpenSSL is installed in the base image for this conversion
# - Groundplex trusts the Django server with ZERO cert changes
#
# Architecture:
# - Single-process server (run_server.py) serves BOTH HTTP and HTTPS
# - Uses Python's stdlib wsgiref + ssl + threading
# - All in-memory state (database, job_store) shared across protocols
# - No gunicorn needed — wsgiref is sufficient for a mock test server
# =============================================================================

FROM python:3.11-slim

WORKDIR /app

# Install curl and openssl (for health check and P12->PEM conversion)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl openssl && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY manage.py ./
COPY run_server.py ./
COPY entrypoint.sh ./
COPY salesforce_mock/ ./salesforce_mock/

# Copy schemas (baked into image, no external volume mount needed)
COPY schemas/ ./schemas/

# Create certs directory (cert is mounted from docker/salesforce/certs/ at runtime)
RUN mkdir -p /app/certs

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=5s \
  CMD curl -f http://localhost:8080/health || exit 1

# Expose HTTP and HTTPS ports
EXPOSE 8080 8443

# Run as non-root user for security
RUN groupadd -g 1001 appgroup && \
    useradd -u 1001 -g appgroup -s /bin/bash appuser && \
    chown -R appuser:appgroup /app
USER appuser

ENTRYPOINT ["./entrypoint.sh"]
