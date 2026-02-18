*** Settings ***
Documentation       Sample Demo — All 16 Reusable Keywords from json_validation.resource
...                 This file demonstrates every reusable keyword available in the shared
...                 resource file. Each test case is a thin one-liner calling one keyword.
...                 Use this as a reference when building new test files.
...
...                 Test data uses realistic SnapLogic EBAS_to_CBS pipeline structure:
...                 - Pipeline config JSON with Accounts (DEV/QA/PREPROD/PROD), Schema, paths
...                 - Expression library file (.expr) with Accounts, Schema, Environment functions,
...                   and transformation functions (rejectedState, irsFundAmount, epoch, etc.)
...
...                 Keywords demonstrated (16):
...                 1.  Validate JSON File Exists And Not Empty
...                 2.  Validate JSON Field Value
...                 3.  Validate JSON Fields Match Expected
...                 4.  Validate All Required Fields Present
...                 5.  Validate Field Matches Pattern
...                 6.  Validate File Exists And Not Empty
...                 7.  Validate File Meets Minimum Size
...                 8.  Validate Content Contains All Fields
...                 9.  Validate JSON Array Contains All Values
...                 10. Validate Nested JSON Fields Match Expected
...                 11. Validate Nested JSON Fields Present
...                 12. Validate JSON Field Greater Than
...                 13. Validate JSON Fields Sum Equals Expected
...                 14. Validate JSON Field Less Than Or Equal
...                 15. Validate JSON Two Fields Are Equal
...                 16. (inline) Field Count Sanity Check using Get Length
...
...                 Run:
...                 robot test/suite/pipeline_tests/standalone_tests/json_content_validation_tests/sample_keyword_demo_tests.robot
...                 robot --include sample test/suite/pipeline_tests/standalone_tests/json_content_validation_tests/

Library             OperatingSystem
Library             JSONLibrary
Library             Collections
Library             String
Resource            ../../../../resources/common/json_validation.resource

Suite Setup         Load Sample Demo Data


*** Variables ***
${SAMPLE_ACTUAL}        ${CURDIR}/test_data/actual/sample_actual.json
${SAMPLE_EXPECTED}      ${CURDIR}/test_data/expected/sample_expected.json

# Expression library file (.expr) — matches EBAS_to_CBS structure from SnapLogic
${EXPR_FILE_PATH}       ${CURDIR}/test_data/actual/EBAS_to_CBS_sample.expr

# For Validate JSON Field Value
${EXPECTED_STATUS}      active

# For Validate Field Matches Pattern (Jira ticket format)
${JIRA_PATTERN}         ^[A-Z]+-\\d+$

# For Validate File Meets Minimum Size — .expr file minimum (bytes)
${MIN_EXPR_SIZE}        100

# For Validate JSON Field Greater Than
${MIN_RECORD_COUNT}     0

# For Validate JSON Fields Sum Equals Expected
${EXPECTED_SUM_TOTAL}   450

# Required fields list for Validate All Required Fields Present
@{REQUIRED_FIELDS}      status    pipeline_name    project    jira_ticket    approved_by    reviewed_by

# Expression file content fields — Accounts, Schema, Environment functions, Transformations
@{EXPR_CONTENT_FIELDS}      Accounts    DEV    QA    PREPROD    PROD    Schema    getOrgName    rejectedState    irsFundAmount    epoch    anaualIncome    qual_eitc    marital2024    sku2024    genzFlag

# Output columns for array check (EBAS_to_CBS column names)
@{EXPECTED_COLUMNS}     DCEVENTHEADERS_USERID    TY2024_TAXFILING_REFUNDBALDUEAMOUNT_FED    TY2024_TAXFILING_EFILESTATUS_STATEREJECTED    TY2024_TTOGTKM_TOTALREVENUE    TY2024_COMMERCE_COMPLETEDSKU

# Nested account environment path fields
@{ACCOUNT_ENV_FIELDS}       DEV    QA    PREPROD    PROD

# Nested path fields
@{PATH_FIELDS}          account_path    upload_source_path    output_path

# Fields for multi-field match
@{MATCH_FIELDS}         status    pipeline_name    project    approved_by    reviewed_by

# Fields for sum check
@{SUM_FIELDS}           source_table_1_count    source_table_2_count    source_table_3_count

# Expected number of required fields
${EXPECTED_FIELD_COUNT}     6


*** Test Cases ***
# ────────────────────────────────────────────────────────────────
# KEYWORD 1: Validate JSON File Exists And Not Empty
# ────────────────────────────────────────────────────────────────
Demo 01 - Validate JSON File Exists And Not Empty
    [Documentation]    Checks that a JSON file exists on disk and has content (size > 0 bytes).
    [Tags]    ebaas    demo    sample    keyword-01
    Validate JSON File Exists And Not Empty    ${SAMPLE_ACTUAL}

