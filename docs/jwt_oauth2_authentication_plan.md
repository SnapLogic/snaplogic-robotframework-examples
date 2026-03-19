# Multi-Method Authentication Enhancement Plan

## 1. Background

The Robot Framework currently supports **only Basic Authentication** (username/password) for SnapLogic API calls. To meet enterprise security requirements — where sharing passwords or granting broad admin rights is not permitted — the framework needs to support additional authentication methods.

The SnapLogic platform natively supports JWT authentication (configurable via Admin Manager > Security > Authentication > JWT tab) and session token authentication via the Session API. This enhancement adds the following authentication methods to the framework:

- **Basic Authentication** (existing, default)
- **JWT / Bearer Token Authentication** (new)
- **OAuth2 Client Credentials Authentication** (new)
- **SLToken / SnapLogic Session Token Authentication** (new)

## 2. Supported Authentication Methods

| Method | ENV Variable | Required Env Vars | Description |
|--------|-------------|-------------------|-------------|
| `basic` (default) | `AUTH_METHOD=basic` | `ORG_ADMIN_USER`, `ORG_ADMIN_PASSWORD` | Current behavior, no changes needed |
| `jwt` | `AUTH_METHOD=jwt` | `BEARER_TOKEN` | Pre-generated JWT token used as Bearer token |
| `oauth2` | `AUTH_METHOD=oauth2` | `OAUTH2_TOKEN_URL`, `OAUTH2_CLIENT_ID`, `OAUTH2_CLIENT_SECRET`, `OAUTH2_SCOPE` (optional) | Framework auto-fetches token from IdP |
| `sltoken` | `AUTH_METHOD=sltoken` | `ORG_ADMIN_USER`, `ORG_ADMIN_PASSWORD` | Authenticates once, uses session token for all subsequent calls |

If `AUTH_METHOD` is not set, the framework **auto-detects** based on which env vars are present. Note: `sltoken` cannot be auto-detected (same env vars as `basic`) — it must be explicitly set via `AUTH_METHOD=sltoken`.

### Security Comparison

| Auth Method | Credentials Sent Per API Call | External IdP Required | Setup Effort |
|-------------|-------------------------------|----------------------|--------------|
| `basic` | Username + password on **every** request | No | None |
| `sltoken` | Only **once** (to get token), then session token | No | Minimal (1 env var change) |
| `jwt` | Never (pre-generated token) | Yes | Medium (IdP + SnapLogic JWT tab) |
| `oauth2` | Never (auto-fetched token) | Yes | Medium (IdP + SnapLogic JWT tab) |

**Recommended upgrade path:** `basic` → `sltoken` → `jwt` / `oauth2`

## 3. Key Design Insight

All 30+ API keywords in the framework use:
```robot
GET On Session    ${ORG_ADMIN_SESSION}    /api/endpoint
POST On Session   ${ORG_ADMIN_SESSION}    /api/endpoint    json=${payload}
```

The session `${ORG_ADMIN_SESSION}` is created once in `Login Api`. By changing **how the session is created**, all downstream API calls automatically inherit the new authentication — no changes needed to individual API keywords.

```
Basic Auth:
    Create Session    ${ORG_ADMIN_SESSION}    ${url}    auth=${auth}    verify=true

JWT / OAuth2:
    ${headers}=    Create Dictionary    Authorization=Bearer ${token}
    Create Session    ${ORG_ADMIN_SESSION}    ${url}    headers=${headers}    verify=true

SLToken:
    ${headers}=    Create Dictionary    Authorization=SLToken ${token}
    Create Session    ${ORG_ADMIN_SESSION}    ${url}    headers=${headers}    verify=true
```

## 4. Authentication Flow Diagrams

### Basic Auth (Current - No Change)
```
.env                    __init__.robot              snaplogic_keywords        snaplogic_apis
ORG_ADMIN_USER    -->   Load Env Vars          -->  Set Up Data          -->  Login Api
ORG_ADMIN_PASSWORD      Validate Env Vars           Create List [u, p]       Create Session auth=[u,p]
                                                                                    |
                                                                              All API calls use
                                                                              ${ORG_ADMIN_SESSION}
```

