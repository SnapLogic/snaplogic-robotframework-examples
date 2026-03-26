# Validate Snap Naming Standards — Complete Reference

## Purpose

When you drag a snap onto the SnapLogic Designer canvas, it gets a **default name** like "Mapper", "Filter", or "Oracle - Select". Developers must rename these to something descriptive so that anyone reading the pipeline understands what each snap does.

This validation enforces that rule automatically by checking every snap in a pipeline against **5 layers of detection**.

---

## The Problem

Snaps with default names tell you **what type** they are, but not **why** they exist in the pipeline:

```
❌ BAD (default names — impossible to understand)

[JSON Generator] → [Mapper] → [Filter] → [Router] → [Oracle - Insert] → [File Writer]
```

```
✅ GOOD (descriptive names — self-documenting)

[CDC Data Generator] → [Extract Customer Fields] → [Remove Inactive Records] → [Route By Region] → [Insert Into Customers Table] → [Write Audit Log CSV]
```

When errors occur, default names make debugging a nightmare:

```
ERROR: Snap 'Mapper' failed at row 4,521
```

Which mapper? If you have 5 mappers all named "Mapper", you have no idea where to look.

---

## The 5-Layer Detection Waterfall

Each snap is checked against 5 layers **in order**. Processing stops at the first violation found per snap.

```
For each snap in pipeline:
│
├── Layer 1: Is the name empty?
│   └── YES → FAIL
│
├── Layer 2: Is the name in KNOWN_DEFAULT_NAMES (hardcoded list)?
│   └── YES → FAIL
│
├── Layer 3: Does the name match a numbered default pattern?
│   └── YES → FAIL
│
├── Layer 4: Is the name in auto-derived defaults from class_id?
│   └── YES → FAIL
│
├── Layer 5: Does the name exactly match its internal type?
│   └── YES → FAIL
│
└── All layers passed → ✅ PASS
```

---

## Layer 1: Empty Name Check

**What it catches:** Snaps with no name or whitespace-only names.

**Logic:**
```python
if not name.strip():
    reason = 'Snap name is empty'
```

**Examples:**

| Snap Name | Result | Reason |
|-----------|--------|--------|
| `""` (blank) | ❌ FAIL | Snap name is empty |
| `"  "` (spaces only) | ❌ FAIL | Snap name is empty |
| `"Mapper"` | — | Passes to Layer 2 |

**Why it matters:** An empty name provides zero information. It's worse than a default name because you can't even tell what type of snap it is from the name alone.

---

## Layer 2: Known Default Names (Hardcoded List)

**What it catches:** The 100+ default names that SnapLogic Designer assigns when a snap is first placed on the canvas.

**Logic:**
```python
all_defaults = KNOWN_DEFAULT_NAMES | extra_defaults  # merge hardcoded + user-provided
if name_lower in all_defaults:
    reason = f"Snap name '{name}' is a known default name"
```

**The comparison is case-insensitive:** `"Mapper"`, `"mapper"`, `"MAPPER"` all match.

### Complete List of Known Default Names

#### Transform Snaps (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `mapper` | Describe the transformation (e.g., "Extract Customer Fields", "Map Order Totals") |
| `structure` | Describe the restructuring (e.g., "Flatten Nested Address", "Reshape API Response") |
| `type converter` | Describe what's being converted (e.g., "Convert Date Strings To Timestamps") |
| `script` | Describe the script's purpose (e.g., "Calculate Weighted Average", "Parse Custom Format") |
| `js script` | Describe the script's purpose (e.g., "Fetch Cyberark Credentials", "Build Dynamic Query") |

