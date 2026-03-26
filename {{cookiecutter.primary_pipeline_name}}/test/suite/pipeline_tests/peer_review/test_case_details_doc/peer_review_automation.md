# SnapLogic Pipeline Peer Review Automation

## Overview

This framework automates the SnapLogic pipeline peer review process using Robot Framework. It performs **static analysis** on pipeline `.slp` files — no running services, no API calls, no pipeline execution required.

All checks are based on the peer review checklist used by development teams to ensure pipeline quality, maintainability, and compliance with design standards.

---

## Architecture

```
peer_review_tests.robot              pipeline_inspector.resource           PipelineInspectorLibrary.py
(WHAT to test)                       (HOW to test + logging)               (ENGINE - parsing + analysis)
────────────────────                 ──────────────────────────            ──────────────────────────────
12 static + 4 post-execution         20 keywords                           16 public keywords + 8 helpers
Tags for selective runs              Reusable across test files            Parses .slp JSON, runs checks
Asserts PASS/FAIL                    Logs violations as warnings           Returns result dictionaries
```

### File Locations

| File | Path | Purpose |
|------|------|---------|
| Test Cases | `test/suite/pipeline_tests/peer_review/peer_review_tests.robot` | Test declarations + assertions |
| Resource Keywords | `test/resources/common/pipeline_inspector.resource` | Reusable keywords with logging |
| Python Library | `test/libraries/common/PipelineInspectorLibrary.py` | Core engine — JSON parsing + validation logic |

---

## Test Cases

### Static Analysis — Individual Pipeline Checks (11 test cases)

| # | Test Case | Tag(s) | Peer Review Item |
|---|-----------|--------|------------------|
| 1 | Verify Snap Naming Standards Are Followed | `peer_review`, `snap_naming`, `static_analysis` | Snap Naming Standards |
| 2 | Verify No Duplicate Snap Names Exist | `peer_review`, `snap_naming`, `static_analysis` | Snap Naming Standards |
| 3 | Verify Pipeline Naming Convention | `peer_review`, `pipeline_naming`, `static_analysis` | Pipeline Naming Standards |
| 4 | Verify Child Pipeline Naming Convention | `peer_review`, `pipeline_naming`, `child_pipeline`, `static_analysis` | Child Pipeline z_ Prefix |
| 5 | Verify Pipeline Naming With Auto Detection | `peer_review`, `pipeline_naming`, `auto_detect`, `static_analysis` | Auto-detect parent/child + naming |
| 6 | Verify All Parameters Have Capture Enabled | `peer_review`, `parameters`, `static_analysis` | Pipeline Properties — Settings |
| 7 | Verify Parameters Follow Naming Convention | `peer_review`, `parameters`, `static_analysis` | Pipeline Properties — Settings |
| 8 | Verify Account References Are Not Hardcoded | `peer_review`, `accounts`, `static_analysis` | Accounts |
| 9 | Verify Account References Use Shared Folder Format | `peer_review`, `accounts`, `static_analysis` | Accounts |
| 10 | Verify Pipeline Info Has Documentation Link | `peer_review`, `documentation`, `static_analysis` | Pipeline Properties — Info |
| 11 | Verify Pipeline Info Has Notes | `peer_review`, `documentation`, `static_analysis` | Pipeline Properties — Info |

### Static Analysis — Batch Review (1 test case)

| # | Test Case | Tag(s) | Purpose |
|---|-----------|--------|---------|
| 12 | Batch Review All Pipeline Files In Directory | `peer_review2`, `batch_review`, `static_analysis` | Runs all checks on every `.slp` file in a directory |

### Post-Execution (Requires Pipeline Execution)

| # | Test Case | Tag(s) | Test File | Peer Review Item |
|---|-----------|--------|-----------|------------------|
| 13 | Execute Trigger Task Within Certain Time | `sla_pipeline` | `sla/sla_pipeline.robot` | Run Pipeline — not excessive time |
| 14 | Verify Data In Oracle Table | `oracle` | `oracle/oracle_baseline_tests.robot` | Run Pipeline — results are expected |
| 15 | Export Oracle Data To CSV | `oracle` | `oracle/oracle_baseline_tests.robot` | Run Pipeline — results are expected |
| 16 | Compare Actual vs Expected CSV Output | `oracle` | `oracle/oracle_baseline_tests.robot` | Run Pipeline — results are expected |

---

## How to Run

### Run All Peer Review Checks (Single Pipeline)

```bash
make robot-run-tests TAGS="peer_review"
```

