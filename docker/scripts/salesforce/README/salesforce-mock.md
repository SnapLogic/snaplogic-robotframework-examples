# Salesforce Mock Service for SnapLogic Testing

This Docker Compose setup provides a comprehensive mock Salesforce environment for testing SnapLogic integrations without connecting to a real Salesforce instance.

## Overview

The mock service consists of two complementary components:

1. **WireMock** (Port 8089) - Handles Salesforce authentication and API-specific endpoints
2. **JSON Server** (Port 8082) - Provides persistent CRUD operations with real data storage

## Why WireMock for Salesforce Mocking?

We chose WireMock over alternatives like Prism for several reasons:

| Feature | **Prism** | **WireMock** | **Why It Matters for Salesforce** |
|---------|-----------|--------------|-----------------------------------|
| **Setup** | ✅ Easy with OpenAPI spec | ⚠️ Manual mappings | Salesforce doesn't provide OpenAPI specs |
| **Maintenance** | ✅ Auto-updates from spec | ❌ Manual updates | We need custom Salesforce behaviors |
| **Response Quality** | ✅ Schema-based | ✅ Full control | Need exact Salesforce response format |
| **Dynamic Behavior** | ❌ Limited | ✅ Templates, states | OAuth tokens, timestamps, IDs |
| **Custom Logic** | ❌ Basic only | ✅ Highly customizable | SOQL parsing, composite APIs |
| **Error Simulation** | ❌ Generic | ✅ Detailed scenarios | Test rate limits, field errors |
| **Salesforce Features** | ❌ Generic REST | ✅ SF-specific | Bulk API, metadata, describes |

**Key Decision Factors:**
- ❌ Salesforce doesn't provide official OpenAPI specifications
- ✅ Need to simulate complex Salesforce-specific behaviors (SOQL, OAuth flows)
- ✅ Require dynamic response generation (tokens, IDs, timestamps)
- ✅ Must test error scenarios (rate limits, validation errors)
- ✅ Industry standard for complex API mocking

## Quick Start

1. **Start the mock services:**
   ```bash
   make salesforce-mock-start
   ```

2. **Stop the mock services:**
   ```bash
   make salesforce-mock-stop
   ```

3. **Restart the services:**
   ```bash
   make salesforce-mock-restart
   ```

4. **Check service status:**
   ```bash
   make salesforce-mock-status
   ```

## SnapLogic Configuration

### For Authentication (WireMock):
- **Login URL**: `http://salesforce-api-mock:8080`
- **Username**: `snap-qa@snaplogic.com` (or any value)
- **Password**: any value
- **Security Token**: leave empty or any value
- **Sandbox**: ✓ (check this box)

### For CRUD Operations (JSON Server):
- **Base URL**: `http://salesforce-json-mock`
- Or use `http://localhost:8082` from your host machine

## Available Endpoints

### WireMock (Authentication & Salesforce APIs)
- **OAuth Token**: `POST http://salesforce-api-mock:8080/services/oauth2/token`
- **API Versions**: `GET http://salesforce-api-mock:8080/services/data`
- **SOQL Queries**: `GET http://salesforce-api-mock:8080/services/data/v59.0/query`
- **Object Describe**: `GET http://salesforce-api-mock:8080/services/data/v59.0/sobjects/Account/describe`
- **Admin Console**: `http://localhost:8089/__admin/`
- **View Mappings**: `http://localhost:8089/__admin/mappings`

### JSON Server (Persistent CRUD Operations)
- **List Accounts**: `GET http://salesforce-json-mock/accounts`
- **Get Account**: `GET http://salesforce-json-mock/accounts/{id}`
- **Create Account**: `POST http://salesforce-json-mock/accounts`
- **Update Account**: `PUT http://salesforce-json-mock/accounts/{id}`
- **Delete Account**: `DELETE http://salesforce-json-mock/accounts/{id}`
- **Contacts**: `http://salesforce-json-mock/contacts`
- **Opportunities**: `http://salesforce-json-mock/opportunities`

## Testing the Services

