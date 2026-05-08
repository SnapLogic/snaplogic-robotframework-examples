# ──────────────────────────────────────────────────────────────────────────────
# CSV File Comparison — Tutorial
#
# Demonstrates the CSV-comparison and validation keywords from
# `resources/common/csv_validations.resource`.
#
# Sample CSV files are organised in two parallel folders:
#   data/actual_data/<scenario>.csv    — the "actual output" file
#   data/expected_data/<scenario>.csv  — the matching "baseline" file
# Each test compares actual_data/X.csv against expected_data/X.csv.
#
# Run with:    make robot-run-tests-no-gp TAGS="compare_csv_sample"
#
# Each test demonstrates ONE keyword or ONE edge case.
# ──────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation       Tutorial — common CSV-comparison operations using csv_validations.resource

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource
Resource            ../../../../../resources/common/csv_validations.resource


*** Variables ***
# Folder roots — each scenario file has the SAME name in both folders.
${ACTUAL_DIR}                ${CURDIR}/data/actual_data
${EXPECTED_DIR}              ${CURDIR}/data/expected_data

# Pair 1 — identical content in both folders (IDENTICAL test)
${ACTUAL_BASIC}              ${ACTUAL_DIR}/basic.csv
${EXPECTED_BASIC}            ${EXPECTED_DIR}/basic.csv

# Pair 2 — actual has Bob modified, expected has original Bob (DIFFERENT test)
${ACTUAL_MODIFIED}           ${ACTUAL_DIR}/modified.csv
${EXPECTED_MODIFIED}         ${EXPECTED_DIR}/modified.csv

# Pair 3 — same data, different row order (ignore_order tests)
${ACTUAL_SHUFFLED}           ${ACTUAL_DIR}/shuffled.csv
${EXPECTED_SHUFFLED}         ${EXPECTED_DIR}/shuffled.csv

# Pair 4 — only the load_timestamp column differs (exclusion tests)
${ACTUAL_WITH_TIMESTAMP}     ${ACTUAL_DIR}/with_timestamp.csv
${EXPECTED_WITH_TIMESTAMP}   ${EXPECTED_DIR}/with_timestamp.csv

# Pair 5 — actual has 6 rows, expected has 5 (row count test)
${ACTUAL_EXTRA_ROW}          ${ACTUAL_DIR}/extra_row.csv
${EXPECTED_EXTRA_ROW}        ${EXPECTED_DIR}/extra_row.csv

# Pair 6 — actual missing salary column, expected has it (column count test)
${ACTUAL_MISSING_COLUMN}     ${ACTUAL_DIR}/missing_column.csv
${EXPECTED_MISSING_COLUMN}   ${EXPECTED_DIR}/missing_column.csv

# Pair 7 — Snowflake-style CSV with JSON records inside cells. Actual has
# count=999 in first row; expected has count=100. Used to demo comparing
# CSVs that hold embedded JSON (RECORD_METADATA / RECORD_CONTENT columns).
${ACTUAL_JSON_RECORDS}       ${ACTUAL_DIR}/json_records.csv
${EXPECTED_JSON_RECORDS}     ${EXPECTED_DIR}/json_records.csv


*** Test Cases ***
# ═══════════════════════════════════════════════════════════════
# 1. VALIDATE — Count rows
# ═══════════════════════════════════════════════════════════════

VALIDATE — Count Data Rows In CSV
    [Documentation]    Counts data rows in a CSV (header excluded by default).
    [Tags]    compare_csv_sample

    ${count}=    Count Data Rows In CSV    ${ACTUAL_BASIC}
    Should Be Equal As Integers    ${count}    5
    ...    msg=Expected 5 data rows in basic.csv, got ${count}

# ═══════════════════════════════════════════════════════════════
# 2. VALIDATE — File shape (rows + columns)
# ═══════════════════════════════════════════════════════════════

VALIDATE — Validate CSV File Template
    [Documentation]    Asserts row count and column count for a CSV file in one call.
    [Tags]    compare_csv_sample

    Validate CSV File Template
    ...    ${ACTUAL_BASIC}
    ...    expected_rows=5
    ...    has_headers=${TRUE}
    ...    expected_columns=4