### Run Specific Check Categories

```bash
# Snap naming checks only
make robot-run-tests TAGS="snap_naming"

# Parameter checks only
make robot-run-tests TAGS="parameters"

# Account checks only
make robot-run-tests TAGS="accounts"

# Documentation checks only
make robot-run-tests TAGS="documentation"

# Child pipeline naming only
make robot-run-tests TAGS="child_pipeline"
```

### Run Batch Review (All Pipelines in Directory)

```bash
make robot-run-tests TAGS="batch_review"
```

### Override Variables

```bash
# Specify a different pipeline file
make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable pipeline_file:/app/src/pipelines/snowflake.slp"

# Specify a different pipeline directory for batch review
make robot-run-tests TAGS="batch_review" EXTRA_ARGS="--variable pipeline_dir:/app/src/generative_pipelines"

# Enforce project name in pipeline naming
make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable project_name:greenlight"

# Mark as child pipeline (enforce z_ prefix) for single pipeline review
make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable is_child_pipeline:True"
```

**Note:** In batch review, parent/child detection is automatic from the pipeline name (starts with `z_` → child). No manual override needed.

---

## Detailed Check Descriptions

### 1. Validate Snap Naming Standards

**Peer Review Requirement:** *"A SnapLogic pipeline should have its snaps named in such a manner that a casual observer should have an idea of their purpose in the pipeline."*

**What it checks:** Every snap in the pipeline is validated against 5 layers of detection:

#### Layer 1: Empty Name Check

Flags snaps with no name or whitespace-only names.

| Snap Name | Result |
|-----------|--------|
| `""` (blank) | FAIL — "Snap name is empty" |
| `"  "` (spaces) | FAIL — "Snap name is empty" |

#### Layer 2: Known Default Names (Hardcoded List)

Checks against 100+ known default names that SnapLogic assigns when a snap is dragged onto the canvas. Organized by category:

| Category | Default Names |
|----------|--------------|
| **Transform** | mapper, structure, type converter, script, js script |
| **Flow/Routing** | filter, router, join, union, data union, sort, merge, split, copy, gate, sequence, cross, zip, unzip, head, tail, sample, group by n, aggregate, binary router, data validator |
| **Pipeline Execution** | pipe execute, pipeline execute |
| **File I/O** | file reader, file writer |
| **JSON** | json parser, json formatter, json generator, json splitter |
| **CSV** | csv parser, csv formatter, csv generator |
| **XML** | xml parser, xml formatter, xml generator |
| **Binary Formats** | avro parser, avro formatter, parquet parser, parquet formatter, fixed width parser, fixed width formatter, excel parser, binary to document, document to binary |
| **Database — Oracle** | oracle - select, oracle - insert, oracle - execute, oracle - update, oracle - delete |
| **Database — PostgreSQL** | postgresql - select, postgresql - insert, postgresql - execute, postgresql - update, postgresql - delete |
| **Database — MySQL** | mysql - select, mysql - insert, mysql - execute, mysql - update, mysql - delete |
| **Database — SQL Server** | sql server - select, sql server - insert, sql server - execute, sql server - update, sql server - delete |
| **Database — Snowflake** | snowflake - select, snowflake - insert, snowflake - execute, snowflake - update, snowflake - delete, snowflake - snowpipe streaming, snowflake - bulk load |
| **Database — DB2** | db2 - select, db2 - insert, db2 - execute, db2 - update, db2 - delete |
| **Database — Redshift** | redshift - select, redshift - insert, redshift - execute, redshift - update, redshift - delete |
| **Database — Teradata** | teradata - select, teradata - insert, teradata - execute, teradata - update, teradata - delete |
| **Database — Generic JDBC** | generic jdbc - select, generic jdbc - insert, generic jdbc - execute, generic jdbc - update, generic jdbc - delete |
| **Cloud — S3** | s3 upload, s3 download, s3 delete, s3 list |
| **Cloud — Salesforce** | salesforce create, salesforce read, salesforce update, salesforce delete, salesforce upsert, salesforce query, salesforce soql, salesforce bulk read, salesforce bulk upsert |
| **Messaging — Kafka** | kafka producer, kafka consumer |
| **Messaging — JMS** | jms consumer, jms producer |
| **Messaging — ActiveMQ** | activemq consumer, activemq producer |
| **Email** | email sender |
| **REST/HTTP** | rest get, rest post, rest put, rest delete, rest patch, rest head |

**Examples:**