# ────────────────────────────────────────────────────────────────
# KEYWORD 2: Validate JSON Field Value
# ────────────────────────────────────────────────────────────────
Demo 02 - Validate JSON Field Value
    [Documentation]    Extracts a single field from JSON and asserts it equals the expected value.
    ...    Example: Verify pipeline_name is EBAS_to_CBS.
    [Tags]    ebaas    demo    sample    keyword-02
    Validate JSON Field Value    ${ACTUAL_DATA}    pipeline_name    EBAS_to_CBS

# ────────────────────────────────────────────────────────────────
# KEYWORD 3: Validate JSON Fields Match Expected
# ────────────────────────────────────────────────────────────────
Demo 03 - Validate JSON Fields Match Expected
    [Documentation]    Compares multiple fields between actual and expected JSON data.
    ...    Example: Verify pipeline_name, project, approved_by, reviewed_by all match.
    [Tags]    ebaas    demo    sample    keyword-03
    Validate JSON Fields Match Expected    ${ACTUAL_DATA}    ${EXPECTED_DATA}
    ...    pipeline_name    project    approved_by    reviewed_by

# ────────────────────────────────────────────────────────────────
# KEYWORD 4: Validate All Required Fields Present
# ────────────────────────────────────────────────────────────────
Demo 04 - Validate All Required Fields Present
    [Documentation]    Validates that all specified fields exist in JSON and have non-empty values.
    ...    Example: status, pipeline_name, project, jira_ticket, approved_by, reviewed_by.
    [Tags]    ebaas    demo    sample    keyword-04
    Validate All Required Fields Present    ${ACTUAL_DATA}    @{REQUIRED_FIELDS}

# ────────────────────────────────────────────────────────────────
# KEYWORD 5: Validate Field Matches Pattern
# ────────────────────────────────────────────────────────────────
Demo 05 - Validate Field Matches Pattern
    [Documentation]    Extracts a field and validates it against a regex pattern.
    ...    Example: Verify jira_ticket matches EBAS-5042 format (^[A-Z]+-\d+$).
    [Tags]    ebaas    demo    sample    keyword-05
    Validate Field Matches Pattern    ${ACTUAL_DATA}    jira_ticket    ${JIRA_PATTERN}

# ────────────────────────────────────────────────────────────────
# KEYWORD 6: Validate File Exists And Not Empty (.expr file)
# ────────────────────────────────────────────────────────────────
Demo 06 - Validate File Exists And Not Empty
    [Documentation]    Generic file existence check — works for any file type (.json, .expr, .csv, etc.).
    ...    Example: Verify the EBAS_to_CBS_sample.expr expression library file exists.
    [Tags]    ebaas    demo    sample    keyword-06
    Validate File Exists And Not Empty    ${EXPR_FILE_PATH}

# ────────────────────────────────────────────────────────────────
# KEYWORD 7: Validate File Meets Minimum Size (.expr file)
# ────────────────────────────────────────────────────────────────
Demo 07 - Validate File Meets Minimum Size
    [Documentation]    Validates that a file size meets or exceeds a minimum threshold in bytes.
    ...    Example: Verify EBAS_to_CBS_sample.expr is at least 100 bytes (not truncated).
    [Tags]    ebaas    demo    sample    keyword-07
    Validate File Meets Minimum Size    ${EXPR_FILE_PATH}    ${MIN_EXPR_SIZE}

# ────────────────────────────────────────────────────────────────
# KEYWORD 8: Validate Content Contains All Fields (.expr file)
# ────────────────────────────────────────────────────────────────
Demo 08 - Validate Content Contains All Fields
    [Documentation]    Validates that all specified field names are present in raw text content.
    ...    Example: Verify .expr file contains Accounts (DEV/QA/PREPROD/PROD), Schema,
    ...    getOrgName, and all transformation functions (rejectedState, irsFundAmount, etc.).
    [Tags]    ebaas    demo    sample    keyword-08
    Validate Content Contains All Fields    ${EXPR_CONTENT}    @{EXPR_CONTENT_FIELDS}

# ────────────────────────────────────────────────────────────────
# KEYWORD 9: Validate JSON Array Contains All Values
# ────────────────────────────────────────────────────────────────
Demo 09 - Validate JSON Array Contains All Values
    [Documentation]    Validates that a JSON array field contains all expected values.
    ...    Example: Verify output_columns contains all EBAS column names.
    [Tags]    ebaas    demo    sample    keyword-09
    Validate JSON Array Contains All Values    ${ACTUAL_DATA}    output_columns    @{EXPECTED_COLUMNS}

# ────────────────────────────────────────────────────────────────
# KEYWORD 10: Validate Nested JSON Fields Match Expected
# ────────────────────────────────────────────────────────────────
Demo 10 - Validate Nested JSON Fields Match Expected
    [Documentation]    Compares fields inside a nested JSON object between actual and expected data.
    ...    Example: Verify accounts.DEV, accounts.QA, accounts.PREPROD, accounts.PROD match.
    [Tags]    ebaas    demo    sample    keyword-10
    Validate Nested JSON Fields Match Expected    ${ACTUAL_DATA}    ${EXPECTED_DATA}    accounts
    ...    DEV    QA    PREPROD    PROD

