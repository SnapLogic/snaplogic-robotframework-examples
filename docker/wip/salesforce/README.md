# Salesforce API Mock Setup

This directory contains Docker Compose configurations to mock Salesforce REST APIs for testing SnapLogic integrations.

## Quick Start

1. **Start all mock services:**
   ```bash
   docker-compose -f docker-compose-salesforce-mock.yml up -d
   ```

2. **Available endpoints:**
   - **Prism Mock (OpenAPI)**: http://localhost:8080
   - **WireMock**: http://localhost:8081
   - **JSON Server**: http://localhost:8082
   - **Mockoon**: http://localhost:8083

## Mock Services Overview

### 1. Prism (OpenAPI Mock Server)
- Port: 8080
- Auto-generates responses from OpenAPI specification
- Good for standard REST API testing
- Configuration: `salesforce-openapi.yaml`

### 2. WireMock
- Port: 8081
- Advanced request matching and response templating
- Supports dynamic responses and state
- Mappings in: `wiremock/mappings/`

### 3. JSON Server
- Port: 8082
- Simple CRUD operations on JSON data
- Database: `salesforce-db.json`
- Automatic REST routes for each collection

### 4. Mockoon
- Port: 8083
- GUI-based API mocking (optional)
- Config: `mockoon/salesforce-env.json`

## Testing Authentication

```bash
# Get OAuth token from WireMock
curl -X POST http://localhost:8081/services/data/v59.0/oauth2/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=test&client_secret=test&username=test&password=test"
```

## Testing Queries

```bash
# Query accounts
curl -X GET "http://localhost:8081/services/data/v59.0/query?q=SELECT+Id,Name+FROM+Account" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Testing CRUD Operations

```bash
# Create account
curl -X POST http://localhost:8081/services/data/v59.0/sobjects/Account \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"Name": "Test Account", "Type": "Customer"}'

# Get specific account (JSON Server)
curl http://localhost:8082/accounts/001XXXXXXXXXXXXXXX
```

## Customization

### Adding New Endpoints

1. **For Prism**: Update `salesforce-openapi.yaml`
2. **For WireMock**: Add JSON files to `wiremock/mappings/`
3. **For JSON Server**: Update `salesforce-db.json`

### Adding Response Data

- Place static response files in `wiremock/__files/`
- Update database entries in `salesforce-db.json`

## Integration with SnapLogic

Configure your SnapLogic Salesforce Snaps to use:
- **Instance URL**: `http://localhost:8081` (or appropriate port)
- **Auth Endpoint**: `http://localhost:8081/services/data/v59.0/oauth2/token`
- **API Version**: `v59.0`

## Troubleshooting

1. **Check service status:**
   ```bash
   docker-compose -f docker-compose-salesforce-mock.yml ps
   ```

2. **View logs:**
   ```bash
   docker-compose -f docker-compose-salesforce-mock.yml logs [service-name]
   ```

3. **Reset all services:**
   ```bash
   docker-compose -f docker-compose-salesforce-mock.yml down
   docker-compose -f docker-compose-salesforce-mock.yml up -d
   ```

## Notes

- All services run on the same Docker network (`snaplogic-test-network`)
- Modify port mappings in docker-compose.yml if conflicts occur
- For production-like testing, use WireMock with comprehensive mappings
- For quick prototyping, use JSON Server or Prism