| Snap Name | Result |
|-----------|--------|
| `"Mapper"` | FAIL — "known default name" |
| `"Oracle - Select"` | FAIL — "known default name" |
| `"Kafka Producer"` | FAIL — "known default name" |
| `"Extract Customer Fields"` | PASS |

#### Layer 3: Numbered Default Pattern (Regex)

Auto-built from the known defaults list. Catches names like `Mapper1`, `Filter 2`, `Oracle - Select 3`.

| Snap Name | Result |
|-----------|--------|
| `"Mapper1"` | FAIL — "numbered default" |
| `"Filter 2"` | FAIL — "numbered default" |
| `"Oracle - Select 3"` | FAIL — "numbered default" |
| `"JSON Splitter2"` | FAIL — "numbered default" |
| `"Customer Mapper 1"` | PASS (not a known default base) |

#### Layer 4: Auto-Derived Defaults (from class_id)

For snap types NOT in the hardcoded list, default names are generated from the snap's `class_id`. This is the **zero-maintenance** layer — works for any snap, including future ones.

How it works:
```
class_id: "com-snaplogic-snaps-oracle-insert"
                                    │       │
                                 category  operation
                                    ↓
                         Generates: {"insert", "oracle - insert"}
```

Pattern types:
- **Database snaps**: `"DB - Operation"` (e.g., `"BigQuery - Select"`)
- **SaaS snaps**: `"Service Operation"` (e.g., `"ServiceNow Read"`)
- **Cloud snaps**: `"CLOUD Operation"` (e.g., `"Azure Upload"`)

| class_id | Auto-Generated Defaults |
|----------|------------------------|
| `com-snaplogic-snaps-bigquery-select` | `{"select", "bigquery - select"}` |
| `com-snaplogic-snaps-dynamics-read` | `{"read", "dynamics read"}` |
| `com-snaplogic-snaps-azure-azureupload` | `{"azureupload", "azure upload"}` |

#### Layer 5: Exact Type Match (Last Resort)

If the snap name exactly matches the internal `simple_type` extracted from the class_id.

| class_id | simple_type | Snap Name | Result |
|----------|-------------|-----------|--------|
| `com-snaplogic-snaps-transform-datatransform` | `datatransform` | `"datatransform"` | FAIL |
| `com-snaplogic-snaps-flow-pipeexec` | `pipeexec` | `"pipeexec"` | FAIL |

#### Adding Custom Default Names

Teams can add their own defaults without modifying Python code:

```robot
*** Variables ***
@{EXTRA_DEFAULTS}    custom etl loader    my company snap    data processor

*** Test Cases ***
Verify Snap Naming Standards
    ${pipeline}=    Load Pipeline File    ${PIPELINE_FILE}
    ${result}=      Validate Snap Naming Standards    ${pipeline}    additional_defaults=${EXTRA_DEFAULTS}
    Should Be Equal    ${result}[status]    PASS
```

---

### 2. Validate No Duplicate Snap Names

**Peer Review Requirement:** *All snap names within a pipeline must be unique.*

Counts occurrences of each snap name. Any name appearing more than once is a violation.

| Pipeline Contents | Result |
|-------------------|--------|
| Mapper, Filter, Router (all unique) | PASS |
| Mapper, Mapper, Router | FAIL — "Mapper appears 2 times" |
| Copy, Copy, Copy | FAIL — "Copy appears 3 times" |

**Why it matters:** Duplicate names make error tracing impossible. When a pipeline fails at "Mapper", you can't tell which of the 3 mappers caused the failure.

---

### 3. Validate Pipeline Naming Convention

**Peer Review Requirement:** *"Pipelines need to include name of project (Ex. z_greenlight_acquisition)"*

Checks that the pipeline name **contains** the required project name (substring match, not prefix).

| Pipeline Name | Project Name | Result |
|---------------|-------------|--------|
| `z_greenlight_acquisition` | `greenlight` | PASS — contains "greenlight" |
| `my_greenlight_pipeline` | `greenlight` | PASS — contains "greenlight" |
| `oracle_test` | `greenlight` | FAIL — does not contain "greenlight" |
| `any_name` | (none configured) | PASS (check skipped) |

---

### 4. Verify Child Pipeline Naming Convention

**Peer Review Requirement:** *"Child pipeline — Need to start with z_"*

Only runs when `is_child_pipeline=True`. Checks that the pipeline name starts with `z_`.

| Pipeline Name | is_child_pipeline | Result |
|---------------|-------------------|--------|
| `z_enrichment_child` | True | PASS |
| `enrichment_child` | True | FAIL — "does not start with z_" |
| `parent_pipeline` | False | SKIP — "Not a child pipeline" |

