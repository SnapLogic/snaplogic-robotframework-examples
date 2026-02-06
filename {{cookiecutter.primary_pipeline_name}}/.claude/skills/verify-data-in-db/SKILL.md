---
name: verify-data-in-db
description: Creates Robot Framework test cases for verifying data in database tables. Use when the user wants to verify record counts, export data to CSV, compare actual vs expected output, or validate pipeline execution results.
user-invocable: true
---

# Verify Data in Database Table Test Case Guide

## Usage Examples

| What You Want | Example Prompt |
|---------------|----------------|
| Verify record count | `Verify that my Oracle table has 2 records after pipeline execution` |
| Export data to CSV | `Export data from Snowflake table to CSV for comparison` |
| Compare actual vs expected | `Compare actual output from database with expected CSV file` |
| Full verification flow | `Verify pipeline results: count records, export to CSV, compare with expected` |
| Get template | `Show me a template for verifying database data` |
| See example | `What does a data verification test case look like?` |

---

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I verify data in a table?", provide a **concise answer first** with just the template/command, then offer to explain more if needed. Do NOT dump all documentation.

**PREREQUISITES (Claude: Always verify these before creating test cases):**
1. Pipeline must have been executed — triggered task must have completed successfully.
2. Database connection must be established in Suite Setup.
3. Know the table name, schema, and expected record count.
4. For CSV comparison, know the expected output file path.

**MANDATORY:** When creating data verification test cases, you MUST call the **Write tool** to create ALL required files. Do NOT read files to check if they exist first. Do NOT say "file already exists" or "already complete". Always write them fresh:
1. **Robot test file** (`.robot`) in `test/suite/pipeline_tests/[type]/` — WRITE this
2. **VERIFY_DATA_README.md** with file structure tree diagram in the same test directory — WRITE this

This applies to ALL data verification test cases. No exceptions. You must call Write for each file.

**Response format for simple questions:**
1. Give the direct template or test case first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

# WHEN USER INVOKES `/verify-data-in-db-in-db` WITH NO ARGUMENTS

**Claude: When user types just `/verify-data-in-db-in-db` with no specific request, present the menu below. Use this EXACT format:**

---

**SnapLogic Data Verification in Database Tables**

**Prerequisites**
1. Pipeline must have been executed (triggered task completed)
2. Database connection must be established in Suite Setup
3. Know the table name, schema, and expected record count
4. For CSV comparison, know the expected output file path

**What I Can Do**

I create test cases for verifying pipeline execution results in database tables:
- **Verify Record Count** — Check that expected number of records were inserted
- **Export Data to CSV** — Export table data for detailed comparison
- **Compare Actual vs Expected** — Compare exported CSV with expected output file

**Three Key Operations:**
1. `Capture And Verify Number of records From DB Table` — Verify record count
2. `Export DB Table Data To CSV` — Export table data to CSV
3. `Compare CSV Files With Exclusions Template` — Compare actual vs expected (with column exclusions)

**Try these sample prompts to get started:**

| Sample Prompt | What It Does |
|---------------|--------------|
| `Verify Oracle table has 2 records after pipeline` | Creates record count verification |
| `Export Snowflake data to CSV and compare with expected` | Creates export + comparison test |
| `Full verification flow for my Oracle pipeline` | Creates complete verification suite |
| `Show me the baseline test for data verification` | Displays existing reference test |
| `Compare CSV files excluding timestamp columns` | Shows column exclusion pattern |

**Need to execute the pipeline first?** Use `/create-triggered-task` to create and execute the task.

---

## Natural Language — Just Describe What You Need

You don't need special syntax. Just describe what you need after `/verify-data-in-db`:

```
/verify-data-in-db Verify my Oracle table has 2 records after pipeline execution
```

```
/verify-data-in-db Export data from Snowflake table and compare with expected output
```

```
/verify-data-in-db Create full verification test for PostgreSQL pipeline results
```

```
/verify-data-in-db Compare actual vs expected CSV, excluding timestamp columns
```

**Baseline test references:**
- `test/suite/pipeline_tests/snowflake/snowflake_baseline_tests.robot`
- `test/suite/pipeline_tests/oracle/oracle_baseline_tests.robot`

---

## Quick Template Reference

**Verify record count:**
```robotframework
Capture And Verify Number of records From DB Table
...    ${table_name}
...    ${schema_name}
...    ${order_by_column}
...    ${expected_record_count}
```

