---
name: end-to-end-pipeline-verification
description: Creates a complete Robot Framework test suite with account creation, file uploads, pipeline import, triggered task creation/execution, and data verification. Use when the user needs to set up accounts, upload test files, import pipelines, create/execute triggered tasks, AND verify results together in a single test file.
user-invocable: true
---

# End-to-End Pipeline Verification Test Case Guide

## Usage Examples

| What You Want | Example Prompt |
|---------------|----------------|
| Complete setup with verification | `Set up Oracle account, upload test files, import pipeline, execute task, and verify data` |
| Full end-to-end test | `Create complete test suite for Snowflake pipeline with data verification` |
| Multiple accounts + full flow | `Create Snowflake and S3 accounts, upload JSON files, import pipeline, run task, and verify 2 records` |
| Get template | `Show me a template for complete pipeline setup with verification` |
| See example | `What does a complete pipeline test look like?` |

---

## Claude Instructions

**IMPORTANT:** When user asks a simple question, provide a **concise answer first** with just the template/command, then offer to explain more if needed. Do NOT dump all documentation.

**PREREQUISITES (Claude: Always verify these before creating test cases):**
1. A valid `.slp` pipeline file must exist under `src/pipelines/`.
2. Local files to upload must exist in the project (typically under `test/suite/test_data/`).
3. Identify which account type(s) the pipeline requires (check the pipeline or ask the user).
4. Know what parameters the pipeline needs for the triggered task.
5. Know the expected record count for data verification.

**MANDATORY:** When creating setup test cases, you MUST call the **Write tool** to create ALL required files. Do NOT read files to check if they exist first. Do NOT say "file already exists" or "already complete". Always write them fresh:
1. **Account payload file(s)** (`acc_[type].json`) in `test/suite/test_data/accounts_payload/` — WRITE this
2. **Account env file(s)** (`.env.[type]`) in `env_files/[category]_accounts/` — WRITE this
3. **Combined Robot test file** (`.robot`) in `test/suite/pipeline_tests/[type]/` — WRITE this
4. **SETUP_README.md** with file structure tree diagram in the same test directory — WRITE this

This applies to ALL setup test cases. No exceptions. You must call Write for each file.

**Response format for simple questions:**
1. Give the direct template or test case first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

# WHEN USER INVOKES `/end-to-end-pipeline-verification` WITH NO ARGUMENTS

**Claude: When user types just `/end-to-end-pipeline-verification` with no specific request, present the menu below. Use this EXACT format:**

---

**SnapLogic Pipeline Setup (Account + Files + Import + Task + Verify)**

**Prerequisites**
1. A valid `.slp` pipeline file must exist under `src/pipelines/`
2. Local files to upload must exist in the project (under `test/suite/test_data/`)
3. Know which account type(s) your pipeline requires (Oracle, Snowflake, Kafka, S3, etc.)
4. Know what parameters the pipeline expects for the triggered task
5. Know the expected record count for data verification

**What I Can Do**

I create a **complete test suite** that handles the full pipeline lifecycle in one file:
- **Account payload file(s)** (`acc_[type].json`) — JSON template with Jinja variable placeholders
- **Account env file(s)** (`.env.[type]`) — Environment variables for the account
- **Combined Robot test file** (`.robot`) — Test cases for all 6 steps
- **SETUP_README.md** — File structure diagram, prerequisites, and run instructions

**Test Execution Order:**
```
1. Create Account(s)  →  2. Upload Files  →  3. Import Pipeline  →  4. Create Task  →  5. Execute Task  →  6. Verify Data  →  7. Export CSV  →  8. Compare CSV
```

**This is the recommended approach** when you need to:
- Set up a new pipeline from scratch
- Create accounts that a pipeline depends on
- Upload test input files or expression libraries
- Import the pipeline and create a triggered task
- Execute the task and verify results in the database
- Have a single test file that handles the full end-to-end flow

**Try these sample prompts to get started:**

| Sample Prompt | What It Does |
|---------------|--------------|
| `Set up Oracle account, upload files, import pipeline, execute task, verify 2 records` | Complete end-to-end setup |
| `Create Snowflake account, upload JSON input, import pipeline, run task, and verify data` | Full Snowflake test |
| `Set up complete test environment for my Oracle to Snowflake ETL with verification` | Multi-account ETL setup |
| `Show me a template for complete setup with data verification` | Shows the complete test file structure |