### JWT / Bearer Token (New)
```
.env                    __init__.robot              snaplogic_keywords        snaplogic_apis
AUTH_METHOD=jwt   -->   Load Env Vars          -->  Set Up Data          -->  Login Api
BEARER_TOKEN            Detect Auth Method          Pass bearer_token         Create Session headers=
                        Validate (BEARER_TOKEN)                               {Authorization: Bearer <token>}
                                                                                    |
                                                                              All API calls use
                                                                              ${ORG_ADMIN_SESSION}
```

### OAuth2 Client Credentials (New)
```
.env                    __init__.robot              snaplogic_keywords        auth_manager.py           snaplogic_apis
AUTH_METHOD=oauth2 -->  Load Env Vars          -->  Set Up Data          --> Configure OAuth2     -->  Login Api
OAUTH2_TOKEN_URL        Detect Auth Method          Pass oauth2 params       Get OAuth2 Access Token    Create Session headers=
OAUTH2_CLIENT_ID        Validate (OAuth2 vars)                               POST to token endpoint     {Authorization: Bearer <token>}
OAUTH2_CLIENT_SECRET                                                         Cache token + expiry             |
                                                                                                        All API calls use
                                                                                                        ${ORG_ADMIN_SESSION}
```

### SLToken / SnapLogic Session Token (New)
```
.env                    __init__.robot              snaplogic_keywords        snaplogic_apis
AUTH_METHOD=sltoken --> Load Env Vars          -->  Set Up Data          -->  Login Api
ORG_ADMIN_USER          Detect Auth Method          Create List [u, p]       1. Create temp session (Basic Auth)
ORG_ADMIN_PASSWORD      Validate (USER/PASS)        Pass auth_method=sltoken 2. GET /api/1/rest/asset/session
                                                                             3. Extract session token
                                                                             4. Recreate session with headers=
                                                                                {Authorization: SLToken <token>}
                                                                                       |
                                                                                 All API calls use
                                                                                 ${ORG_ADMIN_SESSION}
                                                                                 (token-based, no password)
```

**SLToken Advantages:**
- Username/password sent only **once** (to get the session token), not on every API call
- No Identity Provider (Okta, Entra ID) setup required — works out of the box
- Easiest upgrade from basic auth — just change `AUTH_METHOD=sltoken` in `.env`
- Session token is temporary and scoped, reducing risk if intercepted
- The framework makes 30+ API calls per test run; with basic auth that's 30+ password transmissions, with SLToken it's only 1

## 5. Files to Modify

### Overview

| # | File | Repository | Change Type |
|---|------|-----------|-------------|
| 1 | `libraries/auth_manager.py` | snaplogic-common-robot | **NEW FILE** |
| 2 | `snaplogic_apis_keywords/snaplogic_apis.resource` | snaplogic-common-robot | MODIFY |
| 3 | `snaplogic_apis_keywords/snaplogic_keywords.resource` | snaplogic-common-robot | MODIFY |
| 4 | `test/suite/__init__.robot` | snaplogic-robotframework-examples | MODIFY |
| 5 | `.env.example` | snaplogic-robotframework-examples | MODIFY |

### 5.1 NEW: `auth_manager.py`

**Path:** `snaplogic-common-robot/src/snaplogic_common_robot/libraries/auth_manager.py`

Python library with `@keyword` decorators (same pattern as existing `utils.py`):

| Keyword | Purpose |
|---------|---------|
| `Configure OAuth2 Client Credentials` | Stores token_url, client_id, client_secret, scope |
| `Get OAuth2 Access Token` | POSTs to token endpoint, caches token, auto-refreshes 60s before expiry |
| `Is OAuth2 Token Expired` | Checks if cached token needs refresh |
| `Clear OAuth2 Token` | Clears token cache |

**Dependencies:** Uses only `requests` (already in requirements) and `time` (stdlib). No new packages needed.

**Token Refresh Logic:**
- Token and expiry timestamp are cached in memory
- `Get OAuth2 Access Token` checks expiry before returning cached token
- If token expires within 60 seconds, automatically fetches a new one
- For most test suites (< 1 hour), the initial token (typically 3600s) suffices

### 5.2 MODIFY: `snaplogic_apis.resource`

**Path:** `snaplogic-common-robot/src/snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_apis.resource`

**Changes:**

1. **Add import** (after existing library imports):
   ```robot
   Library    ../libraries/auth_manager.py
   ```

2. **Add variable:**
   ```robot
   ${GLOBAL_AUTH_METHOD}    basic
   ```

