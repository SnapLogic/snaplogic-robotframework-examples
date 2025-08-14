# Salesforce WireMock Mappings

This directory contains WireMock mapping files that simulate Salesforce REST API endpoints for testing purposes. These mocks enable testing of Salesforce integrations without requiring a live Salesforce instance.

## Overview

WireMock acts as a mock HTTP server that intercepts API requests and returns predefined responses based on these mapping configurations. This setup is particularly useful for:
- Robot Framework test automation
- SnapLogic pipeline testing
- Integration testing in CI/CD pipelines
- Local development without Salesforce access

## Mapping Files

### Authentication & Session Management

| File                    | Endpoint                 | Method | Purpose                                                 |
| ----------------------- | ------------------------ | ------ | ------------------------------------------------------- |
| `01-oauth-token.json`   | `/services/oauth2/token` | POST   | OAuth 2.0 authentication - returns mock access token    |
| `02-get-user-info.json` | `/id/{org-id}/{user-id}` | GET    | Validates authenticated user and retrieves user context |

### API Discovery & Metadata

| File                       | Endpoint                              | Method | Purpose                                                  |
| -------------------------- | ------------------------------------- | ------ | -------------------------------------------------------- |
| `03-get-api-versions.json` | `/services/data`                      | GET    | Lists available Salesforce API versions                  |
| `04-get-resources.json`    | `/services/data/v{version}/`          | GET    | Discovers available resources for a specific API version |
| `05-list-sobjects.json`    | `/services/data/v{version}/sobjects/` | GET    | Lists all available Salesforce objects                   |
| `06-get-limits.json`       | `/services/data/v{version}/limits/`   | GET    | Returns API usage limits and remaining capacity          |

### Account Object Operations

| File                                | Endpoint                                              | Method | Purpose                                      |
| ----------------------------------- | ----------------------------------------------------- | ------ | -------------------------------------------- |
| `07-describe-account-priority.json` | `/services/data/v59.0/sobjects/Account/describe`      | GET    | High-priority Account metadata (priority: 1) |
| `08-describe-account.json`          | `/services/data/v{version}/sobjects/Account/describe` | GET    | Standard Account object metadata             |
| `13-query-accounts.json`            | `/services/data/v{version}/query`                     | GET    | SOQL query for Account records               |
| `09-create-account.json`            | `/services/data/v{version}/sobjects/Account`          | POST   | Create new Account record                    |
| `10-get-account-by-id.json`         | `/services/data/v{version}/sobjects/Account/{id}`     | GET    | Retrieve specific Account by ID              |
| `11-update-account.json`            | `/services/data/v{version}/sobjects/Account/{id}`     | PATCH  | Update existing Account                      |
| `12-delete-account.json`            | `/services/data/v{version}/sobjects/Account/{id}`     | DELETE | Delete Account record                        |

## API Flow for SnapLogic Salesforce Read Pipeline

When a SnapLogic pipeline reads Account data, it typically follows this sequence:

### 1. Authentication Phase
```
POST /services/oauth2/token
→ Returns: access_token, instance_url
```

### 2. Discovery Phase
```
GET /services/data
→ Returns: Available API versions

GET /services/data/v59.0/
→ Returns: Available resources

GET /services/data/v59.0/sobjects/
→ Returns: List of all SObjects
```

### 3. Metadata Phase
```
GET /services/data/v59.0/sobjects/Account/describe
→ Returns: Account field definitions, types, constraints
```

### 4. Data Retrieval Phase
```
GET /services/data/v59.0/limits/
→ Returns: API limits and remaining calls

GET /services/data/v59.0/query?q=SELECT...FROM Account
→ Returns: Account records matching the query
```

## Mock Data Examples

### Sample Accounts Returned by Query
- **Acme Corporation** (ID: 001000000000001) - Customer, Technology, $50M revenue
- **Global Innovations Inc** (ID: 001000000000002) - Partner, Manufacturing, $75M revenue
- **TechStart Solutions** (ID: 001000000000003) - Prospect, Software, $10M revenue

### Account Fields Available
- `Id` - Salesforce ID (18 characters)
- `Name` - Account name (required)
- `Type` - Picklist: Customer, Partner, Prospect
- `Industry` - Industry classification
- `AnnualRevenue` - Currency field
- `Phone` - Phone number
- `Website` - URL field
- `NumberOfEmployees` - Numeric field

## Dynamic Response Features

The mappings use WireMock's response templating for realistic data:

| Template Variable                         | Description                 | Example                                        |
| ----------------------------------------- | --------------------------- | ---------------------------------------------- |
| `{{randomValue type='UUID'}}`             | Generate random UUID        | `a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6`         |
| `{{randomValue type='NUMERIC' length=X}}` | Random number with X digits | `12345`                                        |
| `{{now}}`                                 | Current timestamp           | `2024-01-15T10:30:00.000+0000`                 |
| `{{now epoch}}`                           | Current epoch time          | `1705316400000`                                |
| `{{request.pathSegments.[X]}}`            | Extract URL path segment    | Account ID from URL                            |
| `{{request.url}}`                         | Complete request URL        | `/services/data/v59.0/sobjects/Account/001...` |

## Configuration Notes

### Priority Levels
- Files with `priority` field are evaluated first
- Lower numbers = higher priority
- `07-describe-account-priority.json` has priority: 1 (highest)
- Default priority is 5 for most mappings

### URL Pattern Matching
- Uses regex patterns for flexible matching
- `v[0-9]+\\.[0-9]+` matches any API version (v58.0, v59.0, etc.)
- `[0-9a-zA-Z]+` matches Salesforce IDs

### Response Status Codes
- `200` - Successful GET requests
- `201` - Successful resource creation (POST)
- `204` - Successful update/delete (no content returned)

## Testing Tips

For detailed instructions on setting up WireMock with HTTPS certificates and Docker configuration, please refer to:
[WireMock HTTPS Certificate Setup Guide](../../../../../../README/How%20To%20Guides/infra_setup_guides/wiremock_https_certificate_setup.md)

This guide covers:
- Docker container setup for WireMock
- HTTPS certificate configuration
- Integration with SnapLogic Groundplex
- Network configuration for container communication

## Troubleshooting

### Common Issues

1. **404 Not Found**
   - Check URL patterns match exactly
   - Verify API version in URL
   - Ensure mappings are loaded

2. **Priority Conflicts**
   - Review priority settings if wrong mapping is matched
   - More specific patterns should have higher priority (lower number)

3. **Missing Dynamic Values**
   - Ensure `"transformers": ["response-template"]` is included
   - Check template variable syntax

## Extending the Mocks

To add new SObject support:
1. Copy an existing Account mapping file
2. Replace "Account" with your object name
3. Update field definitions in describe response
4. Modify sample data in query response
5. Adjust URL patterns as needed

## Related Documentation

- [WireMock Documentation](http://wiremock.org/docs/)
- [Salesforce REST API Reference](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/)
- [SnapLogic Salesforce Snap Pack](https://docs-snaplogic.atlassian.net/wiki/spaces/SD/pages/1438704/Salesforce+Snap+Pack)

## Maintenance

Last Updated: January 2025
Version: 1.0
Compatible with: Salesforce API v59.0

For questions or issues, contact the SLIM team.