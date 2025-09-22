# Minimal Proxy Mappings for SnapLogic Account Validation

This folder contains the **absolute minimum required mappings** for SnapLogic Salesforce account validation to work.

## Files Included

| File | Purpose | Required |
|------|---------|----------|
| `01-oauth-token.json` | OAuth authentication endpoint | ✅ Yes |
| `02-validation-query.json` | Handles SnapLogic validation query | ✅ Yes |

## How SnapLogic Validation Works

When you click "Validate" on a Salesforce account in SnapLogic:

1. **OAuth Request** - `POST /services/oauth2/token`
   - Validates credentials
   - Returns access token and instance URL

2. **Validation Query** - `GET /services/data/v52.0/query?q=SELECT+Name+FROM+Account+LIMIT+1`
   - Tests API access
   - Confirms permissions
   - Returns sample data

## Usage

### Update docker-compose.yml

```yaml
volumes:
  # Use minimal mappings for validation only
  - ./wiremock/proxy_mappings2:/home/wiremock/mappings:ro
```

### Restart Services

```bash
# Restart WireMock with minimal mappings
docker restart salesforce-api-mock

# Verify only 2 mappings are loaded
curl -k https://localhost:8443/__admin/mappings | jq '.mappings | length'
# Should return: 2

# Test OAuth
curl -k -X POST https://localhost:8443/services/oauth2/token \
  -d "grant_type=password&username=test&password=test"

# Test validation query
curl -k "https://localhost:8443/services/data/v52.0/query?q=SELECT+Name+FROM+Account+LIMIT+1"
```

## SnapLogic Configuration

In SnapLogic Salesforce Account settings:
- **Login URL**: `https://salesforce-api-mock:8443` (for Groundplex)
- **Username**: Any value (e.g., `slim@snaplogic.com`)
- **Password**: Any value
- **Security Token**: Leave empty

## What's NOT Included

This minimal setup does NOT include:
- API versions endpoint (`/services/data`)
- Create/Update/Delete operations
- Complex queries
- JSON Server proxy mappings
- Error scenarios

## Notes

- These mappings return **static responses** (no JSON Server needed)
- Suitable for **validation only**, not for actual CRUD operations
- For full CRUD operations, use the complete `proxy_mappings` folder with JSON Server
- Only 2 files are needed for basic SnapLogic account validation

## Troubleshooting

If validation fails:

1. **Check WireMock logs**: 
   ```bash
   docker logs salesforce-api-mock
   ```

2. **Verify network connectivity from Groundplex**:
   ```bash
   docker exec snaplogic-groundplex curl -k https://salesforce-api-mock:8443/__admin/health
   ```

3. **Check loaded mappings**:
   ```bash
   curl -k https://localhost:8443/__admin/mappings | jq '.mappings[].name'
   # Should show:
   # "Salesforce OAuth Token"
   # "SnapLogic Validation Query"
   ```

4. **Test the complete flow manually**:
   ```bash
   # From Groundplex container
   docker exec snaplogic-groundplex sh -c '
   TOKEN=$(curl -sk -X POST https://salesforce-api-mock:8443/services/oauth2/token \
     -d "grant_type=password&username=test&password=test" \
     | grep -o "\"access_token\":\"[^\"]*" | cut -d":" -f2 | tr -d "\"")
   echo "Token: $TOKEN"
   curl -sk "https://salesforce-api-mock:8443/services/data/v52.0/query?q=SELECT+Name+FROM+Account+LIMIT+1" \
     -H "Authorization: Bearer $TOKEN"
   '
   ```

## If You Need More Endpoints

If SnapLogic validation requires additional endpoints (varies by version), you might need to add:

- `03-api-versions.json` - If SnapLogic checks for `/services/data`
- Other endpoints - Check WireMock logs for unmatched requests

But for most SnapLogic installations, these 2 files are sufficient for account validation.