**Export data to CSV:**
```robotframework
Export DB Table Data To CSV
...    ${table_name}
...    ${order_by_column}
...    ${output_file_path}
```

**Compare actual vs expected CSV:**
```robotframework
[Template]    Compare CSV Files With Exclusions Template
${actual_file_path}    ${expected_file_path}    ${ignore_order}    ${show_details}    ${expected_status}    @{excluded_columns}
```

**Required variables:**
| Variable | Description |
|----------|-------------|
| `${table_name}` | Full table name (e.g., `DEMO.TEST_TABLE`) |
| `${schema_name}` | Schema name (e.g., `DEMO`) |
| `${order_by_column}` | Column for consistent ordering |
| `${expected_record_count}` | Number of expected records |
| `${actual_file_path}` | Path to exported actual output CSV |
| `${expected_file_path}` | Path to expected output CSV |
| `@{excluded_columns}` | List of columns to exclude from comparison |

**Related slash command:** `/verify-data-in-db`

---

## Quick Start Template

Here's a basic test case template for data verification:

> **IMPORTANT: Required Libraries**
> When creating any new Robot file, ALWAYS include these Resource imports under `*** Settings ***`:
> - `snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource` - SnapLogic API keywords
> - `../../resources/common/sql_table_operations.resource` - SQL table operations
> - `../../resources/common/files.resource` - CSV/file comparison operations

```robotframework
*** Settings ***
Documentation    Verifies data in database table after pipeline execution
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/sql_table_operations.resource
Resource         ../../resources/common/files.resource
Library          Collections

*** Variables ***
# Table configuration
${table_name}                   DEMO.TEST_TABLE
${schema_name}                  DEMO
${order_by_column}              RECORD_METADATA

# Expected record count
${expected_record_count}        2

# Output files
${actual_output_file}           ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/actual_output.csv
${expected_output_file}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/oracle/expected_output.csv

# Columns to exclude from comparison (timestamps, dynamic values)
@{excluded_columns_for_comparison}
...    event_timestamp
...    unique_event_id
...    SnowflakeConnectorPushTime

*** Test Cases ***
Verify Data In Table
    [Documentation]    Verifies data integrity in database table by querying and validating record counts.
    ...    PREREQUISITES:
    ...    - Pipeline execution completed successfully
    ...    - Table exists with data inserted
    ...    - Database connection is established
    [Tags]    verification    data_validation
    Capture And Verify Number of records From DB Table
    ...    ${table_name}
    ...    ${schema_name}
    ...    ${order_by_column}
    ...    ${expected_record_count}

Export Data To CSV
    [Documentation]    Exports data from database table to CSV for comparison.
    ...    PREREQUISITES:
    ...    - Previous verification passed
    ...    - Database connection established
    [Tags]    verification    export
    Export DB Table Data To CSV
    ...    ${table_name}
    ...    ${order_by_column}
    ...    ${actual_output_file}

Compare Actual vs Expected Output
    [Documentation]    Compares actual database export against expected output.
    ...    PREREQUISITES:
    ...    - Export completed successfully
    ...    - Expected output file exists
    [Tags]    verification    comparison
    [Template]    Compare CSV Files With Exclusions Template
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}
```

---

## IMPORTANT: Step-by-Step Workflow

**Always follow this workflow when creating data verification test cases.**

**MANDATORY: You MUST create ALL of the following files:**

| # | File | Location | Purpose |
|---|------|----------|---------|
| 1 | **Robot test file** | `test/suite/pipeline_tests/[type]/[type]_verify_data.robot` | Robot Framework test case |
| 2 | **VERIFY_DATA_README.md** | `test/suite/pipeline_tests/[type]/VERIFY_DATA_README.md` | File structure diagram and instructions |

**ALWAYS create all files using the Write tool.** There are NO exceptions.

### Step 1: Identify Requirements
- Which database type? (Oracle, Snowflake, PostgreSQL, etc.)
- What table to verify?
- Expected record count?
- Need CSV comparison?
- Which columns to exclude from comparison?

### Step 2: Verify Prerequisites
- Pipeline must have been executed
- Database connection in Suite Setup

### Step 3: Create the Robot Test Case (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the `.robot` test file. Do NOT skip this step.

### Step 4: Create VERIFY_DATA_README.md (ALWAYS — use Write tool)
**ALWAYS use the Write tool** to create the README with file structure diagram. Do NOT skip this step.

---

