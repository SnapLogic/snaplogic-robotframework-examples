# Salesforce Mock Service Usage Guide

## Overview

This guide provides comprehensive documentation for the Salesforce API mock service used in SnapLogic Robot Framework testing. The mock service simulates Salesforce's REST API, OAuth authentication, and Bulk API endpoints, enabling local development and testing without connecting to a real Salesforce instance.

## Table of Contents

- [Purpose](#purpose)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Services](#services)
- [Configuration](#configuration)
- [Available Endpoints](#available-endpoints)
- [SnapLogic Integration](#snaplogic-integration)
- [Usage Examples](#usage-examples)
- [Directory Structure](#directory-structure)
- [Troubleshooting](#troubleshooting)

## Purpose

The Salesforce mock service provides the following benefits:

- **Local Testing**: Test SnapLogic pipelines without Salesforce credentials
- **Development**: Develop and debug Salesforce integrations offline
- **CI/CD Integration**: Run automated tests in pipelines without external dependencies
- **Rate Limit Avoidance**: No API rate limits during development
- **Cost Savings**: No Salesforce API usage costs
- **Data Safety**: No risk of modifying production data
- **Predictable Results**: Consistent mock responses for reliable testing

## Architecture

The mock service uses a Docker Compose configuration with multiple services:

```
┌─────────────────────┐
│   SnapLogic Tests   │
└──────────┬──────────┘
           │
    ┌──────▼──────┐
    │   Network    │
    │ snaplogicnet │
    └──────┬──────┘
           │
    ┌──────┴───────────────┬─────────────────┐
    │                      │                 │
┌───▼────────────┐  ┌──────▼──────┐  ┌──────▼──────┐
│ WireMock       │  │ JSON Server │  │ Prism Mock  │
│ (Primary Mock) │  │ (CRUD Ops)  │  │ (Optional)  │
└────────────────┘  └─────────────┘  └─────────────┘
```

## Quick Start

### Starting the Service

```bash
# Navigate to the docker directory
cd /path/to/snaplogic-robotframework-examples/docker

# Start the Salesforce mock service
docker-compose -f docker-compose.salesforce-mock.yml up -d

# Verify the service is running
docker ps | grep salesforce

# Check service health
curl http://localhost:8089/__admin/health
```

### Stopping the Service

```bash
# Stop and remove containers
docker-compose -f docker-compose.salesforce-mock.yml down

# Stop and remove containers with volumes
docker-compose -f docker-compose.salesforce-mock.yml down -v
```

## Services

### 1. salesforce-mock (WireMock)

The primary mock service using WireMock v3.3.1.

**Configuration:**
- **Image**: `wiremock/wiremock:3.3.1`
- **Container Name**: `salesforce-api-mock`
- **Ports**: `8089:8080` (host:container)
- **Network**: `snaplogicnet`

**Features:**
- Global response templating for dynamic responses
- CORS support enabled
- Verbose logging for debugging
- Health check endpoint
- Request journal for debugging (max 1000 entries)

**Command Options:**
```yaml
command: >
  --global-response-templating 
  --verbose 
  --disable-banner
  --enable-stub-cors
```

### 2. salesforce-json-server

Provides persistent CRUD operations using JSON Server.

**Configuration:**
- **Image**: `clue/json-server`
- **Container Name**: `salesforce-json-mock`
- **Ports**: `8082:80`
- **Database**: `/data/salesforce-db.json`

**Use Cases:**
- Stateful operations requiring data persistence
- Complex CRUD scenarios
- Data relationship testing

### 3. salesforce-prism (Optional)

An alternative OpenAPI-based mock using Stoplight Prism (currently commented out).

**When to Use:**
- When you have OpenAPI specifications for Salesforce
- Need more accurate API contract validation
- Testing specific API versions

## Configuration

### Volume Mappings

```yaml
volumes:
  # WireMock stub mappings
  - ./scripts/salesforce/wiremock/mappings:/home/wiremock/mappings:ro
  
  # Response templates and files
  - ./scripts/salesforce/wiremock/__files:/home/wiremock/__files:ro
  
  # JSON Server database
  - ./scripts/salesforce/json-db:/data
```

### Network Configuration

The service uses a custom bridge network `snaplogicnet` which:
- Isolates mock services from other Docker networks
- Allows inter-service communication using container names
- Provides DNS resolution between containers

### Environment Variables

```yaml
environment:
  - WIREMOCK_OPTIONS=--max-request-journal-entries=1000
```

## Available Endpoints

### OAuth Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/services/oauth2/token` | POST | OAuth token endpoint |
| `/services/oauth2/revoke` | POST | Token revocation |
| `/services/oauth2/userinfo` | GET | User information |

### REST API Endpoints (v59.0)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/services/data/v59.0/query` | GET | SOQL queries |
| `/services/data/v59.0/sobjects/{object}` | POST | Create records |
| `/services/data/v59.0/sobjects/{object}/{id}` | GET | Retrieve record |
| `/services/data/v59.0/sobjects/{object}/{id}` | PATCH | Update record |
| `/services/data/v59.0/sobjects/{object}/{id}` | DELETE | Delete record |
| `/services/data/v59.0/sobjects` | GET | List all objects |
| `/services/data/v59.0/describe` | GET | Describe global |

### Bulk API Endpoints (v59.0)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/services/async/59.0/job` | POST | Create bulk job |
| `/services/async/59.0/job/{jobId}` | GET | Get job status |
| `/services/async/59.0/job/{jobId}/batch` | POST | Add batch |
| `/services/async/59.0/job/{jobId}/batch/{batchId}` | GET | Get batch status |

## SnapLogic Integration

### Configuration in SnapLogic

#### When SnapLogic is Running in Docker (Same Network)

```
Login URL: http://salesforce-api-mock:8080
Username: snap-qa@snaplogic.com
Password: [any value]
Security Token: [leave empty or any value]
Client ID: [any value]
Client Secret: [any value]
```

#### When SnapLogic is Running on Host Machine

```
Login URL: http://localhost:8089
Username: snap-qa@snaplogic.com
Password: [any value]
Security Token: [leave empty or any value]
Client ID: [any value]
Client Secret: [any value]
```

### Account Configuration in SnapLogic Designer

1. Create a new Salesforce Account
2. Set the Login URL based on your deployment scenario
3. Enter any credentials (the mock accepts all)
4. Test the connection
5. Use in your pipelines

## Usage Examples

### 1. Test OAuth Authentication

```bash
curl -X POST http://localhost:8089/services/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=test&client_secret=test&username=test@test.com&password=test"
```

**Response:**
```json
{
  "access_token": "mock-token-12345",
  "instance_url": "http://localhost:8089",
  "id": "https://login.salesforce.com/id/00D000000000000EAA/005000000000000AAA",
  "token_type": "Bearer",
  "issued_at": "1234567890000",
  "signature": "mock-signature"
}
```

### 2. Query Accounts (SOQL)

```bash
curl -X GET "http://localhost:8089/services/data/v59.0/query?q=SELECT+Id,Name+FROM+Account" \
  -H "Authorization: Bearer mock-token-12345"
```

**Response:**
```json
{
  "totalSize": 2,
  "done": true,
  "records": [
    {
      "attributes": {
        "type": "Account",
        "url": "/services/data/v59.0/sobjects/Account/001000000000001"
      },
      "Id": "001000000000001",
      "Name": "Acme Corporation"
    },
    {
      "attributes": {
        "type": "Account",
        "url": "/services/data/v59.0/sobjects/Account/001000000000002"
      },
      "Id": "001000000000002",
      "Name": "Global Industries"
    }
  ]
}
```

### 3. Create an Account

```bash
curl -X POST http://localhost:8089/services/data/v59.0/sobjects/Account \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer mock-token-12345" \
  -d '{
    "Name": "Test Account",
    "Type": "Customer",
    "Industry": "Technology",
    "Phone": "555-1234"
  }'
```

**Response:**
```json
{
  "id": "001000000000003",
  "success": true,
  "errors": []
}
```

### 4. Get Account by ID

```bash
curl -X GET http://localhost:8089/services/data/v59.0/sobjects/Account/001000000000001 \
  -H "Authorization: Bearer mock-token-12345"
```

**Response:**
```json
{
  "attributes": {
    "type": "Account",
    "url": "/services/data/v59.0/sobjects/Account/001000000000001"
  },
  "Id": "001000000000001",
  "Name": "Acme Corporation",
  "Type": "Customer",
  "Industry": "Manufacturing",
  "Phone": "555-0100",
  "Website": "www.acme.com",
  "CreatedDate": "2024-01-15T10:30:00.000+0000",
  "LastModifiedDate": "2024-01-20T14:45:00.000+0000"
}
```

### 5. Update an Account

```bash
curl -X PATCH http://localhost:8089/services/data/v59.0/sobjects/Account/001000000000001 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer mock-token-12345" \
  -d '{
    "Phone": "555-9999",
    "Website": "www.acme-updated.com"
  }'
```

### 6. Delete an Account

```bash
curl -X DELETE http://localhost:8089/services/data/v59.0/sobjects/Account/001000000000001 \
  -H "Authorization: Bearer mock-token-12345"
```

### 7. Bulk API Example

```bash
# Create a bulk job
curl -X POST http://localhost:8089/services/async/59.0/job \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer mock-token-12345" \
  -d '{
    "operation": "insert",
    "object": "Account",
    "contentType": "CSV"
  }'
```

## Directory Structure

The mock service expects the following directory structure:

```
docker/
├── docker-compose.salesforce-mock.yml
└── scripts/
    └── salesforce/
        ├── README-salesfore-mock-usage.md  # This file
        ├── wiremock/
        │   ├── mappings/                    # WireMock stub definitions
        │   │   ├── oauth-endpoints.json
        │   │   ├── account-endpoints.json
        │   │   ├── contact-endpoints.json
        │   │   └── query-endpoints.json
        │   └── __files/                     # Response templates
        │       ├── account-list.json
        │       ├── contact-list.json
        │       └── oauth-response.json
        └── json-db/
            └── salesforce-db.json           # JSON Server database
```

### Sample WireMock Mapping

```json
{
  "request": {
    "method": "GET",
    "urlPathPattern": "/services/data/v59.0/sobjects/Account/.*"
  },
  "response": {
    "status": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "bodyFileName": "account-detail.json",
    "transformers": ["response-template"]
  }
}
```

### Sample JSON Server Database

```json
{
  "accounts": [
    {
      "id": "001000000000001",
      "Name": "Acme Corporation",
      "Type": "Customer"
    }
  ],
  "contacts": [
    {
      "id": "003000000000001",
      "FirstName": "John",
      "LastName": "Doe",
      "AccountId": "001000000000001"
    }
  ]
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Port Already in Use

**Error:** `bind: address already in use`

**Solution:**
```bash
# Find process using port 8089
lsof -i :8089

# Kill the process
kill -9 <PID>

# Or use a different port in docker-compose.yml
ports:
  - "8090:8080"
```

#### 2. WireMock Not Responding

**Check logs:**
```bash
docker logs salesforce-api-mock
```

**Verify mappings are mounted:**
```bash
docker exec salesforce-api-mock ls -la /home/wiremock/mappings
```

#### 3. Authentication Failures

**Ensure you're using the correct URL:**
- Docker network: `http://salesforce-api-mock:8080`
- Host machine: `http://localhost:8089`

#### 4. Missing Responses

**Check if mapping exists:**
```bash
curl http://localhost:8089/__admin/mappings
```

**View request journal:**
```bash
curl http://localhost:8089/__admin/requests
```

### Debug Mode

Enable debug logging by modifying the docker-compose command:

```yaml
command: >
  --global-response-templating 
  --verbose 
  --disable-banner
  --enable-stub-cors
  --root-dir /home/wiremock
  --print-all-network-traffic
```

### Health Checks

Monitor service health:

```bash
# WireMock health
curl http://localhost:8089/__admin/health

# JSON Server health
curl http://localhost:8082/

# Check all running containers
docker-compose -f docker-compose.salesforce-mock.yml ps
```

## Best Practices

1. **Version Control**: Keep mock mappings and responses in version control
2. **Data Consistency**: Ensure mock data matches your test scenarios
3. **Error Scenarios**: Include error response mappings for negative testing
4. **Performance**: Limit response sizes for better performance
5. **Documentation**: Document custom mappings and their purposes
6. **Cleanup**: Regularly clean up unused mappings and responses

## Advanced Configuration

### Custom Response Templates

WireMock supports Handlebars templates for dynamic responses:

```json
{
  "response": {
    "status": 200,
    "jsonBody": {
      "id": "{{randomValue type='UUID'}}",
      "createdDate": "{{now}}",
      "name": "{{request.body.Name}}"
    },
    "transformers": ["response-template"]
  }
}
```

### Stateful Scenarios

Configure WireMock scenarios for stateful behavior:

```json
{
  "scenarioName": "Account Creation Flow",
  "requiredScenarioState": "Started",
  "newScenarioState": "Account Created",
  "request": {
    "method": "POST",
    "url": "/services/data/v59.0/sobjects/Account"
  }
}
```

### Performance Tuning

For high-load testing, adjust Docker resources:

```yaml
services:
  salesforce-mock:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '1'
          memory: 512M
```

## Contributing

To add new mock endpoints:

1. Create mapping file in `wiremock/mappings/`
2. Add response template in `wiremock/__files/`
3. Test the endpoint
4. Document in this README
5. Submit pull request

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review WireMock logs
3. Consult the SnapLogic Robot Framework documentation
4. Contact the QA team

---

Last Updated: 2024-01-20
Version: 1.0.0
