#!/bin/bash
# =============================================================================
# Entrypoint for Django Salesforce Mock Server
# =============================================================================
# 1. Converts PKCS12 certificate to PEM format (Python ssl module needs PEM)
# 2. Starts a single-process Python server serving BOTH HTTP and HTTPS
#
# WHY SINGLE PROCESS?
# -------------------
# This mock server uses in-memory Python dicts (database, job_store, event_bus)
# for state. Multiple processes would have isolated memory, causing requests
# to different processes to see different state (e.g., create via HTTP,
# query via HTTPS returns empty). A single process with threading ensures
# all protocols share the same in-memory state — matching the Node.js
# custom server behavior.
# =============================================================================

set -e

# Configuration from environment
HTTP_PORT=${HTTP_PORT:-8080}
HTTPS_PORT=${HTTPS_PORT:-8443}
P12_FILE=${P12_FILE:-/app/certs/custom-keystore.p12}
P12_PASSWORD=${P12_PASSWORD:-password}

CERT_PEM=/app/certs/cert.pem
KEY_PEM=/app/certs/key.pem

# Export PEM paths for the Python server
export CERT_PEM KEY_PEM

# Convert P12 to PEM if available
if [ -f "$P12_FILE" ]; then
    echo "  Converting PKCS12 certificate to PEM..."

    # Extract certificate
    openssl pkcs12 -in "$P12_FILE" -passin "pass:$P12_PASSWORD" \
        -clcerts -nokeys -out "$CERT_PEM" 2>/dev/null

    # Extract private key
    openssl pkcs12 -in "$P12_FILE" -passin "pass:$P12_PASSWORD" \
        -nocerts -nodes -out "$KEY_PEM" 2>/dev/null

    echo "  Certificate converted successfully"
    echo ""
else
    echo "  No P12 certificate found at $P12_FILE"
    echo "  HTTPS will not be available"
    echo ""
fi

# Start single-process server (HTTP + HTTPS in one process)
# PYTHONUNBUFFERED=1 ensures print() output appears immediately in Docker logs
exec python -u run_server.py