## COMPLETE EXAMPLE: Oracle Data Verification (All Files)

**When a user asks "Verify data in Oracle table after pipeline execution", you MUST create ALL of these files:**

### File 1: Robot Test File — `test/suite/pipeline_tests/oracle/oracle_verify_data.robot`
```robotframework
*** Settings ***
Documentation    Verifies data in Oracle database table after pipeline execution
...              This test suite validates that the pipeline correctly inserted data
...              by checking record counts and comparing with expected output
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/sql_table_operations.resource
Resource         ../../resources/common/files.resource
Resource         ../../../resources/common/database.resource
Library          Collections
Library          DatabaseLibrary
Library          oracledb

Suite Setup      Connect To Oracle And Initialize
Suite Teardown   Disconnect From Database

*** Variables ***
# Table configuration
${table_name}                   DEMO.TEST_TABLE1
${schema_name}                  DEMO
${order_by_column}              DCEVENTHEADERS_USERID

# Task parameters (for reference - passed from pipeline)
&{task_params_set}
...    table_name=DEMO.TEST_TABLE1
...    schema_name=DEMO

# Expected record count after pipeline execution
${expected_record_count}        2

# Output file paths
${actual_output_file}           ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/oracle_actual_output.csv
${expected_output_file}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/oracle/expected_output_file1.csv

# Columns to exclude from comparison (dynamic values that change between runs)
@{excluded_columns_for_comparison}
...    event_timestamp
...    unique_event_id
...    created_date

*** Test Cases ***
Verify Data In Oracle Table
    [Documentation]    Verifies data integrity in Oracle table by querying and validating record counts.
    ...    This test case ensures that the pipeline successfully inserted the expected number
    ...    of records into the target Oracle table.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline execution completed successfully
    ...    • Oracle table exists with data inserted
    ...    • Database connection is established
    ...    • Table is cleaned (truncated) during suite setup for consistent results
    ...
    ...    📋 VERIFICATION DETAILS:
    ...    • Table Name: ${task_params_set}[table_name] - Target table to verify (DEMO.TEST_TABLE1)
    ...    • Schema Name: ${task_params_set}[schema_name] - Schema containing the table (DEMO)
    ...    • Order By Column: DCEVENTHEADERS_USERID - Column used for consistent ordering
    ...    • Expected Record Count: 2 - Number of records expected after pipeline execution
    [Tags]    oracle    verification    data_validation

    Capture And Verify Number of records From DB Table
    ...    ${task_params_set}[table_name]
    ...    ${task_params_set}[schema_name]
    ...    ${order_by_column}
    ...    ${expected_record_count}

Export Oracle Data To CSV
    [Documentation]    Exports data from Oracle table to a CSV file for detailed verification and comparison.
    ...    This test case retrieves all data from the target table and saves it in CSV format,
    ...    enabling file-based validation against expected results.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline execution completed successfully (Execute Triggered Task With Parameters)
    ...    • Oracle table contains data inserted by the pipeline
    ...    • Database connection is established
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Table Name - ${task_params_set}[table_name] - Source table to export data from (DEMO.TEST_TABLE1)
    ...    • Argument 2: Order By Column - DCEVENTHEADERS_USERID - Column for consistent row ordering
    ...    • Argument 3: Output File Path - ${actual_output_file} - Local path to save CSV file
    ...
    ...    📋 OUTPUT:
    ...    • CSV file saved to: test/suite/test_data/actual_expected_data/actual_output/oracle/oracle_actual_output.csv
    ...    • File contains all rows from the Oracle table ordered by DCEVENTHEADERS_USERID
    [Tags]    oracle    verification    export

    Export DB Table Data To CSV
    ...    ${task_params_set}[table_name]
    ...    ${order_by_column}
    ...    ${actual_output_file}

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing actual Oracle export against expected output.
    ...    This test case performs a comprehensive file comparison to ensure that data processed
    ...    through the Oracle pipeline matches the expected results exactly.
    ...
    ...    📋 PREREQUISITES:
    ...    • Export Oracle Data To CSV test case completed successfully
    ...    • Expected output file exists at: test/suite/test_data/actual_expected_data/expected_output/oracle/expected_output_file1.csv
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: file1_path - Path to the actual output CSV file from Oracle
    ...    • Argument 2: file2_path - Path to the expected output CSV file (baseline)
    ...    • Argument 3: ignore_order - Boolean flag to ignore row ordering
    ...    • Argument 4: show_details - Boolean flag to display detailed differences
    ...    • Argument 5: expected_status - Expected comparison result (IDENTICAL, DIFFERENT, SUBSET)
    ...    • Argument 6: exclude_columns - List of columns to exclude from comparison
    ...
    ...    📋 OUTPUT:
    ...    • Test passes if files are IDENTICAL (or match the expected_status)
    ...    • Detailed differences are displayed in console when show_details=${TRUE}
    [Tags]    oracle    verification    comparison
    [Template]    Compare CSV Files With Exclusions Template

    # file1_path    file2_path    ignore_order    show_details    expected_status    exclude_columns
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}

*** Keywords ***
Connect To Oracle And Initialize
    [Documentation]    Establishes Oracle database connection for verification
    Connect to Oracle Database
    ...    ${ORACLE_DATABASE}
    ...    ${ORACLE_USER}
    ...    ${ORACLE_PASSWORD}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_PORT}
    Log    Connected to Oracle database for verification    console=yes
```