**In batch review:** Auto-detected from the pipeline name inside the `.slp` file. If the pipeline name starts with `z_`, it's treated as a child pipeline.

---

### 5. Validate All Parameters Have Capture Enabled

**Peer Review Requirement:** *"Make sure all inputs are captured. (The 'Capture' checkbox should be checked.)"*

Checks every pipeline parameter to ensure the `capture` flag is `True`.

| Parameter | Capture | Result |
|-----------|---------|--------|
| `xx_schema_name` | True | PASS |
| `xx_table_name` | True | PASS |
| `oracle_acct` | False | FAIL — "does not have Capture enabled" |

**Why it matters:** Without capture enabled, parameter values are not logged during execution, making debugging and auditing impossible.

---

### 6. Validate Parameters Follow Naming Convention (xx Prefix)

**Peer Review Requirement:** *"Make all parameters prefixed with xx to ensure variables are being passed through the pipeline correctly. With the exception of top layer pipelines."*

Checks that all parameter names start with the configured prefix (default: `xx`).

| Parameter | Prefix | is_parent_pipeline | Result |
|-----------|--------|--------------------|--------|
| `xx_schema_name` | xx | False | PASS |
| `schema_name` | xx | False | FAIL — "does not start with 'xx'" |
| `schema_name` | xx | True | SKIP — "Parent pipelines are exempt" |

**Why `xx` prefix exists:** When a child pipeline is called via Pipeline Execute, parameters without the `xx` prefix might accidentally inherit values from the parent's scope instead of receiving explicitly passed values. The `xx` prefix acts as a poisoning mechanism to force explicit passing.

**In batch review:** Auto-detected from the pipeline name inside the `.slp` file:
- Pipeline name starts with `z_` → child → `is_parent_pipeline=False` → prefix enforced
- Pipeline name does NOT start with `z_` → parent → `is_parent_pipeline=True` → prefix check skipped

---

### 7. Validate Account References Are Not Hardcoded

**Peer Review Requirement:** *"Accounts should never be hard coded."*

Checks that account references in snaps use expressions (pipeline parameters) rather than hardcoded paths.

| Account Reference | Result |
|-------------------|--------|
| `$oracle_acct` (expression) | PASS |
| `$snowflake_acct` (expression) | PASS |
| `/shared/oracle_account` (hardcoded) | FAIL — "appears to be hardcoded" |
| `my_org/shared/account` (hardcoded) | FAIL — "appears to be hardcoded" |

**Why it matters:** Hardcoded account references break portability. When moving pipelines between environments (dev/staging/prod), expressions allow accounts to be swapped via parameters.

---

### 8. Validate Account References Use Shared Folder Format

**Peer Review Requirement:** *"Account reference should be in format of ../shared/<account>"*

Validates that account reference expressions resolve to the `../shared/<account>` pattern.

| Account Reference Expression | Result |
|------------------------------|--------|
| Expression resolving to `../shared/oracle_acct` | PASS |
| Expression resolving to `../project/oracle_acct` | FAIL — "does not match expected pattern" |

---

### 9. Validate Pipeline Info Has Documentation Link

**Peer Review Requirement:** *"If the pipeline was created for the ticket, the Original User Story URL needs to be linked in the Pipeline Properties > Info > Doc Link"*

Checks that the `doc_link` field in Pipeline Properties > Info is populated.

| doc_link Value | Result |
|----------------|--------|
| `https://jira.company.com/TICKET-123` | PASS |
| `""` (empty) | FAIL — "No doc_link found" |
| (field missing) | FAIL — "No doc_link found" |

---

### 10. Validate Pipeline Info Has Notes

**Peer Review Requirement:** *"If the pipeline was modified for the ticket, and the Doc Link is already present, put the ticket number in the Notes section."*

Checks that the `notes` field in Pipeline Properties > Info is populated.

| notes Value | Result |
|-------------|--------|
| `"TICKET-456: Added error handling"` | PASS |
| `""` (empty) | FAIL — "Notes section is empty" |
| (field missing) | FAIL — "Notes section is empty" |

---

## Batch Review

### How It Works

The batch review scans **every `.slp` file** in a directory and runs all 10 checks on each one.