3. **Replace `Login Api` keyword** — new version supports all four auth methods:

   ```robot
   Login Api
       [Arguments]
       ...    ${auth_method}=basic
       ...    ${auth}=${NONE}
       ...    ${bearer_token}=${EMPTY}
       ...    ${oauth2_token_url}=${EMPTY}
       ...    ${oauth2_client_id}=${EMPTY}
       ...    ${oauth2_client_secret}=${EMPTY}
       ...    ${oauth2_scope}=${EMPTY}

       IF    '${auth_method}' == 'basic'
           Create Session    ${ORG_ADMIN_SESSION}    ${url}    auth=${auth}    verify=true
       ELSE IF    '${auth_method}' == 'jwt'
           ${headers}    Create Dictionary    Authorization=Bearer ${bearer_token}
           Create Session    ${ORG_ADMIN_SESSION}    ${url}    headers=${headers}    verify=true
       ELSE IF    '${auth_method}' == 'oauth2'
           Configure OAuth2 Client Credentials
           ...    ${oauth2_token_url}    ${oauth2_client_id}
           ...    ${oauth2_client_secret}    ${oauth2_scope}
           ${access_token}    Get OAuth2 Access Token
           ${headers}    Create Dictionary    Authorization=Bearer ${access_token}
           Create Session    ${ORG_ADMIN_SESSION}    ${url}    headers=${headers}    verify=true
       ELSE IF    '${auth_method}' == 'sltoken'
           # Authenticate once with Basic Auth to get session token
           Create Session    ${ORG_ADMIN_SESSION}    ${url}    auth=${auth}    verify=true
           ${token}    Get Auth Token    ${auth}[0]    ${auth}[1]
           # Recreate session using session token instead of password
           ${headers}    Create Dictionary    Authorization=SLToken ${token}
           Create Session    ${ORG_ADMIN_SESSION}    ${url}    headers=${headers}    verify=true
       ELSE
           Fail    Unknown auth method: ${auth_method}. Supported: basic, jwt, oauth2, sltoken
       END
       Set Global Variable    ${GLOBAL_AUTH_METHOD}    ${auth_method}
   ```

4. **Add `Refresh Session If Needed` keyword** — for OAuth2 token refresh during long test runs:
   ```robot
   Refresh Session If Needed
       ${auth_method}    Get Variable Value    ${GLOBAL_AUTH_METHOD}    basic
       IF    '${auth_method}' == 'oauth2'
           ${expired}    Is OAuth2 Token Expired
           IF    ${expired}
               ${access_token}    Get OAuth2 Access Token
               ${headers}    Create Dictionary    Authorization=Bearer ${access_token}
               Create Session    ${ORG_ADMIN_SESSION}    ${url}    headers=${headers}    verify=true
           END
       END
   ```

### 5.3 MODIFY: `snaplogic_keywords.resource`

**Path:** `snaplogic-common-robot/src/snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource`

**Changes to `Set Up Data` keyword:**

1. **Update signature** — add optional params with defaults (backward compatible):
   ```robot
   Set Up Data
       [Arguments]
       ...    ${url}
       ...    ${username}=${EMPTY}
       ...    ${password}=${EMPTY}
       ...    ${org_name}=${NONE}
       ...    ${project_space}=${EMPTY}
       ...    ${project_name}=${EMPTY}
       ...    ${env_file_path}=${None}
       ...    ${auth_method}=basic
       ...    ${bearer_token}=${EMPTY}
       ...    ${oauth2_token_url}=${EMPTY}
       ...    ${oauth2_client_id}=${EMPTY}
       ...    ${oauth2_client_secret}=${EMPTY}
       ...    ${oauth2_scope}=${EMPTY}
   ```

2. **Replace auth block** — dispatch based on auth_method:
   ```robot
   IF    '${auth_method}' == 'basic'
       ${auth}    Create List    ${username}    ${password}
       Login Api    auth_method=basic    auth=${auth}
   ELSE IF    '${auth_method}' == 'jwt'
       Login Api    auth_method=jwt    bearer_token=${bearer_token}
   ELSE IF    '${auth_method}' == 'oauth2'
       Login Api    auth_method=oauth2
       ...    oauth2_token_url=${oauth2_token_url}
       ...    oauth2_client_id=${oauth2_client_id}
       ...    oauth2_client_secret=${oauth2_client_secret}
       ...    oauth2_scope=${oauth2_scope}
   ELSE IF    '${auth_method}' == 'sltoken'
       ${auth}    Create List    ${username}    ${password}
       Login Api    auth_method=sltoken    auth=${auth}
   ELSE
       Fail    Unknown AUTH_METHOD: ${auth_method}. Supported: basic, jwt, oauth2, sltoken
   END
   ```