#### Flow and Routing Snaps (21 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `filter` | Describe the filter condition (e.g., "Remove Inactive Records", "Filter By Date Range") |
| `router` | Describe the routing logic (e.g., "Route By Region Code", "Split Success And Error") |
| `join` | Describe what's being joined (e.g., "Join Orders With Customers", "Merge Account Details") |
| `union` | Describe what's being combined (e.g., "Combine All Regional Data", "Union Header And Detail") |
| `data union` | Same as union — describe what's being combined |
| `sort` | Describe the sort criteria (e.g., "Sort By Transaction Date", "Order By Priority") |
| `merge` | Describe the merge logic (e.g., "Merge Sorted Customer Lists") |
| `split` | Describe the split logic (e.g., "Split Into Batches Of 1000") |
| `copy` | Describe the copy purpose (e.g., "Copy For Audit Trail", "Duplicate For Parallel Processing") |
| `gate` | Describe the gate condition (e.g., "Wait For All Inputs", "Synchronize Parallel Flows") |
| `sequence` | Describe the sequencing (e.g., "Process In Order", "Sequential Load") |
| `cross` | Describe the cross join (e.g., "Cross Join With Lookup Table") |
| `zip` | Describe the zip purpose (e.g., "Combine Header With Detail Records") |
| `unzip` | Describe the unzip purpose (e.g., "Separate Combined Records") |
| `head` | Describe the purpose (e.g., "Take First 100 Records For Testing") |
| `tail` | Describe the purpose (e.g., "Get Last 10 Error Records") |
| `sample` | Describe the sampling (e.g., "Sample 10% For QA Validation") |
| `group by n` | Describe the grouping (e.g., "Group Into Batches Of 500") |
| `aggregate` | Describe the aggregation (e.g., "Sum Revenue By Quarter") |
| `binary router` | Describe the routing (e.g., "Route Valid vs Invalid Records") |
| `data validator` | Describe what's being validated (e.g., "Validate Required Fields Present") |

#### Pipeline Execution Snaps (2 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `pipe execute` | Name the child pipeline being called (e.g., "Execute Enrichment Pipeline") |
| `pipeline execute` | Name the child pipeline being called (e.g., "Execute Data Quality Checks") |

#### File I/O Snaps (2 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `file reader` | Describe the source (e.g., "Read Input CSV From SFTP", "Read Config File") |
| `file writer` | Describe the destination (e.g., "Write Output CSV To S3", "Write Audit Log") |

#### JSON Snaps (4 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `json parser` | Describe what's being parsed (e.g., "Parse API Response", "Parse Config JSON") |
| `json formatter` | Describe what's being formatted (e.g., "Format Output For REST API") |
| `json generator` | Describe the data being generated (e.g., "Generate CDC Test Data") |
| `json splitter` | Describe what's being split (e.g., "Split Array Of Orders Into Individual Records") |

#### CSV Snaps (3 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `csv parser` | Describe the source (e.g., "Parse Vendor Upload CSV") |
| `csv formatter` | Describe the output (e.g., "Format Rebate Export CSV") |
| `csv generator` | Describe what's being generated (e.g., "Generate Test CSV Data") |

#### XML Snaps (3 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `xml parser` | Describe the source (e.g., "Parse SOAP Response") |
| `xml formatter` | Describe the output (e.g., "Format HL7 Message") |
| `xml generator` | Describe what's being generated (e.g., "Generate XML Payload For Vendor API") |

#### Binary Format Snaps (9 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `avro parser` | Describe the source (e.g., "Parse Kafka Avro Message") |
| `avro formatter` | Describe the output (e.g., "Format For Avro Storage") |
| `parquet parser` | Describe the source (e.g., "Parse S3 Parquet File") |
| `parquet formatter` | Describe the output (e.g., "Format For Parquet Archive") |
| `fixed width parser` | Describe the source (e.g., "Parse Mainframe Fixed Width File") |
| `fixed width formatter` | Describe the output (e.g., "Format For Legacy System Export") |
| `excel parser` | Describe the source (e.g., "Parse Monthly Sales Report Excel") |
| `binary to document` | Describe what's being converted (e.g., "Convert Downloaded File To Document") |
| `document to binary` | Describe what's being converted (e.g., "Convert Report To Binary For Upload") |

#### Database Snaps — Oracle (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `oracle - select` | Describe the query (e.g., "Read Customer Master Data", "Fetch Pending Orders") |
| `oracle - insert` | Describe the target (e.g., "Insert Into Customers Table", "Load Staging Records") |
| `oracle - execute` | Describe the operation (e.g., "Execute Merge Procedure", "Call Cleanup Stored Proc") |
| `oracle - update` | Describe the update (e.g., "Update Order Status To Complete") |
| `oracle - delete` | Describe the deletion (e.g., "Delete Expired Temp Records") |

#### Database Snaps — PostgreSQL (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `postgresql - select` | Describe the query (e.g., "Read User Profiles") |
| `postgresql - insert` | Describe the target (e.g., "Insert Audit Log Entry") |
| `postgresql - execute` | Describe the operation (e.g., "Execute Refresh Materialized View") |
| `postgresql - update` | Describe the update (e.g., "Update Last Login Timestamp") |
| `postgresql - delete` | Describe the deletion (e.g., "Purge Old Session Records") |

