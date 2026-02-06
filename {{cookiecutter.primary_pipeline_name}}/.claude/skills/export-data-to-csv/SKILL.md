---
name: export-data-to-csv
description: Creates Robot Framework test cases for exporting database table data to CSV files. Use when the user wants to export Oracle, Snowflake, PostgreSQL, or other database data to CSV for verification or comparison purposes.
user-invocable: true
---

# SnapLogic Export Data to CSV Skill - Complete Guide

## Overview

This skill creates Robot Framework test cases for exporting database table data to CSV files. The exported CSV files can be used for:
- Verification against expected output files
- Data comparison between pipeline runs
- Data archiving and backup
- Debugging and troubleshooting

---

## Key Keyword

### `Export DB Table Data To CSV`

**Location:** `test/resources/common/sql_table_operations.resource`

**Arguments:**
| Argument | Description | Example |
|----------|-------------|---------|
| `table_name` | The database table to export (can include schema) | `DEMO.TEST_TABLE1` |
| `order_by_column` | Column to use for consistent row ordering | `DCEVENTHEADERS_USERID` |
| `output_file` | Local file path to save the CSV | `${actual_output_file1_path}` |

**Example Usage:**
```robot
Export DB Table Data To CSV
...    ${task_params_set}[table_name]
...    ${db_order_by_column}
...    ${actual_output_file1_path_from_db}
```

---

## Database-Specific Examples

### Oracle Export Example

```robot
*** Test Cases ***
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
    ...    • Argument 3: Output File Path - ${actual_output_file1_path_from_db} - Local path to save CSV file
    ...
    ...    📋 OUTPUT:
    ...    • CSV file saved to: test/suite/test_data/actual_expected_data/actual_output/oracle/${pipeline_name}_actual_output_file1.csv
    ...    • File contains all rows from the Oracle table ordered by DCEVENTHEADERS_USERID
    [Tags]    oracle    export

    Export DB Table Data To CSV
    ...    ${task_params_set}[table_name]
    ...    ${db_order_by_column}
    ...    ${actual_output_file1_path_from_db}
```

### Snowflake Export Example

```robot
*** Test Cases ***
Export Snowflake Data To CSV
    [Documentation]    Exports data from Snowflake table to a CSV file for detailed verification and comparison.
    ...    This test case retrieves all data from the target table and saves it in CSV format,
    ...    enabling file-based validation against expected results.
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Table Name - ${task_params_set}[table] - Source table to export data from
    ...    • Argument 2: Order By Column - RECORD_METADATA - Column for consistent row ordering
    ...    • Argument 3: Output File Path - ${actual_output_file1_path_from_db} - Local path to save CSV file
    [Tags]    snowflake    export

    Export DB Table Data To CSV
    ...    ${task_params_set}[table]
    ...    RECORD_METADATA
    ...    ${actual_output_file1_path_from_db}
```

### PostgreSQL Export Example

```robot
*** Test Cases ***
Export PostgreSQL Data To CSV
    [Documentation]    Exports data from PostgreSQL table to a CSV file for verification.
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Table Name - ${task_params_set}[table_name] - Source table to export
    ...    • Argument 2: Order By Column - id - Column for consistent row ordering
    ...    • Argument 3: Output File Path - ${actual_output_file_path} - Local path to save CSV file
    [Tags]    postgresql    export

    Export DB Table Data To CSV
    ...    ${task_params_set}[table_name]
    ...    id
    ...    ${actual_output_file_path}
```

---

## Complete Test File Template

```robot
*** Settings ***
Documentation       Export Database Data to CSV Test Suite
...                 This suite exports data from database tables to CSV files for verification.

Library             OperatingSystem
Library             DatabaseLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/common/sql_table_operations.resource
Resource            ../../../resources/common/database.resource

Suite Setup         Initialize Database Connection
Suite Teardown      Disconnect From Database


*** Variables ***
# Pipeline and table configuration
${pipeline_name}                        my_pipeline
${schema_name}                          DEMO
${table_name}                           ${schema_name}.TEST_TABLE

# Order by column for consistent export ordering
${db_order_by_column}                   CREATED_DATE

# Output file paths
${actual_output_file_name}              ${pipeline_name}_actual_output.csv
${actual_output_file_path}              ${CURDIR}/../../test_data/actual_expected_data/actual_output/${pipeline_name}/${actual_output_file_name}


*** Test Cases ***
Export Data To CSV
    [Documentation]    Exports data from database table to a CSV file.
    ...
    ...    📋 PREREQUISITES:
    ...    • Database connection is established
    ...    • Table exists and contains data
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Table Name - ${table_name} - Source table to export
    ...    • Argument 2: Order By Column - ${db_order_by_column} - Column for ordering
    ...    • Argument 3: Output File Path - ${actual_output_file_path} - Path to save CSV
    [Tags]    export    csv

    Export DB Table Data To CSV
    ...    ${table_name}
    ...    ${db_order_by_column}
    ...    ${actual_output_file_path}


*** Keywords ***
Initialize Database Connection
    [Documentation]    Establishes database connection for the test suite
    # Connect to your specific database type here
    # Example for Oracle:
    # Connect to Oracle Database    ${ORACLE_DATABASE}    ${ORACLE_USER}    ${ORACLE_PASSWORD}    ${ORACLE_HOST}    ${ORACLE_PORT}
    # Example for Snowflake:
    # Connect To Snowflake Via DatabaseLibrary    keypair
    Log    Database connection initialized    console=yes
```