### File 2: README — `test/suite/pipeline_tests/oracle/VERIFY_DATA_README.md`
````markdown
# Oracle Data Verification Tests

This test suite verifies data in Oracle database tables after pipeline execution.

## Purpose
Validates that the pipeline correctly inserted data by:
1. Checking record counts match expected values
2. Exporting data to CSV for detailed comparison
3. Comparing actual output with expected baseline files

## Three Key Operations

| Operation | Keyword | Purpose |
|-----------|---------|---------|
| **Verify Count** | `Capture And Verify Number of records From DB Table` | Verify expected record count |
| **Export Data** | `Export DB Table Data To CSV` | Export table data to CSV file |
| **Compare Output** | `Compare CSV Files With Exclusions Template` | Compare actual vs expected |

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── oracle/
│       │       ├── oracle_verify_data.robot                ← Test case file
│       │       └── VERIFY_DATA_README.md                   ← This file
│       └── test_data/
│           └── actual_expected_data/
│               ├── actual_output/
│               │   └── oracle/
│               │       └── oracle_actual_output.csv        ← Exported actual data
│               └── expected_output/
│                   └── oracle/
│                       └── expected_output_file1.csv       ← Expected baseline
└── .env                                                    ← Environment configuration
```

## Prerequisites
1. Pipeline must have been executed (triggered task completed)
2. Oracle database connection configured in `.env`
3. Expected output file exists in `expected_output/oracle/`

## Configuration

### Table Settings
- `table_name` — Target table to verify (e.g., `DEMO.TEST_TABLE1`)
- `schema_name` — Schema containing the table (e.g., `DEMO`)
- `order_by_column` — Column for consistent ordering

### Excluded Columns
Columns that change between runs (timestamps, IDs) should be excluded from comparison:
```robotframework
@{excluded_columns_for_comparison}
...    event_timestamp
...    unique_event_id
...    created_date
```

## How to Run
```bash
# Run verification tests only
make robot-run-all-tests TAGS="oracle AND verification" PROJECT_SPACE_SETUP=True

# Run specific verification type
make robot-run-all-tests TAGS="data_validation" PROJECT_SPACE_SETUP=True
make robot-run-all-tests TAGS="comparison" PROJECT_SPACE_SETUP=True
```
````

**Claude: The above is a COMPLETE example. When creating data verification test cases for ANY database type, follow the same pattern — always create all files.**

---

## Test Case Examples by Database Type

### Snowflake Verification

```robotframework
*** Settings ***
Documentation    Verifies data in Snowflake table after pipeline execution
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../../resources/snowflake/snowflake_keywords_databaselib.resource
Resource         ../../resources/common/sql_table_operations.resource
Resource         ../../resources/common/files.resource
Library          Collections

Suite Setup      Connect To Snowflake Via DatabaseLibrary    keypair
Suite Teardown   Disconnect From Snowflake

*** Variables ***
${table_name}                   DEMO.TEST_SNAP4
${schema_name}                  DEMO
${order_by_column}              RECORD_METADATA
${expected_record_count}        2

${actual_output_file}           ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/actual_output.csv
${expected_output_file}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/expected_output.csv

@{excluded_columns_for_comparison}
...    SnowflakeConnectorPushTime
...    unique_event_id
...    event_timestamp

*** Test Cases ***
Verify Data In Snowflake Table
    [Documentation]    Verifies data integrity in Snowflake table.
    [Tags]    snowflake    verification
    Capture And Verify Number of records From DB Table
    ...    ${table_name}
    ...    ${schema_name}
    ...    ${order_by_column}
    ...    ${expected_record_count}

