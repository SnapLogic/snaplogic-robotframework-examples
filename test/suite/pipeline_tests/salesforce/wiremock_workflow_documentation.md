# WireMock Salesforce Testing Workflow Documentation

## Overview

This document explains the complete workflow for testing Salesforce integrations using WireMock as a mock server. The setup provides a comprehensive testing environment that simulates Salesforce APIs without requiring actual Salesforce connectivity.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Components](#components)
3. [Infrastructure Setup](#infrastructure-setup)
4. [API Testing Framework](#api-testing-framework)
5. [Workflow Process](#workflow-process)
6. [Testing Scenarios](#testing-scenarios)
7. [Best Practices](#best-practices)

---

## Architecture Overview

The WireMock Salesforce testing setup consists of:

```
┌─────────────────────────────────────────────────────────────┐
│                     Test Environment                         │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐        ┌────────────────────┐         │
│  │  Robot Framework │◄──────►│  WireMock Server   │         │
│  │   Test Suite     │        │  (Salesforce Mock) │         │
│  └──────────────────┘        └────────────────────┘         │
│           │                            │                     │
│           │                            │                     │
│           ▼                            ▼                     │
│  ┌──────────────────┐        ┌────────────────────┐         │
│  │  API Resource    │        │   JSON Server      │         │
│  │    Keywords      │        │  (Persistent Data) │         │
│  └──────────────────┘        └────────────────────┘         │
│                                                               │
│  Network: snaplogicnet (Docker Bridge)                       │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. WireMock Server (salesforce-api-mock)

**Purpose**: Simulates Salesforce REST APIs with both HTTP and HTTPS support.

**Key Features**:
- **Container Name**: `salesforce-api-mock`
- **HTTP Port**: 8089 (host) → 8080 (container)
- **HTTPS Port**: 8443 (host) → 8443 (container)
- **Image**: `wiremock/wiremock:3.3.1`
- **SSL/TLS**: Self-signed certificate with custom keystore support

**Configuration Options**:
```yaml
- Global response templating enabled
- Verbose logging for debugging
- CORS support for cross-origin requests
- Host header preservation
- Max 1000 request journal entries
```

**Endpoints Mocked**:
- OAuth Authentication: `/services/oauth2/token`
- REST API: `/services/data/v59.0/*`
- Bulk API: `/services/async/59.0/*`
- Metadata API: `/services/data/v59.0/sobjects/*/describe`

### 2. JSON Server (salesforce-json-mock)

**Purpose**: Provides persistent CRUD operations for test data that needs to survive between test runs.

**Key Features**:
- **Container Name**: `salesforce-json-mock`
- **Port**: 8082 (host) → 80 (container)
- **Image**: `clue/json-server`
- **Data Storage**: `/scripts/salesforce/json-db/salesforce-db.json`

### 3. Robot Framework API Resource

**Purpose**: Provides reusable keywords for interacting with the mocked Salesforce APIs.

**Key Components**:
- Session management
- Authentication handling
- CRUD operations for all Salesforce objects
- Query execution
- Bulk API operations
- Composite API support

---

## Infrastructure Setup

### Docker Compose Configuration

The `docker-compose.salesforce-mock.yml` file sets up the mock environment:

```yaml
version: '3.8'

services:
  salesforce-mock:
    # WireMock configuration
    profiles:
      - salesforce-dev
    volumes:
      - Proxy mappings for request/response definitions
      - Static files for mock responses
      - Custom SSL certificates
    command:
      - HTTP and HTTPS ports
      - SSL keystore configuration
      - Response templating
      - CORS and header preservation
    networks:
      - snaplogicnet
    healthcheck:
      - HTTP and HTTPS endpoint checks
      - 10-second intervals
      - 3 retry attempts

  salesforce-json-server:
    # JSON Server configuration
    profiles:
      - salesforce-dev
    volumes:
      - JSON database file
    networks:
      - snaplogicnet
```

### Starting the Environment

```bash
# Start the Salesforce mock services
docker-compose --profile salesforce-dev up -d

# Verify services are running
docker-compose ps

# Check health status
curl -f http://localhost:8089/__admin/health
curl -fk https://localhost:8443/__admin/health
```

---

## API Testing Framework

### Resource File Structure

The `wiremock_apis.resource` file provides a comprehensive testing framework:

#### 1. **Variables Section**
```robotframework
${WIREMOCK_SESSION}     salesforce-mock
${BASE_URL}             https://salesforce-api-mock:8443
${VERIFY_SSL}           ${FALSE}
${API_VERSION}          v59.0
${AUTH_TOKEN}           ${EMPTY}
```

#### 2. **Session Management**
- `Create Salesforce Session Api`: Initializes HTTP session with WireMock

#### 3. **Authentication APIs**
- `Authenticate Api`: OAuth password flow authentication
- `Refresh Token Api`: Token refresh mechanism
- `Revoke Token Api`: Token invalidation

#### 4. **Standard Object APIs**
Each Salesforce object (Account, Contact, Lead, Opportunity) has:
- `Create [Object] Api`: POST operation
- `Get [Object] Api`: GET operation
- `Update [Object] Api`: PATCH operation
- `Delete [Object] Api`: DELETE operation

#### 5. **Specialized APIs**
- `Convert Lead Api`: Lead conversion process
- `Execute Query Api`: SOQL query execution
- `Execute Query All Api`: Query including deleted records
- `Get Next Query Results Api`: Pagination support

#### 6. **Bulk API 2.0**
- `Create Bulk Job Api`: Initialize bulk operation
- `Upload Bulk Data Api`: CSV data upload
- `Close Bulk Job Api`: Trigger job processing
- `Get Bulk Job Status Api`: Monitor job progress
- `Get Bulk Job Results Api`: Retrieve processed results

#### 7. **Metadata APIs**
- `Get Object Metadata Api`: Object schema information
- `Get All Objects Api`: Available objects list
- `Get Field Metadata Api`: Field-level metadata

#### 8. **Composite APIs**
- `Execute Composite Request Api`: Multiple operations in single call
- `Execute Batch Request Api`: Independent batch operations

#### 9. **Generic SObject APIs**
- `Create SObject Api`: Generic create for any object
- `Get SObject Api`: Generic retrieve
- `Update SObject Api`: Generic update
- `Delete SObject Api`: Generic delete
- `Upsert SObject Api`: External ID based upsert

---

## Workflow Process

### 1. Environment Initialization

```robotframework
*** Test Cases ***
Initialize Salesforce Testing Environment
    # Start Docker containers (done externally)
    # Create API session
    Create Salesforce Session Api
    
    # Authenticate and store token
    ${response}=    Authenticate Api    snap-qa@snaplogic.com    password123
    Should Be Equal As Integers    ${response.status_code}    200
```

### 2. Standard CRUD Testing Flow

```robotframework
*** Test Cases ***
Complete Account Lifecycle Test
    # 1. Create Account
    ${account_data}=    Create Dictionary
    ...    Name=Test Company Inc
    ...    Type=Customer
    ...    Industry=Technology
    
    ${create_response}=    Create Account Api    ${account_data}
    ${account_id}=    Get From Dictionary    ${create_response.json()}    id
    
    # 2. Read Account
    ${get_response}=    Get Account Api    ${account_id}
    Should Be Equal    ${get_response.json()['Name']}    Test Company Inc
    
    # 3. Update Account
    ${update_data}=    Create Dictionary    
    ...    BillingCity=San Francisco
    ...    NumberOfEmployees=100
    
    ${update_response}=    Update Account Api    ${account_id}    ${update_data}
    Should Be Equal As Integers    ${update_response.status_code}    204
    
    # 4. Delete Account
    ${delete_response}=    Delete Account Api    ${account_id}
    Should Be Equal As Integers    ${delete_response.status_code}    204
```

### 3. Complex Query Testing

```robotframework
*** Test Cases ***
Test SOQL Query Execution
    # Execute complex query
    ${query}=    Set Variable    
    ...    SELECT Id, Name, Industry FROM Account WHERE Industry = 'Technology' LIMIT 10
    
    ${response}=    Execute Query Api    ${query}
    ${records}=    Get From Dictionary    ${response.json()}    records
    
    # Handle pagination if needed
    ${done}=    Get From Dictionary    ${response.json()}    done
    IF    ${done} == ${FALSE}
        ${next_url}=    Get From Dictionary    ${response.json()}    nextRecordsUrl
        ${next_response}=    Get Next Query Results Api    ${next_url}
    END
```

### 4. Bulk API Testing

```robotframework
*** Test Cases ***
Test Bulk Data Upload
    # 1. Create bulk job
    ${job_config}=    Create Dictionary
    ...    object=Account
    ...    operation=insert
    
    ${job_response}=    Create Bulk Job Api    ${job_config}
    ${job_id}=    Get From Dictionary    ${job_response.json()}    id
    
    # 2. Upload CSV data
    ${csv_data}=    Set Variable
    ...    Name,Industry,NumberOfEmployees
    ...    "Company A","Technology",50
    ...    "Company B","Finance",100
    
    Upload Bulk Data Api    ${job_id}    ${csv_data}
    
    # 3. Close job and start processing
    Close Bulk Job Api    ${job_id}
    
    # 4. Monitor job status
    Wait Until Keyword Succeeds    30s    2s
    ...    Check Bulk Job Complete    ${job_id}
    
    # 5. Get results
    ${results}=    Get Bulk Job Results Api    ${job_id}
```

### 5. Composite API Testing

```robotframework
*** Test Cases ***
Test Composite Operations
    # Create multiple related records in single call
    ${subrequests}=    Create List
    
    # Subrequest 1: Create Account
    ${account_request}=    Create Dictionary
    ...    method=POST
    ...    url=/services/data/v59.0/sobjects/Account
    ...    referenceId=newAccount
    ...    body=${account_data}
    
    # Subrequest 2: Create Contact
    ${contact_request}=    Create Dictionary
    ...    method=POST
    ...    url=/services/data/v59.0/sobjects/Contact
    ...    referenceId=newContact
    ...    body=${contact_data}
    
    Append To List    ${subrequests}    ${account_request}
    Append To List    ${subrequests}    ${contact_request}
    
    ${composite_request}=    Create Dictionary
    ...    compositeRequest=${subrequests}
    
    ${response}=    Execute Composite Request Api    ${composite_request}
```

---

## Testing Scenarios

### Scenario 1: SnapLogic Integration Testing

When SnapLogic pipelines need to interact with Salesforce:

1. **Configure SnapLogic Account**:
   - Login URL: `https://salesforce-api-mock:8443` (within Docker network)
   - Or: `https://localhost:8443` (from host machine)
   - Username/Password: Any values (mock accepts all)

2. **Test Pipeline Operations**:
   - Data synchronization
   - Batch processing
   - Real-time updates
   - Error handling

### Scenario 2: API Contract Testing

Verify that integrations handle Salesforce API responses correctly:

```robotframework
*** Test Cases ***
Validate API Response Structure
    ${response}=    Get Account Api    001XX000003DHPh
    
    # Validate response structure
    Dictionary Should Contain Key    ${response.json()}    Id
    Dictionary Should Contain Key    ${response.json()}    Name
    Dictionary Should Contain Key    ${response.json()}    attributes
    
    # Validate data types
    ${attributes}=    Get From Dictionary    ${response.json()}    attributes
    Should Be Equal    ${attributes['type']}    Account
```

### Scenario 3: Error Handling Testing

Test how systems handle various error conditions:

```robotframework
*** Test Cases ***
Test Error Scenarios
    # Test 404 - Record not found
    ${response}=    Run Keyword And Expect Error    *404*
    ...    Get Account Api    INVALID_ID
    
    # Test 401 - Unauthorized
    Set Suite Variable    ${AUTH_TOKEN}    INVALID_TOKEN
    ${response}=    Run Keyword And Expect Error    *401*
    ...    Get Account Api    001XX000003DHPh
    
    # Test 400 - Bad request
    ${invalid_data}=    Create Dictionary    
    ...    InvalidField=Value
    ${response}=    Run Keyword And Expect Error    *400*
    ...    Create Account Api    ${invalid_data}
```

### Scenario 4: Performance Testing

```robotframework
*** Test Cases ***
Test Bulk Operations Performance
    ${start_time}=    Get Time    epoch
    
    FOR    ${i}    IN RANGE    100
        ${account_data}=    Create Dictionary
        ...    Name=Account_${i}
        Create Account Api    ${account_data}
    END
    
    ${end_time}=    Get Time    epoch
    ${duration}=    Evaluate    ${end_time} - ${start_time}
    
    Should Be True    ${duration} < 60    
    ...    Bulk operations took too long: ${duration}s
```

---

## Best Practices

### 1. Session Management
- Always create a session at the beginning of test suites
- Store authentication tokens at suite level
- Handle token refresh for long-running tests

### 2. Data Isolation
- Use unique identifiers for test data
- Clean up created records in teardown
- Use separate databases for parallel test execution

### 3. Error Handling
- Always validate response status codes
- Implement proper retry mechanisms
- Log detailed error information for debugging

### 4. Mock Configuration
- Keep WireMock mappings version-controlled
- Use response templating for dynamic data
- Implement realistic response delays

### 5. SSL/TLS Handling
- Use `VERIFY_SSL=${FALSE}` for self-signed certificates
- Mount custom certificates for production-like testing
- Test both HTTP and HTTPS endpoints

### 6. Performance Optimization
- Use batch/composite APIs for multiple operations
- Implement connection pooling
- Monitor WireMock memory usage

### 7. Debugging
- Enable verbose logging in WireMock
- Use WireMock admin API for request verification
- Capture and analyze request/response pairs

### 8. CI/CD Integration
```bash
# Example CI/CD pipeline step
- name: Run Salesforce Mock Tests
  run: |
    docker-compose --profile salesforce-dev up -d
    robot --variable ENV:mock \
          --outputdir results \
          test/suite/pipeline_tests/salesforce/
    docker-compose down
```

---

## Troubleshooting

### Common Issues and Solutions

1. **Connection Refused**
   - Verify containers are running: `docker-compose ps`
   - Check network connectivity: `docker network ls`
   - Ensure correct ports are exposed

2. **SSL Certificate Errors**
   - Set `VERIFY_SSL=${FALSE}` in tests
   - Mount custom certificates if needed
   - Use `-k` flag with curl for testing

3. **Authentication Failures**
   - Check WireMock mappings are loaded
   - Verify token is being stored correctly
   - Review WireMock logs for request details

4. **Data Persistence Issues**
   - Ensure JSON Server volume is mounted
   - Check file permissions on database file
   - Verify JSON Server is watching for changes

5. **Performance Problems**
   - Increase WireMock JVM memory
   - Reduce request journal size
   - Implement request filtering

---

## Conclusion

This WireMock-based Salesforce testing framework provides a robust, scalable solution for testing Salesforce integrations without requiring actual Salesforce connectivity. The combination of WireMock for API mocking, JSON Server for data persistence, and Robot Framework for test automation creates a comprehensive testing environment suitable for both development and CI/CD pipelines.

The modular architecture allows for easy extension and customization, while the Docker-based deployment ensures consistency across different environments. By following the workflows and best practices outlined in this document, teams can effectively test their Salesforce integrations with confidence.
