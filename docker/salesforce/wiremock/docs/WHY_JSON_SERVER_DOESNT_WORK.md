# Why the JSON Server Proxy Approach Doesn't Work with SnapLogic

## The Core Problem

When SnapLogic's Salesforce connector sends a CREATE request through WireMock to JSON Server, three fundamental incompatibilities prevent it from working:

### 1. Path Mismatch

**What happens:**
- SnapLogic sends: `POST /services/data/v52.0/sobjects/Account`
- WireMock proxy forwards to: `http://json-server/services/data/v52.0/sobjects/Account`
- JSON Server expects: `POST /accounts`
- Result: **404 Not Found**

**Understanding the Path Problem in Detail:**

When WireMock uses `proxyBaseUrl`, it works like this:
1. Receives request at path: `/services/data/v52.0/sobjects/Account`
2. Takes the proxy base URL: `http://json-server`
3. Appends the original path: `http://json-server/services/data/v52.0/sobjects/Account`
4. JSON Server receives this complex Salesforce path and returns 404

**Why it can't be easily fixed:**
- WireMock's `proxyBaseUrl` appends the original path, it doesn't replace it
- Path rewriting in WireMock proxy mode is not supported
- JSON Server's route rewriting doesn't work with the proxy's forwarded requests

### 2. Response Format Incompatibility

**Salesforce format (what SnapLogic expects):**
```json
{
  "id": "001234567890",
  "success": true,
  "errors": []
}
```

**JSON Server format (what it returns):**
```json
{
  "id": "abc123",
  "Name": "Test Company",
  "Type": "Customer"
}
```

**Why it matters:**
- SnapLogic validates the response structure
- Missing `success` field causes parsing errors
- Different field structure breaks the Salesforce connector

### 3. Status Code Differences

- **Salesforce**: Returns `201 Created` for successful creation
- **JSON Server**: May return `200 OK` or `201 Created` depending on configuration
- **WireMock proxy**: Passes through whatever JSON Server returns
- **SnapLogic**: May expect specific status codes for different operations

## Understanding JSON Server's REST Conventions

JSON Server follows standard RESTful API conventions. It's important to understand what paths JSON Server automatically creates and recognizes.

### How JSON Server Works

When you provide JSON Server with a `db.json` file like:
```json
{
  "accounts": [],
  "contacts": [],
  "products": []
}
```

JSON Server automatically creates these standard REST endpoints:

| HTTP Method | Path | What It Does |
|-------------|------|--------------|
| GET | `/accounts` | Get all accounts |
| GET | `/accounts/123` | Get account with id=123 |
| POST | `/accounts` | Create new account |
| PUT | `/accounts/123` | Replace entire account 123 |
| PATCH | `/accounts/123` | Update fields in account 123 |
| DELETE | `/accounts/123` | Delete account 123 |

### What JSON Server Does NOT Understand

JSON Server only knows the simple REST paths it generates. It does NOT understand:
- ❌ `/services/data/v52.0/sobjects/Account` (Salesforce format)
- ❌ `/api/v1/accounts` (versioned APIs)
- ❌ `/enterprise/accounts/create` (action-based URLs)
- ❌ `/Account` (singular, capitalized)

### The Language Barrier

This is like having three people who speak different languages:

**SnapLogic** speaks "Salesforce":
```
POST /services/data/v52.0/sobjects/Account
```

**JSON Server** speaks "Simple REST":
```
POST /accounts
```

**WireMock** is just a messenger - it can forward messages but cannot translate between these languages.

## Why Common Solutions Don't Work

### Attempt 1: Simple Proxy
```json
"proxyBaseUrl": "http://json-server/accounts"
```
**Problem:** Creates URL `http://json-server/accounts/services/data/v52.0/sobjects/Account` → 404

### Attempt 2: Route Rewriting
```json
// routes.json
{
  "/services/data/v*/sobjects/Account": "/accounts"
}
```
**Problem:** Only works for direct requests to JSON Server, not proxied requests from WireMock

### Attempt 3: Response Transformation
```json
"transformers": ["response-template"]
```
**Problem:** WireMock can't transform proxied responses easily; transformation only works with static responses

## The Fundamental Architecture Mismatch

```
SnapLogic → [Salesforce Protocol] → WireMock → [REST Protocol] → JSON Server
                     ↓                              ↓
              Complex nested paths            Simple resource paths
              Specific response format       Generic JSON responses
              Enterprise patterns            Simple CRUD patterns
```

These systems speak different "languages" and WireMock alone cannot translate between them.

## What Would Actually Be Required

To make this work, you would need:

1. **A custom middleware service** that:
   - Accepts Salesforce-formatted requests
   - Transforms them to JSON Server format
   - Forwards to JSON Server
   - Transforms responses back to Salesforce format
   - Returns to SnapLogic

2. **Or modify JSON Server** to:
   - Understand Salesforce paths
   - Return Salesforce-formatted responses
   - Handle Salesforce-specific headers and parameters

3. **Or use WireMock's webhook extension** to:
   - Return static Salesforce-formatted response to SnapLogic
   - Simultaneously save data to JSON Server via webhook
   - But this creates ID synchronization issues

## The Practical Reality

The effort required to bridge these incompatible systems exceeds the benefit. You're essentially trying to make a Toyota engine work in a Tesla - while theoretically possible with enough adapters and modifications, it's not practical.

## Recommended Alternatives

### For Pipeline Testing
Use static WireMock responses that return consistent, predictable data. This tests your pipeline logic without the complexity of real persistence.

### For Data Persistence Testing
Test directly against JSON Server (port 8082) using REST clients or scripts, bypassing the Salesforce format requirements.

### For Full Integration Testing
Use an actual Salesforce sandbox environment where all components speak the same protocol.

## Conclusion

The JSON Server proxy approach fails because WireMock, SnapLogic, and JSON Server have fundamentally incompatible expectations about paths, request/response formats, and behavior. While each tool works well for its intended purpose, connecting them requires more transformation logic than WireMock can provide out of the box.

The incompatibility isn't a bug or configuration issue - it's an architectural mismatch between enterprise (Salesforce) and simple (JSON Server) API patterns. JSON Server is designed for simple REST conventions, while Salesforce uses complex enterprise-specific paths and formats. WireMock can forward messages between them but cannot translate between these fundamentally different API languages.