```
/app/src/pipelines/
    │
    ├── oracle.slp ──────→ Run 10 checks ──→ Report: PASS
    ├── oracle2.slp ─────→ Run 10 checks ──→ Report: FAIL
    ├── kafka.slp ───────→ Run 10 checks ──→ Report: PASS
    ├── z_child.slp ─────→ Run 10 checks ──→ Report: FAIL (z_ prefix enforced)
    └── corrupted.slp ───→ Load failed ────→ SKIP (logged as warning)
```

### Auto-Detection in Batch Mode

Detection is based on the **pipeline name inside the `.slp` file** (not the filename):

| Pipeline Name (inside .slp) | `is_child` | `is_parent_pipeline` | Child z_ Check | xx Prefix Check |
|------------------------------|------------|----------------------|----------------|-----------------|
| `oracle2` | False | True | Skipped | Skipped |
| `z_greenlight_acquisition` | True | False | Enforced | Enforced |
| `TAPP102550_Asset_Brokerage` | False | True | Skipped | Skipped |
| `z_rebate_transform` | True | False | Enforced | Enforced |

### Sample Batch Output

```
======================================================================
PEER REVIEW SUMMARY: 6 pipelines reviewed | 2 passed | 4 failed
======================================================================
[PASS] oracle.slp
[FAIL] oracle2.slp - Failed: ['snap_naming', 'parameter_prefix', 'doc_link', 'notes']
[PASS] kafka.slp
[FAIL] snowflake.slp - Failed: ['snap_naming']
[FAIL] salesforce.slp - Failed: ['doc_link']
[FAIL] sit_sqlserver.slp - Failed: ['snap_naming', 'accounts_not_hardcoded']
======================================================================
```

---

## Report Output

### Where to Find Reports

| File | Location | Purpose |
|------|----------|---------|
| `report-*.html` | `test/robot_output/` | Summary — high-level pass/fail per test |
| `log-*.html` | `test/robot_output/` | Detailed log — full violation messages |
| `output-*.xml` | `test/robot_output/` | Machine-readable for CI/CD integration |

### Sample Individual Pipeline Report

```
======================================================================
  PEER REVIEW REPORT: oracle2
  File: oracle2.slp
======================================================================
  Overall: FAIL  |  Passed: 5  |  Failed: 3  |  Skipped: 2
----------------------------------------------------------------------
  [FAIL] Snap Naming (6 violation(s))
         - Snap name 'Data Validator' is a known default name
         - Snap name 'Filter' is a known default name
         - Snap name 'Structure' is a known default name
         - Snap name 'File Writer' is a known default name
         - Snap name 'CSV Formatter' is a known default name
         ... and 1 more
  [PASS] Duplicate Snap Names
  [PASS] Pipeline Naming
  [SKIP] Child Pipeline Naming - Not a child pipeline — z_ prefix check skipped
  [PASS] Parameter Capture
  [SKIP] Parameter Prefix - Parent pipelines are exempt from parameter prefix requirement
  [PASS] Accounts Not Hardcoded
  [PASS] Account Reference Format
  [FAIL] Doc Link - Pipeline Info > Doc Link is empty. New pipelines must have the User Story URL linked.
  [FAIL] Notes - Pipeline Info > Notes is empty. Modified pipelines should have the ticket number in Notes.
======================================================================
```

### Open the Report

```bash
# Mac
open test/robot_output/report-*.html

# Detailed log with all violation messages
open test/robot_output/log-*.html
```

---

## Mapping to Peer Review Form

| Peer Review Checklist Item | Automated? | Test Case | Method |
|----------------------------|:----------:|-----------|--------|
| Snap Naming Standards | Yes | #1 + #2 | Static .slp file analysis |
| Pipeline Naming Standards | Yes | #3 + #5 | Static .slp file analysis |
| Child Pipeline z_ Prefix | Yes | #4 + #5 | Static .slp file analysis |
| Parameters — Capture Enabled | Yes | #6 | Static .slp file analysis |
| Parameters — xx Prefix | Yes | #7 | Static .slp file analysis |
| Accounts — Not Hardcoded | Yes | #8 | Static .slp file analysis |
| Accounts — Shared Folder Format | Yes | #9 | Static .slp file analysis |
| Pipeline Info — Doc Link | Yes | #10 | Static .slp file analysis |
| Pipeline Info — Notes | Yes | #11 | Static .slp file analysis |
| Run Pipeline — Timing | Yes | #13 | Post-execution — `sla/sla_pipeline.robot` |
| Run Pipeline — Expected Results | Yes | #14 + #15 + #16 | Post-execution — `oracle/oracle_baseline_tests.robot` |
| Logging (ABC log table entries) | **Not yet** | — | Requires customer's table structure |
| Metadata (repo checker) | **Not yet** | — | External tool |
| S3 usage compliance | **Not yet** | — | Requires context-specific judgment |
| Release documentation | **Not yet** | — | External document review |
| Data Applications Page | **Not yet** | — | External document review |
| Intermediate snap verification | **Not yet** | — | Waiting for Preview API (IDEA-I-399) |
| SnapGPT quality check | **Not yet** | — | API exists; customization TBD |