### 5.4 MODIFY: `__init__.robot`

**Path:** `snaplogic-robotframework-examples/{{cookiecutter.primary_pipeline_name}}/test/suite/__init__.robot`

**Changes:**

1. **Add `Detect Auth Method` keyword** — auto-detects from env vars:
   ```robot
   Detect Auth Method
       ${explicit}=    Get Environment Variable    AUTH_METHOD    ${EMPTY}
       IF    '${explicit}' != '${EMPTY}'
           RETURN
       END
       ${oauth2_url}=    Get Environment Variable    OAUTH2_TOKEN_URL    ${EMPTY}
       ${bearer}=    Get Environment Variable    BEARER_TOKEN    ${EMPTY}
       IF    '${oauth2_url}' != '${EMPTY}'
           Set Environment Variable    AUTH_METHOD    oauth2
       ELSE IF    '${bearer}' != '${EMPTY}'
           Set Environment Variable    AUTH_METHOD    jwt
       ELSE
           Set Environment Variable    AUTH_METHOD    basic
       END
   ```

2. **Update `Before Suite`** — add `Detect Auth Method` call:
   ```robot
   Before Suite
       Load Environment Variables
       Detect Auth Method
       Validate Environment Variables
       Set Up Global Variables
       Project Set Up-Delete Project Space-Create New Project space-Create Accounts
   ```

3. **Update `Validate Environment Variables`** — auth-method-aware validation:
   - Always require: `URL`, `ORG_NAME`, `PROJECT_SPACE`, `PROJECT_NAME`, `GROUNDPLEX_NAME`
   - If `basic`: also require `ORG_ADMIN_USER`, `ORG_ADMIN_PASSWORD`
   - If `jwt`: also require `BEARER_TOKEN`
   - If `oauth2`: also require `OAUTH2_TOKEN_URL`, `OAUTH2_CLIENT_ID`, `OAUTH2_CLIENT_SECRET`
   - If `sltoken`: also require `ORG_ADMIN_USER`, `ORG_ADMIN_PASSWORD`

4. **Update `Project Set Up...` keyword** — pass auth params based on method:
   - Read `AUTH_METHOD` from env
   - For `basic`: call `Set Up Data` with username/password (same as today)
   - For `jwt`: call `Set Up Data` with `auth_method=jwt` + `bearer_token`
   - For `oauth2`: call `Set Up Data` with `auth_method=oauth2` + OAuth2 params
   - For `sltoken`: call `Set Up Data` with username/password + `auth_method=sltoken`

### 5.5 MODIFY: `.env.example`

**Path:** `snaplogic-robotframework-examples/{{cookiecutter.primary_pipeline_name}}/.env.example`

Add new section documenting all auth options:

```bash
# ============================================================================
#                         AUTHENTICATION CONFIGURATION
# ============================================================================
# AUTH_METHOD controls how the framework authenticates with SnapLogic.
# Supported values: basic (default), jwt, oauth2, sltoken
# If not set, auto-detected from available env vars.
#
# --- Option 1: Basic Auth (default) ---
# AUTH_METHOD=basic
# Uses ORG_ADMIN_USER and ORG_ADMIN_PASSWORD.
#
# --- Option 2: JWT / Bearer Token ---
# AUTH_METHOD=jwt
# BEARER_TOKEN=your_jwt_token_here
#
# --- Option 3: OAuth2 Client Credentials ---
# AUTH_METHOD=oauth2
# OAUTH2_CLIENT_ID=your_client_id
# OAUTH2_CLIENT_SECRET=your_client_secret
# OAUTH2_SCOPE=optional_scope
#
# For Okta:
# OAUTH2_TOKEN_URL=https://your-org.okta.com/oauth2/default/v1/token
#
# For Microsoft Entra ID (Azure AD):
# OAUTH2_TOKEN_URL=https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token
# OAUTH2_SCOPE=https://graph.microsoft.com/.default
#
# --- Option 4: SnapLogic Session Token (SLToken) ---
# AUTH_METHOD=sltoken
# Uses ORG_ADMIN_USER and ORG_ADMIN_PASSWORD (same as basic).
# Authenticates once, then uses session token for all API calls.
# ============================================================================
```