#### Database Snaps — MySQL (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `mysql - select` | Describe the query |
| `mysql - insert` | Describe the target |
| `mysql - execute` | Describe the operation |
| `mysql - update` | Describe the update |
| `mysql - delete` | Describe the deletion |

#### Database Snaps — SQL Server (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `sql server - select` | Describe the query |
| `sql server - insert` | Describe the target |
| `sql server - execute` | Describe the operation |
| `sql server - update` | Describe the update |
| `sql server - delete` | Describe the deletion |

#### Database Snaps — Snowflake (7 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `snowflake - select` | Describe the query |
| `snowflake - insert` | Describe the target |
| `snowflake - execute` | Describe the operation |
| `snowflake - update` | Describe the update |
| `snowflake - delete` | Describe the deletion |
| `snowflake - snowpipe streaming` | Describe the stream (e.g., "Stream Asset Brokerage Events") |
| `snowflake - bulk load` | Describe the load (e.g., "Bulk Load Daily Transaction File") |

#### Database Snaps — DB2 (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `db2 - select` | Describe the query |
| `db2 - insert` | Describe the target |
| `db2 - execute` | Describe the operation |
| `db2 - update` | Describe the update |
| `db2 - delete` | Describe the deletion |

#### Database Snaps — Redshift (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `redshift - select` | Describe the query |
| `redshift - insert` | Describe the target |
| `redshift - execute` | Describe the operation |
| `redshift - update` | Describe the update |
| `redshift - delete` | Describe the deletion |

#### Database Snaps — Teradata (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `teradata - select` | Describe the query |
| `teradata - insert` | Describe the target |
| `teradata - execute` | Describe the operation |
| `teradata - update` | Describe the update |
| `teradata - delete` | Describe the deletion |

#### Database Snaps — Generic JDBC (5 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `generic jdbc - select` | Describe the query |
| `generic jdbc - insert` | Describe the target |
| `generic jdbc - execute` | Describe the operation |
| `generic jdbc - update` | Describe the update |
| `generic jdbc - delete` | Describe the deletion |

#### Cloud — S3 Snaps (4 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `s3 upload` | Describe the upload (e.g., "Upload Processed CSV To Archive Bucket") |
| `s3 download` | Describe the download (e.g., "Download Vendor Input File") |
| `s3 delete` | Describe the deletion (e.g., "Delete Processed Files From Staging") |
| `s3 list` | Describe the listing (e.g., "List New Files In Inbox Folder") |

#### Cloud — Salesforce Snaps (9 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `salesforce create` | Describe the creation (e.g., "Create New Lead Records") |
| `salesforce read` | Describe the read (e.g., "Read Account Details") |
| `salesforce update` | Describe the update (e.g., "Update Opportunity Stage") |
| `salesforce delete` | Describe the deletion (e.g., "Delete Duplicate Contacts") |
| `salesforce upsert` | Describe the upsert (e.g., "Upsert Product Catalog") |
| `salesforce query` | Describe the query (e.g., "Query Open Cases By Priority") |
| `salesforce soql` | Describe the query (e.g., "SOQL Query Active Accounts") |
| `salesforce bulk read` | Describe the bulk read (e.g., "Bulk Export All Contacts") |
| `salesforce bulk upsert` | Describe the upsert (e.g., "Bulk Upsert Campaign Members") |

#### Messaging — Kafka Snaps (2 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `kafka producer` | Describe the message (e.g., "Publish Order Events To Kafka") |
| `kafka consumer` | Describe the consumption (e.g., "Consume Asset Brokerage Messages") |

#### Messaging — JMS Snaps (2 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `jms consumer` | Describe the queue (e.g., "Consume From Order Processing Queue") |
| `jms producer` | Describe the message (e.g., "Send To Notification Queue") |

#### Messaging — ActiveMQ Snaps (2 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `activemq consumer` | Describe the queue |
| `activemq producer` | Describe the message |

#### Email Snap (1 entry)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `email sender` | Describe the email (e.g., "Send Error Notification Email", "Send Daily Report") |

#### REST/HTTP Snaps (6 entries)

