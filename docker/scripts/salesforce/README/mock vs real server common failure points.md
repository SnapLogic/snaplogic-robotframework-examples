# Mock vs Real Salesforce: Common Failure Points

## 1. Authentication & Security 🔐

### Mock Server
- Accepts any username/password
- No real OAuth flow
- No session timeouts
- No IP restrictions
- No security tokens required

### Real Salesforce
```python
# Real Salesforce requires:
- Valid credentials
- Security token (username+password+token)
- OAuth 2.0 flow
- Session management (timeout after inactivity)
- IP whitelisting (org settings)
- Multi-factor authentication (if enabled)
```

**Failure Example:**
```sql
-- Works in mock
SELECT Id FROM Account

-- Fails in real Salesforce with:
-- "INVALID_SESSION_ID: Session expired or invalid"
```

## 2. Data Validation & Business Rules 📋

### Mock Server
```json
{
"Name": "", // Mock accepts empty names
"Phone": "12345", // Accepts any format
"Email": "not-an-email", // No validation
"AnnualRevenue": -1000 // Accepts negative values
}
```

### Real Salesforce
```json
{
"errors": [
"Required fields are missing: [Name]",
"Phone number format is invalid",
"Email format is invalid",
"Annual Revenue cannot be negative"
]
}
```

## 3. Field-Level Security & Permissions 🔒

### Mock Server
- All fields readable/writable
- No user permissions check
- No profile restrictions
- No field-level security

### Real Salesforce
```python
# User might not have access to:
- Certain fields (e.g., AnnualRevenue)
- Certain objects
- Certain record types
- CRUD operations (Create, Read, Update, Delete)
```

**Example Failure:**
```sql
-- Mock returns all fields
SELECT Id, Name, AnnualRevenue, OwnerId FROM Account

-- Real Salesforce error:
-- "Field AnnualRevenue is not accessible due to field-level security"
```

## 4. Governor Limits ⚡

### Mock Server
- No query limits
- No API call limits
- No heap size limits
- No CPU time limits

### Real Salesforce Limits
```yaml
SOQL Queries: 100 per transaction
SOQL Rows: 50,000 per transaction
API Calls: 15,000 per 24 hours (varies by edition)
Heap Size: 6 MB (sync) / 12 MB (async)
CPU Time: 10,000 ms (sync) / 60,000 ms (async)
Bulk API: 10,000 records per batch
```

**Failure Example:**
```sql
-- Works in mock
SELECT Id FROM Account -- Returns 100,000 records

-- Fails in Salesforce
-- "System.LimitException: Too many query rows: 50001"
```

## 5. Relationship & Integrity Constraints 🔗

### Mock Server
```json
{
"AccountId": "any-random-id", // No validation
"ParentId": "non-existent-id", // No check
"OwnerId": "invalid-user" // Accepts any value
}
```

### Real Salesforce
- Foreign keys must exist
- Lookup relationships validated
- Master-detail relationships enforced
- Record types must match
- Cascade delete rules applied

## 6. SOQL Query Differences 🔍

### Mock Server Accepts
```sql
-- Overly simple mock might accept invalid SOQL
SELECT * FROM Account -- Real SOQL doesn't support *
SELECT Name, (SELECT Invalid FROM Nothing) FROM Account
SELECT Id FROM Account WHERE CustomField__c = 'value' -- Field might not exist
```

### Real Salesforce Requirements
```sql
-- Must specify exact fields
SELECT Id, Name FROM Account

-- Child relationships must be valid
SELECT Id, (SELECT Id FROM Contacts) FROM Account

-- Custom fields must exist and be accessible
SELECT Id, CustomField__c FROM Account -- Fails if field doesn't exist
```

## 7. Trigger & Workflow Effects 🔄

### Mock Server
- No triggers fire
- No workflow rules
- No validation rules
- No process builder
- No flows
- No assignment rules

### Real Salesforce
```python
# Inserting an Account might:
- Fire before/after triggers
- Execute validation rules
- Run workflow rules
- Trigger Process Builder
- Execute Flows
- Apply assignment rules
- Send email alerts
- Create related records automatically
```

