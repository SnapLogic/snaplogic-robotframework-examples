# WireMock HTTPS Certificate Setup Guide

## 📋 Table of Contents
- [Overview](#overview)
- [Why Custom Certificates](#why-custom-certificates)
- [Prerequisites](#prerequisites)
- [Step-by-Step Setup](#step-by-step-setup)
  - [Step 1: Create Custom Certificate](#step-1-create-custom-certificate)
  - [Step 2: Configure WireMock with HTTPS](#step-2-configure-wiremock-with-https)
  - [Step 3: Import Certificate to Groundplex](#step-3-import-certificate-to-groundplex)
  - [Step 4: Verification](#step-4-verification)
- [Quick Commands](#quick-commands)
- [Troubleshooting](#troubleshooting)
- [Alternative Approaches](#alternative-approaches)

---

## Overview

This guide explains how to set up HTTPS for WireMock mock services and configure SnapLogic Groundplex to trust the custom certificates, enabling secure communication between Groundplex and mock services.

### Architecture Overview

The testing architecture consists of several key components working together:

* **WireMock Server:** Handles API mocking with static and proxy mappings
  - Static mappings return predefined responses for stateless operations
  - Proxy mappings forward requests to JSON Server for stateful CRUD operations
  - Serves both HTTP (port 8080) and HTTPS (port 8443) endpoints
  - Uses custom certificates for proper hostname verification

* **JSON Server:** Provides stateful data persistence for CRUD operations
  - Stores created records in a JSON database file
  - Maintains state across test runs
  - Enables realistic workflow testing with data relationships
  - Accessible at port 3000 internally within Docker network

* **Groundplex:** Executes SnapLogic pipelines with SSL certificate trust
  - Runs as a Docker container with JCC (Java Component Container)
  - Contains Java truststore for managing SSL certificates
  - Requires custom certificate import to trust WireMock's self-signed certificate
  - Provides the execution environment for SnapLogic Snaps

* **Robot Framework:** Orchestrates and verifies test execution
  - Controls the entire test lifecycle
  - Manages Groundplex container startup and configuration
  - Executes test cases against the mock services
  - Verifies responses and validates test outcomes

### Why You're Dealing with This

In this case:

* **Groundplex** (SnapLogic execution node) needs to connect to another service — your **WireMock Salesforce API mock** — over HTTPS.
* That WireMock instance is running with a **self-signed certificate** (a cert you created yourself).
* By default, Java (inside Groundplex) will reject connections to an unknown/self-signed certificate.
* To make it trust that certificate, you **import** the public part of the certificate into Java's truststore (cacerts).
* This is like saying: *"Hey Java, trust this server's ID card, even though it wasn't issued by a well-known authority."*

### Self-signed vs. CA-signed Certificates

* **CA-signed (public)**: Issued by a trusted Certificate Authority like Let's Encrypt or DigiCert. Browsers and Java already trust them — no manual importing needed.
* **Self-signed**: You create it yourself. Cheaper and easier for local dev/test, but **not trusted by default**. You must manually tell systems (like Java) to trust it.

### Finally

You're:

1. Generating a self-signed cert for your WireMock server.
2. Copying it into the Groundplex container.
3. Importing it into Java's truststore so Groundplex can talk to WireMock over HTTPS without complaining.

## Why Custom Certificates

### 🚨 The Problem

When using WireMock's default certificate with SnapLogic Groundplex, you'll encounter hostname verification errors:

```
javax.net.ssl.SSLPeerUnverifiedException: 
  Host name 'salesforce-api-mock' does not match the certificate subject 
  provided by the peer (CN=localhost)
```

**Root Cause:**
- WireMock's default certificate has `CN=localhost`
- Groundplex connects using Docker service name: `salesforce-api-mock`
- SSL/TLS hostname verification fails due to mismatch

### ✅ The Solution

Create a custom certificate with proper Subject Alternative Names (SANs) that include all hostnames used to access the service.

---

## Prerequisites

- Docker and Docker Compose installed
- OpenSSL command-line tool
- Running SnapLogic Groundplex container
- Access to project directory structure

---

## Step-by-Step Setup

### Step 1: Create Custom Certificate

#### 1.1 Create Directory Structure

```bash
# Navigate to your project root
cd /Users/spothana/QADocs/SNAPLOGIC_RF_EXAMPLES2/snaplogic-robotframework-examples

# Create certificates directory
mkdir -p docker/salesforce/certs
cd docker/salesforce/certs
```

#### 1.2 Generate Private Key

```bash
# Generate a 2048-bit RSA private key
openssl genrsa -out custom-key.pem 2048
```

**What this does:**
- Creates a private RSA key with 2048-bit encryption
- Saves it in PEM format (Privacy Enhanced Mail)
- This key is the foundation for your certificate

#### 1.3 Create Self-Signed Certificate

**Recommended Approach: Certificate with Subject Alternative Names (SANs)**

For maximum compatibility across different access methods, create a certificate with SANs:

```bash
# Create certificate with Subject Alternative Names
openssl req -new -x509 \
  -key custom-key.pem \
  -out custom-cert.pem \
  -days 365 \
  -subj "/C=US/ST=CA/L=San Francisco/O=SnapLogic/CN=salesforce-api-mock" \
  -addext "subjectAltName=DNS:salesforce-api-mock,DNS:localhost,DNS:salesforce-mock,IP:127.0.0.1"
```

**Certificate Fields Explained:**

| Field | Value               | Purpose                        |
| ----- | ------------------- | ------------------------------ |
| `C`   | US                  | Country Code                   |
| `ST`  | CA                  | State/Province (California)    |
| `L`   | San Francisco       | Locality/City                  |
| `O`   | SnapLogic           | Organization                   |
| `CN`  | salesforce-api-mock | Common Name (primary hostname) |

**Subject Alternative Names (SANs) Included:**
- `DNS:salesforce-api-mock` - Docker service name (primary)
- `DNS:localhost` - Local testing access
- `DNS:salesforce-mock` - Alternative service name
- `IP:127.0.0.1` - IP-based access

✅ **Why SANs are recommended:** This certificate will work regardless of how you access the service (via Docker hostname, localhost, or IP address), preventing hostname verification errors.

**Alternative: Basic Certificate (Simpler but Limited)**

If you only need to access via the Docker service name:

```bash
# Basic certificate without SANs
openssl req -new -x509 \
  -key custom-key.pem \
  -out custom-cert.pem \
  -days 365 \
  -subj "/C=US/ST=CA/L=San Francisco/O=SnapLogic/CN=salesforce-api-mock"
```

⚠️ **Limitation:** This only works when accessing the service as `salesforce-api-mock`. Will fail for `localhost` or IP access.

**To verify what's in your certificate:**

```bash
# View certificate details
openssl x509 -in custom-cert.pem -noout -text | grep -A2 "Subject:"

# Check for SANs (should show DNS entries if using recommended approach)
openssl x509 -in custom-cert.pem -noout -text | grep -A2 "Subject Alternative Name"
```

#### 1.4 Create PKCS12 Keystore for WireMock

```bash
# Bundle private key and certificate into PKCS12 format
openssl pkcs12 -export \
  -in custom-cert.pem \
  -inkey custom-key.pem \
  -out custom-keystore.p12 \
  -name "wiremock" \
  -password pass:password
```

**Note:** The password "password" is used here for simplicity. In production, use a strong password.

#### 1.5 Clean Up Intermediate Files (Optional)

```bash
# After creating the P12 file, you can delete the intermediate .pem files
# The P12 contains everything needed (private key + certificate)

rm custom-key.pem     # Private key (already in P12)
rm custom-cert.pem    # Certificate (already in P12)

# Keep only the P12 file that WireMock will use
ls -la custom-keystore.p12
```

💡 **Important:** The `.pem` files can be safely deleted after creating the `.p12` file because:
- The P12 file contains both the private key and certificate
- WireMock only needs the P12 file to serve HTTPS
- You can always extract the certificate from P12 if needed: `openssl pkcs12 -in custom-keystore.p12 -nokeys -out cert.pem`

#### 1.6 Verify the Keystore (Optional)

```bash
# Check contents of the P12 file
openssl pkcs12 -info -in custom-keystore.p12 -password pass:password -noout

# View certificate details
openssl x509 -in custom-cert.pem -noout -text | grep -A2 "Subject Alternative Name"
```

---

### Step 2: Configure WireMock with HTTPS

#### 2.1 Update Docker Compose Configuration

Edit `docker/docker-compose.salesforce-mock.yml`:

```yaml
version: '3.8'

services:
  salesforce-mock:
    image: wiremock/wiremock:3.3.1
    container_name: salesforce-api-mock
    ports:
      - "8089:8080"  # HTTP port mapping
      - "8443:8443"  # HTTPS port mapping
    volumes:
      # Mount API response mappings
      - ./scripts/salesforce/wiremock/mappings:/home/wiremock/mappings
      
      # Mount certificates directory (read-only for security)
      - ./salesforce/certs:/home/wiremock/certs:ro
      
    command:
      - "--port"
      - "8080"
      - "--https-port"
      - "8443"
      - "--https-keystore"
      - "/home/wiremock/certs/custom-keystore.p12"
      - "--keystore-password"
      - "password"
      - "--verbose"
      - "--global-response-templating"
    networks:
      - snaplogicnet
    profiles: ["salesforce-dev", "salesforce-mock-start"]

networks:
  snaplogicnet:
    external: true
    name: docker_snaplogicnet
```

**Volume Mount Explanation:**

| Host Path                             | Container Path         | Purpose                    |
| ------------------------------------- | ---------------------- | -------------------------- |
| `./salesforce/certs` | `/home/wiremock/certs` | Certificate files location |
| `:ro` flag                            | Read-only mount        | Security best practice     |

#### 2.2 Start WireMock Service

```bash
# Using Makefile
cd /Users/spothana/QADocs/SNAPLOGIC_RF_EXAMPLES2/snaplogic-robotframework-examples
make salesforce-mock-start

# Or using docker-compose directly
docker-compose -f docker/docker-compose.salesforce-mock.yml \
  --profile salesforce-mock-start up -d
```

#### 2.3 Verify HTTPS Endpoint

```bash
# Test HTTPS endpoint (ignore certificate warning with -k)
curl -k https://localhost:8443/__admin/health

# Expected response:
# {"status":"OK"}

# Check certificate details
echo | openssl s_client -connect localhost:8443 -servername salesforce-api-mock 2>/dev/null | \
  openssl x509 -noout -subject -issuer -dates
```

---

### Step 3: Import Certificate to Groundplex

#### 3.1 Launch Groundplex

```bash
# Start Groundplex container
make launch-groundplex

# Wait for Groundplex to be fully ready
echo "Waiting for Groundplex to initialize..."
sleep 60

# Verify Groundplex is running
make groundplex-status
```

#### 3.2 Extract Certificate from Running WireMock

```bash
# Extract the certificate that WireMock is actually serving
echo | openssl s_client -connect localhost:8443 \
  -servername salesforce-api-mock 2>/dev/null | \
  openssl x509 > /tmp/wiremock-cert.pem

# Verify extraction was successful
openssl x509 -in /tmp/wiremock-cert.pem -noout -subject
# Should show: subject=CN=salesforce-api-mock
```

#### 3.3 Copy Certificate to Groundplex Container

```bash
# Copy certificate into the running Groundplex container
docker cp /tmp/wiremock-cert.pem snaplogic-groundplex:/tmp/wiremock-cert.pem

# Verify the file was copied
docker exec snaplogic-groundplex ls -la /tmp/wiremock-cert.pem
```

#### 3.4 Import Certificate into Java Truststore

```bash
# Import certificate into Java's truststore
docker exec snaplogic-groundplex bash -c '
  # Find Java installation (version-specific directory)
  JAVA_HOME="/opt/snaplogic/pkgs/jdk-11.0.24+8-jre"
  
  # Alternative: Dynamically find Java directory
  # JAVA_HOME=$(ls -d /opt/snaplogic/pkgs/jdk* 2>/dev/null | head -1)
  
  echo "Found Java Home: $JAVA_HOME"
  
  # Set keytool and truststore paths
  KEYTOOL="$JAVA_HOME/bin/keytool"
  TRUSTSTORE="$JAVA_HOME/lib/security/cacerts"
  
  # Verify paths exist
  if [ ! -f "$KEYTOOL" ]; then
    echo "ERROR: keytool not found at $KEYTOOL"
    exit 1
  fi
  
  if [ ! -f "$TRUSTSTORE" ]; then
    echo "ERROR: truststore not found at $TRUSTSTORE"
    exit 1
  fi
  
  echo "Using keytool: $KEYTOOL"
  echo "Using truststore: $TRUSTSTORE"
  
  # Import the certificate (password "changeit" is Java default)
  $KEYTOOL -import -trustcacerts \
    -keystore $TRUSTSTORE \
    -storepass changeit \
    -noprompt \
    -alias wiremock-salesforce \
    -file /tmp/wiremock-cert.pem
  
  echo "Certificate imported successfully!"
  
  # Clean up
  rm /tmp/wiremock-cert.pem
'
```

**Note:** The Java path `/opt/snaplogic/pkgs/jdk-11.0.24+8-jre` is version-specific. If your Groundplex uses a different Java version, adjust accordingly or use the dynamic discovery method shown in the comment.

#### 3.5 Restart JCC to Apply Changes

```bash
# Restart JCC service
docker exec snaplogic-groundplex bash -c '
  cd /opt/snaplogic/bin && ./jcc.sh restart
'

# Wait for JCC to restart
echo "Waiting for JCC to restart..."
sleep 60

# Verify JCC is running
docker exec snaplogic-groundplex bash -c '
  cd /opt/snaplogic/bin && ./jcc.sh status
'
```

---

### Step 4: Verification

#### 4.1 Verify Certificate in Truststore

```bash
# Check if certificate is properly imported
docker exec snaplogic-groundplex bash -c '
  # Set Java paths
  JAVA_HOME="/opt/snaplogic/pkgs/jdk-11.0.24+8-jre"
  KEYTOOL="$JAVA_HOME/bin/keytool"
  TRUSTSTORE="$JAVA_HOME/lib/security/cacerts"
  
  echo "Checking for wiremock certificate in truststore..."
  $KEYTOOL -list -keystore $TRUSTSTORE -storepass changeit 2>/dev/null | grep -i wiremock
  
  if [ $? -eq 0 ]; then
    echo "✅ Certificate found!"
    # Show certificate details
    $KEYTOOL -list -v -keystore $TRUSTSTORE -storepass changeit -alias wiremock-salesforce 2>/dev/null | \
      grep -E "Alias|Owner|Valid" | head -5
  else
    echo "❌ Certificate not found"
  fi
'
```

#### 4.2 Test HTTPS Connection from Groundplex

```bash
# Test connection from inside Groundplex container
docker exec snaplogic-groundplex curl -v https://salesforce-api-mock:8443/__admin/health

# Should return: {"status":"OK"} without SSL errors
```

#### 4.3 Configure SnapLogic Salesforce Account

In SnapLogic Designer:

1. **Create or Edit Salesforce Account**
2. **Configure Settings:**
   - **Login URL:** `https://salesforce-api-mock:8443`
   - **Username:** `snap-qa@snaplogic.com` (any value works)
   - **Password:** Any value
   - **Security Token:** Leave empty
3. **Validate the account** - Should show "Account validation successful"

---

## Quick Commands

### Using Makefile Targets

After initial setup, use these convenient commands:

```bash
# Launch Groundplex with automatic certificate setup
make launch-groundplex-with-cert

# Or separately:
make launch-groundplex        # Start Groundplex
make setup-groundplex-cert    # Import certificates

# Check certificate status
make groundplex-check-cert

# Remove certificate if needed
make groundplex-remove-cert
```

### All-in-One Setup Script

```bash
#!/bin/bash
# Complete setup in one script

# 1. Start WireMock with HTTPS
make salesforce-mock-start

# 2. Launch Groundplex with certificate
make launch-groundplex-with-cert

# 3. Verify everything
make groundplex-check-cert
make salesforce-mock-status
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Hostname Verification Errors

**Problem:** Still getting hostname verification errors after setup

**Solution:** Verify the certificate SANs include the hostname you're using:

```bash
# Check certificate SANs
docker exec snaplogic-groundplex bash -c '
  echo | openssl s_client -connect salesforce-api-mock:8443 2>/dev/null | \
  openssl x509 -noout -text | grep -A2 "Subject Alternative Name"
'
```

#### 2. Certificate Already Exists

**Problem:** Certificate import fails with "Certificate already exists"

**Solution:** Remove the old certificate first:

```bash
# Remove existing certificate
docker exec snaplogic-groundplex bash -c '
  JAVA_HOME="/opt/snaplogic/pkgs/jdk-11.0.24+8-jre"
  KEYTOOL="$JAVA_HOME/bin/keytool"
  TRUSTSTORE="$JAVA_HOME/lib/security/cacerts"
  
  $KEYTOOL -delete -keystore $TRUSTSTORE \
    -storepass changeit -alias wiremock-salesforce 2>/dev/null
  
  if [ $? -eq 0 ]; then
    echo "✅ Old certificate removed"
  else
    echo "No existing certificate to remove"
  fi
'

# Then re-import
make setup-groundplex-cert
```

#### 3. JCC Won't Restart

**Problem:** JCC fails to restart after certificate import

**Solution:** Check JCC logs and manually restart:

```bash
# Check logs
docker exec snaplogic-groundplex tail -n 100 /opt/snaplogic/run/log/jcc.log

# Force stop and start
docker exec snaplogic-groundplex bash -c '
  cd /opt/snaplogic/bin
  ./jcc.sh stop
  sleep 10
  ./jcc.sh start
'
```

#### 4. Connection Refused

**Problem:** Getting connection refused when accessing HTTPS endpoint

**Solution:** Ensure WireMock is running with HTTPS enabled:

```bash
# Check if port 8443 is listening
docker exec salesforce-api-mock netstat -tlnp | grep 8443

# Check WireMock logs
docker logs salesforce-api-mock --tail 50
```

---

## Alternative Approaches

### Option 1: Use HTTP Instead of HTTPS (Development Only)

If HTTPS setup is problematic, you can configure Groundplex to allow HTTP:

```bash
# Add to Groundplex environment or JVM options
-Dcom.snaplogic.snaps.salesforce.force.http=true
```

### Option 2: Trust All Certificates (Not Recommended)

For development only, disable certificate validation:

```bash
# Add to JVM options (INSECURE - DEV ONLY)
-Dcom.sun.net.ssl.checkRevocation=false
-Dtrust.all.cert=true
```

### Option 3: Use Real Certificates

For production-like testing, use certificates from Let's Encrypt or your CA:

```bash
# Use certbot to get real certificates
certbot certonly --standalone -d your-domain.com

# Then convert to PKCS12
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/your-domain.com/fullchain.pem \
  -inkey /etc/letsencrypt/live/your-domain.com/privkey.pem \
  -out custom-keystore.p12
```

---

## Directory Structure

Final structure after setup:

```
snaplogic-robotframework-examples/
├── Makefile                           # Contains certificate management targets
├── docker/
│   ├── docker-compose.yml             # Main compose file
│   ├── docker-compose.salesforce-mock.yml  # WireMock configuration
│   └── salesforce/
│       ├── certs/                     # Certificate files
│       │   └── custom-keystore.p12    # PKCS12 keystore (only file needed)
│       │   # Note: .pem files can be deleted after P12 creation
│       └── wiremock/
│           └── mappings/              # API response mappings
│               └── *.json
└── test/
    └── .config/                       # Groundplex configuration
```

**Certificate Files:**
- `custom-keystore.p12` - **Required:** Contains both private key and certificate for WireMock
- `custom-key.pem` - **Optional:** Can be deleted after P12 creation
- `custom-cert.pem` - **Optional:** Can be deleted after P12 creation

---

## Security Best Practices

1. **Never commit private keys to version control**
   - Add `*.pem` and `*.p12` to `.gitignore`
   - Use secrets management for production

2. **Use strong passwords for keystores**
   - Don't use "password" in production
   - Store passwords in environment variables

3. **Rotate certificates regularly**
   - Set calendar reminders before expiry
   - Automate certificate renewal if possible

4. **Limit certificate scope**
   - Use specific SANs, not wildcards
   - Create separate certificates for different environments

5. **Monitor certificate expiry**
   ```bash
   # Check certificate expiry date
   openssl x509 -in custom-cert.pem -noout -enddate
   ```

---

## Summary

This guide provides a complete solution for:
- ✅ Creating custom certificates with proper SANs
- ✅ Configuring WireMock for HTTPS
- ✅ Importing certificates into Groundplex
- ✅ Enabling secure communication between services

The setup eliminates SSL hostname verification errors and enables proper HTTPS testing with mock services.

---

## Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review WireMock logs: `docker logs salesforce-api-mock`
- Review Groundplex logs: `docker exec snaplogic-groundplex tail -f /opt/snaplogic/run/log/jcc.log`
- Verify network connectivity: `docker network inspect docker_snaplogicnet`

---

*Last Updated: 2025*
*Version: 1.0*