**Only need specific steps?**
- `/create-account` — Just account creation
- `/upload-file` — Just file uploads
- `/import-pipeline` — Just pipeline import
- `/create-triggered-task` — Just task creation and execution
- `/verify-data-in-db` — Just data verification
- `/export-data-to-csv` — Just data export to CSV
- `/compare-csv` — Just CSV file comparison

---

## Natural Language — Just Describe What You Need

You don't need special syntax. Just describe what you need after `/end-to-end-pipeline-verification`:

```
/end-to-end-pipeline-verification Set up Oracle account, upload test files, import oracle_etl.slp, execute task, and verify 2 records
```

```
/end-to-end-pipeline-verification Create Snowflake keypair account, upload JSON input files, import my_pipeline.slp, run task, and verify data
```

```
/end-to-end-pipeline-verification I need PostgreSQL and Kafka accounts, upload expression libraries, import data_processor.slp, execute task, and verify output
```

```
/end-to-end-pipeline-verification Show me a complete setup example for Snowflake with data verification
```

---

## Quick Template Reference

**Combined test case structure:**
```robotframework
*** Test Cases ***
Create [Type] Account
    [Tags]    [type]    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${[TYPE]_ACCOUNT_PAYLOAD_FILE_NAME}    ${[TYPE]_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Upload Test Files
    [Tags]    [type]    upload    setup
    [Template]    Upload File Using File Protocol Template
    ${input_file_path}    ${PIPELINES_LOCATION_PATH}

Import Pipeline
    [Tags]    [type]    pipeline_import
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}

Create Triggered Task
    [Tags]    [type]    task_creation    triggered_task
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=300

Execute Triggered Task
    [Tags]    [type]    task_execution    triggered_task
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file_name}

Verify Data In [Type] Table
    [Tags]    [type]    verification    data_validation
    Capture And Verify Number of records From DB Table
    ...    ${table_name}    ${schema_name}    ${order_by_column}    ${expected_record_count}

Export [Type] Data To CSV
    [Tags]    [type]    export    csv
    Export DB Table Data To CSV
    ...    ${table_name}    ${order_by_column}    ${actual_output_file}

Compare Actual vs Expected CSV Output
    [Tags]    [type]    verification    comparison
    [Template]    Compare CSV Files With Exclusions Template
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns}
```

**Key principle:** Accounts FIRST, then Files, then Pipeline, then Create Task, then Execute Task, then Verify Data, then Export CSV, then Compare CSV.

---

## COMPLETE EXAMPLE: Snowflake Pipeline Setup with Verification (All Files)

**When a user asks "Set up Snowflake account, upload test files, import pipeline, execute task, and verify data", you MUST create ALL of these files:**

### File 1: Account Payload — `test/suite/test_data/accounts_payload/acc_snowflake_s3_db.json`
```json
{
  "entity_map": {
    "Snowflake - S3 Database": {
      "acc_snowflake_s3_db": {
        "property_map": {
          "account_label": {
            "value": "{{SNOWFLAKE_ACCOUNT_NAME}}"
          },
          "hostname": {
            "value": "{{SNOWFLAKE_HOSTNAME}}"
          },
          "username": {
            "value": "{{SNOWFLAKE_USERNAME}}"
          },
          "password": {
            "value": "{{SNOWFLAKE_PASSWORD}}"
          },
          "database": {
            "value": "{{SNOWFLAKE_DATABASE}}"
          },
          "warehouse": {
            "value": "{{SNOWFLAKE_WAREHOUSE}}"
          },
          "schema_name": {
            "value": "{{SNOWFLAKE_SCHEMA}}"
          },
          "role": {
            "value": "{{SNOWFLAKE_ROLE}}"
          }
        }
      }
    }
  }
}
```