## 6. Backward Compatibility

| Scenario | Behavior |
|----------|----------|
| No `AUTH_METHOD` set, `ORG_ADMIN_USER`/`ORG_ADMIN_PASSWORD` present | Auto-detects `basic`, works exactly as today |
| `Set Up Data` called with positional args (url, user, pass) | Still works — new params all have defaults |
| `Login Api` called with just `${auth}` list | Still works — `auth_method` defaults to `basic` |
| Existing `.env` files unchanged | No modifications needed |
| Existing test files unchanged | No modifications needed |

## 7. Implementation Order

| Step | Task | Depends On |
|------|------|-----------|
| 1 | Create `auth_manager.py` | None |
| 2 | Modify `snaplogic_apis.resource` | Step 1 |
| 3 | Modify `snaplogic_keywords.resource` | Step 2 |
| 4 | Modify `__init__.robot` | Steps 2-3 |
| 5 | Update `.env.example` | None |
| 6 | Test backward compatibility (basic auth) | Steps 1-5 |
| 7 | Test SLToken auth | Steps 1-5 |
| 8 | Test JWT auth | Steps 1-5 |
| 9 | Test OAuth2 auth | Steps 1-5 |

## 8. Environment Variable Reference

### Basic Auth (Default)
```bash
AUTH_METHOD=basic          # Optional (auto-detected)
URL=https://elastic.snaplogic.com
ORG_ADMIN_USER=username
ORG_ADMIN_PASSWORD=password
ORG_NAME=org-name
```

### JWT / Bearer Token
```bash
AUTH_METHOD=jwt            # Optional (auto-detected if BEARER_TOKEN exists)
URL=https://elastic.snaplogic.com
BEARER_TOKEN=eyJhbGciOiJSUzI1NiIs...
ORG_NAME=org-name
```

### OAuth2 Client Credentials (Okta)
```bash
AUTH_METHOD=oauth2         # Optional (auto-detected if OAUTH2_TOKEN_URL exists)
URL=https://elastic.snaplogic.com
OAUTH2_TOKEN_URL=https://company.okta.com/oauth2/default/v1/token
OAUTH2_CLIENT_ID=0oa1b2c3d4e5f6g7h8
OAUTH2_CLIENT_SECRET=abcdef123456
OAUTH2_SCOPE=snaplogic.api   # Optional
ORG_NAME=org-name
```

### OAuth2 Client Credentials (Microsoft Entra ID)
```bash
AUTH_METHOD=oauth2         # Optional (auto-detected if OAUTH2_TOKEN_URL exists)
URL=https://elastic.snaplogic.com
OAUTH2_TOKEN_URL=https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token
OAUTH2_CLIENT_ID=12345678-abcd-efgh-ijkl-123456789012
OAUTH2_CLIENT_SECRET=AbCdEfGh~123456789
OAUTH2_SCOPE=https://graph.microsoft.com/.default   # Optional
ORG_NAME=org-name
```

### SLToken / SnapLogic Session Token
```bash
AUTH_METHOD=sltoken        # Required (cannot be auto-detected)
URL=https://elastic.snaplogic.com
ORG_ADMIN_USER=username
ORG_ADMIN_PASSWORD=password
ORG_NAME=org-name
```

> **Note:** SLToken uses the same `ORG_ADMIN_USER` and `ORG_ADMIN_PASSWORD` as basic auth. The difference is that the password is sent only once to obtain a session token, and then the token is used for all subsequent API calls via the `Authorization: SLToken <token>` header.

## 9. Testing Plan