| Default Name | What It Should Be Named |
|-------------|------------------------|
| `rest get` | Describe the API call (e.g., "GET Customer Details From CRM API") |
| `rest post` | Describe the API call (e.g., "POST New Order To Fulfillment API") |
| `rest put` | Describe the API call (e.g., "PUT Updated Profile To User Service") |
| `rest delete` | Describe the API call (e.g., "DELETE Expired Token From Auth Service") |
| `rest patch` | Describe the API call (e.g., "PATCH Order Status In ERP") |
| `rest head` | Describe the API call (e.g., "HEAD Check File Exists On Remote Server") |

---

## Layer 3: Numbered Default Pattern

**What it catches:** Default names with a number appended. SnapLogic appends numbers when you drag multiple snaps of the same type onto the canvas.

**Logic:**
```python
# Pattern is auto-built from KNOWN_DEFAULT_NAMES at init time
# Matches: "KnownDefault" + optional whitespace + one or more digits
if NUMBERED_DEFAULT_PATTERN.match(name_lower):
    reason = f"Snap name '{name}' appears to be a numbered default"
```

**Examples:**

| Snap Name | Base | Number | Result |
|-----------|------|--------|--------|
| `"Mapper1"` | Mapper | 1 | ❌ FAIL |
| `"Mapper 1"` | Mapper | 1 | ❌ FAIL |
| `"Filter 2"` | Filter | 2 | ❌ FAIL |
| `"Oracle - Select 3"` | Oracle - Select | 3 | ❌ FAIL |
| `"Copy 47"` | Copy | 47 | ❌ FAIL |
| `"JSON Splitter2"` | JSON Splitter | 2 | ❌ FAIL |
| `"Snowflake - Insert 5"` | Snowflake - Insert | 5 | ❌ FAIL |
| `"Kafka Producer3"` | Kafka Producer | 3 | ❌ FAIL |
| `"Customer Mapper 1"` | — | — | ✅ PASS ("Customer Mapper" is not a known default) |
| `"Mapper One"` | — | — | ✅ PASS ("One" is not a digit) |
| `"Extract Fields 2"` | — | — | ✅ PASS ("Extract Fields" is not a known default) |

**Why it matters:** `Mapper1` is marginally better than `Mapper` because you can distinguish it in error messages. But it still tells you nothing about the snap's purpose. "First Mapper" or "Mapper for customers" would be even worse — but at least they attempt to describe something. The numbered pattern is a clear sign the developer didn't think about naming at all.

---

## Layer 4: Auto-Derived Defaults from class_id

**What it catches:** Default names for snap types **NOT** in the hardcoded list. This is the **zero-maintenance** layer — it works for any snap type, including ones released after this library was written.

**Logic:**
```python
auto_defaults = _generate_default_names_from_class_id(snap['class_id'])
if name_lower in auto_defaults:
    reason = f"Snap name '{name}' is a default name (auto-detected from snap type)"
```

### How class_id Maps to Default Names

Every snap has a `class_id` that follows a predictable structure:

```
com - snaplogic - snaps - category - operation
│         │         │        │          │
└─────────┴─────────┘        │          │
  Always the same             │          │
  (stripped off)           category    operation
```

The method generates possible default names based on the **category**:

### Pattern 1: Database Snaps → `"DB - Operation"`

```
class_id: com-snaplogic-snaps-oracle-insert
category: oracle
operation: insert
→ Generated: {"insert", "oracle - insert"}
```

Recognized database categories:
`oracle`, `postgres`, `mysql`, `sqlserver`, `snowflake`, `db2`, `redshift`, `teradata`, `jdbc`, `bigquery`, `sybase`, `informix`, `saphana`, `aurora`

Display name mappings for non-obvious categories:

| category | Display Name |
|----------|-------------|
| `postgres` | PostgreSQL |
| `sqlserver` | SQL Server |
| `jdbc` | Generic JDBC |
| `bigquery` | BigQuery |
| `saphana` | SAP HANA |
| `db2` | DB2 |

### Pattern 2: SaaS Snaps → `"Service Operation"`

```
class_id: com-snaplogic-snaps-salesforce-create
category: salesforce
operation: create
→ Generated: {"create", "salesforce create"}
```

Recognized SaaS categories:
`salesforce`, `servicenow`, `workday`, `netsuite`, `dynamics`

### Pattern 3: Cloud Snaps → `"CLOUD Operation"`

```
class_id: com-snaplogic-snaps-s3-s3upload
category: s3
operation: s3upload
→ Strip repeated prefix: s3upload → upload
→ Generated: {"s3upload", "s3 upload"}
```

Recognized cloud categories:
`s3`, `azure`, `gcs`