### File 2: Account Env File — `env_files/database_accounts/.env.snowflake`
```bash
# ============================================================================
#                      SNOWFLAKE DATABASE ACCOUNT - PASSWORD AUTHENTICATION
# ============================================================================

# Account payload file name
SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME=acc_snowflake_s3_db.json

# Account Label
SNOWFLAKE_ACCOUNT_NAME=SNOWFLAKE_acct

# Connection Configuration
SNOWFLAKE_HOSTNAME=your_account.snowflakecomputing.com

# Authentication
SNOWFLAKE_USERNAME=your_username
SNOWFLAKE_PASSWORD=your_password

# Database Configuration
SNOWFLAKE_DATABASE=YOUR_DB
SNOWFLAKE_WAREHOUSE=YOUR_WH
SNOWFLAKE_SCHEMA=PUBLIC
SNOWFLAKE_ROLE=SYSADMIN
```

### File 3: Combined Robot Test File — `test/suite/pipeline_tests/snowflake/snowflake_pipeline_setup.robot`
```robotframework
*** Settings ***
Documentation    Complete Snowflake pipeline setup: creates account, uploads files, imports pipeline,
...              creates and executes triggered task, and verifies data in database
...              This test suite handles the full end-to-end flow for Snowflake pipeline testing
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../../resources/snowflake/snowflake_keywords_databaselib.resource
Resource         ../../resources/common/files.resource
Resource         ../../resources/common/general.resource
Resource         ../../resources/common/sql_table_operations.resource
Library          Collections
Library          OperatingSystem

Suite Setup      Check Connections
Suite Teardown   Disconnect From Snowflake

*** Variables ***
# Pipeline configuration
${pipeline_name}                snowflake_demo
${pipeline_file_name}           snowflake_demo.slp
${task_name}                    Task
${sf_acct}                      ${pipeline_name}_account

# Input file paths (local)
${input_file1_name}             test_input_file1.json
${input_file2_name}             test_input_file2.json
${input_file1_path}             ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file1_name}
${input_file2_path}             ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file2_name}
${expr_lib_path}                ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr

# Task parameters - passed to pipeline during execution
&{task_params_set}
...    snowflake_acct=../shared/${sf_acct}
...    schema=DEMO
...    table=DEMO.TEST_TABLE
...    isTest=test
...    test_input_file=${input_file1_name}

# Data verification settings
${table_name}                   DEMO.TEST_TABLE
${schema_name}                  DEMO
${order_by_column}              RECORD_METADATA
${expected_record_count}        2

# Output file paths for CSV comparison
${actual_output_file}           ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/actual_output.csv
${expected_output_file}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/expected_output.csv

# Columns to exclude from comparison (dynamic values)
@{excluded_columns_for_comparison}
...    SnowflakeConnectorPushTime
...    unique_event_id
...    event_timestamp

*** Test Cases ***
Create Snowflake Account
    [Documentation]    Creates a Snowflake database account in SnapLogic.
    ...    This account will be used by the pipeline for database operations.
    [Tags]    snowflake    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${SNOWFLAKE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Upload Test Input Files
    [Documentation]    Uploads test input files and expression libraries to SnapLogic SLDB.
    ...    - Test input files go to ${PIPELINES_LOCATION_PATH} (project folder)
    ...    - Expression libraries go to ${ACCOUNT_LOCATION_PATH} (shared folder)
    [Tags]    snowflake    upload    setup
    [Template]    Upload File Using File Protocol Template
    ${input_file1_path}                  ${PIPELINES_LOCATION_PATH}
    ${input_file2_path}                  ${PIPELINES_LOCATION_PATH}
    ${expr_lib_path}                     ${ACCOUNT_LOCATION_PATH}

Import Snowflake Pipeline
    [Documentation]    Imports Snowflake pipeline file (.slp) into the SnapLogic project space.
    [Tags]    snowflake    pipeline_import
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}

Create Snowflake Triggered Task
    [Documentation]    Creates a triggered task for Snowflake pipeline execution.
    [Tags]    snowflake    task_creation    triggered_task
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=300

Execute Snowflake Triggered Task
    [Documentation]    Executes the triggered task with specified parameters and monitors completion.
    ...    PREREQUISITES:
    ...    - Task must be created first (Create Snowflake Triggered Task)
    ...    - Task must be in ready state before execution
    [Tags]    snowflake    task_execution    triggered_task
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file1_name}

Verify Data In Snowflake Table
    [Documentation]    Verifies data integrity in Snowflake table by querying and validating record counts.
    ...    PREREQUISITES:
    ...    - Pipeline execution completed successfully
    ...    - Snowflake table exists with data inserted
    ...    - Database connection is established
    [Tags]    snowflake    verification    data_validation
    Capture And Verify Number of records From DB Table
    ...    ${task_params_set}[table]
    ...    ${task_params_set}[schema]
    ...    ${order_by_column}
    ...    ${expected_record_count}

Export Snowflake Data To CSV
    [Documentation]    Exports data from Snowflake table to a CSV file for comparison.
    [Tags]    snowflake    verification    export
    Export DB Table Data To CSV
    ...    ${task_params_set}[table]
    ...    ${order_by_column}
    ...    ${actual_output_file}

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing actual Snowflake export against expected output.
    [Tags]    snowflake    verification    comparison
    [Template]    Compare CSV Files With Exclusions Template
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}

*** Keywords ***
Check Connections
    [Documentation]    Verifies Snowflake database connection and Snaplex availability
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Test ID: ${unique_id}    console=yes
    Connect To Snowflake Via DatabaseLibrary    keypair
    Clean Table    ${task_params_set}[table]    ${task_params_set}[schema]
```

