---
name: compare-csv
description: Creates Robot Framework test cases for comparing actual vs expected CSV output files. Use when the user wants to compare CSV files, validate pipeline output against expected results, or needs to exclude dynamic columns from comparison.
user-invocable: true
---

# SnapLogic Compare CSV Skill - Complete Guide

## Overview

This skill creates Robot Framework test cases for comparing actual vs expected CSV output files. The comparison:
- Validates that pipeline output matches expected baseline
- Supports excluding dynamic columns (timestamps, IDs, etc.)
- Can ignore row ordering for flexible comparison
- Provides detailed difference reports
- Supports key-based row matching

---

## Key Keywords

### `Compare CSV Files With Exclusions Template`

**Location:** `test/resources/common/files.resource`

**Arguments:**
| Argument | Description | Example |
|----------|-------------|---------|
| `file1_path` | Path to actual output CSV file | `${actual_output_file}` |
| `file2_path` | Path to expected output CSV file | `${expected_output_file}` |
| `ignore_order` | Whether to ignore row order | `${TRUE}` or `${FALSE}` |
| `show_details` | Whether to show detailed differences | `${TRUE}` or `${FALSE}` |
| `expected_status` | Expected comparison result | `IDENTICAL`, `DIFFERENT`, `SUBSET` |
| `@exclude_keys` | Columns to exclude from comparison | `timestamp`, `event_id` |
| `&options` | Additional options | `match_key=profile_id` |

**Example Usage:**
```robot
Compare CSV Files With Exclusions Template
...    ${actual_output_file}
...    ${expected_output_file}
...    ${FALSE}           # ignore_order
...    ${TRUE}            # show_details
...    IDENTICAL          # expected_status
...    @{excluded_columns_for_comparison}
```

### `Compare CSV Files Template`

**Location:** `test/resources/common/files.resource`

Use this simpler keyword when you don't need to exclude columns.

**Arguments:**
| Argument | Description | Example |
|----------|-------------|---------|
| `file1_path` | Path to actual output CSV file | `${actual_output_file}` |
| `file2_path` | Path to expected output CSV file | `${expected_output_file}` |
| `ignore_order` | Whether to ignore row order | `${TRUE}` or `${FALSE}` |
| `show_details` | Whether to show detailed differences | `${TRUE}` or `${FALSE}` |
| `expected_status` | Expected comparison result | `IDENTICAL`, `DIFFERENT` |

---

## Expected Status Values

| Status | Description |
|--------|-------------|
| `IDENTICAL` | Files must match exactly (after exclusions) |
| `DIFFERENT` | Files are expected to differ |
| `SUBSET` | File1 is expected to be a subset of File2 |

---

## Database-Specific Examples

### Oracle CSV Comparison

```robot
*** Variables ***
# Output file paths
${actual_output_file}           ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/oracle_actual_output.csv
${expected_output_file}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/oracle/expected_output.csv

# Columns to exclude (dynamic values that change between runs)
@{excluded_columns_for_comparison}
...    CREATED_DATE
...    MODIFIED_TIMESTAMP
...    UNIQUE_ID

*** Test Cases ***
Compare Oracle Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing actual Oracle export against expected output.
    ...    This test case performs a comprehensive file comparison to ensure that data processed
    ...    through the Oracle pipeline matches the expected results exactly.
    ...
    ...    📋 PREREQUISITES:
    ...    • Export Oracle Data To CSV test case completed successfully
    ...    • Expected output file exists at: test/suite/test_data/actual_expected_data/expected_output/oracle/expected_output.csv
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: file1_path - Path to the actual output CSV file from Oracle
    ...    • Argument 2: file2_path - Path to the expected output CSV file (baseline)
    ...    • Argument 3: ignore_order - Boolean flag to ignore row ordering
    ...      ${TRUE} = Compare without considering row order
    ...      ${FALSE} = Rows must match in exact order
    ...    • Argument 4: show_details - Boolean flag to display detailed differences
    ...      ${TRUE} = Show all differences in console output
    ...      ${FALSE} = Show only summary
    ...    • Argument 5: expected_status - Expected comparison result
    ...      IDENTICAL = Files must match exactly
    ...      DIFFERENT = Files expected to differ
    ...      SUBSET = File1 is subset of File2
    ...    • Argument 6: exclude_columns (Optional) - List of columns to exclude from comparison
    ...      Useful for dynamic columns like timestamps that change between runs
    ...
    ...    📋 OUTPUT:
    ...    • Test passes if files are IDENTICAL (or match the expected_status)
    ...    • Detailed differences are displayed in console when show_details=${TRUE}
    [Tags]    oracle    verification    comparison

    [Template]    Compare CSV Files With Exclusions Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status    exclude_columns
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}
```