### Test OAuth Authentication:
```bash
# From Groundplex container
docker exec snaplogic-groundplex curl -X POST \
  http://salesforce-api-mock:8080/services/oauth2/token \
  -d "grant_type=password"

# From your host
curl -X POST http://localhost:8089/services/oauth2/token \
  -d "grant_type=password"
```

### Test CRUD Operations:
```bash
# List all accounts
curl http://localhost:8082/accounts

# Create a new account
curl -X POST http://localhost:8082/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "Name": "New Test Company",
    "Type": "Customer",
    "Industry": "Technology",
    "AnnualRevenue": 1000000
  }'

# Get specific account
curl http://localhost:8082/accounts/001000000000001
```

## Mock Data

### Initial Data
The JSON Server starts with pre-configured data including:
- **3 sample accounts**: Acme Corporation, Global Innovations Inc, TechStart Solutions
- **2 sample contacts**: Linked to the accounts
- **1 sample opportunity**: Enterprise deal example

### Data Persistence
- All CRUD operations are persisted in `/docker/scripts/salesforce/json-db/salesforce-db.json`
- Data survives container restarts
- You can manually edit the JSON file to add more test data

### Dynamic Data (WireMock)
WireMock generates dynamic values for:
- OAuth tokens (UUIDs)
- Timestamps
- Random IDs for created records

## Architecture

```
SnapLogic Pipeline
       ↓
   [OAuth Request] → WireMock (port 8080/8089)
       ↓                    ↓
   [Get Token]     [Salesforce-specific APIs]
       ↓
   [CRUD Operations] → JSON Server (port 80/8082)
       ↓
   Persistent JSON Database
```

## Customization

### Adding More Mock Endpoints (WireMock)
Edit the mappings file:
```
docker/scripts/salesforce/wiremock/mappings/salesforce-api-mappings.json
```

### Adding More Test Data (JSON Server)
Edit the database file:
```
docker/scripts/salesforce/json-db/salesforce-db.json
```

After making changes, restart the services:
```bash
make salesforce-mock-restart
```

## Monitoring

- **WireMock Admin**: http://localhost:8089/__admin/
- **View all requests**: http://localhost:8089/__admin/requests
- **JSON Server logs**: `docker logs salesforce-json-mock`
- **WireMock logs**: `docker logs salesforce-api-mock`

## Troubleshooting

### Port Already in Use
If port 8089 or 8082 is already in use:
1. Change the port in `docker-compose.salesforce-mock.yml`
2. Update your SnapLogic configuration accordingly

### Connection Refused
1. Ensure both services are running: `make salesforce-mock-status`
2. Verify containers are on the same network: `docker network inspect docker_snaplogicnet`
3. Check if Groundplex can reach the services:
   ```bash
   docker exec snaplogic-groundplex curl http://salesforce-api-mock:8080/__admin/health
   docker exec snaplogic-groundplex curl http://salesforce-json-mock/accounts
   ```

### Authentication Issues
- The mock accepts any credentials
- Ensure you're using the correct URLs for each service
- WireMock for auth, JSON Server for data

## Integration with Robot Framework Tests

Use these variables in your Robot Framework tests:
```robot
*** Variables ***
${SALESFORCE_AUTH_URL}     http://salesforce-api-mock:8080
${SALESFORCE_DATA_URL}     http://salesforce-json-mock
${SALESFORCE_USERNAME}     snap-qa@snaplogic.com
${SALESFORCE_PASSWORD}     test123
```

## Best Practices

1. **Use WireMock for**: OAuth, Salesforce-specific APIs, SOQL queries
2. **Use JSON Server for**: CRUD operations, data that needs to persist
3. **Keep test data realistic**: Use proper Salesforce field names and data types
4. **Clean up after tests**: Reset test data when needed
5. **Version control**: Commit your mock mappings and test data

## Notes

- Both services run on the `docker_snaplogicnet` network (same as Groundplex)
- The 403 error when accessing WireMock's root URL is normal
- All data is stored locally and not shared outside your environment
- These are mock services for testing only - never use in production
