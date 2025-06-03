# Groundplex Launch Guide
*Complete Setup, Configuration, and Troubleshooting*

## Table of Contents

1. [What is a Groundplex?](#what-is-a-groundplex)
2. [Prerequisites](#prerequisites)
3. [Groundplex Launch Process Overview](#groundplex-launch-process-overview)
4. [Step 1: Environment Configuration](#step-1-environment-configuration)
5. [Step 2: Creating the Groundplex](#step-2-creating-the-groundplex)
6. [Step 3: Downloading Configuration](#step-3-downloading-configuration)
7. [Step 4: Launching the Container](#step-4-launching-the-container)
8. [Step 5: Health Verification](#step-5-health-verification)
9. [Troubleshooting Guide](#troubleshooting-guide)
10. [Advanced Configuration](#advanced-configuration)
11. [Best Practices](#best-practices)
12. [Complete Launch Workflow](#complete-launch-workflow)

## What is a Groundplex?

A Groundplex (also called Snaplex) is SnapLogic's on-premises integration runtime that:

- **Executes pipelines locally** in your infrastructure
- **Provides secure access** to on-premises systems
- **Runs in a Docker container** or on bare metal
- **Connects to SnapLogic's control plane** while keeping data local

### Key Components

```
┌─────────────────────────────────────────────────────────┐
│                   SnapLogic Cloud                       │
│  ┌─────────────┐        ┌──────────────┐              │
│  │ Control Plane│        │  Designer UI  │              │
│  └──────┬───────┘        └──────────────┘              │
└─────────┼───────────────────────────────────────────────┘
          │ Control Connection (HTTPS)
          │
┌─────────┼───────────────────────────────────────────────┐
│         ▼            Your Infrastructure                │
│  ┌─────────────┐                                       │
│  │ Groundplex  │◄───► Local Systems                    │
│  │  Container  │      (Databases, Files, APIs)         │
│  └─────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

Before launching a Groundplex, ensure you have:

### 1. SnapLogic Account Access

- Organization admin credentials
- Project space created
- Appropriate permissions

### 2. Environment Variables Set

Required in `.env` file:
```bash
GROUNDPLEX_NAME=your-groundplex-name
GROUNDPLEX_ENV=development
GROUNDPLEX_LOCATION_PATH=/org/projects/shared
RELEASE_BUILD_VERSION=main-30027
```

### 3. Docker Environment Ready

```bash
# Verify Docker is running
docker --version
docker compose version

# Check available resources
docker system info | grep -E "CPUs|Total Memory"
```

### 4. Network Requirements

- Outbound HTTPS (443) to SnapLogic cloud
- Local network access to your systems
- Ports 8081 and 8090 available

## Groundplex Launch Process Overview

The complete Groundplex launch involves five phases:

```
1. Configure Environment
        ↓
2. Create Groundplex in SnapLogic
        ↓
3. Download Configuration File (.slpropz)
        ↓
4. Launch Docker Container
        ↓
5. Verify Health Status
```

## Step 1: Environment Configuration

### 1.1 Set Environment Variables

Edit your `.env` file with Groundplex-specific settings:

```bash
# === GROUNDPLEX CONFIGURATION ===
# Name must be unique within your organization
GROUNDPLEX_NAME=test-groundplex-dev

# Environment label (dev, test, prod)
GROUNDPLEX_ENV=development

# Location in SnapLogic (usually project/shared)
GROUNDPLEX_LOCATION_PATH=/your-org/projects/TestAutomation/shared

# SnapLogic version to use
RELEASE_BUILD_VERSION=main-30027

# Organization details
ORG_NAME=your-organization
PROJECT_SPACE=/your-org/projects
PROJECT_NAME=TestAutomation
```


## Step 2: Creating the Groundplex

### 2.1 Automated Creation via Robot Framework

The framework automates Groundplex creation using the createplex test:

```bash
# Run the createplex test
make robot-run-tests TAGS=createplex
```

This test performs:
- Authentication with SnapLogic
- Groundplex creation via API
- Configuration file download

### 2.2 Understanding the Creation Process

From `create_plex.robot`:
```robot
Create Snaplex In Project Space
    [Tags]    createplex
    [Template]    Create Snaplex
    ${env_file_path}    
    ${GROUNDPLEX_NAME}    
    ${GROUNDPLEX_ENV}    
    ${ORG_NAME}    
    ${RELEASE_BUILD_VERSION}    
    ${GROUNDPLEX_LOCATION_PATH}
```

## Step 3: Downloading Configuration

### 3.1 Automatic Download

The createplex test automatically creates aconfig dir and downloads the configuration:

```robot
Download And Save slpropz File
    [Tags]    createplex
    [Template]    Download And Save Config File
    ${url}    
    ./.config    
    ${GROUNDPLEX_LOCATION_PATH}    
    ${GROUNDPLEX_NAME}.slpropz
```

### 3.2 Verify Configuration File

```bash
# Check the .slpropz file was downloaded
ls -la test/.config/
# Should see: test-groundplex-dev.slpropz

# Verify file size (should be > 0)
du -h test/.config/*.slpropz
```

### 3.3 Critical: File Name Must Match

⚠️ **IMPORTANT**: The downloaded file name MUST match the GROUNDPLEX_NAME:

- **Groundplex name**: `test-groundplex-dev`
- **File name**: `test-groundplex-dev.slpropz`

If they don't match, the Groundplex will fail silently!

## Step 4: Launching the Container

### 4.1 Using Makefile (Recommended)

```bash
# Launch the Groundplex container
make launch-groundplex
```

This command:
- Uses the `gp` profile from docker-compose
- Mounts the `.slpropz` configuration
- Starts the container in detached mode
- Runs health status check

### 4.2 Direct Docker Compose

```bash
# Alternative: Launch directly with docker-compose
docker compose --profile gp up -d snaplogic-groundplex
```

### 4.3 Understanding the Docker Configuration

From `docker-compose.groundplex.yml`:

```yaml
services:
  snaplogic-groundplex:
    # Official SnapLogic image with dynamic version from env
    image: registry.hub.docker.com/snaplogic/snaplex:${RELEASE_BUILD_VERSION}
    
    # Container name for easy reference
    container_name: snaplogic-groundplex
    
    # Force Linux AMD64 for compatibility
    platform: linux/amd64
    
    # Port mappings
    ports:
      - "8090:8090"  # HTTP port for health checks
      - "8081:8081"  # HTTPS port for secure communication
    
    # Volume mounts
    volumes:
      # Mount configuration file
      - ./test/.config/${GROUNDPLEX_NAME}.slpropz:/opt/snaplogic/etc/${GROUNDPLEX_NAME}.slpropz
      
      # Docker socket for container operations
      - /var/run.docker.sock:/var/run/docker.sock
    
    # Service profile
    profiles: [ gp ]
    
    # Custom network
    networks:
      - snaplogicnet

networks:
  snaplogicnet:
    driver: bridge
```

### 4.4 Monitor Container Startup

```bash
# Watch container logs during startup
docker compose logs -f snaplogic-groundplex

# You should see:
# - JCC starting up
# - Connection to control plane
# - Node registration
```

## Step 5: Health Verification

### 5.1 Automated Health Check

```bash
# Use the Makefile health check
make groundplex-status
```

This runs a loop checking JCC status inside the container.

### 5.2 Manual Health Checks

#### Check Container Status

```bash
# Verify container is running
docker ps | grep snaplogic-groundplex

# Check container health
docker inspect snaplogic-groundplex --format='{{.State.Health.Status}}'
```

#### Check JCC Status Inside Container

```bash
# Execute JCC status check
docker exec snaplogic-groundplex /bin/bash -c \
  "cd /opt/snaplogic/bin && sh jcc.sh status"

# Expected output:
# ✅ JCC is running
```

#### Check HTTP Health Endpoint

```bash
# Test HTTP health endpoint
curl -f http://localhost:8090/healthz

# Or check metrics
curl http://localhost:8090/metrics
```

### 5.3 Verify in SnapLogic UI

1. Log into SnapLogic Manager
2. Navigate to your project space
3. Click on "Snaplex" tab
4. Find your Groundplex
5. Check status shows "Active" with green indicator

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Container Exits Immediately

```bash
# Check exit code
docker ps -a | grep snaplogic-groundplex

# View detailed logs
docker logs snaplogic-groundplex --tail 50

# Common causes:
# - Missing or incorrect .slpropz file
# - File name mismatch
# - Invalid credentials
```

**Solution:**
```bash
# Verify configuration file
ls -la test/.config/${GROUNDPLEX_NAME}.slpropz

# Re-run createplex test
make robot-run-tests TAGS=createplex
```

#### 2. JCC Not Starting

```bash
# Check JCC logs inside container
docker exec snaplogic-groundplex tail -f /opt/snaplogic/run/logs/jcc.log

# Common errors:
# - "Unable to connect to control plane"
# - "Invalid organization or environment"
```

**Solution:**
```bash
# Verify network connectivity
docker exec snaplogic-groundplex ping -c 3 elastic.snaplogic.com

# Check environment variables
docker exec snaplogic-groundplex env | grep -E "GROUNDPLEX|ORG"
```

#### 3. Port Conflicts

```bash
# Error: bind: address already in use

# Find process using port
lsof -i :8090
lsof -i :8081

# Kill conflicting process or change ports
```

**Solution:**
```yaml
# Modify docker-compose.groundplex.yml
ports:
  - "8091:8090"  # Use different host port
  - "8082:8081"
```

#### 4. Memory Issues

```bash
# Check container resources
docker stats snaplogic-groundplex

# If using too much memory, adjust JVM settings
```

**Solution:**
```yaml
# Set memory limits in docker-compose
deploy:
  resources:
    limits:
      memory: 8G
    reservations:
      memory: 4G
```

#### 5. Authentication Failures

```bash
# Check credentials in .slpropz
# Note: File is encrypted, check creation logs

# Re-create with correct credentials
make robot-run-tests TAGS=createplex PROJECT_SPACE_SETUP=False
```

### Debug Commands Cheat Sheet

```bash
# Container status
docker ps -a | grep snaplogic-groundplex

# Container logs
docker logs snaplogic-groundplex --tail 100 -f

# JCC logs
docker exec snaplogic-groundplex tail -f /opt/snaplogic/run/logs/jcc.log

# Health check
docker exec snaplogic-groundplex /opt/snaplogic/bin/jcc.sh status

# Network test
docker exec snaplogic-groundplex curl -I https://elastic.snaplogic.com

# File system check
docker exec snaplogic-groundplex ls -la /opt/snaplogic/etc/

# Process list
docker exec snaplogic-groundplex ps aux | grep java
```

## Advanced Configuration

### Custom JVM Options

```json
// In your Groundplex creation payload:
"node_settings": {
    "jvm_options": "-server -Xms4g -Xmx16g -XX:+UseG1GC",
    "http_port": 8090,
    "https_port": 8081
}
```

### Multi-Node Groundplex

```bash
# Scale to multiple nodes
docker compose --profile gp up -d --scale snaplogic-groundplex=3
```

### Resource Allocation

```yaml
# docker-compose.groundplex.yml
services:
  snaplogic-groundplex:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 16G
        reservations:
          cpus: '2'
          memory: 8G
```

### Custom Network Configuration

```yaml
# Use specific network settings
networks:
  groundplex-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## Best Practices

### 1. Naming Conventions

```bash
# Use environment-specific names
GROUNDPLEX_NAME=projectname-env-purpose
# Examples:
# - salesforce-dev-integration
# - oracle-prod-etl
# - api-test-gateway
```

### 2. Version Management

```bash
# Pin specific versions for stability
RELEASE_BUILD_VERSION=main-30027  # Tested version

# For production, use stable releases
RELEASE_BUILD_VERSION=4.35-stable
```

### 3. Monitoring Setup

```yaml
# Set up log rotation
volumes:
  - ./logs/groundplex:/opt/snaplogic/run/logs
```

```bash
# Monitor disk usage
df -h ./logs/groundplex
```

### 4. Security Considerations

- Keep `.slpropz` files secure (they contain credentials)
- Use read-only volume mounts where possible
- Implement network policies
- Regular security updates

### 5. Automation Tips

```bash
#!/bin/bash
# Create a startup script
make robot-run-tests TAGS=createplex && \
make launch-groundplex && \
make groundplex-status
```

## Complete Launch Workflow

### Quick Start Commands

```bash
# 1. Setup environment
cp .env.example .env
vim .env  # Configure your settings

# 2. Create and launch Groundplex
make robot-run-tests TAGS=createplex
make launch-groundplex

# 3. Verify health
make groundplex-status

# 4. Run tests using the Groundplex
make robot-run-tests TAGS=oracle
```

### Full Automation

```bash
# Complete end-to-end workflow
make robot-run-all-tests

# This runs:
# 1. Environment validation
# 2. Groundplex creation
# 3. Service startup
# 4. Health checks
# 5. Integration tests
```

## Success Indicators

Your Groundplex is successfully running when:

- ✅ Container status shows "Up" and healthy
- ✅ JCC status returns "JCC is running"
- ✅ HTTP health endpoint responds with 200 OK
- ✅ SnapLogic UI shows Groundplex as "Active"
- ✅ You can execute pipelines on the Groundplex
- ✅ No errors in JCC logs

## Additional Resources

- [SnapLogic Groundplex Documentation](https://docs.snaplogic.com/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Robot Framework Keywords Reference](https://robotframework.org/)
- [Troubleshooting Guide](#troubleshooting-guide)

## Important Notes

- **Wait Time**: After launching, wait 30-60 seconds for full initialization
- **File Name Matching**: Configuration file name MUST match Groundplex name
- **Project Cleanup**: Running tests may delete/recreate project spaces
- **Resource Usage**: Monitor memory usage, especially with multiple nodes
- **Network Access**: Ensure firewall rules allow outbound HTTPS

---
*Last Updated: January 2025*