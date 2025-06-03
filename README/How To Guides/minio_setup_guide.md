# MinIO Setup and Configuration Guide
*Mock S3 Server for SnapLogic S3 Snap Testing*

## Overview: MinIO as Mock S3 Server

**MinIO serves as a local mock S3 server specifically designed for testing SnapLogic S3 snaps without requiring actual AWS S3 services.** This setup provides:

- **Cost-Free Testing** - No AWS charges during development and testing
- **Offline Development** - Test S3 snaps without internet connectivity  
- **Complete S3 API Compatibility** - Full support for SnapLogic S3 snap operations
- **Isolated Test Environment** - No risk of affecting production S3 buckets
- **Rapid Testing Cycles** - Instant setup and teardown for continuous testing

### Why Mock S3 for SnapLogic Testing?

When developing and testing SnapLogic pipelines that use S3 snaps (S3 Reader, S3 Writer, S3 List, etc.), you need:

1. **Reliable Test Data** - Consistent, predictable S3 objects for validation
2. **Safe Testing Environment** - No accidental production data modifications  
3. **Cost Control** - Avoid AWS storage and request charges during testing
4. **Network Independence** - Test without internet or VPN connectivity
5. **Performance** - Local storage for faster test execution

**MinIO perfectly fulfills these requirements by providing a local S3-compatible server that SnapLogic S3 snaps can connect to as if it were real AWS S3.**

## Table of Contents