Export Snowflake Data To CSV
    [Documentation]    Exports Snowflake table data to CSV.
    [Tags]    snowflake    export
    Export DB Table Data To CSV
    ...    ${table_name}
    ...    ${order_by_column}
    ...    ${actual_output_file}

Compare Actual vs Expected
    [Documentation]    Compares actual vs expected CSV output.
    [Tags]    snowflake    comparison
    [Template]    Compare CSV Files With Exclusions Template
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}
```

### PostgreSQL Verification

```robotframework
*** Settings ***
Documentation    Verifies data in PostgreSQL table after pipeline execution
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../resources/common/sql_table_operations.resource
Resource         ../../resources/common/files.resource
Library          Collections
Library          DatabaseLibrary

Suite Setup      Connect To PostgreSQL Database
Suite Teardown   Disconnect From Database

*** Variables ***
${table_name}                   public.test_table
${schema_name}                  public
${order_by_column}              id
${expected_record_count}        5

${actual_output_file}           ${CURDIR}/../../test_data/actual_expected_data/actual_output/postgres/actual_output.csv
${expected_output_file}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/postgres/expected_output.csv

*** Test Cases ***
Verify Data In PostgreSQL Table
    [Documentation]    Verifies data integrity in PostgreSQL table.
    [Tags]    postgres    verification
    Capture And Verify Number of records From DB Table
    ...    ${table_name}
    ...    ${schema_name}
    ...    ${order_by_column}
    ...    ${expected_record_count}
