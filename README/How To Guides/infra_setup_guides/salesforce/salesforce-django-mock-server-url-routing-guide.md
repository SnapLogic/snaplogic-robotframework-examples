# Mock Server URL Routing Guide

> How SnapLogic talks to real Salesforce vs. the Django Mock Server

**Django Salesforce Mock Server Documentation**

---

## Quick Stats

| The Only Change | Real Salesforce | Mock Server | URL Paths | Pipeline Changes |
|---|---|---|---|---|
| **Login URL** | `login.salesforce.com` | `salesforce-api-mock:8443` | **Identical** | **Zero** |

---

## Table of Contents

1. [The Big Picture](#the-big-picture)
2. [URL Anatomy](#url-anatomy)
3. [Django Route Matching](#django-route-matching)
4. [Step-by-Step Walkthrough](#step-by-step-walkthrough)
5. [All URL Routes](#all-url-routes)
6. [Plugin Architecture](#plugin-architecture)
7. [SnapLogic Config](#snaplogic-config)
8. [Why Mock?](#why-mock)

---

## The Big Picture

When a SnapLogic pipeline talks to Salesforce, it doesn't know (or care) whether it's talking to the **real** Salesforce or a **mock**. It just sends HTTP requests to a URL. **We swap the URL.**

> **Key Insight:** The pipeline, the Snaps, the data flow, the mappings, the expressions — everything stays **exactly the same**. Only the Login URL in the SnapLogic Account configuration changes.

### Real Salesforce Flow

```
SnapLogic Pipeline
    |
    |  POST https://login.salesforce.com/services/oauth2/token
    |
    v
Salesforce Cloud (paid license, rate-limited, shared org)
    |
    |  Returns: instance_url = "https://na139.salesforce.com"
    |
    v
SnapLogic Pipeline sends all API calls to na139.salesforce.com
```

### Mock Server Flow

```
SnapLogic Pipeline
    |
    |  POST https://salesforce-api-mock:8443/services/oauth2/token
    |
    v
Django Mock Server (free, local Docker, unlimited, instant)
    |
    |  Returns: instance_url = "https://salesforce-api-mock:8443"
    |
    v
SnapLogic Pipeline sends all API calls to salesforce-api-mock:8443
```

> **The OAuth trick:** The `instance_url` in the OAuth response tells SnapLogic where to send ALL future API calls. Real Salesforce returns `na139.salesforce.com`. Our mock returns **itself** — so all subsequent calls automatically go to the mock!

### Real Salesforce vs. Mock Server

```
REAL SALESFORCE
+-------------------------------------------------------------+
|  Auth System    Schema Metadata    Database (Oracle)    Triggers & Flows  |
|  Rate Limits    Security & Perms    Audit Trail          Workflow Rules    |
|  Apex Code      Validation Rules   Record Types         Process Builder   |
+-------------------------------------------------------------+

                      Mock replaces ALL of that with:

MOCK SERVER
+-------------------------------------------------------------+
|  Fake OAuth     Schema from        Python Dict                            |
|  (accept all)   JSON files         {key: value}          That's it!       |
|                                                     Just enough           |
|                                                     to test the           |
|                                                     pipeline.             |
+-------------------------------------------------------------+
```

---

## URL Anatomy

Every Salesforce API URL follows a consistent pattern. Let's break one apart:

```
Complete URL:
https://na139.salesforce.com/services/data/v58.0/sobjects/Account/001xx000003GYk8AAG

Broken into parts:
https://na139.salesforce.com  /services/data/  v58.0  /sobjects/  Account  /  001xx000003GYk8AAG
|___________________________|  |______________|  |_____|  |__________|  |_______|   |__________________|
      Hostname                  Base path       API Ver   Resource     Object        Record ID
  (we replace this)             (fixed)        (dynamic)  (fixed)     (dynamic)     (dynamic)
```

> **Django only matches the PATH** (everything after the hostname). The hostname is handled by Docker networking. So Django sees: `/services/data/v58.0/sobjects/Account/001xx000003GYk8AAG`

### Color Legend

| Part | Type | What It Means | Django Pattern |
|---|---|---|---|
| `na139.salesforce.com` | Hostname | Replaced by mock server hostname. Django doesn't see this. | — (not matched) |
| `/services/data/` | Fixed path | Always the same string. Must match exactly. | `'services/data/'` |
| `v58.0` | Dynamic (API Version) | Can be v55.0, v58.0, v62.0 — any version | `<str:version>` |
| `/sobjects/` | Fixed path | Always the same. Means "Salesforce objects" | `'sobjects/'` |
| `Account` | Dynamic (Object Name) | Can be Account, Contact, Opportunity, Custom__c — any object | `<str:object_name>` |
| `001xx000003GYk8AAG` | Dynamic (Record ID) | 18-character Salesforce ID. Different for every record. | `<str:record_id>` |

### The Path is Always Identical

```
Real Salesforce:
  https://na139.salesforce.com/services/data/v58.0/sobjects/Account

Mock Server:
  https://salesforce-api-mock:8443/services/data/v58.0/sobjects/Account
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                        Identical path on both!
```

---

## Django Route Matching

Django uses **angle bracket patterns** like `<str:variable_name>` to capture dynamic segments of the URL. Think of them as "slots" that grab whatever value appears in that position.

> **Key Rule:** Django scans `urls.py` **top-to-bottom** and uses the **first matching pattern**. That's why specific routes (like `.../describe`) must come BEFORE generic ones (like `.../{id}`).

### Pattern Matching Example: Describe Object

```python
# Django URL Pattern
path('services/data/<str:version>/sobjects/<str:object_name>/describe',
     rest_views.describe_object)
```

This **one pattern** catches ALL of these URLs:

```
/services/data/ v58.0 /sobjects/ Account        /describe   →  object_name = "Account"
/services/data/ v58.0 /sobjects/ Contact        /describe   →  object_name = "Contact"
/services/data/ v58.0 /sobjects/ Opportunity    /describe   →  object_name = "Opportunity"
/services/data/ v58.0 /sobjects/ My_Custom__c   /describe   →  object_name = "My_Custom__c"
                       ^^^^^            ^^^^^^^^^^^^
                  <str:version>    <str:object_name>   ← captures ANY value
```

### Inside the View Function

```python
def describe_object(request, version, object_name):
    #                         |         |
    #                    "v58.0"    "Account" (or "Contact", or anything)

    # Load the schema file for whatever object was requested
    schema = schemas.get(object_name)   # looks up Account.json, Contact.json, etc.

    if not schema:
        return JsonResponse({"error": f"Object {object_name} not found"}, status=404)

    return JsonResponse(schema)
```

### Same URL, Different HTTP Methods

The **same URL path** does different things based on the **HTTP method** (GET, POST, PATCH, DELETE):

| Method | URL Path | Operation | Django Pattern | View Function |
|---|---|---|---|---|
| **POST** | `/services/data/v58.0/sobjects/Account` | Create new record | `<str:object_name>` | `create_record()` |
| **GET** | `/services/data/v58.0/sobjects/Account/001xx...` | Read record by ID | `<str:object_name>/<str:record_id>` | `record_detail()` |
| **PATCH** | `/services/data/v58.0/sobjects/Account/001xx...` | Update record | `<str:object_name>/<str:record_id>` | `record_detail()` |
| **DELETE** | `/services/data/v58.0/sobjects/Account/001xx...` | Delete record | `<str:object_name>/<str:record_id>` | `record_detail()` |

```python
def record_detail(request, version, object_name, record_id):

    if request.method == 'GET':
        # Return the record from in-memory dict
        record = database[object_name].get(record_id)
        return JsonResponse(record)

    elif request.method == 'PATCH':
        # Update the record in memory
        database[object_name][record_id].update(json.loads(request.body))
        return HttpResponse(status=204)

    elif request.method == 'DELETE':
        # Remove from memory
        del database[object_name][record_id]
        return HttpResponse(status=204)
```

### Django Top-to-Bottom Matching (Full Example)

> **Why order matters:** If generic patterns come before specific ones, the generic pattern would match first. For example, `/sobjects/Account/describe` would match `<object_name>/<record_id>` and think "describe" is a record ID!

```
Django scans urls.py top-to-bottom for: PATCH /services/data/v58.0/sobjects/Account/001xx...

  ✗ services/oauth2/token                                       → no match
  ✗ services/data/<V>/search                                   → no match (not "search")
  ✗ services/data/<V>/sobjects/Attachment/<id>/Body              → no match (not "Attachment")
  ✗ services/data/<V>/sobjects/<name>/describe                  → no match (no "describe" at end)
  ✗ services/data/<V>/query                                    → no match (not "query")
  ✗ services/data/<V>/limits                                   → no match (not "limits")
  ✗ services/data/<V>/sobjects/<name>/<ext_field>/<ext_value>   → no match (3 dynamic parts, URL has 2)

  ✓ services/data/<V>/sobjects/<name>/<id>                      → MATCH!

     Captured: version="v58.0"  object_name="Account"  record_id="001xx..."
     Method: PATCH → calls record_detail() → updates the record in memory
```

---

## Step-by-Step Walkthrough

### Step 1: Authentication (OAuth Token)

**Real Salesforce:**
- URL: `POST https://login.salesforce.com/services/oauth2/token`
- Salesforce validates credentials, checks MFA, permissions, and returns a real access token + instance_url pointing to their cloud.

**Mock Server:**
- URL: `POST https://salesforce-api-mock:8443/services/oauth2/token`
- Mock accepts **any** credentials and returns a fake token + instance_url pointing back to itself.

**Request (identical on both):**

```http
POST /services/oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=password&client_id=xxx&client_secret=xxx&username=admin@test.com&password=pass123
```

**Real Response:**

```json
{
  "access_token": "00D8F000001gPVm!AR...",
  "instance_url": "https://na139.salesforce.com",
  "token_type": "Bearer"
}
```

**Mock Response:**

```json
{
  "access_token": "mock_token_abc123",
  "instance_url": "https://salesforce-api-mock:8443",
  "token_type": "Bearer"
}
```

> **This is the magic moment!** The `instance_url` tells SnapLogic where to send ALL future API calls. Real Salesforce returns their cloud URL. Mock returns itself. From this point on, every API call automatically goes to the mock.

### Step 2: Describe Object (Get Schema)

The pipeline asks: *"What fields does the Account object have?"*

| | Real Salesforce | Mock Server |
|---|---|---|
| **URL** | `GET https://na139.salesforce.com/services/data/v58.0/sobjects/Account/describe` | `GET https://salesforce-api-mock:8443/services/data/v58.0/sobjects/Account/describe` |
| **Action** | Looks up the Account object metadata from Salesforce's database | Loads `Account.json` schema file from `/app/schemas/` directory |

> **Same path:** `/services/data/v58.0/sobjects/Account/describe` — identical on both real and mock.

### Step 3: Create Record (INSERT)

| | Real Salesforce | Mock Server |
|---|---|---|
| **URL** | `POST .../v58.0/sobjects/Account` | `POST .../v58.0/sobjects/Account` |
| **Action** | Validates schema, checks permissions, runs triggers, saves to Oracle database | Validates against schema JSON, saves to Python dict in memory |

**Request Body (identical):**

```json
{ "Name": "Acme Corp", "Industry": "Technology", "AnnualRevenue": 5000000 }
```

**Response (same format):**

```json
{ "id": "001xx000003GYk8AAG", "success": true, "errors": [] }
```

> **After this:** Real Salesforce stores it in their cloud database. Mock stores it in `database['Account']['001xx...'] = {...}` (Python dict in memory).

### Step 4: Query Records (SOQL)

| | Real Salesforce | Mock Server |
|---|---|---|
| **URL** | `GET .../query?q=SELECT Id,Name FROM Account WHERE Industry='Technology'` | `GET .../query?q=SELECT Id,Name FROM Account WHERE Industry='Technology'` |
| **Action** | Runs SOQL against massive distributed Oracle database | `soql_parser.py` parses the query and filters the in-memory Python dict |

**Response (same format):**

```json
{
  "totalSize": 1,
  "done": true,
  "records": [
    {
      "attributes": { "type": "Account" },
      "Id": "001xx000003GYk8AAG",
      "Name": "Acme Corp"
    }
  ]
}
```

> **How it works:** Django matches the `/query` path, then reads `?q=SELECT...` from the query string parameter. The `soql_parser.py` handles WHERE, LIKE, IN, ORDER BY, LIMIT, and nested queries.

### Step 5: Update Record

```http
PATCH /services/data/v58.0/sobjects/Account/001xx000003GYk8AAG
Content-Type: application/json

{ "Industry": "Finance" }
```

| Real Salesforce | Mock Server |
|---|---|
| Updates record in cloud DB. Returns `204 No Content`. | Updates record in Python dict. Returns `204 No Content`. |

### Step 6: Delete Record

```http
DELETE /services/data/v58.0/sobjects/Account/001xx000003GYk8AAG
```

| Real Salesforce | Mock Server |
|---|---|
| Permanently deletes from cloud DB. Returns `204 No Content`. | Removes from Python dict. Returns `204 No Content`. |

### Step 7: Bulk API (Large Data Loads)

Bulk API is a multi-step process. Each step uses a different URL ending:

| Step | Method | URL Path | Real Salesforce | Mock Server |
|---|---|---|---|---|
| **1. Create Job** | POST | `.../jobs/ingest` | Creates async bulk job | Creates job in job_store dict |
| **2. Upload CSV** | PUT | `.../jobs/ingest/{jobId}/batches` | Queues CSV for processing | Parses CSV into memory |
| **3. Close Job** | PATCH | `.../jobs/ingest/{jobId}` | Starts async processing | Processes records immediately |
| **4. Get Results** | GET | `.../jobs/ingest/{jobId}/successfulResults` | Returns processed results | Returns success CSV |

> **Notice the pattern:** The `{jobId}` is dynamic (`<str:job_id>`), but the endings (`/batches`, `/successfulResults`, `/failedResults`) are fixed strings that Django uses to route to different view functions.

---

## All URL Routes

> Every URL path below is **identical** between real Salesforce and the mock server. Only the hostname differs.

### Authentication

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **POST** | `/services/oauth2/token` | `oauth_token()` | Get access token + instance_url |

### REST API — CRUD Operations

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **GET** | `/services/data/{V}/sobjects/{Object}/describe` | `describe_object()` | Get object schema/metadata |
| **POST** | `/services/data/{V}/sobjects/{Object}` | `create_record()` | Create a new record |
| **GET** | `/services/data/{V}/sobjects/{Object}/{Id}` | `record_detail()` | Read a record by ID |
| **PATCH** | `/services/data/{V}/sobjects/{Object}/{Id}` | `record_detail()` | Update a record |
| **DELETE** | `/services/data/{V}/sobjects/{Object}/{Id}` | `record_detail()` | Delete a record |
| **PATCH** | `/services/data/{V}/sobjects/{Object}/{ExtField}/{ExtValue}` | `upsert_record()` | Upsert by external ID |

### Query & Search

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **GET** | `/services/data/{V}/query?q=SELECT...` | `soql_query()` | SOQL query with WHERE, LIKE, IN, ORDER BY |
| **GET** | `/services/data/{V}/search?q=FIND...` | `sosl_search()` | SOSL search across objects |
| **GET** | `/services/data/{V}/limits` | `api_limits()` | API usage limits |

### Bulk API v2 — Ingest

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **POST** | `/services/data/{V}/jobs/ingest` | `ingest_job_list()` | Create new ingest job |
| **GET** | `/services/data/{V}/jobs/ingest/{jobId}` | `ingest_job_detail()` | Get job status |
| **PATCH** | `/services/data/{V}/jobs/ingest/{jobId}` | `ingest_job_detail()` | Close/abort job |
| **PUT** | `/services/data/{V}/jobs/ingest/{jobId}/batches` | `upload_csv_data()` | Upload CSV data |
| **GET** | `/services/data/{V}/jobs/ingest/{jobId}/successfulResults` | `get_successful_results()` | Download success results |
| **GET** | `/services/data/{V}/jobs/ingest/{jobId}/failedResults` | `get_failed_results()` | Download failed results |
| **GET** | `/services/data/{V}/jobs/ingest/{jobId}/unprocessedrecords` | `get_unprocessed_records()` | Download unprocessed records |

### Bulk API v2 — Query

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **POST** | `/services/data/{V}/jobs/query` | `query_job_list()` | Create bulk query job |
| **GET** | `/services/data/{V}/jobs/query/{jobId}` | `query_job_detail()` | Get query job status |
| **GET** | `/services/data/{V}/jobs/query/{jobId}/results` | `get_query_results()` | Download query results |

### Bulk API v1 (Legacy)

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **POST** | `/services/async/{V}/job` | `create_v1_job()` | Create v1 bulk job |
| **POST** | `/services/async/{V}/job/{jobId}/batch` | `v1_batch_handler()` | Add batch to job |
| **GET** | `/services/async/{V}/job/{jobId}/batch/{batchId}` | `get_v1_batch()` | Get batch status |
| **GET** | `/services/async/{V}/job/{jobId}/batch/{batchId}/result` | `get_v1_batch_results()` | Get batch results |

### Other APIs

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **GET** | `/services/data/{V}/sobjects/Attachment/{Id}/Body` | `download_attachment_body()` | Download attachment file |
| **POST** | `/services/data/{V}/sobjects/{Object}__e` | `publish_event()` | Publish platform event |
| **GET** | `/services/data/{V}/wave/datasets` | `list_datasets()` | Wave/Analytics datasets |
| **POST** | `/cometd/{V}` | `cometd_handler()` | Streaming API (CometD) |

### Admin Endpoints (Mock Server Only)

> **Note:** These endpoints do NOT exist on real Salesforce. They are mock-server-only tools for inspecting and managing the in-memory data.

| Method | URL Path | View Function | Description |
|---|---|---|---|
| **GET** | `/__admin/db` | `admin_db()` | View all data in memory |
| **GET** | `/__admin/schemas` | `admin_schemas()` | View loaded object schemas |
| **POST** | `/__admin/reset` | `admin_reset()` | Clear all data (fresh start) |
| **GET** | `/__admin/bulk-jobs` | `admin_bulk_jobs()` | View all bulk jobs |
| **GET** | `/health` | `health()` | Health check |

---

## Plugin Architecture

The mock server is designed to evolve into a **plugin-based** service. Each enterprise system (Salesforce, SAP, NetSuite, etc.) becomes a plugin that registers its own URL routes.

> **Ben's vision:** "A single container in the Compose file that is the SLIM Mock Service, and that mock service loads different endpoints based on what systems need to be mocked."

### Current Architecture (Single-System)

```
docker/salesforce/django-server/            ← Single-purpose: Salesforce only
|
+-- salesforce_mock/
|   +-- views/
|   |   +-- rest_views.py                       ← Salesforce REST API
|   |   +-- bulk_v1_views.py                     ← Salesforce Bulk v1
|   |   +-- bulk_v2_ingest_views.py               ← Salesforce Bulk v2
|   |   +-- ...
|   +-- state/
|   |   +-- database.py                          ← In-memory data store
|   |   +-- job_store.py                         ← Bulk job tracking
|   +-- parsers/
|       +-- soql_parser.py                       ← Salesforce query language
|       +-- sosl_parser.py
|
+-- run_server.py
+-- Dockerfile
```

### Future Architecture (Multi-System Plugins)

```
slim-mock-service/                              ← Generic mock service
|
+-- mock_core/                                  ← Shared foundation (reusable)
|   +-- settings.py
|   +-- middleware.py                            ← CORS, logging, error handling
|   +-- run_server.py                            ← HTTP+HTTPS server
|   +-- base_database.py                         ← Generic in-memory store
|   +-- plugin_loader.py                        ← Discovers & loads plugins
|   +-- urls.py                                  ← Dynamically assembles routes
|
+-- plugins/                                    ← Each system is a "plugin"
|   +-- salesforce/                              ← Plugin #1
|   |   +-- __init__.py                          ← registers routes, schemas
|   |   +-- views/
|   |   +-- parsers/
|   |   +-- schemas/
|   |
|   +-- sap/                                     ← Plugin #2
|   |   +-- __init__.py
|   |   +-- views/
|   |   |   +-- odata_views.py                   ← SAP OData endpoints
|   |   |   +-- idoc_views.py                    ← SAP iDoc endpoints
|   |   +-- schemas/
|   |
|   +-- netsuite/                                ← Plugin #3
|   +-- workday/                                 ← Plugin #4
|
+-- Dockerfile
+-- docker-compose.yml
```

### Docker Compose Usage

```bash
# Only Salesforce
MOCK_PLUGINS=salesforce docker-compose up

# Salesforce + SAP (e.g., Caterpillar project)
MOCK_PLUGINS=salesforce,sap docker-compose up

# Everything
MOCK_PLUGINS=all docker-compose up
```

### What's Already Generic vs. Plugin-Specific

| Component | Already Generic? | Notes |
|---|---|---|
| `run_server.py` | **YES** | HTTP+HTTPS dual-protocol — works for any API |
| `middleware.py` | **YES** | CORS, trailing slash, logging — nothing Salesforce-specific |
| `database.py` | **YES** | Generic key-value in-memory store |
| `settings.py` | **YES** | Minimal Django config |
| `soql_parser.py` | Salesforce Plugin | Salesforce-specific query language |
| `job_store.py` | Salesforce Plugin | Salesforce Bulk API specific |
| `rest_views.py` | Salesforce Plugin | Salesforce REST API patterns |
| `odata_views.py` | SAP Plugin | SAP OData protocol (future) |

> **Key insight:** ~80% of the current code is already generic! The refactor to plugins is mostly just **moving files** into a `plugins/salesforce/` directory. The hard work is already done.

---

## SnapLogic Config

To switch a pipeline from real Salesforce to the mock server, **only the Login URL changes**. Everything else can be anything — the mock accepts all credentials.

### Real Salesforce Account

```
Login URL:       https://login.salesforce.com
Username:        admin@company.com
Password:        realP@ssw0rd!
Security Token:  abc123xyz789
Client ID:       3MVG9A2kN3B...
Client Secret:   E8B2F71A3C...
```

### Mock Server Account

```
Login URL:       https://salesforce-api-mock:8443    ← ONLY this changes!
Username:        anything@test.com                   ← anything works
Password:        anything                             ← anything works
Security Token:  anything                             ← anything works
Client ID:       anything                             ← anything works
Client Secret:   anything                             ← anything works
```

> **The pipeline itself doesn't change at all.** Same Snaps, same mappings, same expressions, same Router conditions, same error handling. It just talks to a different server.

### How Docker Networking Makes It Work

```yaml
# docker-compose.yml

services:
  salesforce-api-mock:              # ← This container name IS the hostname
    build: ./docker/salesforce/django-server
    ports:
      - "8089:8080"                    # ← HTTP  (host:container)
      - "8443:8443"                    # ← HTTPS (host:container)
```

```
From SnapLogic GroundPlex (inside Docker network):
  → https://salesforce-api-mock:8443/services/oauth2/token

From your browser (outside Docker network):
  → https://localhost:8443/services/oauth2/token
```

---

## Why Mock?

| Problem | Real Salesforce | Mock Server |
|---|---|---|
| **Cost** | $25–300/user/month license | **Free** (Docker container) |
| **Rate Limits** | 100,000 API calls/day | **Unlimited** |
| **Speed** | 200–500ms per call (network latency) | **<1ms** (local Docker) |
| **Test Data** | Pollutes real org, hard to reset | `POST /__admin/reset` clears everything |
| **Availability** | Down during maintenance windows | **Always up** (runs locally) |
| **CI/CD** | Can't run in GitHub Actions | **Runs anywhere Docker runs** |
| **Parallel Tests** | Shared org = conflicts between testers | **Each test run gets fresh state** |
| **Snaps Team** | Must maintain paid licenses for every system | **No licenses needed for testing** |

> **Ben's key point:** "Every Snap is just a no-code interface to an API call. If you have an API-level mock, you can mock **any Snap** in the SnapLogic ecosystem."

### Who Benefits?

| QA / Test Engineers | Snaps Team | Pipeline Developers | CI/CD Pipelines |
|---|---|---|---|
| Automated testing without real systems | No paid licenses needed for testing | Fast feedback loop locally | Runs in GitHub Actions, Jenkins, etc. |

### The Bigger Vision

1. **SLIM extracts metadata from pipeline packages** — Knows which Salesforce objects, SAP tables, and API calls each pipeline uses.
2. **Auto-generate mock schemas from that metadata** — No manual JSON files — SLIM builds the mock configuration automatically.
3. **Run tests against the mock service** — Robot Framework tests execute pipelines against the mock — instant, free, repeatable.
4. **Iterate with coding agents (Claude)** — Claude generates pipelines, runs them against mocks, fixes failures — automated development loop.
