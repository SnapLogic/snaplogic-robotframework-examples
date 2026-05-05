# Setting Up JWT and OAuth2 Authentication

This guide walks through the complete end-to-end setup for JWT and OAuth2 authentication in the SnapLogic Robot Framework. Both methods require configuration in **three places**: your Identity Provider, SnapLogic Admin Manager, and the framework's `.env` file.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Understanding the Architecture](#2-understanding-the-architecture)
3. [Action Plan — Who Does What](#3-action-plan--who-does-what)
4. [Part A: Identity Provider Setup](#4-part-a-identity-provider-setup)
   - [Okta Setup](#41-okta-setup)
   - [Microsoft Entra ID (Azure AD) Setup](#42-microsoft-entra-id-azure-ad-setup)
   - [Other Identity Providers](#43-other-identity-providers)
5. [Part B: SnapLogic Admin Manager Configuration](#5-part-b-snaplogic-admin-manager-configuration)
6. [Part C: Framework Configuration (.env)](#6-part-c-framework-configuration-env)
   - [JWT Configuration](#61-jwt-configuration)
   - [OAuth2 Configuration](#62-oauth2-configuration)
7. [Running Tests](#7-running-tests)
8. [Verifying Authentication](#8-verifying-authentication)
9. [Token Lifecycle and Refresh](#9-token-lifecycle-and-refresh)
10. [Troubleshooting](#10-troubleshooting)
11. [Security Best Practices](#11-security-best-practices)
12. [FAQ](#12-faq)

---

## 1. Prerequisites

Before starting, ensure you have:

- [ ] **SnapLogic Org Admin access** — You need admin rights to configure the JWT tab in Admin Manager
- [ ] **Identity Provider (IdP) admin access** — You need to create an application registration in Okta, Entra ID, or your chosen IdP
- [ ] **Robot Framework project set up** — The `snaplogic-common-robot` package (version with multi-auth support) must be installed
- [ ] **Working basic auth tests** — Verify your tests pass with basic auth first before switching

---

## 2. Understanding the Architecture

### How JWT/OAuth2 Authentication Works with SnapLogic

```
┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│                  │         │                  │         │                  │
│  Identity        │  Trust  │  SnapLogic       │  API    │  Robot           │
│  Provider        │◄───────►│  Platform        │◄───────►│  Framework       │
│  (Okta/Entra ID) │         │                  │         │                  │
│                  │         │                  │         │                  │
└──────────────────┘         └──────────────────┘         └──────────────────┘
        │                            │                            │
        │  1. Register App           │  2. Configure JWT tab      │  3. Configure .env
        │     Get Client ID/Secret   │     Add Issuer + JWKS URL  │     Set AUTH_METHOD
        │     Get Issuer URL         │                            │     Add token/credentials
        │     Get JWKS URL           │                            │
        └────────────────────────────┘────────────────────────────┘
```

### The Complete Setup Flow — What Goes Where

Setting up JWT or OAuth2 authentication involves **three places** and **five key pieces of information**. Here's the big picture before you dive into the details:

#### Step 1: Create an App Registration in Your Identity Provider

Register an application in your IdP (Okta, Entra ID, etc.) and collect these **5 items**:

```
┌──────────────────────────────────────────────────────────────┐
│                  IDENTITY PROVIDER (IdP)                     │
│               Okta / Entra ID / Ping / Auth0                 │
│                                                              │
│   Create an App Registration and collect:                    │
│                                                              │
│   ① Client ID ............. e.g. 0oa1b2c3d4e5f6g7h8i9       │
│   ② Client Secret ......... e.g. AbCdEf123456789             │
│   ③ Token URL ............. e.g. https://your-org.okta.com/  │
│                                  oauth2/default/v1/token     │
│   ④ Issuer ID ............. e.g. https://your-org.okta.com/  │
│                                  oauth2/default              │
│   ⑤ JWKS Endpoint URL ..... e.g. https://your-org.okta.com/  │
│                                  oauth2/default/v1/keys      │
│                                                              │
└────────────────┬─────────────────────────┬───────────────────┘
                 │                         │
                 │                         │
        Items ④ and ⑤              Items ①, ②, and ③
        go to SnapLogic            go to your .env file
                 │                         │
                 ▼                         ▼
┌────────────────────────────┐  ┌──────────────────────────────┐
│  SNAPLOGIC ADMIN MANAGER   │  │  YOUR .env FILE              │
│  JWT Tab                   │  │                              │
│                            │  │  # For JWT:                  │
│  Issuer ID ←──── ④         │  │  AUTH_METHOD=jwt             │
│  JWKS URL ←───── ⑤         │  │  BEARER_TOKEN=<from curl> ← │
│                            │  │   (use ①②③ to get token)    │
│  This tells SnapLogic HOW  │  │                              │
│  to VALIDATE tokens from   │  │  # For OAuth2:               │
│  your IdP                  │  │  AUTH_METHOD=oauth2           │
│                            │  │  OAUTH2_TOKEN_URL ←──── ③    │
│                            │  │  OAUTH2_CLIENT_ID ←──── ①    │
│                            │  │  OAUTH2_CLIENT_SECRET ←─ ②   │
│                            │  │  OAUTH2_SCOPE=optional       │
└────────────────────────────┘  └──────────────────────────────┘
```

#### Step 2: Configure SnapLogic JWT Tab (Items ④ and ⑤)

Take the **Issuer ID** and **JWKS Endpoint URL** from your IdP and enter them in the SnapLogic Admin Manager JWT tab. This establishes trust — it tells SnapLogic: *"Tokens from this issuer are legitimate. Here's where to find the public keys to verify their signatures."*

```
SnapLogic Admin Manager → Security → Authentication → JWT tab

┌─────────────────────────────────────────────────────────────┐
│  JWT Configuration                                          │
│                                                             │
│  Issuer ID:          [④ https://your-org.okta.com/          │
│                          oauth2/default                  ]  │
│                                                             │
│  JWKS Endpoint URL:  [⑤ https://your-org.okta.com/          │
│                          oauth2/default/v1/keys          ]  │
│                                                             │
│                                            [ Save ]         │
└─────────────────────────────────────────────────────────────┘
```

> **Why is this needed?** When the Robot Framework sends a JWT token to SnapLogic, SnapLogic needs to verify the token is authentic. It does this by:
> 1. Checking the token's `iss` (issuer) claim matches the Issuer ID you configured
> 2. Fetching the public keys from the JWKS URL to verify the token's digital signature

#### Step 3: Configure Your .env File (Items ①, ②, and ③)

What you put in `.env` depends on whether you choose **JWT** or **OAuth2**:

**For JWT** — You use items ①②③ to manually generate a token via curl, then paste the token:

```
┌─────────────────────────────────────────────────────────────┐
│  # First, generate a token using curl:                      │
│  curl -X POST ③TOKEN_URL \                                  │
│    -d "client_id=①CLIENT_ID" \                              │
│    -d "client_secret=②CLIENT_SECRET" \                      │
│    -d "grant_type=client_credentials"                       │
│                                                             │
│  # Then paste the access_token into .env:                   │
│  AUTH_METHOD=jwt                                            │
│  BEARER_TOKEN=eyJhbGciOiJSUzI1NiIs...  ← the token output  │
└─────────────────────────────────────────────────────────────┘
```

**For OAuth2** — You put items ①②③ directly in `.env` and the framework generates tokens automatically:

```
┌─────────────────────────────────────────────────────────────┐
│  AUTH_METHOD=oauth2                                         │
│  OAUTH2_TOKEN_URL=③ https://your-org.okta.com/.../v1/token  │
│  OAUTH2_CLIENT_ID=① 0oa1b2c3d4e5f6g7h8i9                   │
│  OAUTH2_CLIENT_SECRET=② AbCdEf123456789                     │
│  OAUTH2_SCOPE=optional_scope                                │
│                                                             │
│  → Framework automatically calls ③ with ①+② to get tokens  │
│  → Auto-refreshes before expiry — fully hands-off!          │
└─────────────────────────────────────────────────────────────┘
```

#### Summary: What Goes Where

| Item | From IdP | Goes To | Used By |
|------|----------|---------|---------|
| ① **Client ID** | App Registration → General | `.env` (`OAUTH2_CLIENT_ID`) or curl command | OAuth2 auto-fetch / JWT manual token generation |
| ② **Client Secret** | App Registration → Credentials | `.env` (`OAUTH2_CLIENT_SECRET`) or curl command | OAuth2 auto-fetch / JWT manual token generation |
| ③ **Token URL** | Authorization Server → Token endpoint | `.env` (`OAUTH2_TOKEN_URL`) or curl command | OAuth2 auto-fetch / JWT manual token generation |
| ④ **Issuer ID** | Authorization Server → Issuer URI | SnapLogic JWT tab → Issuer ID | SnapLogic validates token's `iss` claim |
| ⑤ **JWKS URL** | Authorization Server → Keys endpoint | SnapLogic JWT tab → JWKS Endpoint URL | SnapLogic fetches public keys to verify token signature |

> **Key Takeaway:** Items ④ and ⑤ always go to SnapLogic (they're about *validating* tokens). Items ①, ②, and ③ always go to `.env` or curl (they're about *getting* tokens). The split is logical: SnapLogic needs to know *who to trust*, while the framework needs to know *how to authenticate*.

---

### JWT vs OAuth2 — Which to Choose?

#### But Wait — Don't Both Need the Same Setup?

**Yes!** The IdP setup and SnapLogic JWT tab configuration are **identical for both methods**:

```
WHAT'S THE SAME FOR BOTH:
══════════════════════════════════════════════════
✅ Create app in IdP (Okta/Entra)         — SAME
✅ Get Client ID, Secret, Token URL       — SAME
✅ Configure SnapLogic JWT tab (④⑤)       — SAME
✅ SnapLogic validates token the same way  — SAME

WHAT'S DIFFERENT — Only ONE thing:
══════════════════════════════════════════════════
WHO fetches the token from the IdP?
```

The **only difference** is who fetches the token and when:

```
JWT Method (YOU fetch the token manually):
──────────────────────────────────────────

  YOU (manually)          Robot Framework         SnapLogic
      │                        │                      │
      │  1. Run curl           │                      │
      │  2. Copy token         │                      │
      │  3. Paste in .env      │                      │
      │                        │                      │
      │       BEARER_TOKEN=eyJ...                     │
      │ ─────────────────────► │                      │
      │                        │  Uses that token     │
      │                        │ ──────────────────►  │
      │                        │                      │
      │    ⏰ 1 hour later...  │                      │
      │    Token EXPIRES!      │                      │
      │                        │  401 Unauthorized ❌ │
      │                        │ ◄──────────────────  │
      │                        │                      │
      │  YOU must run curl     │                      │
      │  again, paste new      │                      │
      │  token, restart tests  │                      │


OAuth2 Method (FRAMEWORK fetches the token automatically):
──────────────────────────────────────────────────────────

  YOU (one-time setup)    Robot Framework         SnapLogic
      │                        │                      │
      │  Put credentials       │                      │
      │  in .env (once):       │                      │
      │  OAUTH2_TOKEN_URL=③    │                      │
      │  OAUTH2_CLIENT_ID=①    │                      │
      │  OAUTH2_CLIENT_SECRET=②│                      │
      │ ─────────────────────► │                      │
      │                        │                      │
      │  Done! Go have coffee  │                      │
      │                        │  1. Auto-calls IdP   │
      │                        │     with ①②③         │
      │                        │  2. Gets token       │
      │                        │  3. Uses token       │
      │                        │ ──────────────────►  │
      │                        │                      │
      │                        │  ⏰ 59 min later...  │
      │                        │  Auto-fetches NEW    │
      │                        │  token (you do       │
      │                        │  NOTHING)            │
      │                        │ ──────────────────►  │
      │                        │                      │
      │                        │  Tests keep running  │
      │                        │  forever ✅          │
```

#### Quick Comparison

| Consideration | JWT | OAuth2 |
|--------------|-----|--------|
| **Token generation** | Manual (you generate it before running tests) | Automatic (framework fetches it at runtime) |
| **Token refresh** | Manual (generate a new token if expired) | Automatic (framework refreshes when expired) |
| **CI/CD friendly** | Requires token generation step in pipeline | Fully automated — just set credentials |
| **Setup complexity** | Simpler (1 env var: `BEARER_TOKEN`) | Slightly more (3 env vars: TOKEN_URL, CLIENT_ID, CLIENT_SECRET) |
| **Best for** | Quick manual testing, short test runs | CI/CD pipelines, long-running test suites |

#### Real-World Impact

| Scenario | JWT | OAuth2 |
|----------|-----|--------|
| **Quick manual test** (10 min) | Fine — token won't expire | Also fine, but more env vars to set |
| **Long test suite** (2+ hours) | Tests FAIL after 1 hour when token expires | Tests keep running — auto-refreshes |
| **CI/CD pipeline** | Need a "generate token" step. If pipeline takes >1hr, it breaks | Just set env vars. Fully automated, never breaks |
| **Multiple runs per day** | Generate new token EVERY time | Set once, never touch again |
| **Weekend/overnight runs** | Impossible without manual intervention | Works unattended |

#### Why Does JWT Method Even Exist?

It's simpler for **quick one-off testing**:

```
JWT:    1 env var   → BEARER_TOKEN=eyJ...       (fast to set up, manual refresh)
OAuth2: 3 env vars  → TOKEN_URL, CLIENT_ID,     (slightly more setup, fully automatic)
                      CLIENT_SECRET
```

If you're just verifying that the JWT tab is configured correctly or doing a quick 10-minute test, JWT is faster — run curl, paste token, run test, done.

> **Recommendation:** Use **OAuth2** for CI/CD and automated workflows. Use **JWT** for quick manual testing or initial verification. Both require the same IdP and SnapLogic setup — the only difference is who fetches the token.

---

## 3. Action Plan — Who Does What

Before diving into the detailed steps, here's a practical overview of what needs to happen, who needs to do it, and in what order.

### People Involved

You may need to coordinate with up to three teams depending on your access level:

| Person/Team | What They Do | Why |
|-------------|-------------|-----|
| **IdP Admin** (Okta/Entra ID admin) | Creates the app registration, provides ①②③④⑤ | Only IdP admins can create applications |
| **SnapLogic Org Admin** | Configures the JWT tab (④⑤), ensures user mapping works | Only org admins can access Admin Manager → JWT tab |
| **You** (Test Engineer) | Configures `.env` (①②③), verifies with curl, runs tests | You own the Robot Framework setup |

> **If you have all three roles** (IdP admin + SnapLogic admin + test engineer), you can do everything yourself. Otherwise, coordinate with the relevant teams.

### Step-by-Step Action Plan

```
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: Get App Registration from IdP                         │
│  WHO: IdP Admin (or you if you have Okta/Entra admin access)   │
│                                                                 │
│  Action: Create an "API Services" app in your IdP               │
│  Collect these 5 items:                                         │
│    ① Client ID                                                  │
│    ② Client Secret                                              │
│    ③ Token URL                                                  │
│    ④ Issuer ID                                                  │
│    ⑤ JWKS Endpoint URL                                          │
│                                                                 │
│  If someone else does this, send them this message:             │
│  "I need an app registration in Okta/Entra ID for              │
│   machine-to-machine API access (OAuth2 Client Credentials).    │
│   Please provide: Client ID, Client Secret, Token URL,          │
│   Issuer ID, and JWKS Endpoint URL."                            │
│                                                                 │
│  See: Part A (Section 4) for detailed IdP-specific steps        │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 2: Configure SnapLogic JWT Tab                           │
│  WHO: SnapLogic Org Admin (or you if you have admin access)    │
│                                                                 │
│  Action: Go to Admin Manager → Security → Authentication → JWT  │
│  Enter:                                                         │
│    ④ Issuer ID         → "Issuer ID" field                      │
│    ⑤ JWKS Endpoint URL → "JWKS Endpoint URL" field              │
│  Click Save.                                                    │
│                                                                 │
│  IMPORTANT: Do NOT disable basic auth. Keep both enabled.       │
│                                                                 │
│  If someone else does this, send them this message:             │
│  "Please add a JWT configuration in SnapLogic Admin Manager:    │
│   Issuer ID: [④ value]                                          │
│   JWKS Endpoint URL: [⑤ value]"                                 │
│                                                                 │
│  See: Part B (Section 5) for detailed steps                     │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 3: Ensure SnapLogic User Exists                          │
│  WHO: SnapLogic Org Admin                                       │
│                                                                 │
│  The token from your IdP carries an identity (email/username).  │
│  That same identity must exist as a SnapLogic user with admin   │
│  permissions.                                                   │
│                                                                 │
│  Example:                                                       │
│    Your IdP email: user1@company.com                            │
│    SnapLogic must have: user1@company.com as a user             │
│    with org admin or project admin role                         │
│                                                                 │
│  If you already use SnapLogic with the same email → already     │
│  done, nothing to do.                                           │
│                                                                 │
│  See: Part B Step 5 (Section 5) for claim mapping details       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 4: Verify with curl (Before Touching Robot Framework)    │
│  WHO: You                                                       │
│                                                                 │
│  4a. Get a token from your IdP:                                 │
│    curl -X POST ③TOKEN_URL \                                    │
│      -H "Content-Type: application/x-www-form-urlencoded" \     │
│      -d "grant_type=client_credentials" \                       │
│      -d "client_id=①CLIENT_ID" \                                │
│      -d "client_secret=②CLIENT_SECRET"                          │
│                                                                 │
│    ✅ Should return: {"access_token": "eyJhbG...", ...}         │
│    ❌ If error → Step 1 is wrong (check credentials)            │
│                                                                 │
│  4b. Test that token against SnapLogic:                         │
│    curl -H "Authorization: Bearer eyJhbG..." \                  │
│      "https://your-instance.snaplogic.com/api/1/rest/asset/     │
│       session?caller=test"                                      │
│                                                                 │
│    ✅ 200 response → Steps 1-3 are correct, proceed!            │
│    ❌ 401 response → Step 2 or 3 is wrong (JWT tab or user      │
│       mapping)                                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 5: Configure .env                                        │
│  WHO: You                                                       │
│                                                                 │
│  For OAuth2 (recommended):                                      │
│    AUTH_METHOD=oauth2                                            │
│    OAUTH2_TOKEN_URL=③                                           │
│    OAUTH2_CLIENT_ID=①                                           │
│    OAUTH2_CLIENT_SECRET=②                                       │
│    OAUTH2_SCOPE=your_scope (or leave empty)                     │
│                                                                 │
│  For JWT:                                                       │
│    AUTH_METHOD=jwt                                               │
│    BEARER_TOKEN=<token from Step 4a>                             │
│                                                                 │
│  See: Part C (Section 6) for details                            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 6: Run Tests                                             │
│  WHO: You                                                       │
│                                                                 │
│  make robot-run-tests TAGS="oracle"                              │
│                                                                 │
│  Look for in console output:                                    │
│    "Authentication method: oauth2" (or jwt)                     │
│                                                                 │
│  All tests should pass exactly as they did with basic auth.     │
│  The framework handles token fetching/refreshing automatically. │
└─────────────────────────────────────────────────────────────────┘
```

### Quick Summary

| Step | Who | Action | Time |
|------|-----|--------|------|
| 1 | IdP Admin | Create app, provide ①②③④⑤ | 15-30 min |
| 2 | SnapLogic Admin | Enter ④⑤ in JWT tab | 5 min |
| 3 | SnapLogic Admin | Verify user exists with matching email | 5 min |
| 4 | You | Test with curl to verify Steps 1-3 | 10 min |
| 5 | You | Add ①②③ to `.env` | 5 min |
| 6 | You | Run `make robot-run-tests` | 5 min |

> **Total estimated time:** ~45 minutes if you have all the access, or ~1-2 days if you need to coordinate with other teams.

---

## 4. Part A: Identity Provider Setup

### 4.1 Okta Setup

#### Step 1: Create an Application in Okta

1. Log in to your **Okta Admin Console** (`https://your-org-admin.okta.com`)
2. Navigate to **Applications** → **Applications**
3. Click **Create App Integration**
4. Select:
   - **Sign-in method:** OIDC - OpenID Connect
   - **Application type:** API Services (for machine-to-machine / client credentials)
5. Click **Next**
6. Enter a name (e.g., `SnapLogic Robot Framework`)
7. Click **Save**

#### Step 2: Collect Required Information

After creating the app, note down these values:

| Value | Where to Find | Example |
|-------|--------------|---------|
| **Client ID** | Application → General tab → Client Credentials | `0oa1b2c3d4e5f6g7h8i9` |
| **Client Secret** | Application → General tab → Client Credentials | `AbCdEf123456789...` |
| **Issuer URL** | Security → API → Authorization Servers → default → Issuer URI | `https://your-org.okta.com/oauth2/default` |
| **Token URL** | Issuer URL + `/v1/token` | `https://your-org.okta.com/oauth2/default/v1/token` |
| **JWKS URL** | Issuer URL + `/v1/keys` | `https://your-org.okta.com/oauth2/default/v1/keys` |

#### Step 3: Configure Scopes (Optional)

1. Go to **Security** → **API** → **Authorization Servers** → **default**
2. Click **Scopes** tab → **Add Scope**
3. Add a scope name (e.g., `snaplogic.api`) — this is optional but can be used for access control
4. If you skip this, leave `OAUTH2_SCOPE` empty in your `.env`

#### Step 4: Assign the Application

When you create an app in Okta, it doesn't automatically allow anyone to use it. You need to **assign** which users or groups can authenticate through the application.

**What are "Users" and "Groups"?**
- **Users** = Individual people with Okta accounts (e.g., `user1@company.com`, `user2@company.com`)
- **Groups** = Collections of users managed by your Okta admin (e.g., "QA Engineers", "DevOps Team")

```
┌─────────────────────────────────────────────────────────┐
│  App: "SnapLogic Robot Framework"                       │
│  ┌───────────────────────────────────────────────┐      │
│  │  Who can use this app?                        │      │
│  │                                               │      │
│  │  ✅ User: user1@company.com      ← Assigned  │      │
│  │  ✅ User: user2@company.com      ← Assigned  │      │
│  │  ✅ Group: "QA Engineers"        ← All members│      │
│  │  ❌ User: other@company.com     ← NOT assigned│      │
│  └───────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

**For Robot Framework / CI/CD, you have two approaches:**

| Approach | How | Best For |
|----------|-----|----------|
| **Service Account** | Create a dedicated user (e.g., `snaplogic-automation@company.com`), assign it to the app. This user must also exist in SnapLogic. | CI/CD pipelines, shared automation |
| **Group Assignment** | Assign an existing group (e.g., "QA Engineers") to the app. All group members can authenticate. | Multiple team members running tests |

**Steps:**

1. Go to your application → **Assignments** tab
2. Click **Assign** → **Assign to People** or **Assign to Groups**
3. Select the user(s) or group(s) who need API access
4. Click **Done**

> **Note for API Services apps:** If you created the app as "API Services" type (machine-to-machine), Okta may handle this differently — the app authenticates as itself rather than on behalf of a specific user. In this case, assignment may not be required. If your tests fail with a user-mapping error after completing all other steps, come back to this step and assign the appropriate service account.

#### Step 5: Verify Okta Setup

Test that your Okta app can issue tokens:

```bash
curl -X POST https://your-org.okta.com/oauth2/default/v1/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  -d "scope=YOUR_SCOPE"
```

Expected response:
```json
{
  "token_type": "Bearer",
  "expires_in": 3600,
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6..."
}
```

If you get this response, your Okta setup is correct. Save the `access_token` — you can use it to test JWT auth.

---

### 4.2 Microsoft Entra ID (Azure AD) Setup

#### Step 1: Register an Application

1. Go to **Azure Portal** → **Microsoft Entra ID** → **App registrations**
2. Click **New registration**
3. Enter:
   - **Name:** `SnapLogic Robot Framework`
   - **Supported account types:** Accounts in this organizational directory only
4. Click **Register**

#### Step 2: Create a Client Secret

1. Go to the app → **Certificates & secrets** → **Client secrets**
2. Click **New client secret**
3. Enter a description (e.g., `Robot Framework Auth`)
4. Select expiry (recommended: 12 months for CI/CD)
5. Click **Add**
6. **Immediately copy the secret Value** — it will not be shown again

#### Step 3: Collect Required Information

| Value | Where to Find | Example |
|-------|--------------|---------|
| **Client ID** | App → Overview → Application (client) ID | `12345678-abcd-efgh-ijkl-123456789012` |
| **Client Secret** | App → Certificates & secrets (copied in Step 2) | `AbCdEfGh~123456789...` |
| **Tenant ID** | App → Overview → Directory (tenant) ID | `abcdefgh-1234-5678-9012-abcdefghijkl` |
| **Issuer URL** | `https://login.microsoftonline.com/{TENANT_ID}/v2.0` | `https://login.microsoftonline.com/abcdefgh-.../v2.0` |
| **Token URL** | `https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token` | `https://login.microsoftonline.com/abcdefgh-.../oauth2/v2.0/token` |
| **JWKS URL** | `https://login.microsoftonline.com/{TENANT_ID}/discovery/v2.0/keys` | `https://login.microsoftonline.com/abcdefgh-.../discovery/v2.0/keys` |

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

---

### 4.3 Other Identity Providers

The framework works with any Identity Provider that supports **OAuth2 Client Credentials** flow and issues **JWT tokens**. Common providers include:

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

---

## 5. Part B: SnapLogic Admin Manager Configuration

This step tells SnapLogic to trust tokens issued by your Identity Provider.

### Step 1: Navigate to JWT Tab

1. Log in to your SnapLogic instance
2. Go to **Admin Manager** (gear icon in top-right)
3. Click **Security** → **Authentication**
4. Click the **JWT** tab

### Step 2: Add JWT Configuration

Enter the following values from your Identity Provider:

| Field | Description | Example (Okta) | Example (Entra ID) |
|-------|-------------|----------------|---------------------|
| **Issuer ID** | The `iss` claim in the JWT token | `https://your-org.okta.com/oauth2/default` | `https://login.microsoftonline.com/{tenant_id}/v2.0` |
| **JWKS Endpoint URL** | URL where SnapLogic fetches public keys to verify token signatures | `https://your-org.okta.com/oauth2/default/v1/keys` | `https://login.microsoftonline.com/{tenant_id}/discovery/v2.0/keys` |

### Step 3: Save Configuration

1. Click **Save**
2. You should see a success message

### Step 4: Verify — Do NOT Disable Basic Auth Yet

- Leave **"Disable basic authentication"** unchecked
- This allows both basic auth and JWT auth to work simultaneously
- Only disable basic auth after you've verified JWT/OAuth2 works

### Step 5: Map JWT Claims to SnapLogic User (If Required)

After SnapLogic verifies a token is *authentic* (using Issuer ID + JWKS URL), it needs to answer a second question: **"Which SnapLogic user is making this API call?"**

#### What Are JWT Claims?

A JWT token is a JSON payload containing **claims** — key-value pairs that carry identity information. Here's what a decoded token looks like:

```
┌──────────────────────────────────────────────────────────────┐
│  JWT TOKEN (decoded payload)                                 │
│                                                              │
│  {                                                           │
│    "iss": "https://your-org.okta.com/oauth2/default",  ← Issuer           │
│    "sub": "user1@company.com",                         ← Subject claim    │
│    "email": "user1@company.com",                       ← Email claim      │
│    "name": "User One",                                 ← Name claim       │
│    "groups": ["QA Engineers"],                         ← Groups claim     │
│    "exp": 1709123456,                                  ← Expiry time      │
│    "iat": 1709119856,                                  ← Issued at        │
│    "aud": "0oa1b2c3d4e5f6g7h8i9"                      ← Audience         │
│  }                                                           │
└──────────────────────────────────────────────────────────────┘
```

#### How Claim Mapping Works

SnapLogic takes ONE claim from the token and matches it to a user in the SnapLogic org:

```
┌───────────────────────┐            ┌──────────────────────────┐
│  JWT TOKEN             │            │  SNAPLOGIC ORG USERS     │
│                        │            │                          │
│  "sub": "user1@..."    │──match────►│  user1@company.com  ✅   │
│         OR             │            │  user2@company.com       │
│  "email": "user1@..."  │──match────►│  admin@company.com       │
│                        │            │                          │
│  If NO user matches    │─────X─────►│  401 Unauthorized  ❌    │
│  the claim value       │            │                          │
└───────────────────────┘            └──────────────────────────┘
```

#### The Three Common Mapping Approaches

| Mapping | How It Works | When It's Used |
|---------|-------------|----------------|
| **Email claim** | Token's `email` field matches a SnapLogic user's email address | Most common with Okta. Users have the same email in both Okta and SnapLogic. |
| **Subject claim** | Token's `sub` field matches a SnapLogic username | Common with Entra ID. The `sub` is often a unique identifier or username. |
| **Custom claim** | A custom field you define in your IdP (e.g., `snaplogic_user`) matches a SnapLogic username | Used when email/sub don't match SnapLogic usernames. You create a custom claim in your IdP. |

#### Example: How Users Must Match

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  In Your IdP (Okta):              In SnapLogic:              │
│  ───────────────────              ─────────────              │
│  user1@company.com         →      user1@company.com  ✅      │
│  user2@company.com         →      user2@company.com  ✅      │
│  contractor@external.com   →      ???                ❌      │
│                                   (no matching user)         │
│                                                              │
│  The contractor's token will be REJECTED because there's     │
│  no SnapLogic user with that email/username.                 │
│                                                              │
│  Fix: Create a SnapLogic user with matching email,           │
│       OR use a service account for automation.               │
└──────────────────────────────────────────────────────────────┘
```

#### For Robot Framework / CI/CD

The identity in the token must map to a real SnapLogic user who has the right permissions (typically org admin or project admin):

| Approach | How It Works |
|----------|-------------|
| **Personal user mapping** | IdP user `user1@company.com` → token carries `email: user1@company.com` → SnapLogic user `user1@company.com` (must be org admin) |
| **Service account (recommended for CI/CD)** | IdP app authenticates as itself → token carries `sub: <client_id>` or mapped claim → SnapLogic user created for this purpose (e.g., `automation-svc@company.com`) |

#### What Do You Need To Do?

In most cases, **nothing** — if your IdP users already have matching email addresses in SnapLogic, it works automatically. You only need to take action if:

1. **Token gets 401 after JWT tab is configured** → The claim-to-user mapping isn't working
2. **Using a service account for CI/CD** → Create a SnapLogic user that matches the service account's identity
3. **Email addresses don't match between IdP and SnapLogic** → Create matching users or set up a custom claim in your IdP

> **Tip:** Ask your SnapLogic admin: *"How are JWT users mapped in our org — by email or by subject?"* If you use the same email in both your IdP and SnapLogic, it likely works automatically with no extra configuration.

### Verification

After configuring the JWT tab, verify it works by making a direct API call:

```bash
# First get a token from your IdP (using the curl command from Part A)
TOKEN="eyJhbGciOi..."

# Test against SnapLogic API
curl -H "Authorization: Bearer ${TOKEN}" \
  "https://elastic.snaplogic.com/api/1/rest/asset/session?caller=test"
```

If you get a 200 response, the JWT tab is configured correctly.

---

## 6. Part C: Framework Configuration (.env)

### 6.1 JWT Configuration

For JWT, you provide a pre-generated token in the `.env` file.

#### Step 1: Generate a Token

Use the curl command from Part A to get a token from your IdP:

```bash
# Okta example
curl -s -X POST https://your-org.okta.com/oauth2/default/v1/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])"
```

This prints just the token string.

#### Step 2: Configure .env

```bash
# Authentication
AUTH_METHOD=jwt
BEARER_TOKEN=eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL3lvdXItb3JnLm9rdGEuY29tL29hdXRoMi9kZWZhdWx0IiwiZXhwIjoxNzA5MTIzNDU2fQ.signature_here

# SnapLogic Connection (still required)
URL=https://elastic.snaplogic.com
ORG_NAME=your_org_name
PROJECT_SPACE=your_project_space
PROJECT_NAME=your_project_name
GROUNDPLEX_NAME=your_groundplex_name

# NOTE: ORG_ADMIN_USER and ORG_ADMIN_PASSWORD are NOT needed for JWT
```

#### Important Notes for JWT
- Tokens typically expire in **1 hour** (3600 seconds)
- You must generate a **new token before each test run** if the previous one expired
- The token is a long string starting with `eyJ...`
- Do not include quotes around the token value in `.env`

---

### 6.2 OAuth2 Configuration

For OAuth2, the framework automatically fetches and refreshes tokens — no manual token generation needed.

#### Configure .env

```bash
# Authentication
AUTH_METHOD=oauth2
OAUTH2_TOKEN_URL=https://your-org.okta.com/oauth2/default/v1/token
OAUTH2_CLIENT_ID=0oa1b2c3d4e5f6g7h8i9
OAUTH2_CLIENT_SECRET=AbCdEf123456789
OAUTH2_SCOPE=snaplogic.api

# SnapLogic Connection (still required)
URL=https://elastic.snaplogic.com
ORG_NAME=your_org_name
PROJECT_SPACE=your_project_space
PROJECT_NAME=your_project_name
GROUNDPLEX_NAME=your_groundplex_name

# NOTE: ORG_ADMIN_USER and ORG_ADMIN_PASSWORD are NOT needed for OAuth2
```

#### OAuth2 Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `AUTH_METHOD` | Yes | Must be `oauth2` |
| `OAUTH2_TOKEN_URL` | Yes | Your IdP's token endpoint URL |
| `OAUTH2_CLIENT_ID` | Yes | Application/Client ID from your IdP app registration |
| `OAUTH2_CLIENT_SECRET` | Yes | Client secret from your IdP app registration |
| `OAUTH2_SCOPE` | No | Optional scope(s) for the token request. Leave empty if not needed |

---

## 7. Running Tests

Once configured, run tests exactly the same way — the authentication method is transparent:

```bash
# Run oracle tests
make robot-run-tests TAGS="oracle"

# Run all tests with Groundplex management
make robot-run-all-tests TAGS="oracle"

# Run multiple test tags
make robot-run-tests TAGS="oracle,postgres"
```

No changes to test files, make commands, or test scripts are needed.

---

## 8. Verifying Authentication

### Check the Console Output

When tests start, look for these log messages:

**JWT:**
```
AUTH_METHOD explicitly set to: jwt
Authentication method: jwt
```

**OAuth2:**
```
AUTH_METHOD explicitly set to: oauth2
Authentication method: oauth2
```

### If Auto-Detection is Used

If you don't set `AUTH_METHOD` explicitly:

```
Auto-detected AUTH_METHOD=jwt (BEARER_TOKEN is set)
```
or
```
Auto-detected AUTH_METHOD=oauth2 (OAUTH2_TOKEN_URL is set)
```

### All Tests Should Pass

If authentication is working, all your existing tests should pass without any changes. The auth method only affects how the API session is created — all 30+ API keywords work the same regardless of auth method.

---

## 9. Token Lifecycle and Refresh

### JWT Token Lifecycle

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ You generate │     │ Token used  │     │ Token       │
│ token from   │────►│ for all API │────►│ expires     │
│ IdP (manual) │     │ calls       │     │ (tests fail)│
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                        Generate new
                                        token manually
```

- **Token lifetime:** Typically 1 hour (3600 seconds), set by your IdP
- **No auto-refresh:** If the token expires mid-test, subsequent API calls will fail with 401
- **Workaround:** For long test runs, increase the token lifetime in your IdP settings

### OAuth2 Token Lifecycle

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Framework    │     │ Token used  │     │ Token near  │     │ Framework   │
│ fetches      │────►│ for all API │────►│ expiry      │────►│ auto-fetches│
│ token (auto) │     │ calls       │     │ (60s buffer)│     │ new token   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                    │
                                                                    ▼
                                                              Continue tests
                                                              seamlessly
```

- **Token lifetime:** Set by your IdP (typically 3600 seconds)
- **Auto-refresh:** The framework checks token expiry before each session refresh
- **Refresh buffer:** Token is refreshed 60 seconds before actual expiry to prevent edge-case failures
- **Token caching:** Token is cached in memory — only one HTTP call to your IdP per token lifetime

### Using `Refresh Session If Needed`

For long-running test suites with OAuth2, the framework includes a `Refresh Session If Needed` keyword. This is a no-op for basic, jwt, and sltoken — it only refreshes the session for OAuth2 when the token is about to expire.

You can call this in your test setup if you have very long test suites:

```robot
*** Test Cases ***
Long Running Test
    Refresh Session If Needed    # Auto-refreshes OAuth2 token if expired
    # ... your test steps ...
```

---

## 10. Troubleshooting

### Common Errors and Solutions

#### Error: `401 Unauthorized` on first API call

**Possible causes:**

| Cause | How to Check | Fix |
|-------|-------------|-----|
| JWT tab not configured | Check Admin Manager → JWT tab | Add Issuer ID + JWKS URL |
| Wrong Issuer ID | Compare IdP issuer with JWT tab value | Must match exactly |
| Wrong JWKS URL | Try opening the JWKS URL in a browser | Should return a JSON with `keys` array |
| Token expired | Decode token at jwt.io — check `exp` claim | Generate a new token |
| User not mapped | Token's email/sub doesn't match a SnapLogic user | Create user or fix claim mapping |
| Wrong token URL (OAuth2) | Check if token URL returns tokens | Test with curl first |
| Invalid client credentials | IdP returns 401 on token request | Verify client_id and client_secret |

#### Error: `Missing required environment variables: BEARER_TOKEN`

```
Cause: AUTH_METHOD=jwt but BEARER_TOKEN is not set in .env
Fix:   Add BEARER_TOKEN=your_token to .env
```

#### Error: `Missing required environment variables: OAUTH2_TOKEN_URL, OAUTH2_CLIENT_ID`

```
Cause: AUTH_METHOD=oauth2 but OAuth2 credentials are missing from .env
Fix:   Add OAUTH2_TOKEN_URL, OAUTH2_CLIENT_ID, OAUTH2_CLIENT_SECRET to .env
```

#### Error: `OAuth2 token request failed: HTTP 401`

```
Cause: Invalid client credentials
Fix:   1. Verify OAUTH2_CLIENT_ID and OAUTH2_CLIENT_SECRET are correct
       2. Check if the client secret has expired in your IdP
       3. Test with curl:
          curl -X POST YOUR_TOKEN_URL \
            -d "grant_type=client_credentials" \
            -d "client_id=YOUR_ID" \
            -d "client_secret=YOUR_SECRET"
```

#### Error: `OAuth2 token request failed: HTTP 400`

```
Cause: Invalid scope or grant type not enabled
Fix:   1. Check if the scope exists in your IdP
       2. Verify "client_credentials" grant type is enabled for your app
       3. Try removing OAUTH2_SCOPE from .env (leave it empty)
```

#### Error: Tests pass initially but fail midway

```
Cause: JWT token expired during test run
Fix:   Option A: Switch to OAuth2 (auto-refreshes tokens)
       Option B: Increase token lifetime in your IdP settings
       Option C: Generate a fresh token right before running tests
```

### Debugging Steps

#### Step 1: Verify IdP is Working

```bash
# Test token generation from IdP
curl -v -X POST YOUR_TOKEN_URL \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET"
```

Look for:
- HTTP 200 response
- `access_token` in the response body
- `expires_in` value (should be > 0)

#### Step 2: Verify Token Works with SnapLogic

```bash
TOKEN="the_access_token_from_step_1"

curl -v -H "Authorization: Bearer ${TOKEN}" \
  "https://elastic.snaplogic.com/api/1/rest/asset/session?caller=test"
```

Look for:
- HTTP 200 response (token is accepted)
- If HTTP 401: JWT tab configuration is wrong or user mapping is missing

#### Step 3: Verify JWKS URL

```bash
curl YOUR_JWKS_URL
```

Should return:
```json
{
  "keys": [
    {
      "kty": "RSA",
      "kid": "...",
      "n": "...",
      "e": "AQAB"
    }
  ]
}
```

#### Step 4: Decode the Token

Go to [jwt.io](https://jwt.io) and paste your token to inspect:
- **`iss`** — Must match the Issuer ID in SnapLogic JWT tab
- **`exp`** — Expiration time (Unix timestamp). Must be in the future
- **`sub`** or **`email`** — Must map to a valid SnapLogic user

---

## 11. Security Best Practices

### Protecting Credentials

| Practice | Why |
|----------|-----|
| Never commit `.env` to version control | Contains secrets (client_secret, tokens) |
| Add `.env` to `.gitignore` | Prevents accidental commits |
| Use CI/CD environment variables | Inject secrets at runtime, not in files |
| Rotate client secrets periodically | Limits exposure if compromised |
| Use short token lifetimes | Reduces window of attack if token is intercepted |

### CI/CD Configuration

For CI/CD pipelines (Travis CI, GitHub Actions, Jenkins), set credentials as environment variables:

**Travis CI (.travis.yml):**
```yaml
env:
  global:
    - AUTH_METHOD=oauth2
    # Set these as encrypted variables in Travis CI settings:
    # OAUTH2_TOKEN_URL, OAUTH2_CLIENT_ID, OAUTH2_CLIENT_SECRET
```

**GitHub Actions:**
```yaml
env:
  AUTH_METHOD: oauth2
  OAUTH2_TOKEN_URL: ${{ secrets.OAUTH2_TOKEN_URL }}
  OAUTH2_CLIENT_ID: ${{ secrets.OAUTH2_CLIENT_ID }}
  OAUTH2_CLIENT_SECRET: ${{ secrets.OAUTH2_CLIENT_SECRET }}
```

### Principle of Least Privilege

- Create a **dedicated IdP application** for the Robot Framework (don't reuse a personal account's app)
- Grant only the **minimum permissions** needed for test execution
- Use a **dedicated SnapLogic user** for API automation (not a personal admin account)
- Consider separate apps for different environments (dev, staging, production)

---

## 12. FAQ

### Q: Can I use JWT and OAuth2 at the same time?
**No.** You can only use one auth method per test run. Set `AUTH_METHOD` to either `jwt` or `oauth2`.

### Q: Do I need to change my test files?
**No.** The auth method only affects how the API session is created. All existing test files work without any changes.

### Q: What if my IdP is not Okta or Entra ID?
Any IdP that supports OAuth2 Client Credentials flow and issues JWT tokens will work. You just need the token URL, JWKS URL, and client credentials.

### Q: Can I switch between auth methods easily?
**Yes.** Just change `AUTH_METHOD` in your `.env` file. No code changes needed.

### Q: What happens if I don't set AUTH_METHOD?
The framework auto-detects:
- If `OAUTH2_TOKEN_URL` is set → uses `oauth2`
- If `BEARER_TOKEN` is set → uses `jwt`
- Otherwise → uses `basic`

### Q: How long do tokens last?
This depends on your IdP configuration. Typical defaults:
- **Okta:** 3600 seconds (1 hour)
- **Entra ID:** 3599 seconds (~1 hour)
- You can change this in your IdP's authorization server settings.

### Q: What if my tests take longer than the token lifetime?
- **JWT:** Tests will fail when the token expires. Generate a token with a longer lifetime, or switch to OAuth2.
- **OAuth2:** The framework auto-refreshes the token 60 seconds before expiry. No action needed.

### Q: Do I need to disable basic auth in SnapLogic?
**No, and we recommend keeping it enabled** during the transition period. This allows you to fall back to basic auth if JWT/OAuth2 has issues. Only disable basic auth after you've fully validated the new auth method.

### Q: Can multiple teams use different auth methods?
**Yes.** Each team can have their own `.env` file with a different `AUTH_METHOD`. The framework handles everything based on the `.env` configuration.

### Q: Where do I get help if something doesn't work?
1. Check the [Troubleshooting](#10-troubleshooting) section above
2. Decode your JWT token at [jwt.io](https://jwt.io) to inspect claims
3. Test with curl to isolate whether the issue is IdP, SnapLogic, or framework
4. Check SnapLogic Admin Manager → JWT tab configuration
5. Contact your IdP admin if token generation fails

---

## Quick Reference Card

### JWT Setup Checklist

```
[ ] 1. IdP: Create application, get Client ID + Secret
[ ] 2. IdP: Note Issuer URL and JWKS URL
[ ] 3. SnapLogic: Admin Manager → JWT tab → Add Issuer ID + JWKS URL → Save
[ ] 4. Test: curl to get token from IdP
[ ] 5. Test: curl to verify token works with SnapLogic API
[ ] 6. .env: Set AUTH_METHOD=jwt and BEARER_TOKEN=<token>
[ ] 7. Run: make robot-run-tests TAGS="oracle"
[ ] 8. Verify: Console shows "Authentication method: jwt"
```

### OAuth2 Setup Checklist

```
[ ] 1. IdP: Create application, get Client ID + Secret + Token URL
[ ] 2. IdP: Note Issuer URL and JWKS URL
[ ] 3. SnapLogic: Admin Manager → JWT tab → Add Issuer ID + JWKS URL → Save
[ ] 4. Test: curl to get token from IdP (verifies credentials)
[ ] 5. Test: curl to verify token works with SnapLogic API
[ ] 6. .env: Set AUTH_METHOD=oauth2, OAUTH2_TOKEN_URL, OAUTH2_CLIENT_ID, OAUTH2_CLIENT_SECRET
[ ] 7. Run: make robot-run-tests TAGS="oracle"
[ ] 8. Verify: Console shows "Authentication method: oauth2"
```