1. [What is MinIO?](#what-is-minio)
2. [MinIO in SnapLogic Testing Framework](#minio-in-snaplogic-testing-framework)
3. [Docker Compose Configuration](#docker-compose-configuration)
4. [Automated Data Setup Process](#automated-data-setup-process)
5. [Profile-Based Deployment](#profile-based-deployment)
6. [Accessing MinIO](#accessing-minio)
7. [Pre-configured Data and Structure](#pre-configured-data-and-structure)
8. [Integration with SnapLogic Tests](#integration-with-snaplogic-tests)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## What is MinIO?

MinIO is a high-performance, S3-compatible object storage system that **acts as a perfect mock server for testing SnapLogic S3 snaps**. In our testing framework, MinIO replaces AWS S3 to provide:

- **Complete S3 API Emulation** - All S3 operations work identically
- **SnapLogic S3 Snap Compatibility** - Drop-in replacement for AWS S3 endpoints
- **Local Development Server** - Runs entirely on your local machine
- **Zero AWS Dependencies** - No cloud accounts or credentials needed


### Why MinIO for SnapLogic S3 Snap Testing?

- **Perfect S3 Snap Compatibility** - All SnapLogic S3 snaps work without modification
- **Cost Effective** - No AWS charges for development and testing
- **Offline Testing** - Test S3 snaps without internet dependency
- **Consistent Environment** - Same S3 behavior across dev/test/prod
- **Fast Setup** - Quick container deployment for immediate testing
- **Safe Testing** - No risk of affecting production S3 data

## MinIO in SnapLogic Testing Framework

In our SnapLogic test automation framework, **MinIO serves as the primary mock S3 server** for testing all S3-related snaps and pipelines:

- **S3 Snap Testing** - Test S3 Reader, S3 Writer, S3 List, and other S3 snaps
- **Pipeline Validation** - End-to-end testing of S3-based data workflows  
- **Mock S3 Operations** - All S3 operations (GET, PUT, LIST, DELETE) work identically
- **Account Configuration Testing** - Validate S3 account configurations
- **Error Scenario Testing** - Test error handling without affecting real S3 data

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│              SnapLogic S3 Snap Testing Architecture             │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │    Robot    │    │ SnapLogic   │    │   MinIO Mock S3     │ │
│  │ Framework   │◄──►│ Groundplex  │◄──►│     Server          │ │
│  │   Tests     │    │             │    │                     │ │
│  └─────────────┘    └─────────────┘    │ • S3 Reader Snap    │ │
│                                         │ • S3 Writer Snap    │ │
│  S3 Snap Test Flow:                     │ • S3 List Snap      │ │
│  Tests → Groundplex → S3 Snaps → MinIO │ • S3 Delete Snap    │ │
│                     (Mock S3 API)      │ • All S3 Operations │ │
│                                         └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Docker Compose Configuration

### MinIO Service Configuration

```yaml
services:
  minio:
    image: minio/minio:latest
    container_name: snaplogic-minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
      MINIO_BROWSER_REDIRECT_URL: http://localhost:9001
      MINIO_SERVER_URL: http://localhost:9000
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"   # S3 API port
      - "9001:9001"   # Web Console port
    profiles: [ minio , minio-dev ]
    healthcheck:
      test: [ "CMD", "curl", "-f", "http://localhost:9000/minio/health/live" ]
      interval: 10s
      timeout: 5s
      retries: 3
    networks:
      - snaplogicnet
```

### Key Configuration Elements



#### Port Mapping
- **Port 9000**: S3 API endpoint for applications
- **Port 9001**: Web console for browser access

#### Volume Mount
- **minio_data**: Persistent storage for S3 objects
- **Mount Point**: `/data` inside container

#### Health Check
- **Endpoint**: `/minio/health/live`
- **Interval**: Every 10 seconds
- **Timeout**: 5 seconds
- **Retries**: 3 attempts

## Automated Data Setup Process

### MinIO Setup Service

The framework includes an automated setup service that configures MinIO with initial data:

```yaml
minio-setup:
  image: minio/mc:latest
  container_name: snaplogic-minio-setup
  depends_on:
    minio:
      condition: service_healthy
```

### Setup Script Breakdown

The setup process performs the following operations:

#### 1. Client Configuration
```bash
mc alias set local http://minio:9000 minioadmin minioadmin
```
- Configures MinIO client (`mc`) to connect to local MinIO instance
- Uses admin credentials for initial setup

#### 2. User Management
```bash
mc admin user add local demouser demopassword
mc admin policy attach local readwrite --user demouser
```
- Creates a demo user: `demouser` with password `demopassword`
- Attaches `readwrite` policy for full access

#### 3. Bucket Creation
```bash
mc ls local/demo-bucket || mc mb local/demo-bucket
mc ls local/test-bucket || mc mb local/test-bucket
```
- Creates two buckets:
  - **demo-bucket**: For demonstration data
  - **test-bucket**: For test data

#### 4. Test Data Upload
```bash
echo 'Hello from MinIO! This is a test file created during setup.' > /tmp/test-file.txt
echo 'Created: '$(date) >> /tmp/test-file.txt
echo 'MinIO Server: http://localhost:9000' >> /tmp/test-file.txt

mc cp /tmp/test-file.txt local/demo-bucket/welcome.txt
mc cp /tmp/test-file.txt local/test-bucket/setup-info.txt
```

Creates and uploads test files with:
- Welcome message
- Creation timestamp
- Server information

#### 5. Configuration Metadata
```bash
echo '{"setup_date":"'$(date -Iseconds)'","buckets":["demo-bucket","test-bucket"],"users":["demouser"],"status":"completed"}' > /tmp/setup-config.json

mc cp /tmp/setup-config.json local/demo-bucket/config.json
```

Generates setup metadata JSON with:
- Setup completion timestamp
- List of created buckets
- List of created users
- Setup status

#### 6. Verification and Reporting
```bash
echo '=== demo-bucket contents ==='
mc ls local/demo-bucket
echo '=== test-bucket contents ==='
mc ls local/test-bucket
```

Lists all created objects for verification.

## Profile-Based Deployment

### Available Profiles

The MinIO service supports multiple deployment profiles:

#### Profile: `minio`
```bash
docker compose --profile minio up -d
```
- Starts both MinIO server and setup service
- Performs complete initialization with data
- Ready for immediate testing

#### Profile: `minio-dev`
```bash
docker compose --profile minio-dev up -d
```
- Starts only MinIO server
- No automatic data setup
- Manual configuration required

### Profile Usage Examples

#### Complete Setup (Recommended for Testing)
```bash
# Start MinIO with full setup
make start-s3-emulator
# OR
docker compose --profile minio up -d
```

#### Development Setup
```bash
# Start MinIO only
docker compose --profile minio-dev up -d
```

#### Combined Profiles
```bash
# Start MinIO with other services
COMPOSE_PROFILES=minio,oracle-dev docker compose up -d
```

## Accessing MinIO

### Web Console Access

**URL**: http://localhost:9001

**Admin Credentials**:
- Username: `minioadmin`
- Password: `minioadmin`

**User Credentials**:
- Username: `demouser`
- Password: `demopassword`

### S3 API Access

**Endpoint**: http://localhost:9000

**SDK Configuration**:
```python
import boto3

s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin',
    region_name='us-east-1'
)
```

### MinIO Client (mc) Access

```bash
# Configure alias
mc alias set local http://localhost:9000 minioadmin minioadmin

# List buckets
mc ls local

# List objects in bucket
mc ls local/demo-bucket

# Upload file
mc cp file.txt local/demo-bucket/

# Download file
mc cp local/demo-bucket/file.txt ./downloaded-file.txt
```

## Pre-configured Data and Structure

When MinIO starts with the `minio` profile, it automatically creates:

### Buckets
1. **demo-bucket**
   - Purpose: Demonstration and example data
   - Pre-loaded with welcome files
   - Contains setup configuration metadata

2. **test-bucket**
   - Purpose: Test data storage
   - Pre-loaded with setup information
   - Used by automated tests

### Files Structure
```
demo-bucket/
├── welcome.txt          # Welcome message with setup info
└── config.json          # Setup metadata and configuration

test-bucket/
└── setup-info.txt       # Test file with server information
```

### Sample File Contents

#### welcome.txt / setup-info.txt
```
Hello from MinIO! This is a test file created during setup.
Created: 2025-01-XX 10:XX:XX
MinIO Server: http://localhost:9000
```

#### config.json
```json
{
  "setup_date": "2025-01-XX10:XX:XX",
  "buckets": ["demo-bucket", "test-bucket"],
  "users": ["demouser"],
  "status": "completed"
}
```

### Users and Permissions

#### Root User (Admin)
- **Username**: `minioadmin`
- **Password**: `minioadmin`
- **Permissions**: Full administrative access
- **Use Case**: Administrative tasks, user management

#### Demo User
- **Username**: `demouser`
- **Password**: `demopassword`
- **Policy**: `readwrite`
- **Permissions**: Read/write access to all buckets
- **Use Case**: Application testing, pipeline operations

## Integration with SnapLogic Tests

### S3 Snap Configuration

When configuring S3 snaps in SnapLogic pipelines for testing:

```json
{
  "account_type": "AWS S3",
  "s3_endpoint": "http://minio:9000",
  "access_key_id": "demouser",
  "secret_access_key": "demopassword",
}
```

### Test Pipeline Examples

#### Reading from MinIO
```
S3 Reader Snap → Data Processing → Output
```
- **Bucket**: `demo-bucket` or `test-bucket`
- **Objects**: Pre-loaded test files
- **Format**: Text, JSON, CSV as needed

#### Writing to MinIO
```
Data Source → Data Transformation → S3 Writer Snap
```
- **Destination**: `test-bucket`
- **Output**: Processed test results
- **Verification**: Automated content validation

### Account Configuration in Tests

The test framework uses account payloads for S3 configuration:

```json
{
  "class_id": "com.snaplogic.account.s3",
  "class_version": 1,
  "settings": {
    "service_endpoint": "http://snaplogic-minio:9000",
    "access_key_id": "demouser",
    "secret_access_key": "demopassword",
    "region": "us-east-1",
    "enable_path_style_access": true
  }
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. MinIO Container Won't Start

**Symptoms**:
- Container exits immediately
- Port binding errors

**Solutions**:
```bash
# Check port conflicts
lsof -i :9000
lsof -i :9001

# Stop conflicting services
docker compose down

# Check container logs
docker logs snaplogic-minio
```

#### 2. Setup Service Fails

**Symptoms**:
- Setup container exits with error
- No buckets or users created

**Solutions**:
```bash
# Check MinIO health
docker exec snaplogic-minio curl -f http://localhost:9000/minio/health/live

# View setup logs
docker logs snaplogic-minio-setup

# Retry setup
docker compose --profile minio down
docker compose --profile minio up -d
```

#### 3. Web Console Access Issues

**Symptoms**:
- Cannot access http://localhost:9001
- Login failures

**Solutions**:
```bash
# Verify container is running
docker ps | grep snaplogic-minio

# Check port mapping
docker port snaplogic-minio

# Use correct credentials
# Admin: minioadmin/minioadmin
# User: demouser/demopassword
```

#### 4. S3 API Connection Problems

**Symptoms**:
- Connection refused on port 9000
- Authentication errors

**Solutions**:
```bash
# Test S3 API endpoint
curl http://localhost:9000/minio/health/live

# Verify credentials
mc alias set test http://localhost:9000 minioadmin minioadmin
mc ls test

# Check network connectivity from other containers
docker exec snaplogic-groundplex curl -f http://snaplogic-minio:9000/minio/health/live
```

#### 5. Data Persistence Issues

**Symptoms**:
- Data lost after container restart
- Empty buckets

**Solutions**:
```bash
# Check volume mounting
docker inspect snaplogic-minio | grep -A 10 "Mounts"

# Verify volume exists
docker volume ls | grep minio_data

# Restart with setup
docker compose --profile minio down -v
docker compose --profile minio up -d
```

### Debug Commands

```bash
# Container status
docker ps -a | grep minio

# Container logs
docker logs snaplogic-minio -f
docker logs snaplogic-minio-setup

# Exec into container
docker exec -it snaplogic-minio sh

# Test S3 operations
mc alias set debug http://localhost:9000 minioadmin minioadmin
mc ls debug
mc mb debug/test-debug
mc cp /etc/hostname debug/test-debug/
```

## Best Practices

### 1. Data Management

```bash
# Regular backup of test data
docker exec snaplogic-minio mc mirror local /backup

# Clean test data between test runs
docker exec snaplogic-minio mc rm --recursive --force local/test-bucket/temp/
```

### 2. Security

```bash
# Use different credentials for different environments
# Development
MINIO_ROOT_USER=dev-admin
MINIO_ROOT_PASSWORD=dev-secret

# Testing
MINIO_ROOT_USER=test-admin
MINIO_ROOT_PASSWORD=test-secret
```

### 3. Performance Optimization

```yaml
# Resource limits for production-like testing
services:
  minio:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1'
        reservations:
          memory: 1G
```

### 4. Network Configuration

```yaml
# Custom network for isolation
networks:
  minio-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.25.0.0/16
```

### 5. Monitoring and Logging

```yaml
# Structured logging
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### 6. Environment-Specific Configurations

```bash
# Development: Fast setup, minimal data
COMPOSE_PROFILES=minio-dev

# Testing: Full setup with test data
COMPOSE_PROFILES=minio

# Integration: Combined with other services
COMPOSE_PROFILES=minio,oracle-dev,gp
```

## Quick Reference

### Startup Commands
```bash
# Full MinIO setup
docker compose --profile minio up -d

# MinIO only (no setup)
docker compose --profile minio-dev up -d

# Via Makefile
make start-s3-emulator
```

### Access URLs
- **Web Console**: http://localhost:9001
- **S3 API**: http://localhost:9000
- **Health Check**: http://localhost:9000/minio/health/live

### Default Credentials
- **Admin**: `minioadmin` / `minioadmin`
- **User**: `demouser` / `demopassword`

### Pre-created Resources
- **Buckets**: `demo-bucket`, `test-bucket`
- **Test Files**: `welcome.txt`, `setup-info.txt`, `config.json`

---

MinIO provides a robust, S3-compatible storage solution for SnapLogic testing, offering complete automation, pre-configured test data, and seamless integration with the testing framework. The profile-based deployment ensures flexibility while the automated setup guarantees consistent, ready-to-use storage for all test scenarios.