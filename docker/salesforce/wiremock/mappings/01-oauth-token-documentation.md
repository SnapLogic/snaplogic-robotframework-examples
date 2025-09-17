# OAuth Token Endpoint Documentation

## File: 01-oauth-token.json

This mapping mocks Salesforce's OAuth 2.0 authentication endpoint and returns an access token for API authorization.

## Endpoint Details
- **URL**: `/services/oauth2/token`
- **Method**: POST
- **Purpose**: Authenticate and receive access token for Salesforce API calls

## Response Fields Explanation

### `access_token`
- **Format**: `"mock-access-token-{{randomValue type='UUID'}}"`
- **Example**: `"mock-access-token-a1b2c3d4-e5f6-7890-abcd-ef1234567890"`
- **Purpose**: Authentication token that must be included in all subsequent API calls
- **Usage**: Add to request headers as `Authorization: Bearer {token}`
- **Dynamic**: Generates a unique UUID for each request
- **Real Salesforce**: Would be an encrypted JWT token containing user/session information

### `instance_url`
- **Value**: `"https://salesforce-api-mock:8443"`
- **Purpose**: Base URL for all Salesforce API calls
- **Usage**: Prepend to all API paths (e.g., `{instance_url}/services/data/v59.0/query`)
- **Note**: Uses Docker container name and port for internal container communication
- **Real Salesforce**: Would be like `https://yourcompany.my.salesforce.com`

### `id`
- **Value**: `"https://login.salesforce.com/id/00D000000000000EAA/005000000000000AAA"`
- **Structure**:
  - `00D000000000000EAA` - Organization ID (18 characters, starts with "00D")
  - `005000000000000AAA` - User ID (18 characters, starts with "005")
- **Purpose**: Identity URL containing organization and user identifiers
- **Customizable**: Can use any 15-18 character alphanumeric values following the prefix rules
- **Usage**: Can be used to fetch additional user information

### `token_type`
- **Value**: `"Bearer"`
- **Purpose**: Indicates the OAuth 2.0 token type
- **Usage**: Tells client to format authorization header as `Authorization: Bearer {token}`
- **Standard**: OAuth 2.0 specification requirement

### `issued_at`
- **Format**: `"{{now epoch}}"`
- **Example**: `1705316400000`
- **Purpose**: Unix epoch timestamp (milliseconds) when token was issued
- **Dynamic**: Generates current timestamp for each request
- **Usage**: Clients can calculate token age and implement refresh logic

### `signature`
- **Value**: `"mock-signature"`
- **Purpose**: Digital signature for token verification
- **Note**: Static mock value for testing
- **Real Salesforce**: Would be a cryptographic signature to prevent token tampering

## How SnapLogic Uses This Response

1. **Authentication Request**: Sends POST to `/services/oauth2/token` with credentials
2. **Token Extraction**: Stores the `access_token` for the session
3. **Base URL Setup**: Uses `instance_url` as the base for all API calls
4. **Header Configuration**: Adds `Authorization: Bearer {token}` to all requests
5. **API Calls**: Makes subsequent calls like:
   ```
   GET https://salesforce-api-mock:8443/services/data/v59.0/sobjects/Account
   Authorization: Bearer mock-access-token-a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```

## Dynamic Templating

The `"transformers": ["response-template"]` enables WireMock's dynamic response features:
- `{{randomValue type='UUID'}}` - Generates unique token for each request
- `{{now epoch}}` - Provides current timestamp in milliseconds

## Differences from Real Salesforce

Real Salesforce OAuth responses include additional fields:
- `scope` - Permissions granted to the token (e.g., "api refresh_token")
- `refresh_token` - Token for refreshing expired access tokens
- `expires_in` - Token lifetime in seconds (typically 7200)
- Complex cryptographic `signature` for security

## Customization Options

### Organization ID
- Must start with `00D`
- Can be 15 or 18 characters
- Examples: `00D123456789ABC`, `00DTestOrg123456`

### User ID
- Must start with `005`
- Can be 15 or 18 characters
- Examples: `005123456789ABC`, `005TestUser00001`

## Salesforce ID Prefixes Reference

Each Salesforce object type has a specific 3-character prefix that identifies the record type:

| Prefix | Object Type | Example ID |
|--------|-------------|------------|
| `001` | Account | `001000000000001AAA` |
| `003` | Contact | `003000000000001AAA` |
| `005` | User | `005000000000001AAA` |
| `006` | Opportunity | `006000000000001AAA` |
| `00D` | Organization | `00D000000000001AAA` |
| `00E` | User Role | `00E000000000001AAA` |
| `00G` | Group | `00G000000000001AAA` |
| `00Q` | Lead | `00Q000000000001AAA` |

### Additional Common Prefixes
- `00O` - Report
- `00l` - Folder
- `015` - Document
- `019` - Email Template
- `02s` - Email Message
- `500` - Case
- `701` - Campaign
- `800` - Contract
- `a00` - Custom Object (prefix varies)

### ID Format Rules
- **Length**: 15 or 18 characters
  - 15-character: Case-sensitive unique ID
  - 18-character: Case-insensitive version with 3-character checksum suffix
- **Characters**: Alphanumeric (0-9, A-Z, a-z)
- **Structure**: `[3-char prefix][12 or 15 char unique identifier]`

### Using IDs in Mock Data
When creating mock data, ensure:
1. Use the correct prefix for the object type
2. Maintain consistency across related records
3. Use meaningful IDs for test scenarios (e.g., `001TestAccount001`)
4. Keep track of IDs used across different mapping files

## Testing Tips

1. Test with any username/password - the mock accepts all credentials
2. Token is valid for the entire session (no expiration in mock)
3. Verify token is properly included in subsequent API calls
4. Check that `instance_url` is correctly used as base URL