### File 4: README — `test/suite/pipeline_tests/snowflake/SETUP_README.md`
````markdown
# Snowflake Pipeline Setup Tests

This test suite creates accounts, uploads files, imports pipelines, creates/executes triggered tasks, AND verifies data in a single file.

## Purpose
Complete end-to-end setup for Snowflake pipeline testing — creates the Snowflake database account, uploads test input files and expression libraries, imports the pipeline, creates and executes the triggered task, and verifies the results in the database.

## Test Execution Order
```
1. Create Account  →  2. Upload Files  →  3. Import Pipeline  →  4. Create Task  →  5. Execute Task  →  6. Verify Data
```

## File Structure
```
project-root/
├── src/
│   └── pipelines/
│       └── snowflake_demo.slp                                 ← Pipeline file (.slp)
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── snowflake/
│       │       ├── snowflake_pipeline_setup.robot             ← Combined test file
│       │       └── SETUP_README.md                            ← This file
│       └── test_data/
│           ├── accounts_payload/
│           │   └── acc_snowflake_s3_db.json                   ← Account payload file
│           └── actual_expected_data/
│               ├── input_data/
│               │   └── snowflake/
│               │       ├── test_input_file1.json              ← Input file 1
│               │       └── test_input_file2.json              ← Input file 2
│               ├── actual_output/
│               │   └── snowflake/
│               │       └── actual_output.csv                  ← Exported actual data
│               ├── expected_output/
│               │   └── snowflake/
│               │       └── expected_output.csv                ← Expected baseline
│               └── expression_libraries/
│                   └── snowflake/
│                       └── snowflake_library.expr             ← Expression library
├── env_files/
│   └── database_accounts/
│       └── .env.snowflake                                     ← Environment file
└── .env                                                       ← Override credentials here
```

## Prerequisites
1. Pipeline `.slp` file must exist in `src/pipelines/`
2. Test input files must exist in `test/suite/test_data/actual_expected_data/input_data/`
3. Expected output file must exist in `test/suite/test_data/actual_expected_data/expected_output/`
4. Configure Snowflake credentials in `env_files/database_accounts/.env.snowflake` or override in root `.env`

## Environment Variables
- `SNOWFLAKE_HOSTNAME` — Snowflake account URL
- `SNOWFLAKE_USERNAME` — Database username
- `SNOWFLAKE_PASSWORD` — Database password
- `SNOWFLAKE_DATABASE` — Target database name
- `SNOWFLAKE_WAREHOUSE` — Compute warehouse

## Task Parameters
The following parameters are passed to the pipeline via the triggered task:
- `snowflake_acct` — Reference to the Snowflake account
- `schema` — Database schema name
- `table` — Target table name
- `isTest` — Test mode flag

## Data Verification
- Expected record count: 2
- Columns excluded from comparison: `SnowflakeConnectorPushTime`, `unique_event_id`, `event_timestamp`

## How to Run
```bash
make robot-run-all-tests TAGS="snowflake" PROJECT_SPACE_SETUP=True
```
````