---

## Variables Section Template

```robot
*** Variables ***
# Pipeline name for file naming
${pipeline_name}                        oracle_pipeline

# Table configuration
${schema_name}                          DEMO
${table_name}                           ${schema_name}.TEST_TABLE1

# Order by column for consistent CSV ordering
${db_order_by_column}                   CREATED_DATE

# Actual output file (generated by export)
${actual_output_file_name}              ${pipeline_name}_actual_output_file_from_db.csv
${actual_output_file_path}              ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/${actual_output_file_name}

# For multiple output files
${actual_output_file1_name}             ${pipeline_name}_actual_output_file1.csv
${actual_output_file2_name}             ${pipeline_name}_actual_output_file2.csv
${actual_output_file1_path_from_db}     ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/${actual_output_file1_name}
${actual_output_file2_path_from_db}     ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/${actual_output_file2_name}
```

---

## Combining with Data Verification

### Export and Verify Flow

```robot
*** Test Cases ***
Verify Data Count Then Export
    [Documentation]    Verifies record count and then exports data to CSV
    [Tags]    verify    export

    # Step 1: Verify record count
    Capture And Verify Number of records From DB Table
    ...    ${table_name}
    ...    ${schema_name}
    ...    ${db_order_by_column}
    ...    ${expected_record_count}

    # Step 2: Export data to CSV
    Export DB Table Data To CSV
    ...    ${table_name}
    ...    ${db_order_by_column}
    ...    ${actual_output_file_path}

Export And Compare CSV
    [Documentation]    Exports data and compares with expected output
    [Tags]    export    compare

    # Step 1: Export data to CSV
    Export DB Table Data To CSV
    ...    ${table_name}
    ...    ${db_order_by_column}
    ...    ${actual_output_file_path}

    # Step 2: Compare with expected output
    Compare CSV Files With Exclusions Template
    ...    ${actual_output_file_path}
    ...    ${expected_output_file_path}
    ...    ${FALSE}    # ignore_order
    ...    ${TRUE}     # show_details
    ...    IDENTICAL   # expected_status
```

---

## Directory Structure

```
test/
├── suite/
│   ├── pipeline_tests/
│   │   ├── oracle/
│   │   │   ├── oracle_export_tests.robot
│   │   │   └── EXPORT_DATA_README.md
│   │   ├── snowflake/
│   │   │   ├── snowflake_export_tests.robot
│   │   │   └── EXPORT_DATA_README.md
│   │   └── postgresql/
│   │       ├── postgresql_export_tests.robot
│   │       └── EXPORT_DATA_README.md
│   └── test_data/
│       └── actual_expected_data/
│           ├── actual_output/
│           │   ├── oracle/
│           │   │   └── pipeline_actual_output.csv    # Generated by export
│           │   └── snowflake/
│           │       └── pipeline_actual_output.csv
│           └── expected_output/
│               ├── oracle/
│               │   └── expected_output.csv           # User-provided baseline
│               └── snowflake/
│                   └── expected_output.csv
└── resources/
    └── common/
        └── sql_table_operations.resource             # Contains Export DB Table Data To CSV
```

---

## Best Practices

1. **Consistent Ordering**: Always use `order_by_column` to ensure consistent row ordering between exports
2. **Unique File Names**: Include `${pipeline_name}` in output file names to avoid conflicts
3. **Output Directory**: Store actual output in `test_data/actual_expected_data/actual_output/[db_type]/`
4. **Clean Before Export**: Consider cleaning the table before pipeline execution for consistent results
5. **Verify First**: Verify record count before exporting to ensure data exists

---

## Related Skills

- `/verify-data-in-db` — Verify record counts in database tables
- `/end-to-end-pipeline-verification` — Complete end-to-end pipeline setup with export and verification
- `/create-triggered-task` — Create and execute triggered tasks before export

---

## Invoke with: `/export-data-to-csv`