### Pattern 4: Generic Fallback

For categories not in the above lists, the raw operation name is generated:

```
class_id: com-snaplogic-snaps-transform-datatransform
→ Generated: {"datatransform"}
```

### Full Examples

| class_id | Auto-Generated Defaults |
|----------|------------------------|
| `com-snaplogic-snaps-oracle-insert` | `{"insert", "oracle - insert"}` |
| `com-snaplogic-snaps-salesforce-create` | `{"create", "salesforce create"}` |
| `com-snaplogic-snaps-s3-s3upload` | `{"s3upload", "s3 upload"}` |
| `com-snaplogic-snaps-transform-datatransform` | `{"datatransform"}` |
| `com-snaplogic-snaps-snowflake-snowpipestreaming` | `{"snowpipestreaming", "snowflake - snowpipestreaming"}` |
| `com-snaplogic-snaps-bigquery-select` | `{"select", "bigquery - select"}` |
| `com-snaplogic-snaps-dynamics-read` | `{"read", "dynamics read"}` |
| `com-snaplogic-snaps-azure-azureupload` | `{"azureupload", "azure upload"}` |
| `com-snaplogic-snaps-servicenow-create` | `{"create", "servicenow create"}` |

### Why Both Layer 2 and Layer 4 Are Needed

SnapLogic sometimes uses **human-friendly** names that don't match the class_id:

| class_id | Default Name on Canvas | Layer 2 Catches | Layer 4 Catches |
|----------|----------------------|:---:|:---:|
| `com-snaplogic-snaps-transform-datatransform` | **Mapper** | ✅ (in hardcoded list) | ❌ (generates "datatransform") |
| `com-snaplogic-snaps-transform-structuraltransform` | **Structure** | ✅ (in hardcoded list) | ❌ (generates "structuraltransform") |
| `com-snaplogic-snaps-flow-pipeexec` | **Pipeline Execute** | ✅ (in hardcoded list) | ❌ (generates "pipeexec") |
| `com-snaplogic-snaps-transform-multijoin` | **Join** | ✅ (in hardcoded list) | ❌ (generates "multijoin") |
| `com-snaplogic-snaps-bigquery-select` | **BigQuery - Select** | ❌ (not in list) | ✅ (auto-derived) |
| `com-snaplogic-snaps-dynamics-read` | **Dynamics Read** | ❌ (not in list) | ✅ (auto-derived) |

**Layer 2** handles snaps where SnapLogic chose a different display name than the class_id implies.
**Layer 4** handles new/unknown snap types that aren't in the hardcoded list.

Together they provide comprehensive coverage.

---

## Layer 5: Exact Type Match

**What it catches:** Snap names that exactly match the internal `simple_type` extracted from the class_id. This is the **last resort** safety net.

**Logic:**
```python
simple_type = _extract_simple_type(class_id)
# e.g., "com-snaplogic-snaps-transform-datatransform" → "datatransform"

if name_lower == simple_type.lower():
    reason = f"Snap name '{name}' matches its type exactly"
```

**Examples:**

| class_id | simple_type | Snap Name | Result |
|----------|-------------|-----------|--------|
| `com-snaplogic-snaps-transform-datatransform` | `datatransform` | `"datatransform"` | ❌ FAIL |
| `com-snaplogic-snaps-flow-pipeexec` | `pipeexec` | `"pipeexec"` | ❌ FAIL |
| `com-snaplogic-snaps-transform-multijoin` | `multijoin` | `"multijoin"` | ❌ FAIL |
| `com-snaplogic-snaps-flow-datavalidator` | `datavalidator` | `"datavalidator"` | ❌ FAIL |
| `com-snaplogic-snaps-transform-datatransform` | `datatransform` | `"Extract Fields"` | ✅ PASS |

**Why it matters:** If someone somehow types the raw internal type name as the snap name, this catches it. It's rare, but possible.

---

## Adding Custom Default Names

Teams can extend the default names list without modifying Python code.

### Option 1: Inline in .robot File

```robot
*** Variables ***
@{EXTRA_DEFAULTS}
...    custom etl loader
...    my company snap
...    data processor
...    snowflake bulk loader

*** Test Cases ***
Verify Snap Naming Standards
    ${pipeline}=    Load Pipeline File    ${PIPELINE_FILE}
    ${result}=      Validate Snap Naming Standards    ${pipeline}    additional_defaults=${EXTRA_DEFAULTS}
    Should Be Equal    ${result}[status]    PASS
```