**12 of 18 checks are automated** — 10 via static .slp file analysis + 2 via post-execution verification.

---

## Keyword Reference

### Resource Keywords (pipeline_inspector.resource)

#### Setup Keywords
| Keyword | Purpose |
|---------|---------|
| `Load Pipeline For Review` | Loads .slp file, skips suite if file not found |

#### Verify + Log Keywords (return results with logging)
| Keyword | Purpose |
|---------|---------|
| `Verify Snap Naming And Return Result` | Runs snap naming check, logs violations as warnings |
| `Verify Pipeline Naming And Return Result` | Runs pipeline naming check, logs violations |
| `Verify Child Pipeline Naming And Return Result` | Runs child pipeline z_ prefix check |
| `Verify Doc Link And Return Result` | Checks doc link, logs if missing |
| `Verify Notes And Return Result` | Checks notes, logs if missing |

#### Assertion Keywords (pass/fail enforcers)
| Keyword | Purpose |
|---------|---------|
| `Pipeline Should Pass Snap Naming Standards` | Assert snap naming PASS |
| `Pipeline Should Have No Duplicate Snap Names` | Assert no duplicates |
| `Pipeline Parameters Should Have Capture Enabled` | Assert capture enabled |
| `Pipeline Parameters Should Have Prefix` | Assert xx prefix (or skip for parent) |
| `Pipeline Accounts Should Not Be Hardcoded` | Assert no hardcoded accounts |
| `Pipeline Account References Should Match Format` | Assert ../shared/ format |
| `Pipeline Should Have Doc Link` | Assert doc link present |
| `Pipeline Should Have Notes` | Assert notes present |

#### Batch + Logging Keywords
| Keyword | Purpose |
|---------|---------|
| `Run Batch Peer Review` | Run all checks on all .slp files in directory |
| `Run Peer Review On Pipeline File` | Run all checks on one file, return report |
| `Run Peer Review On All Pipeline Files` | Loop all files, collect reports |
| `Log Snap Naming Violations` | Print violation details as warnings |
| `Log Peer Review Summary` | Print batch summary table |

### Python Library Keywords (PipelineInspectorLibrary.py)

| Keyword | Purpose |
|---------|---------|
| `Load Pipeline File` | Parse .slp JSON file |
| `Load All Pipeline Files From Directory` | Parse all .slp files in a directory |
| `Get Pipeline Name` | Extract pipeline name |
| `Validate Pipeline Naming Convention` | Check pipeline name prefix |
| `Get All Snap Names` | Extract all snap names, types, class_ids |
| `Validate Snap Naming Standards` | 5-layer snap name validation |
| `Validate No Duplicate Snap Names` | Check for duplicate snap names |
| `Get Pipeline Parameters` | Extract pipeline parameters |
| `Validate Parameters Have Capture Enabled` | Check capture checkbox |
| `Validate Parameters Have Prefix` | Check parameter prefix (xx) |
| `Get Account References` | Extract account refs from all snaps |
| `Validate Accounts Not Hardcoded` | Check accounts use expressions |
| `Validate Account References Format` | Check ../shared/ pattern |
| `Validate Pipeline Info Has Doc Link` | Check doc_link field |
| `Validate Pipeline Info Has Notes` | Check notes field |
| `Get Pipeline Inspection Report` | Run all checks, return comprehensive report |

---

## Variables Reference

### Configurable Variables in peer_review_tests.robot

| Variable | Default | Purpose |
|----------|---------|---------|
| `${pipeline_file}` | `${CURDIR}/../../../../src/pipelines/oracle2.slp` | Pipeline file to review |
| `${pipeline_dir}` | `${CURDIR}/../../../../src/pipelines` | Directory for batch review |
| `${project_name}` | `${EMPTY}` | Required pipeline name prefix |
| `${param_prefix}` | `xx` | Required parameter prefix |
| `${is_parent_pipeline}` | `False` | True = skip xx prefix check |
| `${is_child_pipeline}` | `False` | True = enforce z_ prefix |