### Snowflake CSV Comparison

```robot
*** Variables ***
# Output file paths
${actual_output_file}           ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/snowflake_actual_output.csv
${expected_output_file}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/expected_output.csv

# Dynamic columns to exclude from comparison
@{excluded_columns_for_comparison}
...    SnowflakeConnectorPushTime
...    unique_event_id
...    event_timestamp
...    /MARKETING-NOTIFICATIONS/CONTENT

*** Test Cases ***
Compare Snowflake Actual vs Expected CSV Output
    [Documentation]    Validates Snowflake pipeline output against expected baseline.
    [Tags]    snowflake    verification    comparison

    [Template]    Compare CSV Files With Exclusions Template

    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}
```

### Comparison with Match Key (Row Matching by Column)

```robot
*** Test Cases ***
Compare CSV With Key-Based Matching
    [Documentation]    Compares CSV files using a specific column to match rows.
    ...    Useful when row order varies but rows can be matched by a unique identifier.
    [Tags]    comparison    key_match

    Compare CSV Files With Exclusions Template
    ...    ${actual_output_file}
    ...    ${expected_output_file}
    ...    ${TRUE}                              # ignore_order
    ...    ${TRUE}                              # show_details
    ...    IDENTICAL                            # expected_status
    ...    @{excluded_columns_for_comparison}
    ...    match_key=headers.profile_id         # Match rows by this column
```

---

## Complete Test File Template

```robot
*** Settings ***
Documentation       CSV Comparison Test Suite
...                 Compares actual pipeline output against expected baseline files.

Library             OperatingSystem
Library             Collections
Resource            ../../../resources/common/files.resource


*** Variables ***
# Pipeline configuration
${pipeline_name}                        my_pipeline

# Actual output file (generated by export)
${actual_output_file_name}              ${pipeline_name}_actual_output.csv
${actual_output_file}                   ${CURDIR}/../../test_data/actual_expected_data/actual_output/${pipeline_name}/${actual_output_file_name}

# Expected output file (baseline)
${expected_output_file_name}            expected_output.csv
${expected_output_file}                 ${CURDIR}/../../test_data/actual_expected_data/expected_output/${pipeline_name}/${expected_output_file_name}

# Columns to exclude from comparison (dynamic values)
@{excluded_columns_for_comparison}
...    created_timestamp
...    modified_date
...    unique_id
...    session_id


*** Test Cases ***
Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing actual export against expected output.
    ...
    ...    📋 PREREQUISITES:
    ...    • Export data test case completed successfully
    ...    • Expected output file exists
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • file1_path - Actual output CSV file
    ...    • file2_path - Expected output CSV file (baseline)
    ...    • ignore_order - ${FALSE} for exact order, ${TRUE} to ignore order
    ...    • show_details - ${TRUE} to show differences
    ...    • expected_status - IDENTICAL, DIFFERENT, or SUBSET
    ...    • exclude_columns - Columns to exclude from comparison
    [Tags]    verification    comparison    csv

    [Template]    Compare CSV Files With Exclusions Template

    # file1_path    file2_path    ignore_order    show_details    expected_status    exclude_columns
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}
```

---

## Variables Section Template

```robot
*** Variables ***
# Pipeline name for file naming
${pipeline_name}                        oracle_pipeline

# Actual output file (generated by Export DB Table Data To CSV)
${actual_output_file_name}              ${pipeline_name}_actual_output_file_from_db.csv
${actual_output_file}                   ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/${actual_output_file_name}

# Expected output file (user-provided baseline)
${expected_output_file_name}            expected_output_file.csv
${expected_output_file}                 ${CURDIR}/../../test_data/actual_expected_data/expected_output/oracle/${expected_output_file_name}

# Columns to exclude from comparison (dynamic values that change between runs)
@{excluded_columns_for_comparison}
...    CREATED_DATE                     # Timestamp when record was created
...    MODIFIED_TIMESTAMP               # Last modification time
...    SnowflakeConnectorPushTime       # Snowflake-specific timestamp
...    unique_event_id                  # Auto-generated unique ID
...    event_timestamp                  # Event time
...    /MARKETING-NOTIFICATIONS/CONTENT # Nested JSON path
```

