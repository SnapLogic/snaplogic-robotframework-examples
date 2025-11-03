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

**Deep Dive: How WireMock Proxy Path Appending Works**

When WireMock is configured with a `proxyBaseUrl`, it acts as a pass-through proxy that preserves the original request path and adds it to the end of the proxy base URL.

*What You Might Expect (But Doesn't Happen):*
You might think WireMock could:
- Receive: `POST /services/data/v52.0/sobjects/Account`
- Transform to: `POST /accounts` 
- Forward to: `http://json-server/accounts`

*What Actually Happens:*
WireMock simply concatenates:
1. **Original request arrives**: 
   ```
   POST /services/data/v52.0/sobjects/Account
   ```

2. **WireMock takes the proxy base URL**: 
   ```
   http://json-server
   ```

3. **WireMock appends (adds) the full original path**:
   ```
   http://json-server + /services/data/v52.0/sobjects/Account
   = http://json-server/services/data/v52.0/sobjects/Account
   ```

4. **JSON Server receives**:
   ```
   POST http://json-server/services/data/v52.0/sobjects/Account
   ```

The problem is that JSON Server doesn't understand Salesforce's URL structure. It expects simple endpoints like `/accounts`, `/contacts`, `/opportunities`, but it's receiving the complex Salesforce path `/services/data/v52.0/sobjects/Account`. Since JSON Server doesn't have a route defined for this Salesforce-style path, it returns a **404 Not Found** error.

WireMock's proxy mode is designed for simple forwarding, not path transformation. It:
- **Cannot** rewrite paths during proxying
- **Cannot** strip parts of the path
- **Cannot** map one path structure to another
- **Only** forwards the exact same path to the target server

This is why using JSON Server as a backend through WireMock's proxy won't work for SnapLogic's Salesforce testing - the path structures are fundamentally incompatible and WireMock's proxy can't translate between them.

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

## But Why Does curl Work?

You might have successfully tested with curl commands and wondered why SnapLogic fails with the same setup. Here's the key difference:

### When Using curl (Works ✅)

With curl, you have **full control** over the request format. You can:

1. **Send requests directly to JSON Server** (bypassing WireMock):
```bash
# This works - direct to JSON Server
curl -X POST http://localhost:8082/accounts \
  -H "Content-Type: application/json" \
  -d '{"Name": "Test Company"}'
```

2. **Use WireMock's static mappings** (not proxy):
```bash
# This works - WireMock returns static response
curl -X POST http://localhost:8089/services/data/v52.0/sobjects/Account \
  -H "Content-Type: application/json" \
  -d '{"Name": "Test Company"}'
```

3. **Manually format requests** to match what each service expects

### When Using SnapLogic (Doesn't Work ❌)

SnapLogic's Salesforce connector:
- **Must use Salesforce API format** - it's hardcoded in the connector
- **Cannot be configured** to use simple REST paths like `/accounts`
- **Always sends**: `/services/data/v52.0/sobjects/Account`
- **Always expects** Salesforce-formatted responses with `success` field

### Why Your curl Tests Might Be Misleading

You might be testing one of these scenarios:

**Scenario 1: Testing Different Endpoints**
```bash
# You might be doing this (works):
curl http://localhost:8082/accounts  # Direct to JSON Server

# While SnapLogic is doing this (fails):
# http://localhost:8089/services/data/v52.0/sobjects/Account  # Through WireMock proxy
```

**Scenario 2: Using Static WireMock Responses**
```bash
# Your curl might be hitting static mappings that return:
{
  "id": "001234567890",
  "success": true,
  "errors": []
}
# Not actually proxying to JSON Server
```

**Scenario 3: Different Acceptance Criteria**
```bash
# With curl, you might accept this response:
{"id": "123", "Name": "Test"}  # JSON Server format

# But SnapLogic requires this:
{"id": "001234567890", "success": true, "errors": []}  # Salesforce format
```

### The Real Test

To truly replicate what SnapLogic does, your curl command would need to:

```bash
# This is what SnapLogic actually sends:
curl -X POST http://localhost:8089/services/data/v52.0/sobjects/Account \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer [token]" \
  -H "Sforce-Auto-Assign: TRUE" \
  -d '{"Name": "Test Company", "Type": "Customer"}'
```

If WireMock is configured to proxy this to JSON Server:
- WireMock forwards to: `http://json-server/services/data/v52.0/sobjects/Account`
- JSON Server returns: **404 Not Found**

### The Bottom Line

**curl works** because you can:
- Choose which endpoint to hit
- Accept any response format
- Bypass the proxy if needed
- Adapt your request to what the server expects

**SnapLogic doesn't work** because it:
- Must use Salesforce paths
- Must receive Salesforce responses
- Cannot be reconfigured for simple REST
- Is locked into the Salesforce protocol

It's like the difference between:
- **curl**: You speaking directly in whatever language the server understands
- **SnapLogic**: A translator that only speaks "Salesforce" trying to talk to someone who only speaks "Simple REST"

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
