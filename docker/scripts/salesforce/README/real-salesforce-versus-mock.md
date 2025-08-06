# Real Salesforce vs Mock Salesforce Server

This document explains how the Salesforce mock server works compared to the real Salesforce service, helping you understand when and how to use each.

## 📋 Table of Contents

- [Overview](#overview)
- [Authentication Comparison](#authentication-comparison)
- [Data Operations](#data-operations)
- [Architecture Differences](#architecture-differences)
- [How WireMock Works](#how-wiremock-works)
- [Use Cases](#use-cases)
- [Advantages and Limitations](#advantages-and-limitations)
- [Practical Examples](#practical-examples)
- [Best Practices](#best-practices)

## Overview

The Salesforce mock server is a lightweight WireMock-based service that simulates Salesforce API responses without connecting to actual Salesforce infrastructure. It's designed for local development, testing, and demonstrations.

## 🔐 Authentication Comparison

### Real Salesforce Authentication

```
1. POST to: https://login.salesforce.com/services/oauth2/token
2. Validates: username + password + security token
3. Checks: 
   - User exists in Salesforce
   - Password is correct
   - Security token matches
   - IP restrictions
   - Login hours
   - Profile permissions
4. Returns: Real session token (SessionID)
5. Token expires: Typically after 2 hours of inactivity
6. Requires: Token refresh for long-running operations
```

### Mock Server Authentication

```
1. POST to: http://salesforce-api-mock:8080/services/oauth2/token
2. Accepts: ANY username/password combination
3. No validation performed
4. Returns: Fake token (mock-access-token-[UUID])
5. Token never expires
6. No security checks
```

#### Example Mock Response:
```json
{
  "access_token": "mock-access-token-34bb7a45-32dd-4131-9ff7-9f7620067264",
  "instance_url": "http://salesforce-api-mock:8080",
  "token_type": "Bearer",
  "issued_at": "2025-08-05T18:05:35Z"
}
```

## 📊 Data Operations

### Real Salesforce Data Operations

| Operation | Real Salesforce Behavior |
|-----------|-------------------------|
| **Query** | - Searches real database<br>- Returns actual customer data<br>- Respects field-level security<br>- Applies sharing rules<br>- Can return millions of records<br>- Supports complex SOQL queries |
| **Create** | - Validates against schema<br>- Runs validation rules<br>- Executes triggers<br>- Assigns auto-number fields<br>- Creates audit trail<br>- Returns real record ID |
| **Update** | - Checks record locks<br>- Validates data changes<br>- Maintains history<br>- Fires workflow rules<br>- Updates last modified timestamp |
| **Delete** | - Moves to recycle bin<br>- Maintains relationships<br>- Can be restored<br>- Respects cascade rules |

### Mock Server Data Operations

| Operation | Mock Server Behavior |
|-----------|---------------------|
| **Query** | - Returns hardcoded JSON<br>- Always same test data<br>- No database<br>- No security checks<br>- Limited to mocked responses |
| **Create** | - Returns fake success<br>- Generates mock ID<br>- Nothing saved<br>- No validation |
| **Update** | - Returns success<br>- No actual changes<br>- No persistence |
| **Delete** | - Returns success<br>- Nothing deleted<br>- Record still exists |

## 🏗️ Architecture Differences

### Real Salesforce Architecture

```
┌─────────────────────┐
│   Your Application  │
└──────────┬──────────┘
           │ HTTPS/TLS 1.2+
           ▼
┌─────────────────────┐
│  Salesforce Cloud   │
├─────────────────────┤
│  Global Load        │
│  Balancers          │
├─────────────────────┤
│  Application        │
│  Servers (Pods)     │
├─────────────────────┤
│  Oracle RAC         │
│  Databases          │
├─────────────────────┤
│  File Storage       │
│  (Documents)        │
├─────────────────────┤
│  Search Index       │
│  (SOSL)            │
└─────────────────────┘
```

### Mock Server Architecture

```
┌─────────────────────┐
│   Your Application  │
└──────────┬──────────┘
           │ HTTP (local)
           ▼
┌─────────────────────┐
│  Docker Container   │
├─────────────────────┤
│  WireMock Server    │
├─────────────────────┤
│  JSON Mapping Files │
│  (No Database)      │
└─────────────────────┘
```

## 🔧 How WireMock Works

WireMock uses a simple request-response mapping system:

### 1. Mapping File Structure
```json
{
  "name": "Query Accounts",
  "request": {
    "method": "GET",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/query/?",
    "queryParameters": {
      "q": {
        "matches": ".*"
      }
    }
  },
  "response": {
    "status": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "jsonBody": {
      "totalSize": 3,
      "done": true,
      "records": [
        {
          "Id": "001000000000001",
          "Name": "Acme Corporation",
          "Type": "Customer"
        }
      ]
    }
  }
}
```

### 2. Request Processing Flow
```
1. HTTP Request arrives
2. WireMock compares URL pattern
3. Checks HTTP method
4. Matches query parameters (if any)
5. Returns predefined response
6. No actual processing or database queries
```

## 🎯 Use Cases

### When to Use Real Salesforce

- ✅ **Production deployments**
- ✅ **Integration testing with real data**
- ✅ **Performance testing**
- ✅ **Security testing**
- ✅ **User acceptance testing**
- ✅ **Testing Salesforce-specific features** (triggers, workflows, validation rules)
- ✅ **Multi-user scenarios**
- ✅ **Testing governor limits**

### When to Use Mock Server

- ✅ **Local development** (no internet required)
- ✅ **Unit testing** (predictable responses)
- ✅ **CI/CD pipelines** (fast, reliable)
- ✅ **Demos and POCs** (no setup required)
- ✅ **Learning/training** (safe environment)
- ✅ **Testing error scenarios** (easy to simulate)
- ✅ **Rapid prototyping** (immediate feedback)
- ✅ **Cost-sensitive environments** (no licenses needed)

## 🚀 Advantages and Limitations

### Advantages of Mock Server

| Advantage | Description |
|-----------|------------|
| **No Costs** | No Salesforce licenses required |
| **No API Limits** | Unlimited API calls (no 24-hour rolling limits) |
| **Fast** | Instant responses, no network latency |
| **Predictable** | Same data every time, perfect for testing |
| **Offline** | Works without internet connection |
| **Safe** | Cannot damage production data |
| **Simple Setup** | Just run Docker container |
| **Version Control** | Mock responses can be versioned with code |

### Limitations of Mock Server

| Limitation | Impact |
|------------|--------|
| **No Business Logic** | Validation rules, triggers, workflows don't execute |
| **No Real Persistence** | Data changes aren't saved |
| **Limited Scenarios** | Only mocked endpoints work |
| **No Integrations** | External integrations don't function |
| **Static Data** | Always returns same responses |
| **No Multi-user** | Can't test concurrent access |
| **No Governor Limits** | Won't catch limit violations |

## 📝 Practical Examples

### Example 1: Creating an Account

#### Real Salesforce
```bash
POST https://yourorg.salesforce.com/services/data/v52.0/sobjects/Account
Headers:
  Authorization: Bearer 00D5000000...actual-token
Body:
{
  "Name": "New Tech Company",
  "Type": "Technology Partner",
  "Website": "www.newtech.com"
}

Response:
{
  "id": "0015000000VMw3eAAD",  # Real Salesforce ID
  "success": true,
  "errors": []
}
# Account is permanently created in database
# Triggers fire, workflows execute
# Record visible to other users based on sharing
```

#### Mock Server
```bash
POST http://salesforce-api-mock:8080/services/data/v52.0/sobjects/Account
Headers:
  Authorization: Bearer mock-access-token-12345
Body:
{
  "Name": "New Tech Company",
  "Type": "Technology Partner",
  "Website": "www.newtech.com"
}

Response:
{
  "id": "001MOCK000001ABC",  # Fake ID
  "success": true
}
# Nothing actually created
# No triggers or workflows
# Data not persisted
```

### Example 2: Querying Records

#### Real Salesforce
```sql
-- SOQL Query
SELECT Id, Name, Type, AnnualRevenue 
FROM Account 
WHERE Type = 'Customer' 
AND AnnualRevenue > 1000000
ORDER BY AnnualRevenue DESC
LIMIT 10

-- Returns actual customer data
-- Respects user permissions
-- Could return 0 to 10 records based on real data
```

#### Mock Server
```sql
-- Same SOQL Query
SELECT Id, Name, Type, AnnualRevenue 
FROM Account 
WHERE Type = 'Customer' 
AND AnnualRevenue > 1000000
ORDER BY AnnualRevenue DESC
LIMIT 10

-- Always returns same 3 test accounts
-- WHERE clause ignored
-- ORDER BY ignored
-- LIMIT ignored
```

## 🛠️ Best Practices

### 1. **Development Workflow**
```
Local Development → Mock Server
Integration Testing → Real Salesforce Sandbox
User Acceptance → Real Salesforce Sandbox
Production → Real Salesforce Production
```

### 2. **Testing Strategy**
- Use mock for unit tests (fast, isolated)
- Use real Salesforce for integration tests (complete validation)
- Keep mock data realistic but simple
- Version control your mock mappings

### 3. **Configuration Management**

#### SnapLogic Account Configuration
```yaml
Development:
  Label: salesforce_dev_mock
  Username: dev@mock.com
  Password: mock
  Login URL: http://salesforce-api-mock:8080

Staging:
  Label: salesforce_staging
  Username: real-user@company.com.staging
  Password: [encrypted]
  Login URL: https://test.salesforce.com

Production:
  Label: salesforce_prod
  Username: real-user@company.com
  Password: [encrypted]
  Login URL: https://login.salesforce.com
```

### 4. **Error Simulation**

The mock can simulate errors by adding specific mappings:
```json
{
  "name": "Simulate 500 Error",
  "request": {
    "urlPathPattern": "/services/data/.*/sobjects/Account/ERROR500"
  },
  "response": {
    "status": 500,
    "jsonBody": {
      "message": "Internal Server Error",
      "errorCode": "INTERNAL_ERROR"
    }
  }
}
```

### 5. **Performance Testing**

| Test Type | Recommended Environment |
|-----------|------------------------|
| Unit Test Performance | Mock (consistent baseline) |
| API Latency | Real Salesforce |
| Bulk Operations | Real Salesforce |
| Concurrent Users | Real Salesforce |

## 🔍 Troubleshooting

### Common Issues with Mock

1. **404 Errors**: Add missing endpoint mappings
2. **Authentication Failures**: Check Login URL format
3. **Data Mismatches**: Update mock JSON responses
4. **Missing Headers**: Add required headers to mappings

### Debugging Tips

```bash
# View all loaded mappings
curl http://localhost:8089/__admin/mappings | jq '.mappings[].name'

# Check recent requests
curl http://localhost:8089/__admin/requests | jq '.requests[0]'

# View unmatched requests
curl http://localhost:8089/__admin/requests | \
  jq '.requests[] | select(.wasMatched == false)'
```

## 📚 Additional Resources

- [WireMock Documentation](http://wiremock.org/docs/)
- [Salesforce API Documentation](https://developer.salesforce.com/docs/apis)
- [SnapLogic Salesforce Snap Pack](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/pages/1438843/Salesforce+Snap+Pack)

## 🎯 Conclusion

The Salesforce mock server is an invaluable tool for:
- Rapid development without Salesforce licenses
- Consistent testing environments
- Offline development
- Learning and training

However, always validate your integrations against real Salesforce environments before production deployment to ensure compatibility with:
- Business logic and validation rules
- Governor limits
- Security and sharing settings
- Real-world data scenarios

Use the mock server as a development accelerator, not a replacement for proper integration testing!
