# WireMock Proxy Mappings for Salesforce API

## Overview
This directory contains WireMock proxy mappings that enable stateful CRUD operations by forwarding requests to a JSON database server (json-server) while maintaining Salesforce API compatibility.

## Architecture

```
Robot Framework Tests
        ↓
    WireMock (Port 8443)
        ↓
    Proxy Mappings
        ↓
    JSON Server (salesforce-json-mock)
        ↓
    Persistent Data Storage
```

## Proxy Mappings List

### Authentication & Core APIs
- `01-proxy-oauth-token.json` - OAuth2 token generation (static response)
- `08-proxy-get-user-info.json` - User information endpoint
- `09-proxy-get-api-versions.json` - Available API versions
- `10-proxy-get-resources.json` - API resources listing
- `11-proxy-list-sobjects.json` - List all Salesforce objects
- `12-proxy-get-limits.json` - API limits and usage

### Account Operations
- `02-proxy-create-account.json` - Create new account (proxied to JSON DB)
- `03-proxy-get-account.json` - Get account by ID (proxied to JSON DB)
- `04-proxy-update-account.json` - Update account (proxied to JSON DB)
- `05-proxy-delete-account.json` - Delete account (proxied to JSON DB)
- `06-proxy-query-accounts.json` - SOQL query for accounts (proxied to JSON DB)
- `13-proxy-describe-account.json` - Account metadata/schema

### Contact Operations
- `07-proxy-create-contact.json` - Create new contact (proxied to JSON DB)
- `14-proxy-get-contact.json` - Get contact by ID (proxied to JSON DB)
- `15-proxy-update-contact.json` - Update contact (proxied to JSON DB)
- `16-proxy-delete-contact.json` - Delete contact (proxied to JSON DB)
- `17-proxy-query-contacts.json` - SOQL query for contacts (proxied to JSON DB)
- `23-proxy-describe-contact.json` - Contact metadata/schema

### Opportunity Operations
- `18-proxy-create-opportunity.json` - Create new opportunity (proxied to JSON DB)
- `19-proxy-get-opportunity.json` - Get opportunity by ID (proxied to JSON DB)
- `20-proxy-update-opportunity.json` - Update opportunity (proxied to JSON DB)
- `21-proxy-delete-opportunity.json` - Delete opportunity (proxied to JSON DB)
- `22-proxy-query-opportunities.json` - SOQL query for opportunities (proxied to JSON DB)
- `24-proxy-describe-opportunity.json` - Opportunity metadata/schema

## Key Features

### 1. Stateful Operations
Unlike static mappings, proxy mappings maintain state through JSON DB:
- Created records persist and can be retrieved
- Updates modify existing records
- Deletes remove records from storage
- Queries return actual stored data

### 2. URL Rewriting
Proxy mappings transform Salesforce API URLs to JSON Server endpoints:
```
Salesforce: /services/data/v59.0/sobjects/Account
JSON Server: /accounts
```

### 3. Response Transformation
Responses from JSON Server are wrapped in Salesforce-compatible format:
```json
{
  "id": "{{jsonPath response.body '$.id'}}",
  "success": true,
  "errors": []
}
```

### 4. SOQL Query Support
Query mappings transform JSON Server responses into Salesforce query format:
```json
{
  "totalSize": "{{size response.body}}",
  "done": true,
  "records": "{{response.body}}"
}
```

## Usage

### 1. Start Services with Proxy Mappings
```bash
# Copy proxy mappings to active mappings directory
cp proxy_mappings/*.json mappings/

# Start WireMock with JSON Server
docker-compose up -d
```

### 2. Test Stateful Operations
```robot
*** Test Cases ***
Test Stateful Account CRUD
    # Create account - stored in JSON DB
    ${account_id}=    Create Account    Test Corp
    
    # Retrieve created account - from JSON DB
    ${account}=    Get Account    ${account_id}
    Should Be Equal    ${account.Name}    Test Corp
    
    # Update account - persisted in JSON DB
    Update Account    ${account_id}    Name=Updated Corp
    
    # Query accounts - returns from JSON DB
    ${accounts}=    Query Accounts
    Should Contain    ${accounts}    Updated Corp
```

### 3. Switch Between Static and Proxy Mappings

#### Use Static Mappings (No State)
```bash
# Use original mappings directory
docker-compose up -d
```

#### Use Proxy Mappings (With State)
```bash
# Use proxy_mappings directory
docker-compose -f docker-compose-proxy.yml up -d
```

## Configuration

### Docker Compose for Proxy Setup
```yaml
services:
  wiremock:
    image: wiremock/wiremock:latest
    volumes:
      - ./proxy_mappings:/home/wiremock/mappings
    ports:
      - "8443:8443"
    command:
      - "--https-port=8443"
      - "--verbose"
      - "--enable-response-templating"
      
  json-server:
    image: vimagick/json-server
    container_name: salesforce-json-mock
    volumes:
      - ./db.json:/data/db.json
    ports:
      - "3000:3000"
```

### Initial JSON DB Data (db.json)
```json
{
  "accounts": [],
  "contacts": [],
  "opportunities": []
}
```

## Benefits of Proxy Mappings

1. **Realistic Testing**: Tests behave like real Salesforce integration
2. **Data Persistence**: Created test data persists across test runs
3. **Relationship Testing**: Can test parent-child relationships
4. **Error Scenarios**: Can test duplicate prevention, validation rules
5. **Performance Testing**: Can load test with realistic data operations

## Troubleshooting

### Issue: Proxy requests failing
**Solution**: Ensure JSON Server is running and accessible at `http://salesforce-json-mock`

### Issue: Data not persisting
**Solution**: Check JSON Server logs and ensure db.json is writable

### Issue: Response format errors
**Solution**: Verify response transformers are enabled in WireMock:
```
--enable-response-templating
```

## Testing the Setup

Run this test to verify proxy mappings are working:

```robot
*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Test Cases ***
Verify Proxy Mappings
    # Test OAuth (static response)
    Create Session    salesforce    https://localhost:8443    verify=${FALSE}
    ${auth_response}=    POST On Session    salesforce    /services/oauth2/token
    Should Contain    ${auth_response.json()}    access_token
    
    # Test Account CRUD (proxied to JSON DB)
    ${account_data}=    Create Dictionary    Name=Test Account
    ${create_response}=    POST On Session    salesforce    
    ...    /services/data/v59.0/sobjects/Account
    ...    json=${account_data}
    ${account_id}=    Get From Dictionary    ${create_response.json()}    id
    
    # Verify account was stored
    ${get_response}=    GET On Session    salesforce    
    ...    /services/data/v59.0/sobjects/Account/${account_id}
    Should Be Equal    ${get_response.json()['Name']}    Test Account
```

## Migration Path

### Phase 1: Static Testing
Use regular mappings for initial development and testing

### Phase 2: Stateful Testing  
Switch to proxy mappings for integration testing

### Phase 3: Production
Replace WireMock with actual Salesforce connection