# ═══════════════════════════════════════════════════════════════
# 3. COMPARE — Identical files (positive)
# ═══════════════════════════════════════════════════════════════

COMPARE — Identical files
    [Documentation]    Two byte-identical files → status=IDENTICAL.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_BASIC}
    ...    ${EXPECTED_BASIC}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    IDENTICAL

# ═══════════════════════════════════════════════════════════════
# 4. COMPARE — Different content (Bob's role + salary changed)
# ═══════════════════════════════════════════════════════════════

COMPARE — Different files
    [Documentation]    Two files differing in one row → status=DIFFERENT.
    ...    show_details=TRUE prints which cells changed.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_MODIFIED}
    ...    ${EXPECTED_MODIFIED}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    DIFFERENT

# ═══════════════════════════════════════════════════════════════
# 5. COMPARE — Same data, different row order (ignore_order=TRUE)
# ═══════════════════════════════════════════════════════════════

COMPARE — Shuffled rows with ignore_order=TRUE
    [Documentation]    Same data in a different sequence → IDENTICAL when order is ignored.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_SHUFFLED}
    ...    ${EXPECTED_SHUFFLED}
    ...    ${TRUE}
    ...    ${TRUE}
    ...    IDENTICAL

# ═══════════════════════════════════════════════════════════════
# 6. COMPARE — Same data, different row order (ignore_order=FALSE)
# ═══════════════════════════════════════════════════════════════

COMPARE — Shuffled rows with ignore_order=FALSE
    [Documentation]    Same data in a different sequence → DIFFERENT when order matters.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_SHUFFLED}
    ...    ${EXPECTED_SHUFFLED}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    DIFFERENT

# ═══════════════════════════════════════════════════════════════
# 7. COMPARE — Excluded columns hide differences
# ═══════════════════════════════════════════════════════════════

COMPARE — Differ only in timestamp column (EXCLUDED)
    [Documentation]    Two files differ only in load_timestamp values.
    ...    Excluding that column → status=IDENTICAL.
    [Tags]    compare_csv_sample

    Compare CSV Files With Exclusions Template
    ...    ${ACTUAL_WITH_TIMESTAMP}
    ...    ${EXPECTED_WITH_TIMESTAMP}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    IDENTICAL
    ...    load_timestamp

# ═══════════════════════════════════════════════════════════════
# 8. COMPARE — Without exclusion, the same files differ
# ═══════════════════════════════════════════════════════════════

COMPARE — Differ only in timestamp column (NOT EXCLUDED)
    [Documentation]    Without excluding load_timestamp → status=DIFFERENT.
    ...    Demonstrates why excluding non-deterministic columns matters.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_WITH_TIMESTAMP}
    ...    ${EXPECTED_WITH_TIMESTAMP}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    DIFFERENT

# ═══════════════════════════════════════════════════════════════
# 9. COMPARE — Different row counts
# ═══════════════════════════════════════════════════════════════

COMPARE — Different row counts
    [Documentation]    One file has an extra row → status=DIFFERENT.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_EXTRA_ROW}
    ...    ${EXPECTED_EXTRA_ROW}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    DIFFERENT

# ═══════════════════════════════════════════════════════════════
# 10. COMPARE — Different column counts
# ═══════════════════════════════════════════════════════════════

COMPARE — Different column counts
    [Documentation]    One file is missing the salary column → status=DIFFERENT.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_MISSING_COLUMN}
    ...    ${EXPECTED_MISSING_COLUMN}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    DIFFERENT

# ═══════════════════════════════════════════════════════════════
# 11. COMPARE — CSV with embedded JSON records (Snowflake-style)
# ═══════════════════════════════════════════════════════════════

COMPARE — CSV with embedded JSON records
    [Documentation]    Snowflake-style export — RECORD_METADATA and RECORD_CONTENT
    ...    columns hold JSON objects as quoted strings. The two files differ in
    ...    the first row's "count" field (999 vs 100) → status=DIFFERENT.
    [Tags]    compare_csv_sample

    Compare CSV Files Template
    ...    ${ACTUAL_JSON_RECORDS}
    ...    ${EXPECTED_JSON_RECORDS}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    DIFFERENT