## 8. API Version Compatibility 📱

### Mock Server
```javascript
// Mock might not enforce version-specific features
"/services/data/v59.0/sobjects/Account"
// Accepts any fields regardless of version
```

### Real Salesforce
```javascript
// Different API versions have different features
v59.0 - Supports certain fields
v58.0 - Might not have newer fields
v45.0 - Deprecated features removed
```

## 9. Bulk Operations Differences 📦

### Mock Server
```python
# Processes instantly
bulk_insert(10000_records) # Immediate response
```

### Real Salesforce
```python
# Batch processing with delays
- Queued state
- InProgress state
- Completed/Failed state
- Async processing time
- Batch size limits (10,000 records)
```

## 10. Special Characters & Encoding 🔤

### Mock Server
```sql
SELECT Id FROM Account WHERE Name = 'Test&Co' -- Works
SELECT Id FROM Account WHERE Name = 'O'Reilly' -- Works
```

### Real Salesforce
```sql
-- Requires proper escaping
SELECT Id FROM Account WHERE Name = 'Test&amp;Co'
SELECT Id FROM Account WHERE Name = 'O\'Reilly' -- Escaped quote
```

## Best Practices to Minimize Differences 🎯

### 1. Make Your Mock Realistic
```json
{
"mappings": [{
"request": {
"method": "POST",
"urlPath": "/services/data/v59.0/sobjects/Account"
},
"response": {
"status": 400,
"jsonBody": {
"message": "Required fields are missing: [Name]",
"errorCode": "REQUIRED_FIELD_MISSING"
}
},
"priority": 1,
"scenarioName": "Missing Required Field"
}]
}
```

### 2. Test Configuration for Both Environments
```yaml
# test-config.yml
environments:
mock:
url: http://localhost:8089
validate_schema: false
check_limits: false

sandbox:
url: https://test.salesforce.com
validate_schema: true
check_limits: true

production:
url: https://login.salesforce.com
validate_schema: true
check_limits: true
respect_permissions: true
```

### 3. Implement Mock Validations
```javascript
// Add validation to mock server
function validateAccount(account) {
const errors = [];

if (!account.Name) {
errors.push("Name is required");
}

if (account.Phone && !isValidPhone(account.Phone)) {
errors.push("Invalid phone format");
}

if (account.AnnualRevenue < 0) { errors.push("Annual Revenue cannot be negative"); } return errors; } ``` ### 4. Create
    Integration Test Levels ```python class TestLevels: UNIT="mock" # Fast, uses mock INTEGRATION="sandbox" # Slower,
    uses sandbox E2E="production_copy" # Full end-to-end @pytest.mark.unit def test_with_mock(): # Quick validation with
    mock pass @pytest.mark.integration def test_with_sandbox(): # Real Salesforce sandbox test pass ``` ### 5. Mock
    Realistic Responses ```json { "response" : { "status" : 200, "headers" : { "Sforce-Limit-Info"
    : "api-usage=15/15000" }, "jsonBody" : { "id" : "001xx000003DHPh" , "success" : true, "errors" : [], "created" :
    true } } } ``` ## Recommendations 🚀 1. **Always test in a Salesforce Sandbox** before production 2. **Use realistic
    test data** in mocks 3. **Implement error scenarios** in your mock 4. **Test with actual permissions** in sandbox 5.
    **Monitor API limits** in real environments 6. **Validate SOQL queries** against real schema 7. **Test bulk
    operations** with realistic volumes 8. **Include security testing** (OAuth, permissions) 9. **Test trigger/workflow
    effects** in sandbox 10. **Use feature flags** to handle API version differences ## Testing Strategy ```mermaid
    graph LR A[Local Dev] -->|Mock Server| B[Unit Tests]
    B --> C[Integration Tests]
    C -->|Sandbox| D[UAT Testing]
    D --> E[Production Smoke Tests]
    E -->|Real Salesforce| F[Production]
    ```

    The key is to use mocks for rapid development and then progressively test in more realistic environments before
    production deployment.