```

---

## Keyword Arguments Reference

### Capture And Verify Number of records From DB Table

| Argument | Description | Required | Example |
|----------|-------------|----------|---------|
| `${table_name}` | Full table name (schema.table) | Yes | `DEMO.TEST_TABLE1` |
| `${schema_name}` | Schema containing the table | Yes | `DEMO` |
| `${order_by_column}` | Column for ordering results | Yes | `DCEVENTHEADERS_USERID` |
| `${expected_record_count}` | Expected number of records | Yes | `2` |

### Export DB Table Data To CSV

| Argument | Description | Required | Example |
|----------|-------------|----------|---------|
| `${table_name}` | Table to export data from | Yes | `DEMO.TEST_TABLE1` |
| `${order_by_column}` | Column for ordering export | Yes | `DCEVENTHEADERS_USERID` |
| `${output_file}` | Path to save CSV file | Yes | `${CURDIR}/.../actual_output.csv` |

### Compare CSV Files With Exclusions Template

| Argument | Description | Required | Example |
|----------|-------------|----------|---------|
| `${file1_path}` | Path to actual output CSV | Yes | `${actual_output_file}` |
| `${file2_path}` | Path to expected output CSV | Yes | `${expected_output_file}` |
| `${ignore_order}` | Ignore row order in comparison | Yes | `${FALSE}` |
| `${show_details}` | Display detailed differences | Yes | `${TRUE}` |
| `${expected_status}` | Expected result (IDENTICAL/DIFFERENT) | Yes | `IDENTICAL` |
| `@{exclude_columns}` | Columns to exclude from comparison | Optional | `@{excluded_columns}` |

---

## Column Exclusion Patterns

### When to Exclude Columns

Exclude columns that have dynamic values that change between runs:

```robotframework
*** Variables ***
@{excluded_columns_for_comparison}
...    event_timestamp                    # Timestamp when event was created
...    unique_event_id                    # Auto-generated unique ID
...    SnowflakeConnectorPushTime         # Snowflake connector timestamp
...    created_date                       # Record creation date
...    modified_date                      # Record modification date
...    /MARKETING-NOTIFICATIONS/CONTENT   # Dynamic notification content
```

### Common Patterns by Database

| Database | Common Excluded Columns |
|----------|------------------------|
| Snowflake | `SnowflakeConnectorPushTime`, `_metadata_*` |
| Oracle | `CREATED_DATE`, `MODIFIED_DATE`, `SYS_*` |
| PostgreSQL | `created_at`, `updated_at`, `ctid` |
| SQL Server | `TIMESTAMP`, `ROWVERSION` |

---

## Typical Test Execution Flow

```
┌─────────────────────────┐
│  1. Suite Setup         │
│  (Connect to Database)  │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  2. (Previous Steps)    │
│  - Create Account       │
│  - Import Pipeline      │
│  - Execute Task         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  3. Verify Record Count │  ◄── VERIFY COUNT
│  (Expected: 2 records)  │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  4. Export Data to CSV  │  ◄── EXPORT DATA
│  (actual_output.csv)    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  5. Compare CSV Files   │  ◄── COMPARE OUTPUT
│  (Actual vs Expected)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  6. Suite Teardown      │
│  (Disconnect Database)  │
└─────────────────────────┘
```

---

## Supported Database Types

| Database | Connection Resource | Notes |
|----------|---------------------|-------|
| Oracle | `database.resource` + `oracledb` | Use `Connect to Oracle Database` |
| Snowflake | `snowflake_keywords_databaselib.resource` | Use `Connect To Snowflake Via DatabaseLibrary` |
| PostgreSQL | `database.resource` + `DatabaseLibrary` | Use standard DatabaseLibrary |
| MySQL | `database.resource` + `DatabaseLibrary` | Use standard DatabaseLibrary |
| SQL Server | `database.resource` + `DatabaseLibrary` | Use standard DatabaseLibrary |
| DB2 | `database.resource` + `DatabaseLibrary` | Use standard DatabaseLibrary |
| Teradata | `database.resource` + `DatabaseLibrary` | Use standard DatabaseLibrary |

---

## MANDATORY: VERIFY_DATA_README.md with File Structure

**IMPORTANT: Every time you create data verification test cases, you MUST also create a VERIFY_DATA_README.md in the same directory with a file structure diagram.**

This is required for ALL data verification test cases. No exceptions.

### README Template

````markdown
# [Type] Data Verification Tests

This test suite verifies data in [Type] database tables after pipeline execution.

## Purpose
Validates that the pipeline correctly inserted data by:
1. Checking record counts match expected values
2. Exporting data to CSV for detailed comparison
3. Comparing actual output with expected baseline files

## Three Key Operations

| Operation | Keyword | Purpose |
|-----------|---------|---------|
| **Verify Count** | `Capture And Verify Number of records From DB Table` | Verify expected record count |
| **Export Data** | `Export DB Table Data To CSV` | Export table data to CSV file |
| **Compare Output** | `Compare CSV Files With Exclusions Template` | Compare actual vs expected |

## File Structure
```
project-root/
├── test/
│   └── suite/
│       ├── pipeline_tests/
│       │   └── [type]/
│       │       ├── [type]_verify_data.robot                ← Test case file
│       │       └── VERIFY_DATA_README.md                   ← This file
│       └── test_data/
│           └── actual_expected_data/
│               ├── actual_output/
│               │   └── [type]/
│               │       └── actual_output.csv               ← Exported actual data
│               └── expected_output/
│                   └── [type]/
│                       └── expected_output.csv             ← Expected baseline
└── .env                                                    ← Environment configuration
```

## Prerequisites
1. Pipeline must have been executed (triggered task completed)
2. [Type] database connection configured in `.env`
3. Expected output file exists in `expected_output/[type]/`

## How to Run
```bash
make robot-run-all-tests TAGS="[type] AND verification" PROJECT_SPACE_SETUP=True
```
````

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| `Table not found` | Wrong table name or schema | Verify table name includes schema |
| `Connection failed` | Database credentials | Check `.env` configuration |
| `Record count mismatch` | Pipeline didn't complete | Verify triggered task completed |
| `CSV comparison failed` | Dynamic columns | Add columns to exclusion list |
| `File not found` | Wrong output path | Check file path in variables |

### Debug Tips

1. **Log record count:**
   ```robotframework
   ${count}=    Get Row Count    ${table_name}
   Log    Current record count: ${count}    console=yes
   ```

2. **Verify table exists:**
   ```robotframework
   Table Should Exist    ${table_name}    ${schema_name}
   ```

3. **List columns to exclude:**
   ```robotframework
   Log    Excluded columns: @{excluded_columns_for_comparison}    console=yes
   ```

---

## Checklist Before Committing

- [ ] Pipeline has been executed successfully
- [ ] Database connection established in Suite Setup
- [ ] Table name includes schema (e.g., `DEMO.TEST_TABLE`)
- [ ] Expected record count is correct
- [ ] Expected output file exists and is up to date
- [ ] Dynamic columns added to exclusion list
- [ ] Test has appropriate tags (`verification`, `data_validation`, `comparison`)
- [ ] **VERIFY_DATA_README.md created with file structure diagram**