| Test Case | `.env` Config | Expected Result |
|-----------|--------------|-----------------|
| Backward compat (no changes) | Current `.env` unchanged | Tests pass as before |
| Explicit basic | Add `AUTH_METHOD=basic` | Tests pass |
| SLToken auth | `AUTH_METHOD=sltoken` + `ORG_ADMIN_USER` + `ORG_ADMIN_PASSWORD` | Session token obtained, all API calls use SLToken header |
| JWT auth | `AUTH_METHOD=jwt` + `BEARER_TOKEN=<token>` | Session created with Bearer header |
| OAuth2 auth | `AUTH_METHOD=oauth2` + OAuth2 vars | Token fetched, session created |
| Auto-detect basic | No `AUTH_METHOD`, only user/pass | Detects basic |
| Auto-detect jwt | No `AUTH_METHOD`, only `BEARER_TOKEN` | Detects jwt |
| Auto-detect oauth2 | No `AUTH_METHOD`, only `OAUTH2_TOKEN_URL` | Detects oauth2 |
| Missing vars (jwt) | `AUTH_METHOD=jwt`, no `BEARER_TOKEN` | Clear error message |
| Missing vars (oauth2) | `AUTH_METHOD=oauth2`, no `OAUTH2_CLIENT_ID` | Clear error message |
| Missing vars (sltoken) | `AUTH_METHOD=sltoken`, no `ORG_ADMIN_USER` | Clear error message |
| Invalid method | `AUTH_METHOD=saml` | Clear error message |
| Token refresh (oauth2) | Long-running test suite | Token auto-refreshed |

## 10. Error Handling

| Error Scenario | Where Caught | Error Message |
|---------------|-------------|---------------|
| Missing required env vars | `Validate Environment Variables` | "Missing required environment variables for AUTH_METHOD=jwt: BEARER_TOKEN" |
| Invalid `AUTH_METHOD` | `Validate Environment Variables` + `Login Api` | "Invalid AUTH_METHOD: saml. Supported: basic, jwt, oauth2, sltoken" |
| OAuth2 token request fails | `auth_manager.py` | "OAuth2 token request failed: HTTP 401 ..." |
| OAuth2 response missing token | `auth_manager.py` | "OAuth2 response missing 'access_token'. Response: {...}" |
| SLToken session API fails | `Login Api` → `Get Auth Token` | Standard HTTP error from session endpoint |
| SLToken missing auth list | `Login Api` | "SLToken auth requires auth list [username, password]" |
| JWT/Bearer rejected by SnapLogic | Subsequent API call (401) | Standard SnapLogic error via `Handle API Error` |

## 11. Dependencies

**No new packages required.** `auth_manager.py` uses:
- `requests` — already in `pyproject.toml` (`requests>=2.25.0`)
- `time` — Python stdlib
- `robot.api.deco` — from `robotframework` (already a dependency)
- `robot.api` — from `robotframework` (already a dependency)

## 12. SnapLogic Configuration Requirements (For Reference)

### JWT / OAuth2 — Requires JWT Tab Configuration

For JWT and OAuth2 to work, the SnapLogic org must have JWT configured:

1. **Admin Manager > Security > Authentication > JWT tab**
2. Enter **Issuer ID** (from IdP — see provider-specific values below)
3. Enter **JWKS Endpoint URL** (from IdP — see provider-specific values below)
4. Click **Save**
5. Leave "Disable basic authentication" unchecked during transition

#### SnapLogic JWT Tab Values by Identity Provider

| Field | Okta | Microsoft Entra ID |
|-------|------|-------------------|
| **Issuer ID** | `https://company.okta.com/oauth2/default` | `https://login.microsoftonline.com/{tenant-id}/v2.0` |
| **JWKS Endpoint URL** | `https://company.okta.com/oauth2/default/v1/keys` | `https://login.microsoftonline.com/{tenant-id}/discovery/v2.0/keys` |

### SLToken — No Additional Configuration Required

SLToken authentication uses the SnapLogic Session API (`/api/1/rest/asset/session`) which is available by default on all SnapLogic instances. No admin configuration or Identity Provider setup is needed — just set `AUTH_METHOD=sltoken` in your `.env` file.

## 13. Identity Provider Setup Guides

### 13.1 Okta Setup

1. **Create an Application:** Okta Admin Console → Applications → Create App Integration → Select **API Services** (Client Credentials)
2. **Collect Required Information:**

| Value | Where to Find |
|-------|--------------|
| **Client ID** | General tab → Client ID |
| **Client Secret** | General tab → Client Secret |
| **Token URL** | `https://your-org.okta.com/oauth2/default/v1/token` |
| **Issuer URL** | `https://your-org.okta.com/oauth2/default` |
| **JWKS URL** | `https://your-org.okta.com/oauth2/default/v1/keys` |

3. **Verify Setup:**
```bash
curl -X POST https://your-org.okta.com/oauth2/default/v1/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "scope=snaplogic.api"
```

### 13.2 Microsoft Entra ID (Azure AD) Setup

#### Step 1: Register an Application