### Option 2: From a YAML Variable File

```robot
*** Settings ***
Variables    ../test_data/naming_defaults.yaml

*** Test Cases ***
Verify Snap Naming Standards
    ${pipeline}=    Load Pipeline File    ${PIPELINE_FILE}
    ${result}=      Validate Snap Naming Standards    ${pipeline}    additional_defaults=${EXTRA_DEFAULTS}
    Should Be Equal    ${result}[status]    PASS
```

Where `naming_defaults.yaml`:
```yaml
EXTRA_DEFAULTS:
  - custom etl loader
  - my company snap
  - data processor
```

Custom names are merged with the hardcoded list — no names are removed.

---

## Return Value Structure

The validation returns a dictionary with full details:

```python
{
    "status": "FAIL",               # "PASS" if zero violations
    "total_snaps": 15,              # Total snaps in the pipeline
    "total_violations": 6,          # How many snaps failed
    "violations": [
        {
            "snap_id": "abc123-def456",
            "snap_name": "Filter",
            "snap_type": "filter",
            "reason": "Snap name 'Filter' is a known default name"
        },
        {
            "snap_id": "ghi789-jkl012",
            "snap_name": "Mapper1",
            "snap_type": "datatransform",
            "reason": "Snap name 'Mapper1' appears to be a numbered default"
        },
        {
            "snap_id": "mno345-pqr678",
            "snap_name": "Oracle - Insert",
            "snap_type": "oracle-insert",
            "reason": "Snap name 'Oracle - Insert' is a default name (auto-detected from snap type)"
        },
        {
            "snap_id": "stu901-vwx234",
            "snap_name": "",
            "snap_type": "filter",
            "reason": "Snap name is empty"
        },
        {
            "snap_id": "yza567-bcd890",
            "snap_name": "datatransform",
            "snap_type": "datatransform",
            "reason": "Snap name 'datatransform' matches its type exactly"
        },
        {
            "snap_id": "efg123-hij456",
            "snap_name": "BigQuery - Select",
            "snap_type": "bigquery-select",
            "reason": "Snap name 'BigQuery - Select' is a default name (auto-detected from snap type)"
        }
    ]
}
```

---

## Real-World Example: oracle2.slp

Running against `oracle2.slp` produces:

```
[FAIL] Snap Naming (6 violation(s))
       - Snap name 'Data Validator' is a known default name        ← Layer 2
       - Snap name 'Filter' is a known default name                ← Layer 2
       - Snap name 'Structure' is a known default name             ← Layer 2
       - Snap name 'File Writer' is a known default name           ← Layer 2
       - Snap name 'CSV Formatter' is a known default name         ← Layer 2
       - Snap name 'Oracle - Insert' is a known default name       ← Layer 2
```

Snaps that **passed**:

| Snap Name | Why It Passed |
|-----------|---------------|
| `CDC Data Generator` | Not a default — describes purpose |
| `Extract fields` | Not a default — describes purpose |
| `Enrichment & Map` | Not a default — describes purpose |
| `Map_Col_Values` | Not a default — describes purpose |
| `RUUID` | Not a default — describes purpose |

Snaps that **failed** and what they should be renamed to:

| Current Name | Suggested Rename |
|-------------|-----------------|
| `Data Validator` | `Validate Required Fields Present` |
| `Filter` | `Remove Null Records` or `Filter By Status` |
| `Structure` | `Reshape For Oracle Insert` |
| `File Writer` | `Write Audit Output CSV` |
| `CSV Formatter` | `Format Audit Report CSV` |
| `Oracle - Insert` | `Insert Into Customers Table` |

---

## Summary Table: All 5 Layers

| Layer | What It Catches | Maintenance | Example Caught |
|-------|----------------|-------------|----------------|
| **1. Empty** | Blank or whitespace names | None | `""` |
| **2. Known Defaults** | 100+ hardcoded default names | Manual — add new entries | `"Mapper"`, `"Oracle - Select"` |
| **3. Numbered Defaults** | Defaults with appended numbers | Auto-built from Layer 2 | `"Mapper1"`, `"Filter 2"` |
| **4. Auto-Derived** | Defaults generated from class_id | Zero — works for any snap | `"BigQuery - Select"`, `"Azure Upload"` |
| **5. Exact Type** | Name matches internal type string | Zero — uses class_id | `"datatransform"`, `"pipeexec"` |
