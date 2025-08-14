# JSON-DB Integration with WireMock

## How It Would Work

### 1. Query Accounts - Dynamic from JSON-DB
```json
{
  "name": "Query Accounts - JSON DB Integration",
  "request": {
    "method": "GET",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/query"
  },
  "response": {
    "status": 200,
    "headers": {
      "Content-Type": "application/json"
    },
    "transformers": ["json-db-transformer"],
    "transformerParameters": {
      "operation": "query",
      "table": "accounts",
      "query": "{{request.query.q}}"
    }
  }
}
```

### 2. Create Account - Insert into JSON-DB
```json
{
  "name": "Create Account - JSON DB Integration",
  "request": {
    "method": "POST",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account"
  },
  "response": {
    "status": 201,
    "transformers": ["json-db-transformer"],
    "transformerParameters": {
      "operation": "insert",
      "table": "accounts",
      "data": "{{request.body}}",
      "generateId": true,
      "validation": {
        "required": ["Name"],
        "unique": ["Name", "TaxId__c"]
      }
    }
  }
}
```

### 3. Update Account - Modify in JSON-DB
```json
{
  "name": "Update Account - JSON DB Integration",
  "request": {
    "method": "PATCH",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account/([0-9a-zA-Z]+)"
  },
  "response": {
    "transformers": ["json-db-transformer"],
    "transformerParameters": {
      "operation": "update",
      "table": "accounts",
      "id": "{{request.pathSegments.[6]}}",
      "data": "{{request.body}}",
      "returnStatus": 204
    }
  }
}
```

### 4. Delete Account - Remove from JSON-DB
```json
{
  "name": "Delete Account - JSON DB Integration",
  "request": {
    "method": "DELETE",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account/([0-9a-zA-Z]+)"
  },
  "response": {
    "transformers": ["json-db-transformer"],
    "transformerParameters": {
      "operation": "delete",
      "table": "accounts",
      "id": "{{request.pathSegments.[6]}}",
      "checkRelations": ["opportunities", "contacts"],
      "returnStatus": 204
    }
  }
}
```

## JSON-DB Schema Example

### accounts.json
```json
{
  "schema": {
    "tableName": "accounts",
    "primaryKey": "Id",
    "fields": {
      "Id": {"type": "string", "required": true, "generated": true},
      "Name": {"type": "string", "required": true, "unique": true},
      "Type": {"type": "string", "values": ["Customer", "Partner", "Prospect"]},
      "Industry": {"type": "string"},
      "AnnualRevenue": {"type": "number"},
      "Phone": {"type": "string"},
      "Website": {"type": "string"},
      "CreatedDate": {"type": "datetime", "generated": true},
      "LastModifiedDate": {"type": "datetime", "generated": true}
    },
    "relations": {
      "opportunities": {"type": "hasMany", "foreignKey": "AccountId"},
      "contacts": {"type": "hasMany", "foreignKey": "AccountId"}
    }
  },
  "data": [
    {
      "Id": "001000000000001",
      "Name": "Acme Corporation",
      "Type": "Customer",
      "Industry": "Technology",
      "AnnualRevenue": 50000000
    }
  ]
}
```

## Benefits of JSON-DB Integration

### 1. Realistic Data Behavior
```python
# Test Case 1: Create and Query
POST /Account {"Name": "New Company"}  # Creates in DB
GET /query?q=SELECT...WHERE Name='New Company'  # Finds it!

# Test Case 2: Update Persistence
PATCH /Account/001 {"Revenue": 100000}  # Updates DB
GET /Account/001  # Returns updated revenue

# Test Case 3: Delete Actually Deletes
DELETE /Account/001  # Removes from DB
GET /Account/001  # Returns 404 Not Found
DELETE /Account/001  # Returns 404 (can't delete twice!)
```

### 2. Complex Validation Rules
```python
# Duplicate Detection (Real)
POST /Account {"Name": "Acme"}  # Success
POST /Account {"Name": "Acme"}  # ERROR: Duplicate

# Referential Integrity
POST /Opportunity {"AccountId": "001"}  # Success
DELETE /Account/001  # ERROR: Has related opportunities

# Required Field Validation
POST /Account {"Type": "Customer"}  # ERROR: Name is required
```

### 3. Stateful Test Scenarios
```python
# Multi-step workflows actually work
def test_account_lifecycle():
    # Create
    account_id = create_account({"Name": "Test Corp"})
    
    # Add related data
    add_contact(account_id, {"Name": "John Doe"})
    add_opportunity(account_id, {"Amount": 50000})
    
    # Try to delete (should fail)
    result = delete_account(account_id)
    assert result.error == "Has related records"
    
    # Delete children first
    delete_opportunities(account_id)
    delete_contacts(account_id)
    
    # Now delete succeeds
    result = delete_account(account_id)
    assert result.success == True
    
    # Verify it's gone
    result = get_account(account_id)
    assert result.status == 404
```

## Implementation Approaches

### Option 1: WireMock Extensions
```java
public class JsonDbTransformer extends ResponseTransformer {
    @Override
    public Response transform(Request request, Response response, 
                            FileSource files, Parameters parameters) {
        String operation = parameters.getString("operation");
        String table = parameters.getString("table");
        
        switch(operation) {
            case "query":
                return executeQuery(table, request.getQueryParams());
            case "insert":
                return insertRecord(table, request.getBody());
            case "update":
                return updateRecord(table, extractId(request), request.getBody());
            case "delete":
                return deleteRecord(table, extractId(request));
        }
    }
}
```

### Option 2: Proxy Layer
```python
# Python proxy between WireMock and JSON-DB
@app.route('/api/transform', methods=['POST'])
def transform():
    request_data = request.json
    operation = request_data['operation']
    
    if operation == 'query':
        return json_db.query(request_data['table'], request_data['filters'])
    elif operation == 'insert':
        return json_db.insert(request_data['table'], request_data['data'])
    # etc...
```

### Option 3: Docker Compose Integration
```yaml
services:
  wiremock:
    image: wiremock/wiremock:latest
    volumes:
      - ./mappings:/home/wiremock/mappings
      - ./extensions:/var/wiremock/extensions
    
  json-db:
    image: json-db-server:latest
    volumes:
      - ./data:/data
    
  transformer:
    image: wiremock-json-db-bridge:latest
    environment:
      - JSON_DB_URL=http://json-db:3000
      - WIREMOCK_URL=http://wiremock:8080
```

## Challenges to Consider

1. **Performance**: DB operations slower than static responses
2. **Complexity**: More moving parts to maintain
3. **Test Isolation**: Tests might affect each other
4. **Reset Strategy**: Need to reset DB between test suites
5. **Transaction Support**: Rollback capabilities needed?

## Recommendation

**Use Hybrid Approach:**
- Static mocks for simple, fast unit tests
- JSON-DB integration for integration tests
- Real Salesforce sandbox for end-to-end tests

This gives you the best of all worlds!