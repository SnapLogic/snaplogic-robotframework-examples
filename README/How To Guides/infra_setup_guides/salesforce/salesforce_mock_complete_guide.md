# Salesforce Mock Service: Complete End-to-End Guide

## Table of Contents

- [1. Why Does This Exist?](#1-why-does-this-exist)
  - [1.1 Why Mock Services in the Automation World](#11-why-mock-services-in-the-automation-world)
  - [1.2 How This Project Uses Mocks](#12-how-this-project-uses-mocks)
- [2. Architecture Overview](#2-architecture-overview)
  - [2.1 The Big Picture](#21-the-big-picture)
  - [2.2 Component Diagram](#22-component-diagram)
  - [2.3 Docker Network Topology](#23-docker-network-topology)
- [3. Every Component Explained](#3-every-component-explained)
  - [3.1 WireMock (The Fake Salesforce)](#31-wiremock-the-fake-salesforce)
  - [3.2 JSON Server (The Persistent Database)](#32-json-server-the-persistent-database)
  - [3.3 Groundplex (The SnapLogic Runtime)](#33-groundplex-the-snaplogic-runtime)
  - [3.4 Robot Framework (The Test Orchestrator)](#34-robot-framework-the-test-orchestrator)
  - [3.5 Custom HTTPS Certificate (The Trust Bridge)](#35-custom-https-certificate-the-trust-bridge)
- [4. End-to-End Flow: How a Test Actually Runs](#4-end-to-end-flow-how-a-test-actually-runs)
  - [4.1 Phase 1: Infrastructure Startup](#41-phase-1-infrastructure-startup)
  - [4.2 Phase 2: SnapLogic Account Creation](#42-phase-2-snaplogic-account-creation)
  - [4.3 Phase 3: OAuth Authentication](#43-phase-3-oauth-authentication)
  - [4.4 Phase 4: Account Validation](#44-phase-4-account-validation)
  - [4.5 Phase 5: Pipeline Operations](#45-phase-5-pipeline-operations)
  - [4.6 Phase 6: Test Verification](#46-phase-6-test-verification)
- [5. WireMock: How Request Matching Works](#5-wiremock-how-request-matching-works)
  - [5.1 The Matching Algorithm](#51-the-matching-algorithm)
  - [5.2 All Mapping Files Explained](#52-all-mapping-files-explained)
  - [5.3 Priority System](#53-priority-system)
  - [5.4 Mapping Anatomy: How a Single Mapping Works](#54-mapping-anatomy-how-a-single-mapping-works)
  - [5.5 The Three Matching Types](#55-the-three-matching-types)
  - [5.6 Each Mapping in Plain English](#56-each-mapping-in-plain-english)
  - [5.7 Debugging: When No Mapping Matches](#57-debugging-when-no-mapping-matches)
- [6. Stateless vs Stateful: The Critical Design Decision](#6-stateless-vs-stateful-the-critical-design-decision)
  - [6.1 The Problem](#61-the-problem)
  - [6.2 Stateless Mode (Current Default)](#62-stateless-mode-current-default)
  - [6.3 Stateful Mode (With JSON Server)](#63-stateful-mode-with-json-server)
  - [6.4 Why the Proxy Approach Has Limitations](#64-why-the-proxy-approach-has-limitations)
  - [6.5 When to Use Which Mode](#65-when-to-use-which-mode)
- [7. HTTPS Certificate Setup: The Trust Chain](#7-https-certificate-setup-the-trust-chain)
  - [7.1 Why This Is Necessary](#71-why-this-is-necessary)
  - [7.2 Self-Signed vs CA-Signed Certificates](#72-self-signed-vs-ca-signed-certificates)
  - [7.3 The Problem: Why WireMock's Default Certificate Fails](#73-the-problem-why-wiremocks-default-certificate-fails)
  - [7.4 Prerequisites](#74-prerequisites)
  - [7.5 The Certificate Chain of Events](#75-the-certificate-chain-of-events)
  - [7.6 Step-by-Step Certificate Creation](#76-step-by-step-certificate-creation)
  - [7.7 WireMock Docker Compose HTTPS Configuration](#77-wiremock-docker-compose-https-configuration)
  - [7.8 Importing Certificate into Groundplex](#78-importing-certificate-into-groundplex)
  - [7.9 Verification](#79-verification)
  - [7.10 Makefile Shortcuts](#710-makefile-shortcuts)
  - [7.11 Alternative Approaches](#711-alternative-approaches)
  - [7.12 Certificate Security Best Practices](#712-certificate-security-best-practices)
  - [7.13 Certificate File Reference](#713-certificate-file-reference)
- [8. Configuration Files: What Each File Does](#8-configuration-files-what-each-file-does)
  - [8.1 Docker Compose Configuration](#81-docker-compose-configuration)
  - [8.2 Environment Variables](#82-environment-variables)
  - [8.3 SnapLogic Account Payload Template](#83-snaplogic-account-payload-template)
  - [8.4 JSON Server Data and Routes](#84-json-server-data-and-routes)
  - [8.5 HTML Dashboard](#85-html-dashboard)
- [9. Makefile Targets: How to Operate Everything](#9-makefile-targets-how-to-operate-everything)
- [10. Complete Directory Structure](#10-complete-directory-structure)
- [11. How Everything Connects: The Integration Map](#11-how-everything-connects-the-integration-map)
  - [11.1 Makefile Include Chain](#111-makefile-include-chain)
  - [11.2 Docker Compose Include Chain](#112-docker-compose-include-chain)
  - [11.3 Environment Variable Flow](#113-environment-variable-flow)
  - [11.4 Test Execution Chain](#114-test-execution-chain)
- [12. Advantages and Limitations of Mock Testing](#12-advantages-and-limitations-of-mock-testing)
  - [12.1 Advantages](#121-advantages)
  - [12.2 What Mock Testing PROVES (Specifically for Accounts)](#122-what-mock-testing-proves-specifically-for-accounts)
  - [12.3 What Mock Testing CANNOT Catch](#123-what-mock-testing-cannot-catch)
  - [12.4 The Pre-Flight Checklist Analogy](#124-the-pre-flight-checklist-analogy)
  - [12.5 The Testing Pyramid](#125-the-testing-pyramid)
  - [12.6 The Golden Rule](#126-the-golden-rule)
  - [12.7 The Functional Testing Gap — What Mocks Still Cannot Verify](#127-the-functional-testing-gap--what-mocks-still-cannot-verify)
  - [12.8 WireMock → JSON Server Webhook Bridge](#128-wiremock--json-server-webhook-bridge)
- [13. Troubleshooting Guide](#13-troubleshooting-guide)
- [14. Quick Reference Cheat Sheet](#14-quick-reference-cheat-sheet)

---

## 1. Why Does This Exist?

You wanted to **test SnapLogic Salesforce pipelines without connecting to a real Salesforce org**. That is the core motivation.

Real Salesforce has problems for testing:
- **API rate limits and costs** — every API call counts against your quota
- **Requires internet connectivity** — no offline development
- **Sandbox provisioning delays** — waiting for fresh sandboxes
- **Test data pollution** — tests leave behind garbage data
- **Flaky tests** — external dependency makes tests unpredictable
- **Security concerns** — real credentials in CI/CD pipelines

So you built a **local, Dockerized fake Salesforce** that your SnapLogic Groundplex talks to as if it were the real thing. From SnapLogic's perspective, it cannot tell the difference.

### 1.1 Why Mock Services in the Automation World

Mock services are not just "prechecks" — they are a core practice in modern automation. Here are the **real reasons** teams adopt them:

#### ① CI/CD Pipeline Speed — The #1 Reason

Every code push triggers automated tests. If those tests call real APIs, they're slow:

```
With Real Salesforce:
  Push code → Run tests → Wait for API responses → 5-15 minutes per run
  × 50 developers × 10 pushes/day = 2,500-7,500 minutes of API wait time/day

With Mock:
  Push code → Run tests → Instant responses → 30 seconds per run
  × 50 developers × 10 pushes/day = 250 minutes total
```

In CI/CD, you're running tests **hundreds of times a day**. Mocks make your pipeline go from **minutes to seconds**.

#### ② Parallel Development — Don't Wait for Others

```
Without mocks:                          With mocks:
─────────────                           ──────────
Team A builds pipeline                  Team A builds pipeline
    │                                       │
    ├── "I need the Salesforce              ├── Uses mock → keeps working ✅
    │    endpoint ready!"                   │
    │                                       │
    ├── Waits for Team B... ⏳              Team B builds real API
    │                                       │
    │   Team B: "Not ready yet,             Both teams work simultaneously
    │   give me 2 more weeks"               No blocking, no waiting
    │
    └── Blocked for 2 weeks ❌
```

The Salesforce admin might be configuring custom objects, the security team setting up permissions, DevOps provisioning sandboxes. **You don't wait for any of that.** With mocks, your team keeps building while others catch up.

#### ③ Test Isolation — No Shared State Problems

```
Real Salesforce Sandbox (Shared):

Developer A: Creates "Acme Corp"              → Works ✅
Developer B: Creates "Acme Corp" (same name)  → DUPLICATE_VALUE ❌
Developer C: Deletes test data                → Developer A's tests break ❌
Nightly batch job: Cleans up records          → Everyone's tests break ❌

Mock (Each Developer's Own):

Developer A: Creates "Acme Corp" → Works ✅  (own WireMock instance)
Developer B: Creates "Acme Corp" → Works ✅  (own WireMock instance)
Developer C: Deletes test data   → Only affects their mock ✅
```

Shared sandboxes are a **nightmare** for test reliability. Mocks give you **complete isolation**.

#### ④ Cost Savings — Real API Calls Cost Real Money

```
Salesforce API costs:
  └── API call limits per 24-hour period (depends on license)
  └── Exceeding limits = extra $$$ or blocked access
  └── Sandbox provisioning = limited number per org
  └── Each sandbox = storage costs

Mock costs:
  └── $0
  └── No limits
  └── Spin up 100 instances, nobody cares
```

For large teams running thousands of tests daily, API call costs add up. **Mocks are free.**

#### ⑤ Edge Case & Error Testing — Test the Unhappy Path

With real Salesforce, how do you test: "What happens when Salesforce returns a 500 error?" or "What happens when the API times out?" You **can't easily force these scenarios**. With mocks, you can:

```json
// A mapping that simulates a server error
{
  "request": {
    "method": "POST",
    "url": "/services/data/v59.0/sobjects/Account"
  },
  "response": {
    "status": 500,
    "jsonBody": { "message": "Internal Server Error" },
    "fixedDelayMilliseconds": 30000
  }
}
```

Mocks let you test **failure scenarios** that are impossible or very hard to reproduce with real APIs. This is where mocks go **beyond prechecks** — they verify your pipeline handles errors gracefully.

#### ⑥ Offline & Anywhere Development

| Scenario | Real API | Mock |
|----------|:--------:|:----:|
| On an airplane | ❌ | ✅ |
| VPN is down | ❌ | ✅ |
| Salesforce maintenance window | ❌ | ✅ |
| Weekend (sandbox frozen) | ❌ | ✅ |
| New developer, day 1 (no credentials yet) | ❌ | ✅ |

#### ⑦ Contract Testing — Catch API Changes Early

Mocks serve as a **contract** between systems:

```
Your WireMock mapping says:
  POST /sobjects/Account → returns {"id": "...", "success": true, "errors": []}

This IS the contract. It documents what your pipeline EXPECTS.

When Salesforce releases API v62.0 and changes the response format,
you update the mock first → see if your pipeline breaks → fix it →
THEN switch to real v62.0.
```

#### The Full Picture

```
┌────────────────────────────────────────────────────────────────┐
│                 WHY TEAMS USE MOCKS                            │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ① CI/CD Speed         "Tests run in seconds, not minutes"     │
│  ② Parallel Dev        "Don't wait for other teams"            │
│  ③ Test Isolation      "No shared sandbox conflicts"           │
│  ④ Cost Savings        "No API call charges"                   │
│  ⑤ Error Testing       "Simulate failures you can't in prod"  │
│  ⑥ Offline Dev         "Work anywhere, anytime"                │
│  ⑦ Contract Testing    "Document what your code expects"       │
│                                                                │
│  And yes, also:                                                │
│  ⑧ Prechecks           "Verify plumbing before real APIs"      │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

> **Prechecks are just one benefit — the real value is speed, isolation, and the ability to test scenarios that are impossible with real APIs.**

### 1.2 How This Project Uses Mocks

| Reason | How Your Setup Uses It |
|--------|----------------------|
| **CI/CD Speed** | `make salesforce-mock-start` → `make robot-run-tests` runs in seconds in any CI environment |
| **Parallel Dev** | Developers can build/test Salesforce pipelines without a real sandbox |
| **Test Isolation** | Each developer/CI run gets its own Docker WireMock — no conflicts |
| **Cost** | Zero API calls to Salesforce — free and unlimited |
| **Prechecks** | Validates OAuth flow, account config, URL format, SSL trust chain |

> **💡 Next Level:** You could add mappings that return `500 errors`, `rate limit responses`, or `timeout delays` to test how your pipelines handle failures. That would be the next level of mock testing maturity.

---

## 2. Architecture Overview

### 2.1 The Big Picture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          YOUR MACHINE (Docker Host)                          │
│                                                                              │
│  ┌───────────────┐                                                           │
│  │  Robot         │  1. "Run this pipeline"                                   │
│  │  Framework     │─────────────────────────────┐                            │
│  │  (Test Runner) │                              │                            │
│  └───────────────┘                              ▼                            │
│                                    ┌────────────────────┐                    │
│                                    │   SnapLogic Cloud   │                    │
│                                    │   (Control Plane)   │                    │
│                                    └─────────┬──────────┘                    │
│                                              │ 2. "Execute on Groundplex"    │
│  ┌───────────────────────────────────────────┼──────────────────────────┐    │
│  │              Docker Network: snaplogicnet  │                          │    │
│  │                                           ▼                          │    │
│  │  ┌──────────────────────────────────────────────────┐                │    │
│  │  │  Groundplex Container (snaplogic-groundplex)      │                │    │
│  │  │  ┌──────────────┐  ┌───────────────────────────┐ │                │    │
│  │  │  │  JCC Runtime  │  │  Java Truststore (cacerts) │ │                │    │
│  │  │  │  (SnapLogic   │  │  Contains WireMock's      │ │                │    │
│  │  │  │   Node)       │  │  self-signed certificate   │ │                │    │
│  │  │  └──────┬───────┘  └───────────────────────────┘ │                │    │
│  │  └─────────┼────────────────────────────────────────┘                │    │
│  │            │ 3. HTTPS requests (OAuth, SOQL, CRUD)                   │    │
│  │            ▼                                                         │    │
│  │  ┌──────────────────────────────────────────────────┐                │    │
│  │  │  WireMock Container (salesforce-api-mock)         │                │    │
│  │  │  :8080 (HTTP) / :8443 (HTTPS)                    │                │    │
│  │  │                                                   │                │    │
│  │  │  ┌─────────────────┐  ┌────────────────────────┐ │                │    │
│  │  │  │ Static Mappings  │  │ Proxy Mappings         │ │                │    │
│  │  │  │ (01-05 .json)   │  │ (disabled currently)   │ │                │    │
│  │  │  │ Returns fake    │  │ Would forward to       │ │                │    │
│  │  │  │ JSON responses  │  │ JSON Server            │ │                │    │
│  │  │  └─────────────────┘  └──────────┬─────────────┘ │                │    │
│  │  └──────────────────────────────────┼───────────────┘                │    │
│  │                                     │ 4. (If proxy enabled)          │    │
│  │                                     ▼                                │    │
│  │  ┌──────────────────────────────────────────────────┐                │    │
│  │  │  JSON Server Container (salesforce-json-mock)     │                │    │
│  │  │  :80 (internal) / :8082 (host)                   │                │    │
│  │  │  ┌──────────────────────────────────────────┐    │                │    │
│  │  │  │  salesforce-db.json                       │    │                │    │
│  │  │  │  (accounts, contacts, opportunities)      │    │                │    │
│  │  │  └──────────────────────────────────────────┘    │                │    │
│  │  └──────────────────────────────────────────────────┘                │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  5. Robot Framework verifies pipeline results                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Diagram

| Component | Container Name | Ports (Host:Container) | Role |
|-----------|---------------|----------------------|------|
| **WireMock** | `salesforce-api-mock` | `8089:8080` (HTTP), `8443:8443` (HTTPS) | Pretends to be `login.salesforce.com` |
| **JSON Server** | `salesforce-json-mock` | `8082:80` | Persistent CRUD data store |
| **Groundplex** | `snaplogic-groundplex` | Various | SnapLogic execution runtime (JCC) |
| **Tools Container** | `snaplogic-test-example-tools-container` | None | Robot Framework test runner |

### 2.3 Docker Network Topology

All containers run on the same Docker bridge network: **`snaplogicnet`**

```
snaplogicnet (bridge)
├── salesforce-api-mock      ← WireMock  (internal: 8080, 8443)
├── salesforce-json-mock     ← JSON Server (internal: 80)
├── snaplogic-groundplex     ← Groundplex (connects via container names)
└── snaplogic-test-example-tools-container ← Robot Framework
```

Containers communicate using **container names as hostnames** (e.g., `https://salesforce-api-mock:8443`). This is why the SSL certificate must include `salesforce-api-mock` as a Subject Alternative Name.

---

## 3. Every Component Explained

### 3.1 WireMock (The Fake Salesforce)

**What it is:** WireMock is an open-source API mock server. In this setup, it impersonates the Salesforce REST API.

**Why it exists:** SnapLogic's Salesforce Snap is hardcoded to talk to Salesforce's API endpoints (`/services/oauth2/token`, `/services/data/vXX.0/...`). You cannot change these paths. So you need something that looks exactly like Salesforce at those paths.

**How it works:**
- Loads JSON mapping files from `wiremock/mappings/` at startup
- When a request arrives, matches it against mappings using method + URL pattern + query params
- Returns the corresponding predefined JSON response
- Supports response templating (dynamic tokens, timestamps, random values)

**Image:** `wiremock/wiremock:3.3.1`

**Key configuration flags:**
```
--port=8080                    # HTTP listener
--https-port=8443              # HTTPS listener
--https-keystore=...p12        # Custom SSL certificate
--keystore-password=password   # Keystore password
--global-response-templating   # Enable Handlebars templating in responses
--verbose                      # Detailed logging
--enable-stub-cors             # Allow cross-origin requests
--preserve-host-header         # Keep original Host header
```

**Admin endpoints (for debugging):**
- `http://localhost:8089/__admin/health` — health check
- `http://localhost:8089/__admin/mappings` — view all loaded mappings
- `http://localhost:8089/__admin/requests` — view request journal

### 3.2 JSON Server (The Persistent Database)

**What it is:** A lightweight Node.js application that creates a full REST API from a JSON file.

**Why it exists:** WireMock is stateless — it cannot remember data between requests. If your pipeline does `Create Account → Query Account`, the query will not find what was just created. JSON Server solves this by providing real data persistence.

**How it works:**
1. Reads `salesforce-db.json` at startup
2. Creates REST endpoints from top-level keys:
   - `accounts` → `GET/POST/PUT/PATCH/DELETE /accounts`
   - `contacts` → `GET/POST/PUT/PATCH/DELETE /contacts`
   - `opportunities` → `GET/POST/PUT/PATCH/DELETE /opportunities`
3. Every write operation (POST, PUT, PATCH, DELETE) updates the JSON file on disk
4. The `--watch` flag monitors for external file changes and reloads automatically

**Image:** `clue/json-server` (with `platform: linux/amd64` for Apple Silicon compatibility)

**Volume mount:** `./json-db:/data` — the JSON file on your host is the same file the container reads/writes. Changes survive container restarts.

### 3.3 Groundplex (The SnapLogic Runtime)

**What it is:** A SnapLogic execution node running as a Docker container. It is the JCC (Java Component Container) that actually executes your Salesforce Snap pipelines.

**Why it matters for this setup:**
- Groundplex runs **Java** internally
- Java has a **truststore** (`cacerts`) that contains all trusted SSL certificates
- By default, Java trusts only well-known Certificate Authorities (DigiCert, Let's Encrypt, etc.)
- WireMock's self-signed certificate is NOT in that list
- So you must **manually import** WireMock's certificate into Groundplex's truststore

**Key paths inside the container:**
```
/opt/snaplogic/pkgs/jdk-11.0.24+8-jre/bin/keytool        ← Certificate import tool
/opt/snaplogic/pkgs/jdk-11.0.24+8-jre/lib/security/cacerts ← Java truststore
/opt/snaplogic/bin/jcc.sh                                   ← JCC service control
/opt/snaplogic/run/log/jcc.log                              ← JCC logs
```

### 3.4 Robot Framework (The Test Orchestrator)

**What it is:** A Python-based test automation framework that orchestrates the entire test lifecycle.

**What it does in this context:**
1. Waits for Groundplex to be ready (`Wait Until Plex Status Is Up`)
2. Creates a Salesforce account in SnapLogic using the mock credentials
3. Imports pipelines, creates triggered tasks
4. Executes pipelines and verifies results

**Test file:** `test/suite/pipeline_tests/salesforce/sfdc.robot`

**Key test case:**
```robot
Create Account
    [Tags]    sfdc    regression
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SALESFORCE_ACCOUNT_PAYLOAD_FILE_NAME}    ${SALESFORCE_ACCOUNT_NAME}
```

This creates a Salesforce account in SnapLogic Designer that points to `https://salesforce-api-mock:8443` instead of real Salesforce.

### 3.5 Custom HTTPS Certificate (The Trust Bridge)

**What it is:** A self-signed SSL certificate stored as `custom-keystore.p12` (PKCS12 format).

**Why it exists:** Two problems needed solving:

**Problem 1: Java rejects unknown certificates**
> Java (inside Groundplex) refuses HTTPS connections to servers with certificates it doesn't recognize. WireMock's certificate is self-signed, not issued by a trusted CA.

**Problem 2: Hostname mismatch**
> WireMock's default certificate says `CN=localhost`, but Groundplex connects using `salesforce-api-mock`. Java checks: "Does the cert match who I'm talking to?" → No → Connection rejected.

**The solution:** A custom certificate with Subject Alternative Names (SANs):
```
DNS:salesforce-api-mock   ← Docker container name (primary)
DNS:localhost              ← Local testing access
DNS:salesforce-mock        ← Alternative service name
IP:127.0.0.1              ← IP-based access
```

This certificate is:
1. **Used by WireMock** to serve HTTPS (via keystore mount)
2. **Imported into Groundplex's Java truststore** so Java trusts it

---

## 4. End-to-End Flow: How a Test Actually Runs

### 4.1 Phase 1: Infrastructure Startup

**Command:** `make salesforce-mock-start`

**What happens:**

```
make salesforce-mock-start
    │
    ├── docker compose --profile salesforce-dev up -d salesforce-mock salesforce-json-server
    │       │
    │       ├── Starts salesforce-api-mock (WireMock)
    │       │     ├── Loads wiremock/mappings/*.json (5 mapping files)
    │       │     ├── Mounts wiremock/certs/custom-keystore.p12
    │       │     ├── Starts HTTP on :8080 and HTTPS on :8443
    │       │     └── Health check: curl http://localhost:8080/__admin/health
    │       │
    │       └── Starts salesforce-json-mock (JSON Server)
    │             ├── Mounts json-db/ directory
    │             ├── Reads salesforce-db.json
    │             ├── Creates REST endpoints: /accounts, /contacts, /opportunities
    │             └── Starts watching for file changes
    │
    └── sleep 5 (wait for initialization)
```

The `DOCKER_COMPOSE` variable from `Makefile.common` expands to include all `--env-file` flags:
```bash
docker compose --env-file env_files/mock_service_accounts/.env.salesforce \
               --env-file .env \
               -f docker-compose.yml \
               --profile salesforce-dev up -d ...
```

This means port numbers from `.env.salesforce` (`SALESFORCE_HTTP_PORT=8089`, `SALESFORCE_HTTPS_PORT=8443`, `SALESFORCE_JSON_PORT=8082`) are injected into the Docker Compose service definitions.

### 4.2 Phase 2: SnapLogic Account Creation

**Triggered by:** Robot Framework test case `Create Account` in `sfdc.robot`

**What happens:**

```
Robot Framework
    │
    ├── Reads account payload template: acc_salesforce.json
    │     {
    │       "path": "{{ACCOUNT_LOCATION_PATH}}",
    │       "account": {
    │         "class_fqid": "com-snaplogic-snaps-salesforce-salesforceaccount_1-...",
    │         "property_map": {
    │           "settings": {
    │             "loginUrl": { "value": "{{SALESFORCE_LOGIN_URL}}" },
    │             "sandbox":  { "value": true },
    │             "username": { "value": "{{SALESFORCE_USERNAME}}" },
    │             "password": { "value": "{{SALESFORCE_PASSWORD}}" }
    │           },
    │           "info": {
    │             "label": { "value": "{{SALESFORCE_ACCOUNT_NAME}}" }
    │           }
    │         }
    │       }
    │     }
    │
    ├── Substitutes environment variables:
    │     SALESFORCE_LOGIN_URL  → https://salesforce-api-mock:8443
    │     SALESFORCE_USERNAME   → slim@snaplogic.com
    │     SALESFORCE_PASSWORD   → test
    │     SALESFORCE_ACCOUNT_NAME → sfdc_acct
    │
    └── Calls SnapLogic API: POST /api/1/rest/public/account/...
          └── Creates a Salesforce account named "sfdc_acct"
              pointing to https://salesforce-api-mock:8443
```

### 4.3 Phase 3: OAuth Authentication

**Triggered by:** SnapLogic when a pipeline uses the Salesforce account

Every Salesforce Snap starts by authenticating. This is hardcoded behavior you cannot skip.

```
Groundplex (JCC)
    │
    ├── Pipeline starts, Salesforce Snap initializes
    │
    ├── Reads account config: loginUrl = https://salesforce-api-mock:8443
    │
    ├── Java checks SSL certificate:
    │     ├── Connects to salesforce-api-mock:8443
    │     ├── Receives self-signed certificate
    │     ├── Checks truststore → finds "wiremock-salesforce" alias ✅
    │     ├── Checks hostname → SANs include "salesforce-api-mock" ✅
    │     └── SSL handshake succeeds
    │
    └── Sends OAuth request:
          POST https://salesforce-api-mock:8443/services/oauth2/token
          Body: grant_type=password&username=slim@snaplogic.com&password=test

WireMock
    │
    ├── Receives POST /services/oauth2/token
    ├── Checks mappings by priority...
    ├── Matches: 01-oauth-token.json (priority 1, method POST, urlPath /services/oauth2/token)
    │
    └── Returns (with response templating):
          {
            "access_token": "00D000000000000!mock.token.aB3kF9xR2mN7...",
            "instance_url": "https://salesforce-api-mock:8443",
            "id": "https://salesforce-api-mock:8443/id/00D.../005...",
            "token_type": "Bearer",
            "issued_at": "1738100000",
            "signature": "kL9mN2pQ7rS..."
          }
```

The Salesforce Snap now has a Bearer token. It stores the `instance_url` and uses it for all subsequent API calls. SnapLogic believes it is talking to a real Salesforce org.

### 4.4 Phase 4: Account Validation

**Triggered by:** SnapLogic when you click "Validate" on the account, or during pipeline initialization

```
Groundplex (JCC)
    │
    └── Sends validation query:
          GET https://salesforce-api-mock:8443/services/data/v52.0/query?q=SELECT+Name+FROM+Account+LIMIT+1
          Header: Authorization: Bearer 00D000000000000!mock.token.aB3kF9xR2mN7...

WireMock
    │
    ├── Receives GET /services/data/v52.0/query/ with q=SELECT Name FROM Account LIMIT 1
    ├── Checks mappings by priority...
    ├── Matches: 02-validation-query.json (priority 5, exact query match)
    │
    └── Returns:
          {
            "totalSize": 1,
            "done": true,
            "records": [{
              "attributes": { "type": "Account", "url": "/services/data/v52.0/sobjects/Account/001000000000TEST01" },
              "Id": "001000000000TEST01",
              "Name": "Validation Test Account"
            }]
          }
```

SnapLogic sees valid response → "Account validation successful" ✅

> **These two mappings (01 + 02) are the absolute minimum** needed for SnapLogic to believe it is connected to Salesforce. Everything else is for actual pipeline operations.

### 4.5 Phase 5: Pipeline Operations

Depending on what the pipeline does, different WireMock mappings are hit:

#### Describe Account (Metadata Lookup)
```
Pipeline sends:  GET /services/data/v59.0/sobjects/Account/describe
WireMock matches: 03-describe-account.json
Returns:         Account object schema with 8 fields
                 (Id, Name, Type, Industry, Phone, Website, AnnualRevenue, NumberOfEmployees)
                 including picklist values for Type and Industry
```

#### Create Account
```
Pipeline sends:  POST /services/data/v59.0/sobjects/Account
                 Body: {"Name": "New Customer", "Type": "Customer"}
WireMock matches: 04-create-account.json
Returns:         {"id": "001000000000TEST01", "success": true, "errors": []}
```

#### Query Accounts
```
Pipeline sends:  GET /services/data/v59.0/query?q=SELECT Name FROM Account WHERE Type='Customer'
WireMock matches: 05-read-account-query.json (matches any query containing "Account")
Returns:         {"totalSize": 1, "done": true, "records": [{...test account...}]}
```

### 4.6 Phase 6: Test Verification

```
Robot Framework
    │
    ├── Checks pipeline execution status (Completed/Failed)
    ├── Verifies output documents match expected format
    ├── Optionally compares CSV output against expected files
    └── Reports pass/fail
```

---

## 5. WireMock: How Request Matching Works

### 5.1 The Matching Algorithm

When a request arrives at WireMock, this is the exact sequence:

```
Request arrives (e.g., POST /services/oauth2/token)
    │
    ├── 1. Load ALL mapping files from /home/wiremock/mappings/
    │
    ├── 2. Sort mappings by PRIORITY (lower number = higher priority, default = 5)
    │
    ├── 3. For EACH mapping (in priority order):
    │       │
    │       ├── Does HTTP METHOD match?
    │       │   POST == POST? ✅ → continue
    │       │   POST == GET?  ❌ → skip to next mapping
    │       │
    │       ├── Does URL PATTERN match?
    │       │   Three matching types:
    │       │   • urlPath: exact string match
    │       │   • urlPathPattern: regex match (e.g., /services/data/v[0-9]+\.[0-9]+/...)
    │       │   • url: full URL including domain
    │       │
    │       ├── Do QUERY PARAMETERS match? (only if specified in mapping)
    │       │   • equalTo: exact match
    │       │   • contains: substring match
    │       │   • matches: regex match
    │       │
    │       ├── Do HEADERS match? (only if specified)
    │       │
    │       └── Does BODY match? (only if specified)
    │
    ├── 4. FIRST full match → return that mapping's response
    │
    └── 5. NO match found → return 404 Not Found
```

### 5.2 All Mapping Files Explained

#### `01-oauth-token.json` — OAuth Authentication

| Field | Value |
|-------|-------|
| **Priority** | 1 (high) |
| **Method** | POST |
| **URL Pattern** | `/services/oauth2/token` (urlPathPattern) |
| **Query Params** | None required |
| **Response Status** | 200 |
| **Response Body** | Mock OAuth token with dynamic values via Handlebars templating |

**Why it exists:** Every Salesforce Snap must authenticate first. This mapping accepts ANY credentials (username, password, grant_type) and returns a valid-looking token.

**Response templating details:**
```json
{
  "access_token": "00D000000000000!mock.token.{{randomValue type='ALPHANUMERIC' length=32}}",
  "instance_url": "https://salesforce-api-mock:8443",
  "issued_at": "{{now epoch}}",
  "signature": "{{randomValue type='ALPHANUMERIC' length=44}}"
}
```
- `{{randomValue ...}}` generates a different token each time
- `{{now epoch}}` inserts the current Unix timestamp
- `"transformers": ["response-template"]` enables the templating engine

#### `02-validation-query.json` — SnapLogic Account Validation

| Field | Value |
|-------|-------|
| **Priority** | 5 (default) |
| **Method** | GET |
| **URL Path** | `/services/data/v52.0/query/` (exact match) |
| **Query Params** | `q` equalTo `SELECT Name FROM Account LIMIT 1` |
| **Response Status** | 200 |

**Why it exists:** When you click "Validate" on a Salesforce account in SnapLogic Designer, it sends this exact query. If the response is valid, SnapLogic marks the account as validated.

**Why priority 5:** This is a very specific query (exact match on `q` parameter). The broader `05-read-account-query.json` (priority 1) would match first if they had the same priority, but since `02` matches `urlPath` exactly while `05` uses `urlPathPattern` regex, and `02` requires an exact `equalTo` on the query parameter, WireMock correctly resolves between them.

#### `03-describe-account.json` — Account Object Metadata

| Field | Value |
|-------|-------|
| **Priority** | 2 |
| **Method** | GET |
| **URL Pattern** | `/services/data/v[0-9]+\.[0-9]+/sobjects/Account/describe` (regex) |
| **Response Status** | 200 |

**Why it exists:** The Salesforce Snap calls this to discover the Account object's field schema — what fields exist, their types, lengths, and picklist values. SnapLogic uses this to populate the Snap's field mapping UI.

**Fields defined in the response:**

| Field Name | Type | Createable | Updateable |
|-----------|------|------------|------------|
| Id | id | No | No |
| Name | string (255) | Yes | Yes |
| Type | picklist (Customer, Partner, Prospect) | Yes | Yes |
| Industry | picklist (Technology, Manufacturing, Finance, Healthcare) | Yes | Yes |
| Phone | phone (40) | Yes | Yes |
| Website | url (255) | Yes | Yes |
| AnnualRevenue | currency | Yes | Yes |
| NumberOfEmployees | int | Yes | Yes |

#### `04-create-account.json` — Create Account

| Field | Value |
|-------|-------|
| **Priority** | 1 (high) |
| **Method** | POST |
| **URL Pattern** | `/services/data/v[0-9]+\.[0-9]+/sobjects/Account` (regex) |
| **Response Status** | 201 (Created) |

**Why it exists:** When a Salesforce Create Snap runs, it POSTs to this endpoint. The response tells SnapLogic the record was created successfully.

**Response:**
```json
{
  "id": "001000000000TEST01",
  "success": true,
  "errors": []
}
```

**Important note:** This is a static response. The `id` is always `001000000000TEST01` regardless of what was sent. The data is not actually stored anywhere (see Section 6 on stateless vs stateful).

#### `05-read-account-query.json` — Query Accounts

| Field | Value |
|-------|-------|
| **Priority** | 1 (high) |
| **Method** | GET |
| **URL Pattern** | `/services/data/v[0-9]+\.[0-9]+/query.*` (regex) |
| **Query Params** | `q` contains `Account` |
| **Response Status** | 200 |

**Why it exists:** When a Salesforce Read or SOQL Snap queries for accounts, this mapping catches it and returns test data.

**Important:** This is a broad catch-all — any SOQL query containing the word "Account" will match. The response always returns the same single test record regardless of the WHERE clause.

#### `create-account-proxy.disabled` — Proxy to JSON Server

| Field | Value |
|-------|-------|
| **Priority** | 0 (highest possible) |
| **Method** | POST |
| **URL Path** | `/services/data/v52.0/sobjects/Account/` (exact) |
| **Response** | Proxy to `http://salesforce-json-mock` |
| **Status** | **DISABLED** (`.disabled` extension) |

**Why it exists:** This was an experiment to make Account creates actually persist to JSON Server. It is currently disabled because of fundamental incompatibilities (see Section 6.4).

**Why priority 0:** If enabled, it would need to override `04-create-account.json` (priority 1) for the same endpoint.

### 5.3 Priority System

```
Priority 0: create-account-proxy.disabled  ← Would override everything (disabled)
Priority 1: 01-oauth-token.json            ← OAuth must always work
Priority 1: 04-create-account.json         ← Account creation
Priority 1: 05-read-account-query.json     ← Broad query catch-all
Priority 2: 03-describe-account.json       ← Metadata
Priority 5: 02-validation-query.json       ← Very specific validation query
```

Lower number = higher priority. When two mappings could match the same request, the one with the lower priority number wins.

### 5.4 Mapping Anatomy: How a Single Mapping Works

Every mapping file has just **two parts** — a **request** (the trigger) and a **response** (the answer):

```
┌──────────────────────────────────────────────────┐
│  REQUEST  (The "IF" part)                        │
│  "If someone sends a request that looks          │
│   like THIS..."                                  │
├──────────────────────────────────────────────────┤
│  RESPONSE (The "THEN" part)                      │
│  "...then send back THIS answer"                 │
└──────────────────────────────────────────────────┘
```

**Example: `04-create-account.json` broken down:**

```json
{
  "priority": 1,
  "request": {
    "method": "POST",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account"
  },
  "response": {
    "status": 201,
    "headers": { "Content-Type": "application/json" },
    "jsonBody": {
      "id": "001000000000TEST01",
      "success": true,
      "errors": []
    }
  }
}
```

#### The REQUEST — "What am I listening for?"

| Field | Value | Meaning |
|-------|-------|---------|
| `method` | `POST` | Only match POST requests (not GET, PUT, DELETE) |
| `urlPathPattern` | `/services/data/v[0-9]+\\.[0-9]+/sobjects/Account` | URL must match this **regex pattern** |

#### The URL Pattern — Regex Explained

```
/services/data/v[0-9]+\.[0-9]+/sobjects/Account
│              ││     │ │     ││               │
│              ││     │ │     ││               └── Literal "Account"
│              ││     │ │     │└── Literal "/sobjects/"
│              ││     │ │     └── One or more digits (e.g., "0")
│              ││     │ └── Literal dot "." (the \. means actual period)
│              ││     └── One or more digits (e.g., "59")
│              │└── Literal "v"
│              └── Literal "/services/data/"
└── Start of path
```

**URLs that MATCH this pattern:**
```
/services/data/v59.0/sobjects/Account     ✅  (your pipeline sends this)
/services/data/v52.0/sobjects/Account     ✅  (older API version)
/services/data/v61.0/sobjects/Account     ✅  (future API version)
```

**URLs that DO NOT match:**
```
/services/data/v59.0/sobjects/Contact     ❌  (Contact, not Account)
/services/data/v59.0/sobjects2/Account    ❌  (sobjects2 ≠ sobjects — even one character off!)
/services/data/sobjects/Account           ❌  (missing version number)
/services/data/v59.0/query                ❌  (different path entirely)
```

> **Why use regex?** Because SnapLogic's API version might change (v52.0 → v59.0 → v61.0). The regex `v[0-9]+\.[0-9]+` matches **any version**, so you never need to update this mapping.

#### The RESPONSE — "What do I send back?"

| Field | Value | Meaning |
|-------|-------|---------|
| `status` | `201` | HTTP 201 Created — "I successfully created it" |
| `Content-Type` | `application/json` | "My response is JSON" |
| `id` | `001000000000TEST01` | A fake 18-character Salesforce record ID |
| `success` | `true` | "The operation worked" |
| `errors` | `[]` | "No errors occurred" |

> **The ID is always the same.** Whether you create "Acme Corp" or "Test123" — you always get back `001000000000TEST01`. It's a mock — it doesn't store anything.

#### The Real-World Flow — What Happens When a Snap Fires

```
SnapLogic Create Snap                           WireMock
       │                                           │
       │  Snap is configured with:                 │
       │  • Account: https://salesforce-api-mock:8443
       │  • Object: Account                        │
       │  • API Version: 59.0                      │
       │                                           │
       │  Snap builds the URL:                     │
       │  POST /services/data/v59.0/sobjects/Account
       │  Body: {"Name": "Acme Corp"}              │
       │                                           │
       ├──── sends request ───────────────────────→│
       │                                           │
       │         WireMock checks mapping:           │
       │         • Method: POST? ✅                 │
       │         • URL matches regex? ✅             │
       │           v59.0 matches v[0-9]+\.[0-9]+    │
       │         • Priority 1 — first match wins    │
       │                                           │
       │←─── returns response ────────────────────┤
       │                                           │
       │  {"id": "001000000000TEST01",             │
       │   "success": true, "errors": []}          │
       │                                           │
  Snap: "Success! ID = 001000000000TEST01" ✅      │
```

**The key insight:** The URL path (`/services/data/v59.0/sobjects/Account`) is **built by the SnapLogic Snap itself** — it follows the real Salesforce REST API spec. You don't control it. The only thing you changed is the **host** (from `login.salesforce.com` to `salesforce-api-mock:8443`):

```
Real Salesforce:  POST https://login.salesforce.com/services/data/v59.0/sobjects/Account
Your Mock:        POST https://salesforce-api-mock:8443/services/data/v59.0/sobjects/Account
                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                       Only THIS part is different (the host)
```

### 5.5 The Three Matching Types

| Match Type | How It Works | Analogy |
|-----------|-------------|---------|
| **`equalTo`** | Exact text match — must be letter-for-letter identical | "Only open the door if they say the EXACT password" |
| **`urlPathPattern`** (regex) | Matches a URL pattern with wildcards | "Open the door for anyone whose name starts with 'Dr.'" |
| **`contains`** | Matches if the text appears anywhere in the value | "Open the door if they mention 'Account' anywhere" |

### 5.6 Each Mapping in Plain English

| # | File | Plain English |
|---|------|--------------|
| ① | `01-oauth-token.json` | "When someone tries to **log in**, give them a fake access token" |
| ② | `02-validation-query.json` | "When someone asks **'SELECT Name FROM Account LIMIT 1'**, reply with a dummy name" |
| ③ | `03-describe-account.json` | "When someone asks **'what does an Account look like?'**, give them a list of fields" |
| ④ | `04-create-account.json` | "When someone **creates a new Account**, reply with 'OK, here's the ID'" |
| ⑤ | `05-read-account-query.json` | "When someone **queries for Accounts**, give them a pre-made test account" |

### 5.7 Debugging: When No Mapping Matches

If WireMock can't find a matching mapping, it returns a `404`. To see what went wrong:

```bash
# Show all requests that DIDN'T match any mapping
curl http://localhost:8089/__admin/requests/unmatched | python3 -m json.tool
```

This shows the **exact URL** that came in, so you can compare it against your mapping patterns and spot the mismatch. Even one character off (like `sobjects2` instead of `sobjects`) causes a miss.

---

## 6. Stateless vs Stateful: The Critical Design Decision

### 6.1 The Problem

Consider a pipeline that does: `Create Account → Query that Account`

The question is: **when you query for the account you just created, will it be found?**

### 6.2 Stateless Mode (Current Default)

With only WireMock static mappings (the current setup):

```
Step 1: Create "Acme Corp"
    POST /services/data/v59.0/sobjects/Account
    Body: {"Name": "Acme Corp", "Type": "Customer"}

    Response: {"id": "001000000000TEST01", "success": true}  ← Looks good!

    BUT: Nothing was actually saved anywhere. WireMock just returned a canned response.

Step 2: Query "Acme Corp"
    GET /services/data/v59.0/query?q=SELECT Name FROM Account WHERE Name='Acme Corp'

    Response: {
      "totalSize": 1,
      "records": [{"Name": "Test Account for CRUD"}]  ← NOT "Acme Corp"!
    }

    The query returns pre-canned data, NOT what was just created.
```

**Result: The workflow appears to succeed (each individual operation returns 200/201) but the data does not flow through.**

### 6.3 Stateful Mode (With JSON Server)

If you enable the proxy mapping and route creates through JSON Server:

```
Step 1: Create "Acme Corp"
    POST → WireMock → proxies to → JSON Server
    JSON Server: Saves {"Name": "Acme Corp"} to salesforce-db.json
    Response: {"id": "abc123", "Name": "Acme Corp"}  ✅ Actually saved!

Step 2: Query "Acme Corp"
    GET → (would need proxy mapping too) → JSON Server
    JSON Server: Finds "Acme Corp" in salesforce-db.json
    Response: Found!  ✅ Data persisted!
```

### 6.4 Why the Proxy Approach Has Limitations

You documented this extensively in `WHY_JSON_SERVER_DOESNT_WORK.md`. There are three fundamental incompatibilities:

#### Incompatibility 1: Path Mismatch

WireMock's `proxyBaseUrl` **appends** the original path — it does not replace it:

```
SnapLogic sends:     POST /services/data/v52.0/sobjects/Account
WireMock forwards:   POST http://salesforce-json-mock/services/data/v52.0/sobjects/Account
JSON Server expects: POST http://salesforce-json-mock/accounts
Result:              404 Not Found
```

WireMock cannot rewrite paths during proxying. It only forwards the exact same path to the target server.

#### Incompatibility 2: Response Format Mismatch

```
Salesforce format (what SnapLogic expects):
  {"id": "001234567890", "success": true, "errors": []}

JSON Server format (what it returns):
  {"id": "abc123", "Name": "Test Company", "Type": "Customer"}
```

SnapLogic validates the response structure. Missing `success` field causes parsing errors.

#### Incompatibility 3: It is Three Different "Languages"

```
SnapLogic speaks:    "Salesforce" (complex enterprise paths, specific response formats)
JSON Server speaks:  "Simple REST" (flat resource paths, generic JSON)
WireMock is:         A messenger (forwards messages but cannot translate between languages)
```

#### Why curl Tests Were Misleading

When testing with curl, you have full control — you can choose which endpoint to hit and accept any response format. SnapLogic's Salesforce connector is locked into the Salesforce protocol and cannot be reconfigured.

### 6.5 When to Use Which Mode

| Testing Goal | Use Stateless (WireMock Only) | Use Stateful (JSON Server) |
|-------------|------------------------------|---------------------------|
| Pipeline logic & transformation | ✅ | Overkill |
| OAuth/authentication flow | ✅ | Not needed |
| Individual CRUD operations | ✅ | Not needed |
| Create → Query workflows | ❌ Data does not persist | ✅ (but requires custom middleware) |
| Error handling | ✅ (add error mappings) | Not needed |
| CI/CD smoke tests | ✅ | Not needed |
| Full integration test | ❌ | Use real Salesforce sandbox instead |

**Current recommendation:** Use stateless mode for pipeline development and CI smoke tests. Use a real Salesforce sandbox for integration testing.

---

## 7. HTTPS Certificate Setup: The Trust Chain

### 7.1 Why This Is Necessary

**Groundplex** (SnapLogic execution node) needs to connect to **WireMock** (your Salesforce API mock) over HTTPS. That WireMock instance runs with a **self-signed certificate** — one you created yourself, not issued by a trusted Certificate Authority. By default, Java (inside Groundplex) will **reject** connections to an unknown/self-signed certificate. You must **import** the public part of the certificate into Java's truststore (`cacerts`) — essentially telling Java: *"Trust this server's ID card, even though it wasn't issued by a well-known authority."*

```
Groundplex (Java)                    WireMock
      │                                  │
      ├── Connects to port 8443 ─────────┤
      │                                  │
      ├── Receives certificate            │
      │   CN=salesforce-api-mock          │
      │   (self-signed, not from a CA)    │
      │                                  │
      ├── Checks truststore (cacerts)     │
      │   "Do I trust this cert?"         │
      │                                  │
      │   DEFAULT: ❌ No! Unknown issuer! │
      │   AFTER IMPORT: ✅ Yes! Found it! │
      │                                  │
      └── Checks hostname                │
          "Does cert match who I'm        │
           talking to?"                   │
          ✅ SAN includes                 │
             salesforce-api-mock          │
```

Without the certificate setup, you get:
```
javax.net.ssl.SSLPeerUnverifiedException:
  Host name 'salesforce-api-mock' does not match the certificate subject
  provided by the peer (CN=localhost)
```

### 7.2 Self-Signed vs CA-Signed Certificates

| Type | Description | Trust |
|------|-------------|-------|
| **CA-signed (public)** | Issued by a trusted Certificate Authority (Let's Encrypt, DigiCert, etc.) | Browsers and Java already trust them — no manual import needed |
| **Self-signed** | You create it yourself. Free and easy for local dev/test | **Not trusted by default**. You must manually tell systems (like Java) to trust it |

**In this project:** We use a self-signed certificate because:
1. It's a local Docker environment — no public domain needed
2. It's free and instant — no CA approval process
3. It's fully under your control — can set any hostname in SANs

### 7.3 The Problem: Why WireMock's Default Certificate Fails

WireMock ships with a built-in certificate that has `CN=localhost`. But Groundplex connects using the Docker service name `salesforce-api-mock`. SSL/TLS **hostname verification fails** because the names don't match.

**The solution:** Create a custom certificate with proper **Subject Alternative Names (SANs)** that include all hostnames used to access the service.

### 7.4 Prerequisites

Before creating certificates, ensure you have:

- Docker and Docker Compose installed
- `openssl` command-line tool available (pre-installed on Mac/Linux)
- Access to the project directory structure
- A running or soon-to-be-running Groundplex container

### 7.5 The Certificate Chain of Events

```
1. GENERATE certificate with SANs
       │
       ├── openssl genrsa → custom-key.pem (private key)
       ├── openssl req -new -x509 → custom-cert.pem (certificate)
       │   SANs: salesforce-api-mock, localhost, 127.0.0.1
       └── openssl pkcs12 -export → custom-keystore.p12 (bundled)

2. WIREMOCK uses the keystore
       │
       └── Volume mount: ./wiremock/certs/custom-keystore.p12:/home/wiremock/keystore.p12
           Command: --https-keystore=/home/wiremock/keystore.p12 --keystore-password=password

3. EXTRACT the public certificate from the running WireMock
       │
       └── echo | openssl s_client -connect localhost:8443 ... | openssl x509 > /tmp/wiremock-cert.pem

4. COPY into Groundplex container
       │
       └── docker cp /tmp/wiremock-cert.pem snaplogic-groundplex:/tmp/wiremock-cert.pem

5. IMPORT into Java truststore
       │
       └── keytool -import -trustcacerts -keystore cacerts -alias wiremock-salesforce -file /tmp/wiremock-cert.pem

6. RESTART JCC so it picks up the new trust
       │
       └── ./jcc.sh restart
```

### 7.6 Step-by-Step Certificate Creation

#### 7.6.1 Create Directory Structure

```bash
# Navigate to your project root
cd {{cookiecutter.primary_pipeline_name}}

# Create certificates directory
mkdir -p docker/salesforce/wiremock/certs
cd docker/salesforce/wiremock/certs
```

#### 7.6.2 Generate Private Key

```bash
# Generate a 2048-bit RSA private key
openssl genrsa -out custom-key.pem 2048
```

**What this does:** Creates a private RSA key with 2048-bit encryption in PEM format. This key is the foundation for your certificate.

#### 7.6.3 Create Self-Signed Certificate with SANs (Recommended)

```bash
# Create certificate with Subject Alternative Names
openssl req -new -x509 \
  -key custom-key.pem \
  -out custom-cert.pem \
  -days 365 \
  -subj "/C=US/ST=CA/L=San Francisco/O=SnapLogic/CN=salesforce-api-mock" \
  -addext "subjectAltName=DNS:salesforce-api-mock,DNS:localhost,DNS:salesforce-mock,IP:127.0.0.1"
```

**Certificate Fields Explained:**

| Field | Value | Purpose |
|-------|-------|---------|
| `C` | US | Country Code |
| `ST` | CA | State/Province (California) |
| `L` | San Francisco | Locality/City |
| `O` | SnapLogic | Organization |
| `CN` | salesforce-api-mock | Common Name (primary hostname) |

**Subject Alternative Names (SANs) Included:**

| SAN | Why It's Included |
|-----|-------------------|
| `DNS:salesforce-api-mock` | Docker service name — **primary** access method from Groundplex |
| `DNS:localhost` | For local testing from your host machine |
| `DNS:salesforce-mock` | Alternative service name |
| `IP:127.0.0.1` | IP-based access from host |

> **✅ Why SANs are recommended:** This certificate works regardless of how you access the service (via Docker hostname, localhost, or IP address), preventing hostname verification errors.

**Alternative: Basic Certificate without SANs (Simpler but Limited)**

If you only need to access via the Docker service name:
```bash
# Basic certificate without SANs
openssl req -new -x509 \
  -key custom-key.pem \
  -out custom-cert.pem \
  -days 365 \
  -subj "/C=US/ST=CA/L=San Francisco/O=SnapLogic/CN=salesforce-api-mock"
```

> **⚠️ Limitation:** This only works when accessing the service as `salesforce-api-mock`. Will fail for `localhost` or IP access.

#### 7.6.4 Bundle into PKCS12 Keystore

```bash
# Bundle private key and certificate into PKCS12 format
openssl pkcs12 -export \
  -in custom-cert.pem \
  -inkey custom-key.pem \
  -out custom-keystore.p12 \
  -name "wiremock" \
  -password pass:password
```

> **Note:** The password `password` is used here for simplicity. In production, use a strong password.

#### 7.6.5 Verify Your Certificate (Optional but Recommended)

```bash
# View certificate subject and SANs
openssl x509 -in custom-cert.pem -noout -text | grep -A2 "Subject:"
openssl x509 -in custom-cert.pem -noout -text | grep -A2 "Subject Alternative Name"

# Check P12 keystore contents
openssl pkcs12 -info -in custom-keystore.p12 -password pass:password -noout

# Check certificate expiry date
openssl x509 -in custom-cert.pem -noout -enddate
```

#### 7.6.6 Clean Up Intermediate Files (Optional)

```bash
# After creating the P12 file, you can delete the intermediate .pem files
# The P12 contains everything needed (private key + certificate)
rm custom-key.pem custom-cert.pem

# Keep only the P12 file that WireMock will use
ls -la custom-keystore.p12
```

> **💡 Why it's safe:** The `.pem` files can be safely deleted because the P12 file contains both the private key and certificate. WireMock only needs the P12 file to serve HTTPS. If you ever need to re-extract the certificate: `openssl pkcs12 -in custom-keystore.p12 -nokeys -out cert.pem -password pass:password`

### 7.7 WireMock Docker Compose HTTPS Configuration

The certificate is mounted into WireMock via the Docker Compose configuration:

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `./wiremock/certs/custom-keystore.p12` | `/home/wiremock/certs/custom-keystore.p12` | Certificate keystore |
| `:ro` flag | Read-only mount | Security best practice |

**WireMock command flags that enable HTTPS:**
```
--https-port=8443
--https-keystore=/home/wiremock/certs/custom-keystore.p12
--keystore-password=password
```

After starting, verify HTTPS is working:
```bash
# Test HTTPS endpoint (use -k to ignore self-signed cert warning)
curl -k https://localhost:8443/__admin/health
# Expected: {"status":"OK"}

# Check certificate details being served
echo | openssl s_client -connect localhost:8443 -servername salesforce-api-mock 2>/dev/null | \
  openssl x509 -noout -subject -issuer -dates
```

### 7.8 Importing Certificate into Groundplex

#### 7.8.1 Extract Certificate from Running WireMock

```bash
# Extract the certificate that WireMock is actually serving
echo | openssl s_client -connect localhost:8443 \
  -servername salesforce-api-mock 2>/dev/null | \
  openssl x509 > /tmp/wiremock-cert.pem

# Verify extraction was successful
openssl x509 -in /tmp/wiremock-cert.pem -noout -subject
# Should show: subject=CN=salesforce-api-mock
```

#### 7.8.2 Copy Certificate to Groundplex Container

```bash
# Copy certificate into the running Groundplex container
docker cp /tmp/wiremock-cert.pem snaplogic-groundplex:/tmp/wiremock-cert.pem

# Verify the file was copied
docker exec snaplogic-groundplex ls -la /tmp/wiremock-cert.pem
```

#### 7.8.3 Import into Java Truststore

```bash
# Import certificate into Java's truststore
docker exec snaplogic-groundplex bash -c '
  # Find Java installation (version-specific directory)
  JAVA_HOME="/opt/snaplogic/pkgs/jdk-11.0.24+8-jre"

  # Alternative: Dynamically find Java directory
  # JAVA_HOME=$(ls -d /opt/snaplogic/pkgs/jdk* 2>/dev/null | head -1)

  echo "Found Java Home: $JAVA_HOME"

  # Set keytool and truststore paths
  KEYTOOL="$JAVA_HOME/bin/keytool"
  TRUSTSTORE="$JAVA_HOME/lib/security/cacerts"

  # Verify paths exist
  if [ ! -f "$KEYTOOL" ]; then
    echo "ERROR: keytool not found at $KEYTOOL"
    exit 1
  fi

  if [ ! -f "$TRUSTSTORE" ]; then
    echo "ERROR: truststore not found at $TRUSTSTORE"
    exit 1
  fi

  echo "Using keytool: $KEYTOOL"
  echo "Using truststore: $TRUSTSTORE"

  # Import the certificate (password "changeit" is Java default)
  $KEYTOOL -import -trustcacerts \
    -keystore $TRUSTSTORE \
    -storepass changeit \
    -noprompt \
    -alias wiremock-salesforce \
    -file /tmp/wiremock-cert.pem

  echo "Certificate imported successfully!"

  # Clean up
  rm /tmp/wiremock-cert.pem
'
```

> **Note:** The Java path `/opt/snaplogic/pkgs/jdk-11.0.24+8-jre` is version-specific. If your Groundplex uses a different Java version, adjust accordingly or use the dynamic discovery method shown in the comment.

#### 7.8.4 Restart JCC to Apply Changes

```bash
# Restart JCC service (NOT the container — just the JCC process inside)
docker exec snaplogic-groundplex bash -c '
  cd /opt/snaplogic/bin && ./jcc.sh restart
'

# Wait for JCC to restart
echo "Waiting for JCC to restart..."
sleep 60

# Verify JCC is running
docker exec snaplogic-groundplex bash -c '
  cd /opt/snaplogic/bin && ./jcc.sh status
'
```

### 7.9 Verification

#### 7.9.1 Verify Certificate in Truststore

```bash
# Check if certificate is properly imported
docker exec snaplogic-groundplex bash -c '
  JAVA_HOME="/opt/snaplogic/pkgs/jdk-11.0.24+8-jre"
  KEYTOOL="$JAVA_HOME/bin/keytool"
  TRUSTSTORE="$JAVA_HOME/lib/security/cacerts"

  echo "Checking for wiremock certificate in truststore..."
  $KEYTOOL -list -keystore $TRUSTSTORE -storepass changeit 2>/dev/null | grep -i wiremock

  if [ $? -eq 0 ]; then
    echo "✅ Certificate found!"
    # Show certificate details
    $KEYTOOL -list -v -keystore $TRUSTSTORE -storepass changeit -alias wiremock-salesforce 2>/dev/null | \
      grep -E "Alias|Owner|Valid" | head -5
  else
    echo "❌ Certificate not found"
  fi
'
```

#### 7.9.2 Test HTTPS Connection from Inside Groundplex

```bash
# Test connection from inside Groundplex container (no -k flag — should work without it!)
docker exec snaplogic-groundplex curl -v https://salesforce-api-mock:8443/__admin/health
# Should return: {"status":"OK"} without SSL errors
```

#### 7.9.3 Configure SnapLogic Salesforce Account

In SnapLogic Designer:

1. **Create or Edit Salesforce Account**
2. **Configure Settings:**
   - **Login URL:** `https://salesforce-api-mock:8443`
   - **Username:** `slim@snaplogic.com` (any value works)
   - **Password:** Any value
   - **Security Token:** Leave empty
   - **Sandbox:** `true`
3. **Validate the account** — Should show "Account validation successful"

### 7.10 Makefile Shortcuts

| Command | When to Use | What It Does |
|---------|-------------|--------------|
| `make launch-groundplex-with-cert` | Groundplex is **NOT** running | Starts the container **+** imports the certificate |
| `make setup-groundplex-cert` | Groundplex is **already running** | Imports cert into running container (JCC restarts, container stays up) |
| `make groundplex-check-cert` | Anytime | Verify certificate is installed in the truststore |
| `make groundplex-remove-cert` | Cleanup / troubleshooting | Remove certificate from truststore |

> **💡 Already have Groundplex running?** You do **NOT** need to stop it. Just run `make setup-groundplex-cert` — it imports the certificate via `docker exec` and restarts only the JCC process inside the container. The container itself stays running. See [Section 9: Makefile Targets](#9-makefile-targets-how-to-operate-everything) for the full step-by-step for both scenarios.

### 7.11 Alternative Approaches

#### Option 1: Use HTTP Instead of HTTPS (Development Only)

If HTTPS setup is problematic, you can configure the Salesforce account to use HTTP:
- Change Login URL to `http://salesforce-api-mock:8080` instead of `https://...`
- No certificate setup needed
- **⚠️ Only for quick local testing — not realistic for production-like testing**

#### Option 2: Trust All Certificates (Not Recommended)

For development only, disable certificate validation via JVM options:
```bash
# Add to JVM options (INSECURE - DEV ONLY)
-Dcom.sun.net.ssl.checkRevocation=false
-Dtrust.all.cert=true
```
> **⚠️ Never use this in production. It defeats the purpose of SSL/TLS.**

#### Option 3: Use Real Certificates (Production-Like Testing)

For production-like testing, use certificates from Let's Encrypt or your internal CA:
```bash
# Use certbot to get real certificates
certbot certonly --standalone -d your-domain.com

# Then convert to PKCS12
openssl pkcs12 -export \
  -in /etc/letsencrypt/live/your-domain.com/fullchain.pem \
  -inkey /etc/letsencrypt/live/your-domain.com/privkey.pem \
  -out custom-keystore.p12
```

### 7.12 Certificate Security Best Practices

1. **Never commit private keys to version control**
   - Add `*.pem` and `*.p12` to `.gitignore`
   - Use secrets management for production

2. **Use strong passwords for keystores**
   - Don't use `password` in production
   - Store passwords in environment variables

3. **Rotate certificates regularly**
   - Set calendar reminders before the 365-day expiry
   - Automate certificate renewal if possible

4. **Limit certificate scope**
   - Use specific SANs, not wildcards
   - Create separate certificates for different environments

5. **Monitor certificate expiry**
   ```bash
   # Check certificate expiry date
   openssl x509 -in custom-cert.pem -noout -enddate
   # Or from the running server:
   echo | openssl s_client -connect localhost:8443 2>/dev/null | openssl x509 -noout -enddate
   ```

### 7.13 Certificate File Reference

| File | Required? | Purpose |
|------|-----------|---------|
| `custom-keystore.p12` | **Yes** | Contains both private key and certificate. This is the only file WireMock needs. |
| `custom-key.pem` | No (can delete after P12 creation) | Intermediate private key file |
| `custom-cert.pem` | No (can delete after P12 creation) | Intermediate certificate file |

> **Re-extract certificate from P12 if needed:** `openssl pkcs12 -in custom-keystore.p12 -nokeys -out cert.pem -password pass:password`

---

## 8. Configuration Files: What Each File Does

### 8.1 Docker Compose Configuration

**File:** `docker/salesforce/docker-compose.salesforce-mock.yml`

This file is **included** by the main `docker-compose.yml`:
```yaml
# docker-compose.yml (root)
include:
  - docker/salesforce/docker-compose.salesforce-mock.yml
  # ... other services (oracle, postgres, kafka, etc.)
```

**Service: salesforce-mock (WireMock)**
```yaml
salesforce-mock:
  image: wiremock/wiremock:3.3.1
  container_name: salesforce-api-mock
  profiles: [salesforce-mock-start, salesforce-dev]
  ports:
    - "${SALESFORCE_HTTP_PORT:-8089}:8080"     # HTTP
    - "${SALESFORCE_HTTPS_PORT:-8443}:8443"    # HTTPS
  volumes:
    - ./wiremock/mappings:/home/wiremock/mappings:ro
    - ./wiremock/__files:/home/wiremock/__files:ro
    - ./wiremock/certs/custom-keystore.p12:/home/wiremock/keystore.p12:ro
  command: >
    --port=8080 --https-port=8443
    --https-keystore=/home/wiremock/keystore.p12
    --keystore-password=password --keystore-type=PKCS12
    --global-response-templating --verbose
    --disable-banner --enable-stub-cors --preserve-host-header
  healthcheck:
    test: ["CMD-SHELL", "curl -f http://localhost:8080/__admin/health || curl -fk https://localhost:8443/__admin/health"]
    interval: 10s
    timeout: 5s
    retries: 3
```

**Service: salesforce-json-server**
```yaml
salesforce-json-server:
  image: clue/json-server
  platform: linux/amd64                   # Apple Silicon compatibility
  container_name: salesforce-json-mock
  profiles: [salesforce-json-server, salesforce-dev]
  ports:
    - "${SALESFORCE_JSON_PORT:-8082}:80"
  volumes:
    - ./json-db:/data
  command: --watch /data/salesforce-db.json --host 0.0.0.0
```

**Docker Compose profiles explained:**
- `salesforce-mock-start` — starts only WireMock
- `salesforce-json-server` — starts only JSON Server
- `salesforce-dev` — starts both (used by `make salesforce-mock-start`)

### 8.2 Environment Variables

**File:** `env_files/mock_service_accounts/.env.salesforce`

```properties
# Account payload file name (located at test/suite/test_data/accounts_payload/)
SALESFORCE_ACCOUNT_PAYLOAD_FILE_NAME=acc_salesforce.json

# SnapLogic Account Configuration
SALESFORCE_ACCOUNT_NAME=sfdc_acct
SALESFORCE_USERNAME=slim@snaplogic.com
SALESFORCE_PASSWORD=test
SALESFORCE_SECURITY_TOKEN=test
SALESFORCE_LOGIN_URL=https://salesforce-api-mock:8443
SALESFORCE_SANDBOX=true
SALESFORCE_API_VERSION=59.0

# Port Mappings (used in docker-compose.salesforce-mock.yml)
SALESFORCE_HTTP_PORT=8089
SALESFORCE_HTTPS_PORT=8443
SALESFORCE_JSON_PORT=8082
```

**How env files are loaded (from Makefile.common):**
```
1. All .env files from env_files/ directory (sorted alphabetically)
2. Root .env file (HIGHEST PRECEDENCE)
3. Optional: ENV=.env.stage override (HIGHEST PRECEDENCE if specified)
```

This means if `SALESFORCE_LOGIN_URL` is defined in both `.env.salesforce` and root `.env`, the root `.env` value wins.

### 8.3 SnapLogic Account Payload Template

**File:** `test/suite/test_data/accounts_payload/acc_salesforce.json`

```json
{
    "path": "{{ACCOUNT_LOCATION_PATH}}",
    "duplicate_check": true,
    "account": {
        "class_fqid": "com-snaplogic-snaps-salesforce-salesforceaccount_1-441patches31587",
        "property_map": {
            "view_serial": 100,
            "settings": {
                "loginUrl":  { "value": "{{SALESFORCE_LOGIN_URL}}" },
                "sandbox":   { "value": true },
                "username":  { "value": "{{SALESFORCE_USERNAME}}" },
                "password":  { "value": "{{SALESFORCE_PASSWORD}}" }
            },
            "info": {
                "label": { "value": "{{SALESFORCE_ACCOUNT_NAME}}" }
            }
        }
    }
}
```

**What each field means:**

| Field | Purpose | Value in Mock Setup |
|-------|---------|-------------------|
| `path` | Where to create the account in SnapLogic project | Set by `ACCOUNT_LOCATION_PATH` |
| `duplicate_check` | Skip creation if account already exists | `true` |
| `class_fqid` | SnapLogic internal ID for Salesforce Account snap | Fixed value |
| `loginUrl` | Where to authenticate | `https://salesforce-api-mock:8443` |
| `sandbox` | Is this a sandbox org? | `true` |
| `username` | Salesforce username | `slim@snaplogic.com` (any value works with mock) |
| `password` | Salesforce password | `test` (any value works with mock) |
| `label` | Display name for the account | `sfdc_acct` |

### 8.4 JSON Server Data and Routes

**Data file:** `json-db/salesforce-db.json`

Contains three collections:

```
accounts (13 records)
├── Seeded business data:
│   ├── Global Innovations Inc (Partner, Manufacturing, $75M revenue, 1200 employees)
│   └── TechStart Solutions (Prospect, Software, $10M revenue, 50 employees)
├── Test artifacts (created during previous test runs):
│   ├── Direct Test, Container Test, One Second Test, etc.
│   └── Test Account (Customer)
│
contacts (2 records)
├── John Doe (CEO at Acme, john.doe@acme.com)
└── Jane Smith (VP of Sales at Global Innovations)
│
opportunities (1 record)
└── Acme - Enterprise Deal ($500K, Negotiation stage, 75% probability)
```

**Routes file:** `json-db/routes.json`

Maps Salesforce-style REST paths to JSON Server endpoints:
```json
{
  "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account": "/accounts",
  "/services/data/v52.0/sobjects/Account": "/accounts",
  "/services/data/v59.0/sobjects/Account": "/accounts"
}
```

This only works for **direct** requests to JSON Server (port 8082), not for requests proxied through WireMock (see Section 6.4).

### 8.5 HTML Dashboard

**File:** `json-db/jsonserver_data.html`

A web-based dashboard for viewing and managing JSON Server data.

**How to use:**
```bash
open docker/salesforce/json-db/jsonserver_data.html
```

**Features:**
- Displays all accounts, contacts, and opportunities in tables
- Shows record counts in stat cards
- Create Account form (modal dialog)
- Delete buttons for each record
- Raw JSON view of entire database
- Auto-refreshes every 1 second

**Connection:** Connects directly to `http://localhost:8082` (JSON Server host port).

---

## 9. Makefile Targets: How to Operate Everything

All Salesforce targets are defined in `makefiles/mock_services/Makefile.salesforce`:

| Command | What It Does |
|---------|-------------|
| `make salesforce-mock-start` | Start both WireMock and JSON Server, print all endpoints |
| `make salesforce-mock-stop` | Stop and remove both containers and volumes |
| `make salesforce-mock-restart` | Stop + start (with 2-second pause) |
| `make salesforce-mock-status` | Check container status, health checks, test endpoints |
| `make salesforce-mock-clean` | Stop, remove volumes, delete JSON data files |
| `make salesforce-mock-logs` | Show last 20 lines of both WireMock and JSON Server logs |
| `make salesforce-test` | Test OAuth endpoint and JSON Server accounts endpoint |
| `make start-jsonserver` | Start only JSON Server (without WireMock) |
| `make stop-jsonserver` | Stop only JSON Server |
| `make launch-groundplex-with-cert` | Start Groundplex + import certificate |
| `make setup-groundplex-cert` | Import certificate into running Groundplex |
| `make groundplex-check-cert` | Verify certificate is in Groundplex truststore |
| `make groundplex-remove-cert` | Remove certificate from Groundplex truststore |

### Scenario A: Fresh Start (No Groundplex Running)

Use this when you're starting everything from scratch — no Groundplex container is running yet.

```bash
# 1. Start mock services
make salesforce-mock-start

# 2. Start Groundplex WITH certificate (one command does both)
make launch-groundplex-with-cert

# 3. Verify everything
make salesforce-mock-status
make groundplex-check-cert

# 4. Run tests
make robot-run-tests TAGS="sfdc"
```

> **What happens:** `launch-groundplex-with-cert` starts the Groundplex container, waits for it to be healthy, then imports the self-signed certificate into the JCC's Java truststore and restarts JCC.

### Scenario B: Existing Groundplex Already Running

Use this when Groundplex is **already running** (e.g., you started it earlier for Oracle/Postgres tests) and you now want to add the Salesforce mock certificate.

> **⚠️ You do NOT need to stop the Groundplex.** The certificate import happens on the live container. Only the JCC process restarts inside the container — the container itself stays running.

```bash
# 1. Start mock services (if not already running)
make salesforce-mock-start

# 2. Import certificate into the RUNNING Groundplex (no restart of container)
make setup-groundplex-cert

# 3. Verify certificate was imported
make groundplex-check-cert

# 4. Run tests
make robot-run-tests TAGS="sfdc"
```

> **What happens:** `setup-groundplex-cert` uses `docker exec` to run `keytool -importcert` inside the already-running Groundplex container, importing the WireMock self-signed certificate into the JCC's Java truststore (`cacerts`). It then restarts the JCC process (`jcc.sh restart`) — **only the JCC process restarts, NOT the container**. The Groundplex container remains running throughout.

### Key Difference: `launch-groundplex-with-cert` vs `setup-groundplex-cert`

| Command | When to Use | What It Does |
|---------|-------------|--------------|
| `make launch-groundplex-with-cert` | Groundplex is **NOT** running | Starts the Groundplex container **+** imports the certificate |
| `make setup-groundplex-cert` | Groundplex is **already running** | Imports the certificate into the **running** container (JCC restarts, container stays up) |

> **💡 Tip:** If you're unsure whether Groundplex is running, check with:
> ```bash
> docker ps | grep snaplogic-groundplex
> ```
> - If it shows a running container → use `make setup-groundplex-cert`
> - If no output → use `make launch-groundplex-with-cert`

---

## 10. Complete Directory Structure

```
{{cookiecutter.primary_pipeline_name}}/
│
├── docker-compose.yml                         # Main compose (includes salesforce)
├── Makefile                                   # Main Makefile (includes Makefile.salesforce)
├── .env                                       # Root env file (highest precedence)
│
├── makefiles/
│   ├── common_services/
│   │   └── Makefile.common                    # Shared variables, DOCKER_COMPOSE definition
│   └── mock_services/
│       └── Makefile.salesforce                # All salesforce-* make targets
│
├── env_files/
│   └── mock_service_accounts/
│       └── .env.salesforce                    # Salesforce env vars (credentials, ports)
│
├── docker/
│   └── salesforce/
│       ├── docker-compose.salesforce-mock.yml # Service definitions
│       │
│       ├── wiremock/
│       │   ├── __files/                       # (empty) WireMock static files
│       │   ├── certs/
│       │   │   └── custom-keystore.p12        # Self-signed SSL certificate
│       │   ├── mappings/
│       │   │   ├── 01-oauth-token.json        # OAuth authentication
│       │   │   ├── 02-validation-query.json   # SnapLogic account validation
│       │   │   ├── 03-describe-account.json   # Account metadata/schema
│       │   │   ├── 04-create-account.json     # Create account (static)
│       │   │   ├── 05-read-account-query.json # Query accounts (static)
│       │   │   └── create-account-proxy.disabled  # (disabled) Proxy to JSON Server
│       │   └── docs/
│       │       ├── JSON_SERVER_WORKFLOW.md     # How JSON Server persistence works
│       │       ├── MOCK_SERVICES_TESTING_GUIDE.md  # Advantages/limitations of mocks
│       │       ├── WHY_JSON_SERVER_DOESNT_WORK.md  # Why proxy approach fails
│       │       └── oauth_account_validation_details.md  # Minimum mappings needed
│       │
│       └── json-db/
│           ├── salesforce-db.json             # Persistent data (accounts, contacts, opps)
│           ├── routes.json                    # Salesforce URL → JSON Server path mapping
│           └── jsonserver_data.html           # Web dashboard for JSON Server
│
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── salesforce/
│       │       └── sfdc.robot                 # Robot Framework test suite
│       └── test_data/
│           └── accounts_payload/
│               └── acc_salesforce.json        # SnapLogic account payload template
│
└── README/
    └── How To Guides/
        └── infra_setup_guides/
            └── salesforce/
                ├── wiremock_https_certificate_setup.md  # Full HTTPS setup guide
                └── README/
                    ├── puml/
                    │   ├── salesforce-mock-components.puml      # Architecture diagram
                    │   ├── wiremock-matching-flowchart.puml     # Request matching flow
                    │   └── wiremock-routing-decision-flow.puml  # Stateless vs stateful
                    └── stateless vs stateful workflow.html      # Visual comparison
```

---

## 11. How Everything Connects: The Integration Map

### 11.1 Makefile Include Chain

```
Makefile (root)
├── include makefiles/common_services/Makefile.common
│   └── Defines DOCKER_COMPOSE variable with all --env-file flags
│   └── Defines COMPOSE_PROFILES (includes salesforce-mock-start)
│
├── include makefiles/mock_services/Makefile.salesforce
│   └── include makefiles/common_services/Makefile.common (guarded)
│   └── Uses $(DOCKER_COMPOSE) for all docker compose commands
│
└── include makefiles/mock_services/Makefile.minio
    include makefiles/mock_services/Makefile.maildev
    include makefiles/database_services/Makefile.oracle
    ... (other services)
```

### 11.2 Docker Compose Include Chain

```
docker-compose.yml (root)
├── include: docker/salesforce/docker-compose.salesforce-mock.yml
│   ├── Service: salesforce-mock (WireMock)
│   └── Service: salesforce-json-server
│
├── include: docker/groundplex/docker-compose.groundplex.yml
│   └── Service: groundplex
│
├── include: docker/oracle/docker-compose.oracle.yml
│   ... (other database/service includes)
│
├── Service: tools (Robot Framework container)
│
└── Network: snaplogicnet (bridge) ← All services connect here
```

### 11.3 Environment Variable Flow

```
.env.salesforce (env_files/mock_service_accounts/)
    │
    │  Defines:
    │  ├── SALESFORCE_LOGIN_URL=https://salesforce-api-mock:8443
    │  ├── SALESFORCE_USERNAME=slim@snaplogic.com
    │  ├── SALESFORCE_HTTP_PORT=8089
    │  └── ... etc
    │
    ├──────► docker-compose.salesforce-mock.yml
    │        Uses: ${SALESFORCE_HTTP_PORT:-8089}:8080
    │        Uses: ${SALESFORCE_HTTPS_PORT:-8443}:8443
    │
    ├──────► acc_salesforce.json (account payload template)
    │        Uses: {{SALESFORCE_LOGIN_URL}}, {{SALESFORCE_USERNAME}}, etc.
    │
    └──────► sfdc.robot (test file)
             Uses: ${SALESFORCE_ACCOUNT_PAYLOAD_FILE_NAME}
             Uses: ${SALESFORCE_ACCOUNT_NAME}
```

### 11.4 Test Execution Chain

```
make robot-run-tests TAGS="sfdc"
    │
    ├── Starts tools container (Robot Framework)
    │
    ├── Robot loads sfdc.robot
    │   ├── Suite Setup: Check connections
    │   │   └── Wait Until Plex Status Is Up (Groundplex must be running)
    │   │
    │   └── Test: Create Account
    │       ├── Reads acc_salesforce.json template
    │       ├── Substitutes env vars (LOGIN_URL, USERNAME, etc.)
    │       └── Calls SnapLogic API to create the account
    │           │
    │           └── SnapLogic validates the account:
    │               ├── POST /services/oauth2/token → WireMock → 01-oauth-token.json
    │               ├── GET  /services/data/v52.0/query?q=SELECT... → WireMock → 02-validation-query.json
    │               └── Account validated ✅
    │
    └── (Additional test cases would execute pipelines using the account)
```

---

## 12. Advantages and Limitations of Mock Testing

### 12.1 Advantages

| Category | Benefit |
|----------|---------|
| **Speed** | Instant responses, no network latency, no API rate limits |
| **Cost** | Free to run, no API call charges or subscription fees |
| **Predictability** | Same input always produces same output — deterministic tests |
| **Independence** | Tests run without internet connectivity |
| **Safety** | Cannot accidentally delete real customer data |
| **CI/CD** | Works in any environment that has Docker |
| **Version Control** | Mock definitions stored in Git alongside test code |

### 12.2 What Mock Testing PROVES (Specifically for Accounts)

When your mock tests pass, here is **exactly** what you've validated:

#### ✅ 1. End-to-End Connectivity
```
Your Pipeline → Groundplex → Docker Network → WireMock (HTTPS on 8443)
```
Proves: Groundplex can resolve `salesforce-api-mock` hostname, SSL/TLS handshake works, HTTPS port 8443 is reachable, the network path is healthy.

#### ✅ 2. OAuth Token Flow
```
Pipeline: "I need to log in"
    → POST /services/oauth2/token
    → Gets back access_token
    → Uses that token for subsequent calls
```
Proves: Your pipeline correctly handles the OAuth flow — sends credentials, receives a token, and attaches it to future API calls.

#### ✅ 3. Account Validation Handshake
```
SnapLogic: "Let me verify this account is valid"
    → POST /services/oauth2/token        ✅ Token received
    → GET /services/data/v52.0/query?q=SELECT Name FROM Account LIMIT 1  ✅ Got result
    → "Account is valid!"
```
Proves: Your SnapLogic account configuration (Login URL, Username, Password, API version, Sandbox flag) is **structurally correct** and the validation handshake completes.

#### ✅ 4. Snap Sends the Correct URL Format
```
Create Snap sends: POST /services/data/v59.0/sobjects/Account
Mapping expects:   POST /services/data/v[0-9]+\.[0-9]+/sobjects/Account
                   ✅ Match!
```
Proves: The Snap builds the correct Salesforce REST API URL. If you accidentally configured the Snap for `Contact` instead of `Account`, or had a corrupted API version — you'd catch it here.

#### ✅ 5. Response Parsing Works
```
WireMock returns:  { "id": "001000000000TEST01", "success": true, "errors": [] }
Snap receives it:  Parses the JSON, extracts the ID, marks operation as successful
```
Proves: Your pipeline correctly handles a `201 Created` response. Downstream Snaps can read the returned ID.

#### ✅ 6. Account Payload Template Works
```
acc_salesforce.json template:
  "Login URL":  "{{SALESFORCE_LOGIN_URL}}"     → https://salesforce-api-mock:8443  ✅
  "Username":   "{{SALESFORCE_USERNAME}}"       → slim@snaplogic.com               ✅
  "Password":   "{{SALESFORCE_PASSWORD}}"       → test                             ✅
```
Proves: Environment variable substitution works. The template is valid JSON. All required account fields are present.

#### ✅ 7. Robot Framework Orchestration Works
```
Robot Framework:
  1. Starts mock services          ✅
  2. Creates SnapLogic account     ✅
  3. Validates account             ✅
  4. Runs pipeline                 ✅
  5. Checks results                ✅
```
Proves: Your entire CI/CD test automation chain works end-to-end.

#### ✅ 8. CRUD Data Persistence (via Webhook Bridge)
```
Pipeline/curl sends:  POST /services/data/v59.0/sobjects/Account
                      Body: {"Name": "Acme Corp", "Type": "Customer", "Industry": "Technology"}

WireMock returns:     {"id": "001AB...", "success": true, "errors": []}  ← Salesforce format
Webhook fires:        POST http://salesforce-json-mock/accounts          ← same data
JSON Server stores:   {"Name": "Acme Corp", "Type": "Customer", "Industry": "Technology", "id": "xK7..."}

Verify:               curl http://localhost:8082/accounts?Name=Acme+Corp  ✅ Data persisted!
```
Proves: Account data sent through the pipeline is **actually persisted** in JSON Server. You can verify field values, record counts, and data integrity — not just that the pipeline "ran successfully."

**What CRUD verification covers:**

| Verification | How | Example |
|-------------|-----|---------|
| **Data was created** | Check JSON Server record count increased | `curl http://localhost:8082/accounts` |
| **Field values are correct** | Query by field name, verify values match | `curl http://localhost:8082/accounts?Name=Acme+Corp` |
| **Data persists to disk** | Check `salesforce-db.json` file | `cat docker/salesforce/json-db/salesforce-db.json` |
| **Multiple records work** | Create several, verify all appear | Count before vs after |
| **Read back works** | GET from JSON Server after Create | `curl http://localhost:8082/accounts/{id}` |

> **Note:** CRUD verification uses the **webhook bridge** (`serveEventListeners` in `04-create-account.json`). See [Section 12.8](#128-wiremock--json-server-webhook-bridge) for full details on how the webhook works.

**Summary — when mock tests pass you can confidently say:**
```
✅ "My pipeline is wired correctly"
✅ "My SnapLogic account config is structurally valid"
✅ "OAuth token flow completes"
✅ "Account validation handshake works"
✅ "Create Snap sends the right URL to the right endpoint"
✅ "My pipeline can parse Salesforce-format responses"
✅ "SSL certificates are properly trusted"
✅ "My entire CI/CD automation chain works end-to-end"
✅ "Account data actually persisted via webhook to JSON Server"
✅ "Field values match what the pipeline sent"
✅ "Nothing is broken in MY code"
```

### 12.3 What Mock Testing CANNOT Catch

These are things WireMock **hides from you** — they will pass in mock but can fail in real Salesforce:

#### Three Categories of Failures

**Category 1: Failures BEFORE reaching the URL → Both real and mock fail ❌**

| Problem | Real SF | Mock |
|---------|:-------:|:----:|
| Snap configuration error (wrong field mapping) | ❌ | ❌ |
| Pipeline logic error (bad expression, null input) | ❌ | ❌ |
| Missing required field in the input document | ❌ | ❌ |
| SnapLogic account not configured | ❌ | ❌ |
| Groundplex is down | ❌ | ❌ |

> These fail before any HTTP request is sent. Mock catches these just like real Salesforce would.

**Category 2: Failures AT the server → Mock PASSES ✅, Real FAILS ❌**

This is the **most dangerous category** — things that work in mock but break in production:

| Problem | Real SF | Mock | Real Salesforce Error |
|---------|:-------:|:----:|----------------------|
| Duplicate record | ❌ | ✅ | `DUPLICATE_VALUE` |
| Required field missing in body | ❌ | ✅ | `REQUIRED_FIELD_MISSING` |
| Field-level security blocks access | ❌ | ✅ | `INSUFFICIENT_ACCESS` |
| Invalid picklist value | ❌ | ✅ | `INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST` |
| Validation rule fails | ❌ | ✅ | Custom validation message |
| Record type enforcement | ❌ | ✅ | `INVALID_RECORD_TYPE` |
| Apex trigger rejects data | ❌ | ✅ | Trigger error message |
| Field length exceeded (Name > 255 chars) | ❌ | ✅ | `STRING_TOO_LONG` |
| Data type mismatch | ❌ | ✅ | `INVALID_TYPE` |
| Governor limits hit | ❌ | ✅ | `LIMIT_EXCEEDED` |
| API rate limit exceeded | ❌ | ✅ | `REQUEST_LIMIT_EXCEEDED` |
| Cross-object relationship invalid | ❌ | ✅ | `INVALID_CROSS_REFERENCE_KEY` |
| Sharing rule violation | ❌ | ✅ | `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` |
| Salesforce down / maintenance | ❌ | ✅ | Connection timeout |
| Auth credentials expired | ❌ | ✅ | `INVALID_SESSION_ID` |

**Example of the trap:**
```
Your Pipeline:  "Create Account: Name = Acme Corp"

WireMock says:  "Sure! Here's ID 001000000000TEST01"  ✅
                (doesn't care what you sent, always says yes)

Real Salesforce: "REJECTED! 'Acme Corp' already exists.
                  Duplicate rule violation."  ❌
```

WireMock **always returns the same canned response** — it doesn't look at the request body, doesn't check for duplicates, doesn't enforce any business rules.

**Category 3: Failures BETWEEN Snap and server → Depends on the issue**

| Problem | Real SF | Mock |
|---------|:-------:|:----:|
| SSL/Certificate error | ❌ | ❌ (if cert not imported) or ✅ (if cert imported) |
| DNS resolution failure | ❌ | ❌ (if Docker network broken) or ✅ (if Docker healthy) |
| Wrong API version in URL | ❌ | ✅ (regex matches any version!) |
| Network firewall blocks connection | ❌ | ✅ (all local, no firewall) |

### 12.4 The Pre-Flight Checklist Analogy

```
Mock Testing = Pre-flight Checklist ✈️

  ✅ Does the engine start?              (Pipeline executes)
  ✅ Do the instruments work?            (Snap configurations are valid)
  ✅ Is the radio working?               (Network/SSL connectivity)
  ✅ Can the pilot talk to the tower?    (OAuth + Account validation)
  ✅ Are the flight controls responding? (API URLs match, responses parse)

  ❌ Will there be turbulence?           (Salesforce business rules)
  ❌ Is the runway clear?                (Duplicate records)
  ❌ Will customs let you in?            (Field-level security)
  ❌ Is the weather good enough?         (API rate limits, server load)
```

You wouldn't fly without a pre-flight check, even though it doesn't guarantee a smooth flight. Mocks catch the "plane won't even start" problems **instantly, for free, with no dependencies**.

### 12.5 The Testing Pyramid

```
                    ┌─────────────┐
                    │ Production  │  ← Real Salesforce (live data)
                    │ (Real APIs) │
                    ├─────────────┤
                ┌───┤  Staging    │  ← Salesforce Sandbox (integration)
                │   │ (Sandbox)   │
                │   ├─────────────┤
            ┌───┤   │ Development │  ← Mock Services (speed)  ← YOU ARE HERE
            │   │   │ (Mocks)     │
            │   │   └─────────────┘
            │   │
    Speed   │   │   Confidence
    ◄───────┘   └───────────►
```

### 12.6 The Golden Rule

**Mock for speed, sandbox for confidence, production for reality.**

- **Mock** = "My code works" (pipeline plumbing, connectivity, config, URL format, response handling)
- **Sandbox** = "Salesforce agrees" (business rules, validation, security, triggers)
- **Production** = "Reality works" (real data volumes, real users, real integrations)

### 12.7 The Functional Testing Gap — What Mocks Still Cannot Verify

WireMock alone returns **canned responses** — it doesn't validate request data or enforce business rules. However, the **Webhook Bridge** (see [Section 12.8](#128-wiremock--json-server-webhook-bridge)) now covers basic CRUD verification by persisting Account data to JSON Server. This section explains what's covered and what still requires a real Salesforce sandbox.

#### WireMock's Canned Responses (Without Webhook Bridge)

WireMock returns **the same response** regardless of what data you send:

```
Send "Acme Corp" with BillingCity = "San Francisco"
  → WireMock returns: {"id": "001xx...", "success": true, "errors": []}

Send "" (empty name) with no other fields
  → WireMock returns: {"id": "001xx...", "success": true, "errors": []}  ← SAME RESPONSE!

Send complete garbage {"xyz": 123}
  → WireMock returns: {"id": "001xx...", "success": true, "errors": []}  ← STILL SAME!
```

WireMock only matches HTTP method + URL pattern, then returns the mapping response. It does **not validate request data**. However, the **webhook bridge forwards the request body to JSON Server**, so the data **is** stored and can be verified — even though WireMock itself doesn't validate it.

#### What "Functional Data Verification" Means

Functional testing verifies that the **data itself** is correct — not just that the plumbing works. Some of these are now covered by the **Webhook Bridge** (see [Section 12.8](#128-wiremock--json-server-webhook-bridge)), but others still require a real Salesforce sandbox:

| Verification Type | What It Checks | With Webhook Bridge |
|-------------------|---------------|:---:|
| **Record creation** | Did the Account record actually get created? | ✅ JSON Server stores it |
| **Field value accuracy** | Is `Name = "Acme Corp"` and `BillingCity = "San Francisco"`? | ✅ Query JSON Server by field |
| **Field data types** | Is `AnnualRevenue` stored as a number, not a string? | ⚠️ JSON Server stores as-is (no schema) |
| **Record count** | Were exactly 5 Accounts created (not 4, not 6)? | ✅ Count records in JSON Server |
| **Record relationships** | Is the Contact linked to the right Account via `AccountId`? | ❌ No referential integrity checks |
| **Record updates** | Did the update change `BillingCity` from "LA" to "SF"? | ✅ Update logged in `/account_updates` with changed fields |
| **Record deletion** | Is the Account actually gone after DELETE? | ✅ Deletion logged in `/account_deletes` with Salesforce ID |
| **Query results** | Does SOQL `SELECT Name FROM Account WHERE Id='xxx'` return the right data? | ❌ Returns static response for SOQL queries |
| **Bulk operations** | Did all 1000 records in the bulk insert succeed? | ❌ Returns one canned response, not per-record |
| **Calculated fields** | Did the formula field `FullAddress` compute correctly? | ❌ No formula engine |
| **Workflow side effects** | Did the "Welcome Email" workflow fire after Account creation? | ❌ No workflow engine |
| **Audit trail** | Is `CreatedBy`, `CreatedDate`, `LastModifiedBy` correct? | ❌ No audit tracking |

#### The Delivery Truck Analogy

```
Mock Testing = Testing the DELIVERY TRUCK
─────────────────────────────────────────
  ✅ Can the truck start?                  (Pipeline executes)
  ✅ Does it know the address?             (URL format is correct)
  ✅ Does it have the right keys?          (OAuth token works)
  ✅ Can it reach the warehouse door?      (Network/SSL connectivity)
  ✅ Did the warehouse give a receipt?     (Response parsed successfully)

Functional Testing = Testing the PACKAGE CONTENTS
─────────────────────────────────────────────────
  ✅ Is the right item inside?             (Field values correct? — YES, via webhook bridge!)
  ✅ Is the quantity correct?              (Record count correct? — YES, check JSON Server!)
  ❌ Is it damaged?                        (Data integrity intact? — needs real Salesforce)
  ❌ Does it match the order?              (Business rules satisfied? — needs real Salesforce)
  ❌ Was it placed on the right shelf?     (Relationships correct? — needs real Salesforce)

Mock + Webhook Bridge can confirm the truck arrived, got a receipt, AND the package was stored.
But it CANNOT confirm business rules, triggers, or permissions inside the real warehouse.
```

#### What Real Functional Testing Looks Like (Salesforce Account Example)

To truly verify that an Account was created correctly, you'd need to test against a **real Salesforce sandbox**:

```
Step 1: CREATE — Send Account data via pipeline
  POST /services/data/v59.0/sobjects/Account
  Body: {"Name": "Acme Corp", "BillingCity": "San Francisco", "Industry": "Technology"}
  → Response: {"id": "001xx000003REAL1", "success": true}

Step 2: QUERY BACK — Verify the data was actually stored
  GET /services/data/v59.0/query?q=SELECT+Name,BillingCity,Industry+FROM+Account+WHERE+Id='001xx000003REAL1'
  → Response: {"records": [{"Name": "Acme Corp", "BillingCity": "San Francisco", "Industry": "Technology"}]}

Step 3: ASSERT — Compare actual vs expected
  Assert Name       == "Acme Corp"          ✅
  Assert BillingCity == "San Francisco"      ✅
  Assert Industry    == "Technology"         ✅

Step 4: CLEANUP — Delete test data
  DELETE /services/data/v59.0/sobjects/Account/001xx000003REAL1
```

**None of these steps are possible with WireMock** because:
- Step 2 would return the same canned query response regardless of what was created in Step 1
- There's no state between requests — WireMock doesn't remember anything
- The query response is hardcoded, not generated from actual data

#### Side-by-Side: Mock vs Real for Account Operations

| Operation | With Webhook Bridge | Needs Real Salesforce |
|-----------|:---:|:---:|
| **Create Account** | ✅ Data persisted in JSON Server, fields verifiable | Business rules, triggers, duplicate checks |
| **Read Account** | ✅ Can read back from JSON Server by field query | SOQL queries, relationship traversal |
| **Update Account** | ✅ Update logged to JSON Server with changed fields | Before/after state verification |
| **Delete Account** | ✅ Delete logged to JSON Server with Salesforce ID | Confirm record is gone |
| **Query Accounts** | ❌ Static SOQL response | Real SOQL query execution |
| **Bulk Create** | ❌ Single canned response | Per-record results |

#### WireMock Always Returns Success

WireMock does **not validate** anything about the request. It matches the URL pattern and returns the canned response regardless of what data you send:

```bash
# Empty body — still returns 201 success
curl -s -X POST http://localhost:8089/services/data/v59.0/sobjects/Account \
  -H "Content-Type: application/json" -d '{}'

# Wrong fields — still returns 201 success
curl -s -X POST http://localhost:8089/services/data/v59.0/sobjects/Account \
  -H "Content-Type: application/json" -d '{"Nonsense": "xyz"}'
```

| What Mock Testing CATCHES | What Mock Testing CANNOT Catch |
|:---|:---|
| ✅ Pipeline can't connect (wrong URL, SSL, network) | ❌ Required fields missing (e.g. Account without Name) |
| ✅ OAuth flow is misconfigured | ❌ Invalid field names |
| ✅ Response parsing fails | ❌ Wrong data types (string where number expected) |
| ✅ Pipeline crashes during execution | ❌ Duplicate records |
| ✅ Account/Snap configuration is wrong | ❌ Business rule violations |
| ✅ Data persisted via webhook (field values, counts) | ❌ Invalid picklist values |

> **In short:** Mock testing catches **plumbing failures** (is the pipeline wired correctly?), not **data failures** (is the data valid?). It's like testing that a letter gets to the post office — not that the letter contains the right content.

#### SOQL Query Responses Are Static

The query mappings (files 05, 11, 17, 23, 29) return **hardcoded responses**. No matter what fields, WHERE clause, ORDER BY, or LIMIT you put in the SOQL query, WireMock returns the **same fixed response**. It does not parse SOQL or query JSON Server dynamically.

```bash
# These ALL return the exact same canned response:
curl "http://localhost:8089/services/data/v59.0/query?q=SELECT+Name+FROM+Account"
curl "http://localhost:8089/services/data/v59.0/query?q=SELECT+Name+FROM+Account+WHERE+Name='Acme'"
curl "http://localhost:8089/services/data/v59.0/query?q=SELECT+Id,Name,Industry+FROM+Account+LIMIT+100"
```

| What's NOT Possible with WireMock Queries |
|:---|
| ❌ **Dynamic SOQL parsing** — `WHERE Name = 'Acme'` is ignored, same response returned |
| ❌ **Returning webhook-created data** — Data persisted via webhook to JSON Server is NOT queryable through WireMock's SOQL endpoint |
| ❌ **Filtering, sorting, or limiting** — `ORDER BY`, `LIMIT`, `OFFSET` have no effect |
| ❌ **Cross-object queries** — `SELECT Account.Name FROM Contact` returns the same single-object response |
| ❌ **Aggregate queries** — `SELECT COUNT(Id) FROM Account` returns the same record response |
| ❌ **Dynamic record counts** — `totalSize` is always hardcoded (typically `1`) |

> **Why?** WireMock is a **URL pattern matcher**, not a query engine. It sees the SOQL as a query string parameter and matches it using `contains: "Account"` (or "Contact", etc.). It has no ability to parse SQL-like syntax, execute logic, or return dynamic results.

> **Workaround:** If your pipeline runs a **known, predictable SOQL query**, you can create additional mapping files with more specific `contains` matchers to return tailored responses for specific queries. WireMock picks the most specific match.

#### When You Need Functional Testing

```
Mock Testing is SUFFICIENT when:
  ✅ You're in early development (building pipelines)
  ✅ You're running CI/CD pipeline checks (speed matters)
  ✅ You're testing connectivity and configuration
  ✅ You're onboarding new developers

Functional Testing is REQUIRED when:
  ❌ You need to verify data accuracy before go-live
  ❌ You're running UAT (User Acceptance Testing)
  ❌ You're validating business rules and workflows
  ❌ You're testing data migration correctness
  ❌ You need to prove compliance (audit, SOX, GDPR)
  ❌ You're testing cross-object relationships
```

#### The Complete Testing Strategy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE TESTING STRATEGY                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  LAYER 1: Mock Testing (This Project) ← Fast, Free, Automated          │
│  ─────────────────────────────────────                                  │
│  ✅ Pipeline plumbing         ✅ OAuth flow                             │
│  ✅ URL format                ✅ Response parsing                       │
│  ✅ SSL/TLS connectivity      ✅ Account configuration                  │
│  Runs: Every commit, every CI build, every developer push              │
│                                                                         │
│  LAYER 2: Sandbox Functional Testing ← Slow, Limited, Real Data        │
│  ────────────────────────────────────                                   │
│  ✅ Data creation verified    ✅ Business rules enforced                │
│  ✅ Field values correct      ✅ Workflows/triggers fire                │
│  ✅ Relationships valid       ✅ Permissions respected                  │
│  Runs: Before releases, during UAT, scheduled nightly                  │
│                                                                         │
│  LAYER 3: Production Validation ← Real World, Monitored                 │
│  ───────────────────────────────                                        │
│  ✅ Real data volumes         ✅ Real user permissions                  │
│  ✅ Real integrations         ✅ Real network conditions                │
│  Runs: Post-deployment smoke tests, monitoring dashboards              │
│                                                                         │
│  ⚡ Speed decreases as you go up │ 🎯 Confidence increases as you go up │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

> **Bottom Line:** Mock testing catches "the plane won't start" problems instantly. With the **webhook bridge**, it can now also verify that **Account data was created and stored correctly** in JSON Server. But for business rules, triggers, permissions, and complex queries, you still need a **real Salesforce sandbox**.

### 12.8 WireMock → JSON Server Webhook Bridge

WireMock's built-in webhook feature (`serveEventListeners`) connects WireMock and JSON Server. When SnapLogic (or curl, or Robot Framework) creates an Account through WireMock, the data **automatically flows to JSON Server** for persistence and functional verification. No custom JARs, no middleware, no Docker image changes — this uses WireMock 3.3.1's built-in webhook support.

#### How It Works: `serveEventListeners` (Webhooks)

WireMock fires a secondary HTTP call to JSON Server **after** returning the main Salesforce-formatted response to the caller.

```
THE WEBHOOK BRIDGE FLOW:
════════════════════════

  SnapLogic / curl / Robot Framework
       │
       │  POST /services/data/v59.0/sobjects/Account
       │  Body: {"Name": "Acme Corp", "Type": "Customer", "Industry": "Technology"}
       ▼
  ┌─────────────────────────────────────────────────────────────┐
  │  WireMock (salesforce-api-mock, port 8089/8443)             │
  │                                                             │
  │  ① Matches 04-create-account.json mapping                  │
  │  ② Builds response with dynamic ID via response-template   │
  │  ③ Returns 201 to caller immediately                       │
  │  ④ THEN fires webhook to JSON Server (async, ~50ms)        │
  └─────────┬───────────────────────────┬───────────────────────┘
            │                           │
     ③ Response back             ④ Webhook fires
     to caller                     POST /accounts
            │                           │
            ▼                           ▼
  Caller receives:            ┌─────────────────────────┐
  {                           │  JSON Server (port 8082) │
    "id": "001AB...",         │                         │
    "success": true,          │  ⑤ Saves to memory      │
    "errors": []              │  ⑥ Writes to disk       │
  }                           │    (salesforce-db.json)  │
                              └─────────────────────────┘
```

#### Create Account Mapping: `04-create-account.json`

```json
{
  "priority": 1,
  "name": "Create Account - Persist to JSON Server via Webhook",
  "request": {
    "method": "POST",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account"
  },
  "response": {
    "status": 201,
    "headers": { "Content-Type": "application/json" },
    "jsonBody": {
      "id": "001{{randomValue type='ALPHANUMERIC' length=15 uppercase=true}}",
      "success": true,
      "errors": []
    },
    "transformers": ["response-template"]
  },
  "serveEventListeners": [
    {
      "name": "webhook",
      "parameters": {
        "method": "POST",
        "url": "http://salesforce-json-mock/accounts",
        "headers": { "Content-Type": "application/json" },
        "body": "{{originalRequest.body}}"
      }
    }
  ]
}
```

**Key details:**
- `randomValue type='ALPHANUMERIC' length=15` generates a unique Salesforce-style ID per call
- `"transformers": ["response-template"]` enables Handlebars templating in the response
- `originalRequest.body` (not `request.body`) — this is a webhook-specific variable in WireMock 3.x
- The webhook fires **asynchronously** after the response is sent (~50ms delay)

#### Read Account Mapping: `06-read-single-account.json`

Reads a single Account by ID from the URL path:

```json
{
  "priority": 1,
  "name": "Read Single Account by ID",
  "request": {
    "method": "GET",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account/[A-Za-z0-9]+"
  },
  "response": {
    "status": 200,
    "headers": { "Content-Type": "application/json" },
    "body": "{\"attributes\":{\"type\":\"Account\",\"url\":\"{{request.path}}\"},\"Id\":\"{{request.pathSegments.[5]}}\", ...}",
    "transformers": ["response-template"]
  }
}
```

`{{request.pathSegments.[5]}}` extracts the Account ID from the URL (6th segment: `/services/data/v59.0/sobjects/Account/{ID}`).

#### Update Account Mapping: `07-update-account.json`

Logs Account updates to a separate `/account_updates` collection in JSON Server:

```json
{
  "priority": 1,
  "name": "Update Account - Log to JSON Server via Webhook",
  "request": {
    "method": "PATCH",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account/[A-Za-z0-9]+"
  },
  "response": {
    "status": 204,
    "transformers": ["response-template"]
  },
  "serveEventListeners": [
    {
      "name": "webhook",
      "parameters": {
        "method": "POST",
        "url": "http://salesforce-json-mock/account_updates",
        "headers": { "Content-Type": "application/json" },
        "body": "{\"_sfId\": \"{{request.pathSegments.[5]}}\", \"_operation\": \"UPDATE\", \"_timestamp\": \"{{now}}\", \"_updatedFields\": {{originalRequest.body}} }"
      }
    }
  ]
}
```

- Salesforce returns **204 No Content** for successful PATCH
- Webhook logs the Salesforce ID (from URL), timestamp, and the updated fields to `/account_updates`
- Verify: `curl http://localhost:8082/account_updates`

#### Delete Account Mapping: `08-delete-account.json`

Logs Account deletions to a separate `/account_deletes` collection in JSON Server:

```json
{
  "priority": 1,
  "name": "Delete Account - Log to JSON Server via Webhook",
  "request": {
    "method": "DELETE",
    "urlPathPattern": "/services/data/v[0-9]+\\.[0-9]+/sobjects/Account/[A-Za-z0-9]+"
  },
  "response": {
    "status": 204,
    "transformers": ["response-template"]
  },
  "serveEventListeners": [
    {
      "name": "webhook",
      "parameters": {
        "method": "POST",
        "url": "http://salesforce-json-mock/account_deletes",
        "headers": { "Content-Type": "application/json" },
        "body": "{\"_sfId\": \"{{request.pathSegments.[5]}}\", \"_operation\": \"DELETE\", \"_timestamp\": \"{{now}}\"}"
      }
    }
  ]
}
```

- DELETE requests have no body, so only the Salesforce ID and timestamp are captured
- Verify: `curl http://localhost:8082/account_deletes`

> **Why separate collections?** WireMock webhooks are single HTTP calls — they can't look up a JSON Server record ID first and then PATCH/DELETE it. So Update and Delete operations POST audit log entries to their own collections, queryable by Salesforce ID: `curl http://localhost:8082/account_updates?_sfId=001ABC...`

#### Complete Mapping Inventory (All 32 Files)

##### Common (Shared by All Objects)

| # | File | Method | URL Pattern | Purpose | Webhook? |
|---|------|--------|-------------|---------|:--------:|
| 01 | `01-oauth-token.json` | POST | `/services/oauth2/token` | Returns mock Bearer token | — |
| 02 | `02-validation-query.json` | GET | `/services/data/v52.0/query/` | SnapLogic account validation | — |

##### Account (files 03–08)

| # | File | Method | URL Pattern | Purpose | Webhook Target |
|---|------|--------|-------------|---------|:--------:|
| 03 | `03-describe-account.json` | GET | `/sobjects/Account/describe` | Account object schema | — |
| 04 | `04-create-account.json` | POST | `/sobjects/Account` | **Creates account** | **✅ `/accounts`** |
| 05 | `05-read-account-query.json` | GET | `/query.*` (contains Account) | SOQL query results | — |
| 06 | `06-read-single-account.json` | GET | `/sobjects/Account/{id}` | Read single account by ID | — |
| 07 | `07-update-account.json` | PATCH | `/sobjects/Account/{id}` | **Logs update** | **✅ `/account_updates`** |
| 08 | `08-delete-account.json` | DELETE | `/sobjects/Account/{id}` | **Logs deletion** | **✅ `/account_deletes`** |

##### Contact (files 09–14)

| # | File | Method | URL Pattern | Purpose | Webhook Target |
|---|------|--------|-------------|---------|:--------:|
| 09 | `09-describe-contact.json` | GET | `/sobjects/Contact/describe` | Contact object schema | — |
| 10 | `10-create-contact.json` | POST | `/sobjects/Contact` | **Creates contact** | **✅ `/contacts`** |
| 11 | `11-read-contact-query.json` | GET | `/query.*` (contains Contact) | SOQL query results | — |
| 12 | `12-read-single-contact.json` | GET | `/sobjects/Contact/{id}` | Read single contact by ID | — |
| 13 | `13-update-contact.json` | PATCH | `/sobjects/Contact/{id}` | **Logs update** | **✅ `/contact_updates`** |
| 14 | `14-delete-contact.json` | DELETE | `/sobjects/Contact/{id}` | **Logs deletion** | **✅ `/contact_deletes`** |

##### Opportunity (files 15–20)

| # | File | Method | URL Pattern | Purpose | Webhook Target |
|---|------|--------|-------------|---------|:--------:|
| 15 | `15-describe-opportunity.json` | GET | `/sobjects/Opportunity/describe` | Opportunity object schema | — |
| 16 | `16-create-opportunity.json` | POST | `/sobjects/Opportunity` | **Creates opportunity** | **✅ `/opportunities`** |
| 17 | `17-read-opportunity-query.json` | GET | `/query.*` (contains Opportunity) | SOQL query results | — |
| 18 | `18-read-single-opportunity.json` | GET | `/sobjects/Opportunity/{id}` | Read single opportunity by ID | — |
| 19 | `19-update-opportunity.json` | PATCH | `/sobjects/Opportunity/{id}` | **Logs update** | **✅ `/opportunity_updates`** |
| 20 | `20-delete-opportunity.json` | DELETE | `/sobjects/Opportunity/{id}` | **Logs deletion** | **✅ `/opportunity_deletes`** |

##### Lead (files 21–26)

| # | File | Method | URL Pattern | Purpose | Webhook Target |
|---|------|--------|-------------|---------|:--------:|
| 21 | `21-describe-lead.json` | GET | `/sobjects/Lead/describe` | Lead object schema | — |
| 22 | `22-create-lead.json` | POST | `/sobjects/Lead` | **Creates lead** | **✅ `/leads`** |
| 23 | `23-read-lead-query.json` | GET | `/query.*` (contains Lead) | SOQL query results | — |
| 24 | `24-read-single-lead.json` | GET | `/sobjects/Lead/{id}` | Read single lead by ID | — |
| 25 | `25-update-lead.json` | PATCH | `/sobjects/Lead/{id}` | **Logs update** | **✅ `/lead_updates`** |
| 26 | `26-delete-lead.json` | DELETE | `/sobjects/Lead/{id}` | **Logs deletion** | **✅ `/lead_deletes`** |

##### Case (files 27–32)

| # | File | Method | URL Pattern | Purpose | Webhook Target |
|---|------|--------|-------------|---------|:--------:|
| 27 | `27-describe-case.json` | GET | `/sobjects/Case/describe` | Case object schema | — |
| 28 | `28-create-case.json` | POST | `/sobjects/Case` | **Creates case** | **✅ `/cases`** |
| 29 | `29-read-case-query.json` | GET | `/query.*` (contains Case) | SOQL query results | — |
| 30 | `30-read-single-case.json` | GET | `/sobjects/Case/{id}` | Read single case by ID | — |
| 31 | `31-update-case.json` | PATCH | `/sobjects/Case/{id}` | **Logs update** | **✅ `/case_updates`** |
| 32 | `32-delete-case.json` | DELETE | `/sobjects/Case/{id}` | **Logs deletion** | **✅ `/case_deletes`** |

#### SnapLogic Snap to WireMock Mapping Reference

When a SnapLogic Salesforce Snap executes, it calls specific WireMock endpoints. This table shows which mapping file handles each snap:

##### Account

| SnapLogic Snap | Action | WireMock Mapping File | URL Called |
|---|---|---|---|
| Salesforce Create | POST | `04-create-account.json` | `/sobjects/Account` |
| Salesforce Read | GET (describe) | `03-describe-account.json` | `/sobjects/Account/describe` |
| Salesforce Read | GET (query) | `05-read-account-query.json` | `/query?q=...Account...` |
| Salesforce Read | GET (by ID) | `06-read-single-account.json` | `/sobjects/Account/{Id}` |
| Salesforce Update | PATCH | `07-update-account.json` | `/sobjects/Account/{Id}` |
| Salesforce Delete | DELETE | `08-delete-account.json` | `/sobjects/Account/{Id}` |

##### Contact

| SnapLogic Snap | Action | WireMock Mapping File | URL Called |
|---|---|---|---|
| Salesforce Create | POST | `10-create-contact.json` | `/sobjects/Contact` |
| Salesforce Read | GET (describe) | `09-describe-contact.json` | `/sobjects/Contact/describe` |
| Salesforce Read | GET (query) | `11-read-contact-query.json` | `/query?q=...Contact...` |
| Salesforce Read | GET (by ID) | `12-read-single-contact.json` | `/sobjects/Contact/{Id}` |
| Salesforce Update | PATCH | `13-update-contact.json` | `/sobjects/Contact/{Id}` |
| Salesforce Delete | DELETE | `14-delete-contact.json` | `/sobjects/Contact/{Id}` |

##### Opportunity

| SnapLogic Snap | Action | WireMock Mapping File | URL Called |
|---|---|---|---|
| Salesforce Create | POST | `16-create-opportunity.json` | `/sobjects/Opportunity` |
| Salesforce Read | GET (describe) | `15-describe-opportunity.json` | `/sobjects/Opportunity/describe` |
| Salesforce Read | GET (query) | `17-read-opportunity-query.json` | `/query?q=...Opportunity...` |
| Salesforce Read | GET (by ID) | `18-read-single-opportunity.json` | `/sobjects/Opportunity/{Id}` |
| Salesforce Update | PATCH | `19-update-opportunity.json` | `/sobjects/Opportunity/{Id}` |
| Salesforce Delete | DELETE | `20-delete-opportunity.json` | `/sobjects/Opportunity/{Id}` |

##### Lead

| SnapLogic Snap | Action | WireMock Mapping File | URL Called |
|---|---|---|---|
| Salesforce Create | POST | `22-create-lead.json` | `/sobjects/Lead` |
| Salesforce Read | GET (describe) | `21-describe-lead.json` | `/sobjects/Lead/describe` |
| Salesforce Read | GET (query) | `23-read-lead-query.json` | `/query?q=...Lead...` |
| Salesforce Read | GET (by ID) | `24-read-single-lead.json` | `/sobjects/Lead/{Id}` |
| Salesforce Update | PATCH | `25-update-lead.json` | `/sobjects/Lead/{Id}` |
| Salesforce Delete | DELETE | `26-delete-lead.json` | `/sobjects/Lead/{Id}` |

##### Case

| SnapLogic Snap | Action | WireMock Mapping File | URL Called |
|---|---|---|---|
| Salesforce Create | POST | `28-create-case.json` | `/sobjects/Case` |
| Salesforce Read | GET (describe) | `27-describe-case.json` | `/sobjects/Case/describe` |
| Salesforce Read | GET (query) | `29-read-case-query.json` | `/query?q=...Case...` |
| Salesforce Read | GET (by ID) | `30-read-single-case.json` | `/sobjects/Case/{Id}` |
| Salesforce Update | PATCH | `31-update-case.json` | `/sobjects/Case/{Id}` |
| Salesforce Delete | DELETE | `32-delete-case.json` | `/sobjects/Case/{Id}` |

##### Common (triggered automatically on connection)

| SnapLogic Action | WireMock Mapping File | URL Called |
|---|---|---|
| Account validation (on connect) | `01-oauth-token.json` | `/services/oauth2/token` |
| Account validation (on connect) | `02-validation-query.json` | `/query?q=SELECT Name FROM Account LIMIT 1` |

> **Note:** All Salesforce snaps must use **REST API** (not Bulk API) in snap settings. WireMock mappings only handle REST API URL patterns. Bulk API uses different endpoints (`/services/async/`) which have no mappings.

#### Who Can Trigger the Webhook?

Anyone who sends a POST to WireMock — the webhook fires regardless of the caller:

| Caller | Webhook Fires? |
|--------|:--------------:|
| **curl** from terminal | ✅ Yes |
| **SnapLogic Pipeline** (Salesforce Create Snap) | ✅ Yes |
| **Robot Framework** (triggers pipeline → WireMock) | ✅ Yes |

#### How to Verify Data Persisted

```bash
# 1. Check DB before
curl -s http://localhost:8082/accounts

# 2. Create via WireMock
curl -s -X POST http://localhost:8089/services/data/v59.0/sobjects/Account \
  -H "Content-Type: application/json" \
  -d '{"Name": "Acme Corp", "Type": "Customer", "Industry": "Technology"}'

# 3. Wait and verify in JSON Server
sleep 1
curl -s http://localhost:8082/accounts

# 4. Verify on disk
cat docker/salesforce/json-db/salesforce-db.json

# 5. Check JSON Server logs for proof
docker logs salesforce-json-mock | grep POST
```

#### The Two IDs

The Salesforce ID and JSON Server ID are **different** — this is by design:

```
SnapLogic receives:     "id": "001ODTNWNPKXBSADNP"   ← WireMock generated (Salesforce format)
JSON Server stores:     "id": "xK7mN2p"               ← JSON Server generated (auto string)
```

For functional verification, query JSON Server **by field values** (not by ID):
```bash
curl http://localhost:8082/accounts?Name=Acme+Corp
```

#### The Database File: `salesforce-db.json`

JSON Server's database — a plain JSON file at `docker/salesforce/json-db/salesforce-db.json`:

```json
{
  "accounts": [],              ←  http://localhost:8082/accounts
  "contacts": [],              ←  http://localhost:8082/contacts
  "opportunities": [],         ←  http://localhost:8082/opportunities
  "leads": [],                 ←  http://localhost:8082/leads
  "cases": [],                 ←  http://localhost:8082/cases
  "account_updates": [],       ←  http://localhost:8082/account_updates
  "account_deletes": [],       ←  http://localhost:8082/account_deletes
  "contact_updates": [],       ←  http://localhost:8082/contact_updates
  "contact_deletes": [],       ←  http://localhost:8082/contact_deletes
  "opportunity_updates": [],   ←  http://localhost:8082/opportunity_updates
  "opportunity_deletes": [],   ←  http://localhost:8082/opportunity_deletes
  "lead_updates": [],          ←  http://localhost:8082/lead_updates
  "lead_deletes": [],          ←  http://localhost:8082/lead_deletes
  "case_updates": [],          ←  http://localhost:8082/case_updates
  "case_deletes": []           ←  http://localhost:8082/case_deletes
}
```

**Reset:** `echo '{"accounts":[],"contacts":[],"opportunities":[],"leads":[],"cases":[],"account_updates":[],"account_deletes":[],"contact_updates":[],"contact_deletes":[],"opportunity_updates":[],"opportunity_deletes":[],"lead_updates":[],"lead_deletes":[],"case_updates":[],"case_deletes":[]}' > docker/salesforce/json-db/salesforce-db.json && docker restart salesforce-json-mock`

**View in browser:** [http://localhost:8082/accounts](http://localhost:8082/accounts) or open `docker/salesforce/json-db/jsonserver_data.html` (auto-refreshes every 1 second)

#### Reloading Mappings After Changes

```bash
# Hot-reload (instant, no downtime)
curl -X POST http://localhost:8089/__admin/mappings/reset

# Or restart container (slower, 5-10 seconds)
docker restart salesforce-api-mock
```

#### What JSON Server Still Cannot Test

Even with the webhook bridge, these remain **impossible without real Salesforce**:

| Limitation | Why |
|-----------|-----|
| Salesforce validation rules | JSON Server has no schema enforcement |
| Apex triggers | No trigger engine |
| Duplicate detection rules | No matching rules |
| Field-level security | No permission model |
| Record types | No record type enforcement |
| Sharing rules | No org-wide defaults |
| Governor limits | No limit tracking |
| Workflow rules / Process Builder | No automation engine |
| Formula fields | No formula evaluation |
| Cross-object relationships | No referential integrity |

> **Bottom Line:** WireMock returns the Salesforce-formatted response to SnapLogic, while the webhook delivers the same data to JSON Server for persistence. **WireMock gives SnapLogic a receipt, while the webhook delivers the package to the warehouse (JSON Server) for inspection.**

---

## 13. Troubleshooting Guide

### SSL/Certificate Errors

**Error:** `SSLPeerUnverifiedException: Host name 'salesforce-api-mock' does not match the certificate`

**Fix:**
```bash
# 1. Check if cert is imported
make groundplex-check-cert

# 2. If not, import it
make setup-groundplex-cert

# 3. Verify connection
docker exec snaplogic-groundplex curl -v https://salesforce-api-mock:8443/__admin/health
```

**Still getting hostname verification errors?** Verify the certificate SANs include the hostname:
```bash
docker exec snaplogic-groundplex bash -c '
  echo | openssl s_client -connect salesforce-api-mock:8443 2>/dev/null | \
  openssl x509 -noout -text | grep -A2 "Subject Alternative Name"
'
```

**Error:** `PKIX path building failed: unable to find valid certification path`

**Fix:** The certificate is not in the truststore. Run `make setup-groundplex-cert`.

**Error:** Certificate import fails with `Certificate already exists`

**Fix:** Remove the old certificate first, then re-import:
```bash
# Remove existing certificate
docker exec snaplogic-groundplex bash -c '
  JAVA_HOME="/opt/snaplogic/pkgs/jdk-11.0.24+8-jre"
  $JAVA_HOME/bin/keytool -delete -keystore $JAVA_HOME/lib/security/cacerts \
    -storepass changeit -alias wiremock-salesforce 2>/dev/null
  echo "Old certificate removed"
'

# Re-import
make setup-groundplex-cert
```

**Error:** JCC won't restart after certificate import

**Fix:** Check JCC logs and manually restart:
```bash
# Check logs
docker exec snaplogic-groundplex tail -n 100 /opt/snaplogic/run/log/jcc.log

# Force stop and start
docker exec snaplogic-groundplex bash -c '
  cd /opt/snaplogic/bin
  ./jcc.sh stop
  sleep 10
  ./jcc.sh start
'
```

**Error:** Connection refused when accessing HTTPS endpoint

**Fix:** Ensure WireMock is running with HTTPS enabled:
```bash
# Check if port 8443 is listening
docker exec salesforce-api-mock netstat -tlnp | grep 8443

# Check WireMock logs for startup errors
docker logs salesforce-api-mock --tail 50
```

### WireMock Not Responding

```bash
# Check container status
docker ps | grep salesforce-api-mock

# Check logs
docker logs salesforce-api-mock --tail 50

# Test health
curl http://localhost:8089/__admin/health
curl -k https://localhost:8443/__admin/health

# Check loaded mappings
curl http://localhost:8089/__admin/mappings | python3 -m json.tool

# Check request journal (what requests were received)
curl http://localhost:8089/__admin/requests | python3 -m json.tool
```

### JSON Server Not Working

```bash
# Check container
docker ps | grep salesforce-json-mock

# Test direct access
curl http://localhost:8082/accounts

# Check if data file exists
ls -la docker/salesforce/json-db/salesforce-db.json

# Check logs
docker logs salesforce-json-mock

# Reset data to git version
git checkout docker/salesforce/json-db/salesforce-db.json
```

### Request Not Matching Any Mapping (404)

```bash
# Check WireMock's unmatched requests
curl http://localhost:8089/__admin/requests/unmatched | python3 -m json.tool

# This shows exactly what was requested and why no mapping matched
# Common causes:
#   - API version mismatch (v52.0 vs v59.0)
#   - Missing query parameter
#   - Wrong HTTP method
#   - Trailing slash difference
```

### SnapLogic Account Validation Fails

```bash
# Test OAuth manually
curl -X POST http://localhost:8089/services/oauth2/token \
  -d "grant_type=password&username=test&password=test"

# Test validation query manually
curl "http://localhost:8089/services/data/v52.0/query?q=SELECT+Name+FROM+Account+LIMIT+1"

# If using HTTPS, test from Groundplex
docker exec snaplogic-groundplex curl -k https://salesforce-api-mock:8443/services/oauth2/token \
  -X POST -d "grant_type=password&username=test&password=test"
```

### Port Conflicts

```bash
# Check what is using the ports
lsof -i :8089
lsof -i :8443
lsof -i :8082

# Change ports in .env.salesforce:
SALESFORCE_HTTP_PORT=9089
SALESFORCE_HTTPS_PORT=9443
SALESFORCE_JSON_PORT=9082
```

---

## 14. Quick Reference Cheat Sheet

### Startup — Fresh (No Groundplex Running)
```bash
make salesforce-mock-start       # Start WireMock + JSON Server
make launch-groundplex-with-cert # Start Groundplex + import SSL cert
make salesforce-mock-status      # Verify everything is running
make robot-run-tests TAGS="sfdc" # Run Salesforce tests
```

### Startup — Groundplex Already Running
```bash
make salesforce-mock-start       # Start WireMock + JSON Server
make setup-groundplex-cert       # Import cert into running Groundplex (no container restart!)
make groundplex-check-cert       # Verify cert was imported
make robot-run-tests TAGS="sfdc" # Run Salesforce tests
```

### Endpoints (from host machine)
```
WireMock HTTP:   http://localhost:8089
WireMock HTTPS:  https://localhost:8443  (use -k with curl for self-signed cert)
JSON Server:     http://localhost:8082
WireMock Admin:  http://localhost:8089/__admin/
```

### Endpoints (from Docker containers)
```
WireMock HTTP:   http://salesforce-api-mock:8080
WireMock HTTPS:  https://salesforce-api-mock:8443
JSON Server:     http://salesforce-json-mock
```

### SnapLogic Account Configuration
```
Login URL:       https://salesforce-api-mock:8443
Username:        slim@snaplogic.com (or any value)
Password:        test (or any value)
Security Token:  (leave empty)
Sandbox:         true
API Version:     59.0
```

### Quick Tests
```bash
# Test OAuth
curl -X POST http://localhost:8089/services/oauth2/token -d "grant_type=password"

# Test validation query
curl "http://localhost:8089/services/data/v52.0/query?q=SELECT+Name+FROM+Account+LIMIT+1"

# Test describe
curl http://localhost:8089/services/data/v59.0/sobjects/Account/describe

# Test create
curl -X POST http://localhost:8089/services/data/v59.0/sobjects/Account \
  -H "Content-Type: application/json" -d '{"Name":"Test"}'

# Test JSON Server
curl http://localhost:8082/accounts

# Check WireMock mappings
curl http://localhost:8089/__admin/mappings | python3 -m json.tool

# Check unmatched requests
curl http://localhost:8089/__admin/requests/unmatched | python3 -m json.tool
```

### Shutdown
```bash
make salesforce-mock-stop        # Stop + remove containers
make salesforce-mock-clean       # Stop + remove + delete data
```

---

*This document covers every file, every configuration, every design decision, and every flow in the Salesforce mock service infrastructure. If you are reading this months from now, start from Section 1 and work your way down.*
