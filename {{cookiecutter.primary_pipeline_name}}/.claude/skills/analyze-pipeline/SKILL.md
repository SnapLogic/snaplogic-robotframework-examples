---
name: analyze-pipeline
description: Analyze a SnapLogic .slp pipeline file and extract accounts, parameters, snaps, data flow, and output paths. Use when the user wants to understand what a pipeline does before generating test cases, or needs a test blueprint from a pipeline file.
user-invocable: true
---

# Analyze Pipeline — Extract Test Blueprint from .slp Files

## Claude Instructions

You are a **SnapLogic Pipeline Analyst**. Your job is to read `.slp` pipeline files (JSON format), parse them, and produce a clear, structured analysis that can be used to generate Robot Framework test cases.

**MANDATORY WORKFLOW:**
1. **Read the .slp file** — it's JSON, parse it completely
2. **Extract ALL metadata** — parameters, accounts, snaps, links, output paths
3. **Trace the data flow** — from source to destination through all snaps
4. **Identify test requirements** — what accounts, tasks, and verifications are needed
5. **Produce a PIPELINE_ANALYSIS.md** — structured report with all findings

**DO NOT:**
- Modify the .slp file
- Generate test files (that's for other skills like create-account, end-to-end)
- Guess values — only report what's in the file
- Skip any snaps or parameters

---

## .slp File Format — What to Parse

An `.slp` file is a JSON object with this structure:

```json
{
  "property_map": {
    "info": {
      "label": {"value": "pipeline_name"},
      "author": {"value": "user@company.com"}
    },
    "settings": {
      "param_table": {
        "value": [
          {
            "key": {"value": "param_name"},
            "value": {"value": "default_value"},
            "data_type": {"value": "string"},
            "description": {"value": "..."}
          }
        ]
      }
    }
  },
  "snap_map": {
    "snap_id_1": {
      "class_id": "com-snaplogic-snaps-<type>-<operation>",
      "property_map": {
        "info": {"label": {"value": "Snap Label"}},
        "account": {"account_ref": {"value": "_param_name"}},
        "settings": { ... }
      }
    }
  },
  "link_map": {
    "link1": {
      "src_id": "snap_id_1",
      "dst_id": "snap_id_2"
    }
  }
}
```

### Key extraction points

| JSON Path | What it contains |
|---|---|
| `property_map.info.label.value` | Pipeline name |
| `property_map.info.author.value` | Author |
| `property_map.settings.param_table.value` | Pipeline parameters (array) |
| `snap_map.<id>.class_id` | Snap type (e.g., `com-snaplogic-snaps-jdbc-select`, `com-snaplogic-snaps-binary-write`) |
| `snap_map.<id>.property_map.info.label.value` | Snap label |
| `snap_map.<id>.property_map.account.account_ref.value` | Account reference (expression starting with `_` = pipeline parameter) |
| `snap_map.<id>.property_map.settings.*` | Snap-specific settings (SQL, file paths, topics, etc.) |
| `link_map.<id>.src_id / dst_id` | Data flow connections between snaps |

### Account reference convention

- `_param_name` (with leading underscore) = references pipeline parameter `param_name`
- `../shared/account_name` = hardcoded account path in SnapLogic
- `{}` (empty object) = no account

### Snap type → database/service mapping

| Snap class_id contains | Service |
|---|---|
| `oracle` | Oracle Database |
| `postgres` | PostgreSQL |
| `mysql` | MySQL |
| `sqlserver` | SQL Server |
| `snowflake` | Snowflake |
| `jdbc` | Generic JDBC (check account for actual DB) |
| `kafka` | Apache Kafka |
| `jms` | JMS / ActiveMQ |
| `s3` or `binary-write` with `s3://` | AWS S3 / MinIO |
| `binary-write` with `file://` | Local file system |
| `binary-read` with `file://` | Local file system |
| `transform` or `datatransform` | Data transformation (no account) |
| `csvformatter` or `csvparser` | CSV processing (no account) |
| `jsonformatter` or `jsonparser` | JSON processing (no account) |
| `email` or `smtp` | Email |
| `salesforce` | Salesforce |

---

## What to Extract

### 1. Pipeline Metadata

| Field | Where |
|---|---|
| Name | `property_map.info.label.value` |
| Author | `property_map.info.author.value` |
| Path | `path_id` (if present) |
| Number of snaps | `len(snap_map)` |
| Number of links | `len(link_map)` |

### 2. Pipeline Parameters

For each entry in `param_table.value`:

| Field | Where |
|---|---|
| Name | `key.value` |
| Default value | `value.value` |
| Data type | `data_type.value` |
| Required | `required.value` |
| Description | `description.value` |

**Flag parameters that are account references** — default value containing `../shared/` or used in a snap's `account_ref`.

### 3. Snaps (Components)

For each snap in `snap_map`:

| Field | Where |
|---|---|
| Label | `property_map.info.label.value` |
| Type | `class_id` |
| Account | `property_map.account.account_ref.value` |
| Key settings | `property_map.settings.*` (SQL, file paths, table names, etc.) |

### 4. Data Flow

Trace `link_map` to build the execution order:

```
Source Snap → Intermediate Snap → ... → Destination Snap
```

### 5. Output Paths

Find snaps that write data:
- File Writer snaps: extract `filename` from settings
- S3 snaps: extract bucket/path
- Database Insert/Update snaps: extract table names

### 6. Test Requirements Summary

Based on the analysis, identify:

| What's needed | Why |
|---|---|
| **Accounts to create** | Each unique account_ref = one account test case |
| **Files to upload** | JARs, expression libraries referenced by the pipeline |
| **Pipeline to import** | The .slp file itself |
| **Triggered task parameters** | Pipeline parameters that should be passed at execution |
| **Data to verify** | Output tables/files to check after execution |
| **CSVs to compare** | Output CSV files that can be compared to expected output |

---

## Output Format — PIPELINE_ANALYSIS.md

Write the analysis to `{output_dir}/PIPELINE_ANALYSIS.md` (or the codebase root if no output_dir).

### Template

```markdown
# Pipeline Analysis — {pipeline_name}

**File:** `{slp_file_path}`
**Author:** {author}
**Snaps:** {count} | **Links:** {count} | **Parameters:** {count}

---

## Pipeline Parameters

| # | Parameter | Default Value | Type | Account? | Description |
|---|-----------|--------------|------|----------|-------------|
| 1 | `param_name` | `default` | string | Yes/No | ... |

## Accounts Required

| # | Account Parameter | Default Path | Service Type | Env File Needed |
|---|-------------------|-------------|--------------|-----------------|
| 1 | `{account_param}` | `{default_path}` | {service} | `.env.{service}` |
(list ALL unique accounts found in snap_map)

## Snaps (Execution Order)

| # | Snap Label | Type | Account | Key Settings |
|---|-----------|------|---------|--------------|
| 1 | {snap_label} | {class_id} | {account_ref or (none)} | {key settings from snap} |
(list ALL snaps from snap_map, ordered by data flow)

## Data Flow

```
{Source Snap} → {Next Snap} → ... → {Final Snap}
   ({service})    ({type})           ({destination})
```
(trace link_map to determine execution order)

## Output Files / Tables

| # | Type | Path / Table | Format |
|---|------|-------------|--------|
| 1 | {File/DB/S3/Topic} | {extracted path or table name} | {CSV/JSON/binary} |
(find ALL snaps that write data — File Writers, DB Inserts, S3 Writers, Kafka Producers)

## Test Blueprint

Based on this pipeline, the following Robot Framework test cases are needed:

### 1. Account Setup
- [ ] Create {service} account(s) using the account parameter(s) found above

### 2. Data Setup
- [ ] Create required database tables
- [ ] Load test data (CSV/JSON)

### 3. Pipeline Import & Execution
- [ ] Upload any required JARs or expression libraries
- [ ] Import `{pipeline_name}.slp`
- [ ] Create triggered task with parameters: {param_list}
- [ ] Execute triggered task

### 4. Verification
- [ ] Compare output CSV against expected: `{output_path}`
- [ ] Verify database row counts (if applicable)

### Suggested rf-forge commands

```bash
# 1. Create accounts
rf-forge create-account "Create {service} account for {pipeline_name}" --codebase-path .

# 2. Generate E2E test suite
rf-forge end-to-end-pipeline-verification "E2E tests for {pipeline_name} pipeline" --codebase-path .
```
```

---

## Multiple .slp Files

If the user points at a folder containing multiple `.slp` files, analyze ALL of them and produce:

1. Individual analysis per pipeline
2. A summary table showing all pipelines, their accounts, and shared dependencies

---

## Examples of .slp files in this project

| Pipeline | Accounts | Key snaps | Output |
|---|---|---|---|
| `oracle.slp` | Oracle (execute) | Read → Transform → Execute × 2 | DB operations |
| `db2.slp` | DB2 (JDBC select) | Select → CSV Formatter → File Writer | `employee_db2.csv` |
| `mysql.slp` | MySQL | Select → CSV → File Writer | `employee_mysql.csv` |
| `postgres_to_s3_csv.slp` | PostgreSQL + S3 | Select → CSV → S3 Writer | S3 bucket |
| `snowflake.slp` | Snowflake | Multiple read/write operations | DB + CSV |
| `kafka.slp` | Kafka | Producer/Consumer | Kafka topics |
| `salesforce.slp` | Salesforce | Read/Write Salesforce objects | SF records |

---

## Checklist

- [ ] Read the .slp file(s) completely
- [ ] Extracted all pipeline parameters
- [ ] Identified all account references
- [ ] Mapped all snaps with their types and settings
- [ ] Traced data flow from source to destination
- [ ] Identified all output paths (files, tables, topics)
- [ ] Produced test blueprint with suggested rf-forge commands
- [ ] Wrote PIPELINE_ANALYSIS.md
