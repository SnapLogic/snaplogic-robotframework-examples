# Account Error Scenarios Testing Guide

## Production Issues That Can Occur with Accounts

### 1. Permission & Access Issues

#### Scenario: No Object Access
**Test with**: Query containing "NOACCESS"
```sql
SELECT Id FROM Account WHERE Name = 'NOACCESS'
```
**Expected**: 403 Forbidden - User lacks Account object permissions

#### Scenario: Field-Level Security
**Test with**: Update Account ID `001RESTRICTED001` with AnnualRevenue
```json
PATCH /services/data/v59.0/sobjects/Account/001RESTRICTED001
{
  "AnnualRevenue": 1000000
}
```
**Expected**: 400 Bad Request - Field not accessible

### 2. Data Validation Errors

#### Scenario: Missing Required Fields
**Test with**: POST request with body containing "INVALID"
```json
POST /services/data/v59.0/sobjects/Account
{
  "Type": "INVALID"  // Missing required Name field
}
```
**Expected**: 400 Bad Request - Required field missing

#### Scenario: Duplicate Detection
**Test with**: POST request with body containing "DUPLICATE"
```json
POST /services/data/v59.0/sobjects/Account
{
  "Name": "DUPLICATE Acme Corporation"
}
```
**Expected**: 400 Bad Request - Duplicate detected

### 3. Governor Limits

#### Scenario: Query Row Limit Exceeded
**Test with**: Query containing "LIMIT_EXCEEDED"
```sql
SELECT Id FROM Account WHERE Industry = 'LIMIT_EXCEEDED'
```
**Expected**: 400 Bad Request - Too many rows (>50,000)

### 4. Concurrency Issues

#### Scenario: Record Locked
**Test with**: Update Account ID `001LOCKED0000001`
```json
PATCH /services/data/v59.0/sobjects/Account/001LOCKED0000001
{
  "Name": "Updated Name"
}
```
**Expected**: 400 Bad Request - Unable to lock row

### 5. Referential Integrity

#### Scenario: Cannot Delete Due to Related Records
**Test with**: Delete Account ID `001NODELETE00001`
```
DELETE /services/data/v59.0/sobjects/Account/001NODELETE00001
```
**Expected**: 400 Bad Request - Has related opportunities

#### Scenario: Record Not Found
**Test with**: Get Account ID `001NOTFOUND00001`
```
GET /services/data/v59.0/sobjects/Account/001NOTFOUND00001
```
**Expected**: 404 Not Found

## Real Production Issues Not Currently Mocked

### 1. Trigger & Workflow Errors
```json
{
  "message": "Apex trigger AccountTrigger caused an unexpected exception: System.NullPointerException: Attempt to de-reference a null object",
  "errorCode": "APEX_ERROR"
}
```

### 2. Sharing Rule Violations
```json
{
  "message": "You do not have the level of access necessary to perform the operation you requested.",
  "errorCode": "INSUFFICIENT_ACCESS_OR_READONLY"
}
```

### 3. Data Type Mismatches
```json
{
  "message": "AnnualRevenue: value not of required type: 'not_a_number'",
  "errorCode": "INVALID_TYPE_ON_FIELD_IN_RECORD"
}
```

### 4. Picklist Value Restrictions
```json
{
  "message": "Bad value for restricted picklist field: InvalidType",
  "errorCode": "INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST"
}
```

### 5. Cross-Object Formula Errors
```json
{
  "message": "Formula field cannot be updated",
  "errorCode": "INVALID_FIELD_FOR_INSERT_UPDATE"
}
```

## SnapLogic Pipeline Impact Analysis

### What Happens When These Errors Occur:

1. **Query Failures**
   - Pipeline stops at Read snap
   - Error routed to error view
   - May trigger retry logic

2. **Create/Update Failures**
   - Records sent to error view
   - Batch may partially succeed
   - Rollback may be triggered

3. **Delete Failures**
   - Operation fails
   - Related records remain
   - Manual intervention needed

### SnapLogic Error Handling Best Practices:

```python
# Pseudo-code for robust error handling
def process_accounts(accounts):
    errors = []
    succeeded = []
    
    for account in accounts:
        try:
            result = salesforce.create_account(account)
            succeeded.append(result)
        except ValidationError as e:
            if e.code == 'DUPLICATES_DETECTED':
                # Try to update existing record
                existing = find_duplicate(account)
                result = salesforce.update_account(existing.id, account)
            else:
                errors.append({
                    'record': account,
                    'error': e.message,
                    'code': e.code
                })
        except PermissionError as e:
            # Log and skip
            log_permission_issue(e)
            errors.append(account)
        except LockError as e:
            # Retry with backoff
            retry_with_backoff(account)
    
    return succeeded, errors
```

## Testing Recommendations

### Critical Test Cases:
1. ✅ Happy path - Normal CRUD operations
2. ✅ Permission errors - Object and field level
3. ✅ Validation errors - Required fields, data types
4. ✅ Duplicate handling - Detection and resolution
5. ✅ Concurrency - Record locking scenarios
6. ✅ Limits - Query rows, API calls
7. ✅ Not found - Deleted or non-existent records
8. ✅ Referential integrity - Parent/child relationships

### Test Data Patterns:
- Use "INVALID" in data to trigger validation errors
- Use "DUPLICATE" to test duplicate detection
- Use "NOACCESS" in queries for permission errors
- Use "LIMIT_EXCEEDED" to test governor limits
- Use specific IDs for locked/restricted records

## How to Use These Mocks

```bash
# Test validation error
curl -X POST http://localhost:8443/services/data/v59.0/sobjects/Account \
  -H "Authorization: Bearer token" \
  -d '{"Type": "INVALID"}'

# Test duplicate detection
curl -X POST http://localhost:8443/services/data/v59.0/sobjects/Account \
  -H "Authorization: Bearer token" \
  -d '{"Name": "DUPLICATE Company"}'

# Test record locking
curl -X PATCH http://localhost:8443/services/data/v59.0/sobjects/Account/001LOCKED0000001 \
  -H "Authorization: Bearer token" \
  -d '{"Name": "New Name"}'

# Test query limits
curl "http://localhost:8443/services/data/v59.0/query?q=SELECT+Id+FROM+Account+WHERE+Industry='LIMIT_EXCEEDED'"
```

## Benefits of Comprehensive Error Testing

1. **Robust Error Handling**: Ensures pipelines handle all failure modes
2. **Better User Experience**: Clear error messages and recovery paths
3. **Production Readiness**: Confidence that code handles real-world scenarios
4. **Faster Debugging**: Familiar with error patterns before production
5. **Compliance**: Ensures data integrity and security rules are respected