**Claude: The above is a COMPLETE example. When creating pipeline setup test cases for ANY type, follow the same pattern — always create all files. Never create just the .robot file alone.**

---

## Multiple Accounts + Full Flow Example

When a pipeline needs multiple accounts and full verification:

```robotframework
*** Settings ***
Documentation    Complete ETL setup: Oracle source, Snowflake destination, full execution and verification
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/files.resource
Resource         ../../resources/common/general.resource
Resource         ../../resources/common/sql_table_operations.resource
Library          Collections
Library          OperatingSystem

*** Variables ***
# Pipeline configuration
${pipeline_name}                oracle_to_snowflake_etl
${pipeline_file_name}           oracle_to_snowflake_etl.slp
${task_name}                    Task

# Input files
${input_file_path}              ${CURDIR}/../../test_data/actual_expected_data/input_data/etl/input_data.json
${expr_lib_path}                ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/common/etl_functions.expr

# Task parameters
&{task_params_set}
...    oracle_acct=../shared/${ORACLE_ACCOUNT_NAME}
...    snowflake_acct=../shared/${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}
...    source_schema=SOURCE
...    target_schema=TARGET
...    table_name=ETL_OUTPUT

# Verification settings
${expected_record_count}        10

*** Test Cases ***
Create Oracle Source Account
    [Documentation]    Creates Oracle source database account.
    [Tags]    oracle    account_setup    source
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Create Snowflake Destination Account
    [Documentation]    Creates Snowflake destination account.
    [Tags]    snowflake    account_setup    destination
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    ${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Upload Test Files And Libraries
    [Documentation]    Uploads test input files and expression libraries.
    [Tags]    upload    setup
    [Template]    Upload File Using File Protocol Template
    ${input_file_path}    ${PIPELINES_LOCATION_PATH}
    ${expr_lib_path}      ${ACCOUNT_LOCATION_PATH}

Import ETL Pipeline
    [Documentation]    Imports the Oracle to Snowflake ETL pipeline.
    [Tags]    etl    pipeline_import
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}

Create ETL Triggered Task
    [Documentation]    Creates triggered task for ETL pipeline execution.
    [Tags]    etl    task_creation    triggered_task
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=600

Execute ETL Triggered Task
    [Documentation]    Executes the ETL triggered task.
    [Tags]    etl    task_execution    triggered_task
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}

Verify Data In Target Table
    [Documentation]    Verifies data in Snowflake target table.
    [Tags]    etl    verification    data_validation
    Capture And Verify Number of records From DB Table
    ...    ${task_params_set}[table_name]
    ...    ${task_params_set}[target_schema]
    ...    id
    ...    ${expected_record_count}
```

---

## Supported Account Types

| Type | Payload File | Env File |
|------|--------------|----------|
| Oracle | `acc_oracle.json` | `.env.oracle` |
| PostgreSQL | `acc_postgres.json` | `.env.postgres` |
| MySQL | `acc_mysql.json` | `.env.mysql` |
| SQL Server | `acc_sqlserver.json` | `.env.sqlserver` |
| Snowflake | `acc_snowflake_s3_db.json` | `.env.snowflake` |
| Snowflake (Key Pair) | `acc_snowflake_s3_keypair.json` | `.env.snowflake_s3_keypair` |
| DB2 | `acc_db2.json` | `.env.db2` |
| Teradata | `acc_teradata.json` | `.env.teradata` |
| Kafka | `acc_kafka.json` | `.env.kafka` |
| JMS | `acc_jms.json` | `.env.jms` |
| S3 / MinIO | `acc_s3.json` | `.env.s3` |
| Email | `acc_email.json` | `.env.email` |
| Salesforce | `acc_salesforce.json` | `.env.salesforce` |

---

## Supported File Types

| File Type | Extension | Destination |
|-----------|-----------|-------------|
| JSON | `.json` | `${PIPELINES_LOCATION_PATH}` |
| CSV | `.csv` | `${PIPELINES_LOCATION_PATH}` |
| Expression Library | `.expr` | `${ACCOUNT_LOCATION_PATH}` |
| JAR Files | `.jar` | `${ACCOUNT_LOCATION_PATH}` |
| Pipeline | `.slp` | `${PIPELINES_LOCATION_PATH}` |