# ────────────────────────────────────────────────────────────────
# KEYWORD 11: Validate Nested JSON Fields Present
# ────────────────────────────────────────────────────────────────
Demo 11 - Validate Nested JSON Fields Present
    [Documentation]    Validates that all specified fields exist within a nested JSON object.
    ...    Example: Verify paths has account_path, upload_source_path, output_path.
    [Tags]    ebaas    demo    sample    keyword-11
    Validate Nested JSON Fields Present    ${ACTUAL_DATA}    paths    @{PATH_FIELDS}

# ────────────────────────────────────────────────────────────────
# KEYWORD 12: Validate JSON Field Greater Than
# ────────────────────────────────────────────────────────────────
Demo 12 - Validate JSON Field Greater Than
    [Documentation]    Extracts a numeric field and asserts it is greater than a minimum value.
    ...    Example: Verify record_count > 0 (non-zero records processed).
    [Tags]    ebaas    demo    sample    keyword-12
    Validate JSON Field Greater Than    ${ACTUAL_DATA}    record_count    ${MIN_RECORD_COUNT}

# ────────────────────────────────────────────────────────────────
# KEYWORD 13: Validate JSON Fields Sum Equals Expected
# ────────────────────────────────────────────────────────────────
Demo 13 - Validate JSON Fields Sum Equals Expected
    [Documentation]    Sums multiple numeric fields and asserts the total equals expected value.
    ...    Example: source_table_1 (100) + source_table_2 (200) + source_table_3 (150) = 450.
    [Tags]    ebaas    demo    sample    keyword-13
    Validate JSON Fields Sum Equals Expected    ${ACTUAL_DATA}    ${EXPECTED_SUM_TOTAL}
    ...    source_table_1_count    source_table_2_count    source_table_3_count

# ────────────────────────────────────────────────────────────────
# KEYWORD 14: Validate JSON Field Less Than Or Equal
# ────────────────────────────────────────────────────────────────
Demo 14 - Validate JSON Field Less Than Or Equal
    [Documentation]    Compares a numeric field from actual JSON against a threshold from expected JSON.
    ...    Example: execution_duration (45s) <= max_duration_threshold (120s).
    [Tags]    ebaas    demo    sample    keyword-14
    Validate JSON Field Less Than Or Equal    ${ACTUAL_DATA}    execution_duration_seconds    ${EXPECTED_DATA}    max_duration_threshold

# ────────────────────────────────────────────────────────────────
# KEYWORD 15: Validate JSON Two Fields Are Equal
# ────────────────────────────────────────────────────────────────
Demo 15 - Validate JSON Two Fields Are Equal
    [Documentation]    Asserts that two fields from the same JSON dictionary have equal values.
    ...    Example: source_total (450) = target_total (450) — data integrity check.
    [Tags]    ebaas    demo    sample    keyword-15
    Validate JSON Two Fields Are Equal    ${ACTUAL_DATA}    source_total    target_total

# ────────────────────────────────────────────────────────────────
# BONUS: Inline Field Count Sanity Check
# ────────────────────────────────────────────────────────────────
Demo 16 - Verify Required Fields Count
    [Documentation]    Inline sanity check — confirms the number of required fields matches expected count.
    ...    Uses Get Length (not a reusable keyword, but a common inline pattern).
    [Tags]    ebaas    demo    sample    keyword-16
    ${actual_count}=    Get Length    ${REQUIRED_FIELDS}
    Should Be Equal As Integers    ${actual_count}    ${EXPECTED_FIELD_COUNT}
    ...    Field count mismatch: found ${actual_count} but expected ${EXPECTED_FIELD_COUNT}


*** Keywords ***
Load Sample Demo Data
    [Documentation]    Suite Setup - Loads JSON files, expression file content, and raw text into suite variables.
    Log    Loading sample demo data...    console=yes
    Validate JSON File Exists And Not Empty    ${SAMPLE_ACTUAL}
    Validate JSON File Exists And Not Empty    ${SAMPLE_EXPECTED}
    Validate File Exists And Not Empty    ${EXPR_FILE_PATH}
    ${actual}=    Load Json From File    ${SAMPLE_ACTUAL}
    ${expected}=    Load Json From File    ${SAMPLE_EXPECTED}
    ${expr_content}=    Get File    ${EXPR_FILE_PATH}
    Set Suite Variable    ${ACTUAL_DATA}    ${actual}
    Set Suite Variable    ${EXPECTED_DATA}    ${expected}
    Set Suite Variable    ${EXPR_CONTENT}    ${expr_content}
    Log    Sample demo data loaded successfully    console=yes