---

## Common Exclusion Patterns

### Timestamp Columns
```robot
@{excluded_columns_for_comparison}
...    created_date
...    modified_date
...    timestamp
...    event_timestamp
...    SnowflakeConnectorPushTime
...    last_updated
```

### Auto-Generated IDs
```robot
@{excluded_columns_for_comparison}
...    unique_id
...    unique_event_id
...    session_id
...    transaction_id
...    uuid
```

### Snowflake-Specific
```robot
@{excluded_columns_for_comparison}
...    SnowflakeConnectorPushTime
...    unique_event_id
...    event_timestamp
...    RECORD_METADATA
```

### Oracle-Specific
```robot
@{excluded_columns_for_comparison}
...    CREATED_DATE
...    MODIFIED_DATE
...    ROWID
...    ORA_ROWSCN
```

### Nested JSON Paths
```robot
@{excluded_columns_for_comparison}
...    /MARKETING-NOTIFICATIONS/CONTENT
...    /headers/timestamp
...    /metadata/created_at
```

---

## Directory Structure

```
test/
├── suite/
│   ├── pipeline_tests/
│   │   ├── oracle/
│   │   │   ├── oracle_comparison_tests.robot
│   │   │   └── COMPARE_CSV_README.md
│   │   └── snowflake/
│   │       ├── snowflake_comparison_tests.robot
│   │       └── COMPARE_CSV_README.md
│   └── test_data/
│       └── actual_expected_data/
│           ├── actual_output/
│           │   ├── oracle/
│           │   │   └── oracle_actual_output.csv     # Generated by export
│           │   └── snowflake/
│           │       └── snowflake_actual_output.csv
│           └── expected_output/
│               ├── oracle/
│               │   └── expected_output.csv          # User-provided baseline
│               └── snowflake/
│                   └── expected_output.csv
└── resources/
    └── common/
        └── files.resource                           # Contains comparison keywords
```

---

## Combining with Export

### Export Then Compare Flow

```robot
*** Test Cases ***
Export Data To CSV
    [Documentation]    Exports data from database table to CSV file.
    [Tags]    export    csv

    Export DB Table Data To CSV
    ...    ${table_name}
    ...    ${order_by_column}
    ...    ${actual_output_file}

Compare Actual vs Expected CSV Output
    [Documentation]    Compares exported data against expected baseline.
    [Tags]    verification    comparison

    [Template]    Compare CSV Files With Exclusions Template
    ${actual_output_file}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}
```

---

## Best Practices

1. **Always Exclude Dynamic Columns**: Timestamps, auto-generated IDs, and session-specific values should be excluded
2. **Use `ignore_order=${FALSE}`**: Unless row order is truly non-deterministic, keep strict ordering
3. **Enable `show_details=${TRUE}`**: This helps debug failures by showing exact differences
4. **Create Expected Baseline Once**: Run the pipeline once, verify output manually, then save as expected baseline
5. **Use Meaningful File Names**: Include pipeline name and purpose in file names
6. **Store Expected Files in Version Control**: Keep expected output files in the repo for comparison

---

## Troubleshooting

### Files Show as Different When They Should Match
1. Check if dynamic columns need to be excluded
2. Verify column names match exactly (case-sensitive)
3. Check for whitespace differences
4. Verify row order if `ignore_order=${FALSE}`

### Key-Based Matching Not Working
1. Ensure the `match_key` column exists in both files
2. Verify column name matches exactly
3. Check that key values are unique

### Nested JSON Path Exclusions
Use forward slashes for nested paths:
```robot
@{excluded_columns}
...    /parent/child/field
...    /headers/timestamp
```

---

## Related Skills

- `/export-data-to-csv` — Export database data to CSV before comparison
- `/verify-data-in-db` — Verify record counts before export
- `/end-to-end-pipeline-verification` — Complete end-to-end pipeline setup with comparison

---

## Invoke with: `/compare-csv`