---

## IMPORTANT: Step-by-Step Workflow

**Always follow this workflow when creating setup test cases.**

**MANDATORY: You MUST create ALL of the following files:**

| # | File | Location | Purpose |
|---|------|----------|---------|
| 1 | **Account payload file(s)** | `test/suite/test_data/accounts_payload/acc_[type].json` | JSON template with Jinja variables |
| 2 | **Account env file(s)** | `env_files/[category]_accounts/.env.[type]` | Environment variables for the account |
| 3 | **Combined Robot test file** | `test/suite/pipeline_tests/[type]/[type]_pipeline_setup.robot` | Full end-to-end test |
| 4 | **SETUP_README.md** | `test/suite/pipeline_tests/[type]/SETUP_README.md` | File structure diagram and instructions |

**ALWAYS create all files using the Write tool.** No exceptions.

### Step 1: Identify Requirements
- Which account type(s) does the pipeline need?
- Which file(s) need to be uploaded?
- What is the pipeline file name?
- What parameters does the triggered task need?
- What is the expected record count for verification?

### Step 2: Verify Files Exist
- Pipeline `.slp` file in `src/pipelines/`
- Test input files in `test/suite/test_data/`
- Expected output file for CSV comparison

### Step 3: Create Account Payload File(s) — use Write tool
Create the JSON payload template for each account type.

### Step 4: Create Account Env File(s) — use Write tool
Create the environment file for each account type.

### Step 5: Create Combined Robot Test File — use Write tool
Create the `.robot` file with:
1. Account creation test case(s) FIRST
2. File upload test case(s) SECOND
3. Pipeline import test case THIRD
4. Triggered task creation test case FOURTH
5. Triggered task execution test case FIFTH
6. Data verification test case(s) LAST

### Step 6: Create SETUP_README.md — use Write tool
Create the README with file structure diagram.

---

## Typical Test Execution Flow

```
┌─────────────────────────┐
│  1. Suite Setup         │
│  (Generate unique_id,   │
│   Connect to DB)        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  2. Create Account(s)   │  ◄── FIRST
│  (Database, S3, etc.)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  3. Upload Files        │  ◄── SECOND
│  (Input data, expr libs)│
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  4. Import Pipeline     │  ◄── THIRD
│  (.slp file)            │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  5. Create Triggered    │  ◄── FOURTH
│     Task                │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  6. Execute Triggered   │  ◄── FIFTH
│     Task                │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  7. Verify Data Count   │  ◄── SIXTH
│  (Record count check)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  8. Export Data To CSV  │  ◄── SEVENTH
│  (Export DB table)      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  9. Compare CSV Files   │  ◄── EIGHTH
│  (Actual vs Expected)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ 10. Suite Teardown      │
│  (Disconnect DB)        │
└─────────────────────────┘
```

---

## When to Use Which Skill

| Scenario | Use This |
|----------|----------|
| Need complete end-to-end setup with verification | `/end-to-end-pipeline-verification` (this skill) |
| Already have accounts, files, pipeline, task — just need verification | `/verify-data-in-db` |
| Already have accounts, files, and pipeline — just need task | `/create-triggered-task` |
| Already have accounts and files — just need pipeline | `/import-pipeline` |
| Only need accounts — no files or pipeline | `/create-account` |
| Only need file uploads | `/upload-file` |
| Only need to export data to CSV | `/export-data-to-csv` |
| Only need to compare CSV files | `/compare-csv` |

---

## Checklist Before Committing

- [ ] Pipeline .slp file exists in `src/pipelines/`
- [ ] Test input files exist in `test/suite/test_data/`
- [ ] Expected output file exists for CSV comparison
- [ ] Account payload file(s) created in `accounts_payload/`
- [ ] Account env file(s) created in `env_files/`
- [ ] Combined .robot file has all 8 steps in correct order
- [ ] Task parameters defined for triggered task
- [ ] Expected record count defined for verification
- [ ] Export CSV test case included
- [ ] Excluded columns defined for CSV comparison
- [ ] Test has appropriate tags
- [ ] SETUP_README.md created with file structure diagram