1. Go to **Azure Portal** → **Microsoft Entra ID** → **App registrations**
2. Click **New registration**
   - **Name:** `SnapLogic Robot Framework`
   - **Supported account types:** Accounts in this organizational directory only
3. Click **Register**

#### Step 2: Create a Client Secret

1. Go to the app → **Certificates & secrets** → **Client secrets**
2. Click **New client secret**
   - Enter a description (e.g., `Robot Framework Auth`)
   - Select expiry (recommended: 12 months for CI/CD)
   - Click **Add**
3. **Immediately copy the secret Value** — it will not be shown again

#### Step 3: Collect Required Information

| Value | Where to Find | Example |
|-------|--------------|---------|
| **Client ID** | App → Overview → Application (client) ID | `12345678-abcd-efgh-ijkl-123456789012` |
| **Client Secret** | App → Certificates & secrets (copied in Step 2) | `AbCdEfGh~123456789...` |
| **Tenant ID** | App → Overview → Directory (tenant) ID | `abcdefgh-1234-5678-9012-abcdefghijkl` |
| **Token URL** | `https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token` | |
| **Issuer URL** | `https://login.microsoftonline.com/{TENANT_ID}/v2.0` | |
| **JWKS URL** | `https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys` | |

#### Step 4: Configure API Permissions (Optional)

1. Go to App → **API permissions** → **Add a permission**
2. Add any required permissions for your scenario
3. Click **Grant admin consent** if required

#### Step 5: Verify Entra ID Setup

```bash
curl -X POST https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "scope=https://graph.microsoft.com/.default"
```

Expected response:
```json
{
  "token_type": "Bearer",
  "expires_in": 3599,
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOi..."
}
```

#### Step 6: Configure Framework `.env` for Entra ID

```bash
AUTH_METHOD=oauth2
URL=https://elastic.snaplogic.com
OAUTH2_TOKEN_URL=https://login.microsoftonline.com/YOUR_TENANT_ID/oauth2/v2.0/token
OAUTH2_CLIENT_ID=your_entra_client_id
OAUTH2_CLIENT_SECRET=your_entra_client_secret
OAUTH2_SCOPE=https://graph.microsoft.com/.default
ORG_NAME=your-org-name
```

### 13.3 Other Identity Providers

The framework works with any Identity Provider that supports **OAuth2 Client Credentials** flow and issues **JWT tokens**. Common providers:

| Provider | Token URL Format | JWKS URL Format |
|----------|-----------------|-----------------|
| **Ping Identity** | `https://auth.pingone.com/{env_id}/as/token` | `https://auth.pingone.com/{env_id}/as/jwks` |
| **Auth0** | `https://YOUR_DOMAIN/oauth/token` | `https://YOUR_DOMAIN/.well-known/jwks.json` |
| **Google Workspace** | `https://oauth2.googleapis.com/token` | `https://www.googleapis.com/oauth2/v3/certs` |
| **Keycloak** | `https://host/realms/{realm}/protocol/openid-connect/token` | `https://host/realms/{realm}/protocol/openid-connect/certs` |

For any provider, you need:
1. **Client ID** and **Client Secret** from an app registration
2. **Token URL** for getting access tokens
3. **Issuer URL** and **JWKS URL** for SnapLogic to validate tokens

## 14. JWT Claim Mapping

After SnapLogic verifies a token is authentic (using Issuer ID + JWKS URL), it needs to determine **which SnapLogic user** is making the API call. It does this by matching a claim in the JWT token to a user in the SnapLogic org.

### Common Mapping Approaches

| Mapping | How It Works | When It's Used |
|---------|-------------|----------------|
| **Email claim** | Token's `email` field matches a SnapLogic user's email | Most common with Okta |
| **Subject claim** | Token's `sub` field matches a SnapLogic username | Common with Entra ID |
| **Custom claim** | A custom field you define in your IdP matches a SnapLogic username | When email/sub don't match |

### For Robot Framework / CI/CD

The identity in the token must map to a real SnapLogic user with the right permissions (typically org admin or project admin):

| Approach | How It Works |
|----------|-------------|
| **Personal user mapping** | IdP user `user1@company.com` → token carries `email: user1@company.com` → SnapLogic user `user1@company.com` (must be org admin) |
| **Service account (recommended for CI/CD)** | IdP app authenticates as itself → token carries `sub: <client_id>` or mapped claim → SnapLogic user created for this purpose (e.g., `automation-svc@company.com`) |
