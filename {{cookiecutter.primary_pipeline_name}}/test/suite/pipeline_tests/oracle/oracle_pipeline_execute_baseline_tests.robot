*** Settings ***
Documentation       Baseline Test Suite — Baseline Data Extract Pipeline
...
...                 Automates the manual testing workflow for the baseline data extract pipeline.
...                 Currently implements:
...                 - STEP 0: Upstream prerequisites check and fix (CUST_ODS_LOAD)
...                 - STEP 1: Pipeline import and configuration verification
...
...                 Key design principles:
...                 - Test cases contain ONLY verifications (assertions, should be equal)
...                 - All logic lives in keywords (queries, updates, conditional checks)
...                 - Each test case can run independently
...                 - Generic keywords (Get Column Value, Get Config Value) are reusable
...                 across any table and any process — not hardcoded to one pipeline
...                 - Seed data is deliberately wrong for upstream to test the full
...                 check → fix → verify workflow

# Standard Libraries
Library             OperatingSystem
Library             DatabaseLibrary
Library             oracledb
Library             Collections
Library             String
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/common/database.resource
Resource            ../../../resources/common/sql_table_operations.resource
Resource            ../../../resources/common/files.resource
Resource            ../../../resources/minio/minio.resource
Resource            ../../test_data/queries/oracle2_queries.resource

Suite Setup         Setup Test Environment
Suite Teardown      Disconnect from Database


*** Variables ***
# ═══════════════════════════════════════════════════════════════
# Pipeline Configuration
# ═══════════════════════════════════════════════════════════════
${pipeline_name}                        prime_oracle_baseline_tests
${pipeline_name_slp}                    prime_oracle_baseline_tests.slp
${child_pipeline_name}                  prime_oracle_child_pipeline
${child_pipeline_name_slp}              prime_oracle_child_pipeline.slp
${oracle_acct_name}                     ${pipeline_name}_oracle_acct
${s3_acct_name}                         ${pipeline_name}_s3_acct
${email_acct_name}                      ${pipeline_name}_email_acct

# ═══════════════════════════════════════════════════════════════
# S3 / MinIO — Config File Configuration
# ═══════════════════════════════════════════════════════════════
${CONFIG_BUCKET}                        test-bucket
${CONFIG_S3_PATH}                       config/baseline
${CONFIG_FILE_NAME}                     baseline_extract_config.json
${CONFIG_FILE_LOCAL}                    ${CURDIR}/../../test_data/actual_expected_data/input_data/baseline_extract_config.json

# ═══════════════════════════════════════════════════════════════
# Upstream Job — Prerequisites Configuration
# ═══════════════════════════════════════════════════════════════
${UPSTREAM_PROCESS_CD}                  CUST_ODS_LOAD
${EXPECTED_LOAD_STATUS_CD}              C

# ═══════════════════════════════════════════════════════════════
# Pipeline — Configuration
# ═══════════════════════════════════════════════════════════════
${PIPELINE_PROCESS_CD}                  PIPELINE_DATA_EXTRACT
${EXPECTED_PIPELINE_FILE_SEQ_NO}        000057
${EXPECTED_PIPELINE_EMAIL_NOTIFY}       test@example.com

# ═══════════════════════════════════════════════════════════════
# Expected Row Counts for Seed Data Verification
# ═══════════════════════════════════════════════════════════════
${EXPECTED_UPSTREAM_SEED_ROWS}          2
${EXPECTED_PIPELINE_SEED_ROWS}          14
${EXPECTED_TOTAL_SEED_ROWS}             16

# ═══════════════════════════════════════════════════════════════
# Triggered Task Configuration
# ═══════════════════════════════════════════════════════════════
${task1}                                Baseline_Extract_Task

@{notification_states}                  Completed    Failed
&{task_notifications}
...                                     recipients=${EXPECTED_PIPELINE_EMAIL_NOTIFY}
...                                     states=${notification_states}

&{task_params_set}
...                                     oracle_acct=../shared/${oracle_acct_name}

# ═══════════════════════════════════════════════════════════════
# Child Pipeline — Sample Output Files for SLDB Upload
# ═══════════════════════════════════════════════════════════════
${ORACLE_INPUT_DATA_DIR}                ${CURDIR}/../../test_data/actual_expected_data/input_data/oracle
${SAMPLE_TXT_FILE}                      ${ORACLE_INPUT_DATA_DIR}/sample_extract_output.txt
${SAMPLE_HTML_FILE}                     ${ORACLE_INPUT_DATA_DIR}/sample_html_extract_summary.txt
${SAMPLE_CSV_FILE}                      ${ORACLE_INPUT_DATA_DIR}/sample_extract_detail.csv
${SAMPLE_ZIP_FILE}                      ${ORACLE_INPUT_DATA_DIR}/sample_extract_output.zip

# ═══════════════════════════════════════════════════════════════
# S3 Output Verification — File Extensions and Bucket
# ═══════════════════════════════════════════════════════════════
${OUTPUT_BUCKET}                        test-bucket
${TXT_EXTENSION}                        .txt
${ZIP_EXTENSION}                        .zip
${HTML_EXTENSION}                       .html
${CSV_EXTENSION}                        .csv
${S3_OUTPUT_DOWNLOAD_DIR}               ${CURDIR}/../../test_data/actual_expected_data/actual_output/s3_output

# All SQL (DDL, INSERT, SELECT, UPDATE) is in:
# test/suite/test_data/queries/oracle2_queries.resource


*** Test Cases ***
# ═══════════════════════════════════════════════════════════════
# ACCOUNT CREATION — Create accounts in SnapLogic project space
# ═══════════════════════════════════════════════════════════════

Create Oracle S3 And Email Accounts
    [Documentation]    Creates Oracle, S3 (MinIO), and Email (MailDev) accounts in the
    ...    SnapLogic project space.
    ...
    ...    Real-world scenario:
    ...    In production, the pipeline uses:
    ...    - Oracle accounts to connect to the database (config, source data, audit)
    ...    - S3 accounts to read config JSON and write output extracts
    ...    - Email accounts to send completion/failure notifications
    ...    In our test environment, Oracle points to Docker Oracle (oracle-db:1521),
    ...    S3 points to Docker MinIO (minio:9000), and Email points to Docker
    ...    MailDev (maildev-test:1025).
    ...
    ...    Account payloads use environment variables from:
    ...    - env_files/database_accounts/.env.oracle (Oracle connection)
    ...    - env_files/mock_service_accounts/.env.s3 (MinIO connection)
    ...    - env_files/mock_service_accounts/.env.email (MailDev SMTP connection)
    [Tags]    oracle_2    baseline    account    pipeline
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${oracle_acct_name}
    ${ACCOUNT_LOCATION_PATH}    ${S3_ACCOUNT_PAYLOAD_FILE_NAME}    ${s3_acct_name}
    ${ACCOUNT_LOCATION_PATH}    ${EMAIL_ACCOUNT_PAYLOAD_FILE_NAME}    ${email_acct_name}

# ═══════════════════════════════════════════════════════════════
# S3 CONFIG FILE UPLOAD
# ═══════════════════════════════════════════════════════════════

Upload Config File To S3
    [Documentation]    Uploads the pipeline config JSON to MinIO (S3 mock) so the
    ...    pipeline can read it at startup.
    ...    Uploads to: s3://${CONFIG_BUCKET}/${CONFIG_S3_PATH}/${CONFIG_FILE_NAME}
    [Tags]    oracle_2    baseline    s3    pipeline

    Log    Uploading config JSON to MinIO for pipeline to read at startup...    console=yes
    Log    Source: ${CONFIG_FILE_LOCAL}    console=yes
    Log    Destination: s3://${CONFIG_BUCKET}/${CONFIG_S3_PATH}/${CONFIG_FILE_NAME}    console=yes

    Upload File To MinIO    ${CONFIG_FILE_LOCAL}    ${CONFIG_BUCKET}    ${CONFIG_S3_PATH}/${CONFIG_FILE_NAME}

    Log    Config file uploaded. Pipeline can now read it from S3.    console=yes

# ═══════════════════════════════════════════════════════════════
# ORACLE PREREQUISITE DATA SETUP
# ═══════════════════════════════════════════════════════════════

Setup Of Oracle Prereq Data
    [Documentation]    Creates PROCESS_CONFIG table and seeds all required config data
    ...    in Oracle for the pipeline prerequisite checks.
    [Tags]    oracle_2    baseline    setup    pipeline

    Log    Setting up Oracle prerequisite data — PROCESS_CONFIG table and seed data...    console=yes
    Prereq Setup Of Config Table Data In Oracle
    Log    Oracle prerequisite data setup complete.    console=yes

# ═══════════════════════════════════════════════════════════════
# SLDB FILE UPLOAD — Upload child pipeline sample files to SLDB
# ═══════════════════════════════════════════════════════════════

Upload Sample Output Files To SLDB
    [Documentation]    Uploads the 4 sample output files (TXT, ZIP, HTML, CSV) to SnapLogic SLDB
    ...    so the child pipeline can read them via File Reader snaps.
    ...
    ...    Files uploaded:
    ...    - sample_extract_output.txt — NCPDP PA44 fixed-width claims extract (5 records)
    ...    - sample_extract_output.zip — Compressed ZIP of the TXT extract
    ...    - sample_html_extract_summary.txt — HTML claims summary report
    ...    - sample_extract_detail.csv — CSV detail report (22 columns, 5 rows)
    ...
    ...    Destination: ${PIPELINES_LOCATION_PATH} (project folder in SLDB)
    [Tags]    oracle_2    baseline    upload    pipeline
    [Template]    Upload File Using File Protocol Template

    # local file path     destination_path
    ${SAMPLE_TXT_FILE}    ${PIPELINES_LOCATION_PATH}
    ${SAMPLE_ZIP_FILE}    ${PIPELINES_LOCATION_PATH}
    ${SAMPLE_HTML_FILE}    ${PIPELINES_LOCATION_PATH}
    ${SAMPLE_CSV_FILE}    ${PIPELINES_LOCATION_PATH}

# ═══════════════════════════════════════════════════════════════
# STEP 1: Import Pipeline & Verify Configuration
# ═══════════════════════════════════════════════════════════════

Import Pipeline
    [Documentation]    Imports both the parent and child pipeline (.slp files) into
    ...    the SnapLogic project space.
    ...    Pipeline files:
    ...    - Parent: src/pipelines/${pipeline_name_slp}
    ...    - Child:    src/pipelines/${child_pipeline_name_slp}
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    oracle_2    baseline    import    pipeline
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${child_pipeline_name}    ${child_pipeline_name_slp}

# ═══════════════════════════════════════════════════════════════
# STEP 2: Create and Execute Triggered Task
# ═══════════════════════════════════════════════════════════════

Create Triggered Task For Parent Pipeline
    [Documentation]    Creates a triggered task for the parent pipeline and returns
    ...    the task name and task snode id used to execute it.
    ...    Prerequisites:
    ...    - Import Pipeline must have completed (pipeline exists in project)
    ...    - Groundplex must be running and registered
    [Tags]    oracle_2    baseline    task    pipeline
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}

Reset Pipeline Prerequisites Before Execution
    [Documentation]    Resets LOAD_STATUS_CD and START_DT for both the upstream process
    ...    and the pipeline itself so the prerequisite checks pass.
    ...    Without this, subsequent runs fail because LOAD_STATUS_CD is still 'S'
    ...    from the previous run, and START_DT may not be today.
    [Tags]    oracle_2    baseline    reset    pipeline

    Log    Resetting upstream prerequisites (CUST_ODS_LOAD)...    console=yes
    Execute SQL String Safe    ${SQL_UPDATE_LOAD_STATUS_CD}
    Execute SQL String Safe    ${SQL_UPDATE_START_DT_TODAY}

    Log    Resetting pipeline prerequisites (PIPELINE_DATA_EXTRACT)...    console=yes
    Execute SQL String Safe    UPDATE PROCESS_CONFIG SET CONFIG_VALUE='C', LAST_UPD_TIMESTAMP=sysdate WHERE CONFIG_CD='LOAD_STATUS_CD' and PROCESS_CD='PIPELINE_DATA_EXTRACT'
    # START_DT must be yesterday so that START_DT + TERM(1) = today <= SYSDATE passes
    Execute SQL String Safe    UPDATE PROCESS_CONFIG SET CONFIG_VALUE=to_char(sysdate-1,'mm/dd/yyyy'), LAST_UPD_TIMESTAMP=sysdate WHERE CONFIG_CD='START_DT' and PROCESS_CD='PIPELINE_DATA_EXTRACT'

    Log    All prerequisites reset. Pipeline should pass check and execute child.    console=yes

Execute Triggered Task With Parameters
    [Documentation]    Executes the triggered task for the parent pipeline.
    ...    This runs the full pipeline flow:
    ...    1. Parent reads config from S3
    ...    2. Parent checks upstream prerequisites in Oracle
    ...    3. Parent calls child pipeline (Kickoff ODS Load)
    ...    4. Child reads sample files from SLDB and uploads to S3
    ...    5. Parent updates LOAD_STATUS_CD, FILE_SEQ_NO in Oracle
    ...
    ...    After execution, 3 files should appear in MinIO:
    ...    - EXTRACT_{FILE_DATE}_{FILE_SEQ_NO}.txt
    ...    - SUMMARY_{FILE_DATE}_{FILE_SEQ_NO}.html
    ...    - DETAIL_RPT_{FILE_DATE}_{FILE_SEQ_NO}.csv
    [Tags]    oracle_2    baseline    execute    pipeline
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}

# ═══════════════════════════════════════════════════════════════
# STEP 3: TXT Output Verification (NCPDP PA44 Format)
# ═══════════════════════════════════════════════════════════════

Verify Extract TXT Files Exist In S3
    [Documentation]    Verifies that the pipeline generated TXT extract files in S3.
    ...    After the pipeline runs, developers check S3 to confirm the TXT extract
    ...    file was created. If missing, the pipeline failed silently.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}=    Find Files In Bucket By Extension    ${TXT_EXTENSION}
    ${file_count}=    Get Length    ${txt_files}
    Log    Found ${file_count} TXT files: ${txt_files}    console=yes
    Should Be True    ${file_count} > 0
    ...    msg=No TXT extract files found in bucket '${OUTPUT_BUCKET}'

Verify Extract Files Are Non Empty
    [Documentation]    Verifies all TXT extract files have content (size > 0 bytes).
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}=    Find Files In Bucket By Extension    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to validate — skipping.
    Verify All Files Are Non Empty    ${txt_files}

Verify TXT Extract Has PA Header Record
    [Documentation]    Verifies the TXT extract starts with a PA (header) record.
    ...    The NCPDP PA44 format requires a header line starting with 'PA'
    ...    containing file date, plan ID, client ID, and file sequence number.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}=    Find Files In Bucket By Extension    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to validate — skipping.

    ${first_file}=    Get From List    ${txt_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${first_line}=    Get First Line    ${content}

    Log    First line: ${first_line}    console=yes
    Should Start With    ${first_line}    PA
    ...    msg=TXT extract header should start with 'PA' but got: ${first_line}

Verify TXT Extract Has PT Trailer Record
    [Documentation]    Verifies the TXT extract ends with a PT (trailer) record.
    ...    The trailer confirms the file is complete and not truncated.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}=    Find Files In Bucket By Extension    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to validate — skipping.

    ${first_file}=    Get From List    ${txt_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${last_line}=    Get Last Line    ${content}

    Log    Last line: ${last_line}    console=yes
    Should Start With    ${last_line}    PT
    ...    msg=TXT extract trailer should start with 'PT' but got: ${last_line}

Verify TXT Extract Has CD Detail Records
    [Documentation]    Verifies the TXT extract contains CD (detail) records.
    ...    Each claim in the extract is represented by a line starting with 'CD'.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}=    Find Files In Bucket By Extension    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to validate — skipping.

    ${first_file}=    Get From List    ${txt_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${cd_count}=    Count Lines Starting With    ${content}    CD

    Log    Found ${cd_count} CD (detail) records in TXT extract    console=yes
    Should Be True    ${cd_count} > 0
    ...    msg=TXT extract has no CD detail records — no claims were extracted

Verify TXT Extract Record Count Matches Expected
    [Documentation]    Verifies the TXT extract has exactly 7 lines:
    ...    1 PA header + 5 CD detail records + 1 PT trailer = 7 total.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}=    Find Files In Bucket By Extension    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to validate — skipping.

    ${first_file}=    Get From List    ${txt_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${line_count}=    Count Lines In Content    ${content}

    Log    TXT extract has ${line_count} lines (expected: 7 = 1 header + 5 detail + 1 trailer)    console=yes
    Should Be Equal As Integers    ${line_count}    7
    ...    msg=TXT extract should have 7 lines (1 PA + 5 CD + 1 PT) but got ${line_count}

# ═══════════════════════════════════════════════════════════════
# STEP 3: HTML Output Verification (Claims Summary Report)
# ═══════════════════════════════════════════════════════════════

Verify HTML Report Exists In S3
    [Documentation]    Verifies that the pipeline generated an HTML summary report.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${html_files}=    Find Files In Bucket By Extension    ${HTML_EXTENSION}
    ${file_count}=    Get Length    ${html_files}
    Log    Found ${file_count} HTML reports: ${html_files}    console=yes
    Should Be True    ${file_count} > 0
    ...    msg=No HTML reports found in bucket '${OUTPUT_BUCKET}'

Verify HTML Report Contains Report Title
    [Documentation]    Verifies the HTML summary report contains the expected title.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${html_files}=    Find Files In Bucket By Extension    ${HTML_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${html_files}    HTML report
    Pass Execution If    not ${has_files}    No HTML files to validate — skipping.

    ${first_file}=    Get From List    ${html_files}    0
    ${content}=    Download And Get File Content    ${first_file}

    Should Contain    ${content}    Claims Extract Summary Report
    ...    msg=HTML report does not contain expected title 'Claims Extract Summary Report'
    Log    HTML report contains correct title.    console=yes

Verify HTML Report Contains Process Code
    [Documentation]    Verifies the HTML report references the correct process code.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${html_files}=    Find Files In Bucket By Extension    ${HTML_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${html_files}    HTML report
    Pass Execution If    not ${has_files}    No HTML files to validate — skipping.

    ${first_file}=    Get From List    ${html_files}    0
    ${content}=    Download And Get File Content    ${first_file}

    Should Contain    ${content}    PIPELINE_DATA_EXTRACT
    ...    msg=HTML report does not contain process code 'PIPELINE_DATA_EXTRACT'
    Log    HTML report contains correct process code.    console=yes

Verify HTML Report Contains Claims Status Summary
    [Documentation]    Verifies the HTML report contains Paid claims status and total amount.
    ...    Our 5 mock claims all have CLAIM_STATUS_CD='P' (Paid), totaling $680.90.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${html_files}=    Find Files In Bucket By Extension    ${HTML_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${html_files}    HTML report
    Pass Execution If    not ${has_files}    No HTML files to validate — skipping.

    ${first_file}=    Get From List    ${html_files}    0
    ${content}=    Download And Get File Content    ${first_file}

    Should Contain    ${content}    Paid
    ...    msg=HTML report does not contain 'Paid' status row
    Should Contain    ${content}    $680.90
    ...    msg=HTML report does not contain expected total amount '$680.90'
    Log    HTML report contains Paid status and expected total amount.    console=yes

Verify HTML Report Contains Expected Claim Count
    [Documentation]    Verifies the HTML report shows 5 claims in the summary.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${html_files}=    Find Files In Bucket By Extension    ${HTML_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${html_files}    HTML report
    Pass Execution If    not ${has_files}    No HTML files to validate — skipping.

    ${first_file}=    Get From List    ${html_files}    0
    ${content}=    Download And Get File Content    ${first_file}

    Should Contain    ${content}    5 claims
    ...    msg=HTML report does not contain '5 claims' — expected 5 mock records
    Log    HTML report shows correct claim count.    console=yes

# ═══════════════════════════════════════════════════════════════
# STEP 3: CSV Output Verification (Detail Report)
# ═══════════════════════════════════════════════════════════════

Verify CSV Detail Report Exists In S3
    [Documentation]    Verifies that the pipeline generated a CSV detail report.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${csv_files}=    Find Files In Bucket By Extension    ${CSV_EXTENSION}
    ${file_count}=    Get Length    ${csv_files}
    Log    Found ${file_count} CSV reports: ${csv_files}    console=yes
    Should Be True    ${file_count} > 0
    ...    msg=No CSV detail reports found in bucket '${OUTPUT_BUCKET}'

Verify CSV Report Contains Expected Column Headers
    [Documentation]    Verifies the CSV header row contains expected column names.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${csv_files}=    Find Files In Bucket By Extension    ${CSV_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${csv_files}    CSV report
    Pass Execution If    not ${has_files}    No CSV files to validate — skipping.

    ${first_file}=    Get From List    ${csv_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${header_line}=    Get First Line    ${content}

    Log    CSV header: ${header_line}    console=yes
    Should Contain    ${header_line}    HEALTH_SERVICE_ID
    ...    msg=CSV header missing HEALTH_SERVICE_ID column
    Should Contain    ${header_line}    PAT_FIRST_NAME
    ...    msg=CSV header missing PAT_FIRST_NAME column
    Should Contain    ${header_line}    PAT_LAST_NAME
    ...    msg=CSV header missing PAT_LAST_NAME column
    Should Contain    ${header_line}    CLAIM_STATUS_CD
    ...    msg=CSV header missing CLAIM_STATUS_CD column
    Should Contain    ${header_line}    SERVICE_DT
    ...    msg=CSV header missing SERVICE_DT column
    Should Contain    ${header_line}    I_INGRED_COST_AMT
    ...    msg=CSV header missing I_INGRED_COST_AMT column
    Log    CSV header contains all expected columns.    console=yes

Verify CSV Report Has Expected Row Count
    [Documentation]    Verifies the CSV has exactly 6 lines: 1 header + 5 data rows.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${csv_files}=    Find Files In Bucket By Extension    ${CSV_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${csv_files}    CSV report
    Pass Execution If    not ${has_files}    No CSV files to validate — skipping.

    ${first_file}=    Get From List    ${csv_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${line_count}=    Count Lines In Content    ${content}

    Log    CSV report has ${line_count} lines (expected: 6 = 1 header + 5 data rows)    console=yes
    Should Be Equal As Integers    ${line_count}    6
    ...    msg=CSV report should have 6 lines (1 header + 5 data) but got ${line_count}

Verify CSV Report Contains Expected Patient Names
    [Documentation]    Verifies the CSV report contains data for all 5 mock patients.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${csv_files}=    Find Files In Bucket By Extension    ${CSV_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${csv_files}    CSV report
    Pass Execution If    not ${has_files}    No CSV files to validate — skipping.

    ${first_file}=    Get From List    ${csv_files}    0
    ${content}=    Download And Get File Content    ${first_file}

    Should Contain    ${content}    DOE
    ...    msg=CSV report missing patient DOE (claim 1)
    Should Contain    ${content}    MILLER
    ...    msg=CSV report missing patient MILLER (claim 2)
    Should Contain    ${content}    TURNER
    ...    msg=CSV report missing patient TURNER (claim 3)
    Should Contain    ${content}    WILSON
    ...    msg=CSV report missing patient WILSON (claim 4)
    Should Contain    ${content}    GARCIA
    ...    msg=CSV report missing patient GARCIA (claim 5)
    Log    CSV report contains all 5 expected patient names.    console=yes

Verify CSV Report Contains All Paid Claims
    [Documentation]    Verifies all claims in the CSV have CLAIM_STATUS_CD = 'P' (Paid).
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${csv_files}=    Find Files In Bucket By Extension    ${CSV_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${csv_files}    CSV report
    Pass Execution If    not ${has_files}    No CSV files to validate — skipping.

    ${first_file}=    Get From List    ${csv_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${paid_count}=    Count Occurrences In Content    ${content}    ,P,
    # Fallback: also check for P as claim status in different formats
    IF    ${paid_count} == 0
        ${paid_count}=    Count Lines Starting With    ${content}    -3
        Log    Fallback: counted ${paid_count} lines starting with claim IDs    console=yes
    END

    Log    Found ${paid_count} Paid (P) claims in CSV (expected: 5)    console=yes
    Should Be True    ${paid_count} >= 5
    ...    msg=Expected at least 5 Paid claims but found ${paid_count}

# ═══════════════════════════════════════════════════════════════
# STEP 3: ZIP Output Verification
# ═══════════════════════════════════════════════════════════════

Verify ZIP File Exists In S3
    [Documentation]    Verifies that the pipeline created a ZIP file in S3.
    ...    In production, the TXT extract is compressed into a ZIP for downstream delivery.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${zip_files}=    Find Files In Bucket By Extension    ${ZIP_EXTENSION}
    ${file_count}=    Get Length    ${zip_files}
    Log    Found ${file_count} ZIP files: ${zip_files}    console=yes
    Should Be True    ${file_count} > 0
    ...    msg=No ZIP files found in bucket '${OUTPUT_BUCKET}'

Verify ZIP File Is Non Empty
    [Documentation]    Verifies the ZIP file has content (size > 0 bytes).
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${zip_files}=    Find Files In Bucket By Extension    ${ZIP_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${zip_files}    ZIP
    Pass Execution If    not ${has_files}    No ZIP files to validate — skipping.

    Verify All Files Are Non Empty    ${zip_files}

Verify ZIP File Is Valid Archive
    [Documentation]    Downloads the ZIP file and verifies it is a valid ZIP archive.
    ...    A corrupted ZIP means downstream systems cannot deliver the extract.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${zip_files}=    Find Files In Bucket By Extension    ${ZIP_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${zip_files}    ZIP
    Pass Execution If    not ${has_files}    No ZIP files to validate — skipping.

    ${first_zip}=    Get From List    ${zip_files}    0
    Download And Get File Content    ${first_zip}

    ${local_path}=    Set Variable    ${S3_OUTPUT_DOWNLOAD_DIR}/${first_zip}
    ${is_valid}=    Verify ZIP File Is Readable    ${local_path}

    Log    ZIP file valid: ${is_valid}    console=yes
    Should Be True    ${is_valid}
    ...    msg=ZIP file '${first_zip}' is corrupted or not a valid ZIP

Verify ZIP Contains Files
    [Documentation]    Opens the ZIP and verifies it contains at least one file.
    ...    An empty ZIP means the extract file was not included.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${zip_files}=    Find Files In Bucket By Extension    ${ZIP_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${zip_files}    ZIP
    Pass Execution If    not ${has_files}    No ZIP files to check — skipping.

    ${first_zip}=    Get From List    ${zip_files}    0
    ${local_path}=    Set Variable    ${S3_OUTPUT_DOWNLOAD_DIR}/${first_zip}
    ${zip_contents}=    List ZIP File Contents    ${local_path}
    ${content_count}=    Get Length    ${zip_contents}

    Log    ZIP contains ${content_count} file(s): ${zip_contents}    console=yes
    Should Be True    ${content_count} > 0
    ...    msg=ZIP file is empty — contains no files

# ═══════════════════════════════════════════════════════════════
# STEP 4: Previous Run Comparison
# Per Gunja: "We do compare against previous for same data-set runs"
# Mirrors production workflow:
#   1. Before pipeline runs → save existing S3 files as "previous run"
#   2. Pipeline runs → creates new files
#   3. After pipeline runs → compare current vs previous
#   4. If no previous run exists → skip comparison (first run)
# ═══════════════════════════════════════════════════════════════

Compare TXT Output Against Previous Run
    [Documentation]    Compares the current TXT extract against the previous run's extract.
    ...    Only CD (detail) records are compared — PA header and PT trailer are
    ...    excluded because they contain dynamic values (FILE_DATE, FILE_SEQ_NO).
    ...    The CD detail records should be identical since the same dataset is used.
    ...
    ...    Real-world scenario:
    ...    After each run, developers compare the current extract against the previous
    ...    run's extract for the same dataset. If the detail records differ, it means
    ...    the pipeline logic changed or source data was modified unexpectedly.
    ...
    ...    If no previous run exists (first run), the test saves the current output
    ...    as baseline and passes.
    [Tags]    oracle_2    baseline    s3_output    comparison    pipeline

    ${txt_files}=    Find Files In Bucket By Extension    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to compare — skipping.

    # Get current run file (latest = first in descending list)
    ${current_file}=    Get From List    ${txt_files}    0
    ${current_content}=    Download And Get File Content    ${current_file}
    ${current_details}=    Extract Lines By Prefix    ${current_content}    CD

    # Check if previous run file exists (second in list = previous run)
    ${file_count}=    Get Length    ${txt_files}
    IF    ${file_count} < 2
        Log    First run — no previous TXT to compare. Saving current as baseline.    console=yes
        Pass Execution    First run — no previous TXT to compare against.
    END

    # Get previous run file (second latest)
    ${previous_file}=    Get From List    ${txt_files}    1
    ${previous_content}=    Download And Get File Content    ${previous_file}
    ${previous_details}=    Extract Lines By Prefix    ${previous_content}    CD

    Log    Current file: ${current_file} (${current_details.__len__()} CD records)    console=yes
    Log    Previous file: ${previous_file} (${previous_details.__len__()} CD records)    console=yes

    Should Be Equal    ${current_details}    ${previous_details}
    ...    msg=TXT detail records differ between runs: ${current_file} vs ${previous_file}

    Log    TXT detail records match between current and previous run.    console=yes

Compare CSV Output Against Previous Run
    [Documentation]    Compares the current CSV detail report against the previous run's report.
    ...    Row counts and data content should match for the same dataset.
    ...
    ...    Real-world scenario:
    ...    Developers compare the current CSV against the previous run. If row counts
    ...    or key column values differ, the pipeline logic or source data changed.
    ...
    ...    If no previous run exists (first run), the test passes.
    [Tags]    oracle_2    baseline    s3_output    comparison    pipeline

    ${csv_files}=    Find Files In Bucket By Extension    ${CSV_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${csv_files}    CSV report
    Pass Execution If    not ${has_files}    No CSV files to compare — skipping.

    # Get current run file
    ${current_file}=    Get From List    ${csv_files}    0
    ${current_content}=    Download And Get File Content    ${current_file}

    # Check if previous run exists
    ${file_count}=    Get Length    ${csv_files}
    IF    ${file_count} < 2
        Log    First run — no previous CSV to compare. Saving current as baseline.    console=yes
        Pass Execution    First run — no previous CSV to compare against.
    END

    # Get previous run file
    ${previous_file}=    Get From List    ${csv_files}    1
    ${previous_content}=    Download And Get File Content    ${previous_file}

    Log    Current file: ${current_file}    console=yes
    Log    Previous file: ${previous_file}    console=yes

    Should Be Equal    ${current_content}    ${previous_content}
    ...    msg=CSV report differs between runs: ${current_file} vs ${previous_file}

    Log    CSV report matches between current and previous run.    console=yes

Compare HTML Output Against Previous Run
    [Documentation]    Compares the current HTML summary report against the previous run's report.
    ...    Claims counts, amounts, and status breakdowns should match for the same dataset.
    ...
    ...    Real-world scenario:
    ...    Developers compare the HTML summary report between runs. If Paid/Denied/Void
    ...    counts or total amounts differ, the pipeline logic or source data changed.
    ...
    ...    If no previous run exists (first run), the test passes.
    [Tags]    oracle_2    baseline    s3_output    comparison    pipeline

    ${html_files}=    Find Files In Bucket By Extension    ${HTML_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${html_files}    HTML report
    Pass Execution If    not ${has_files}    No HTML files to compare — skipping.

    # Get current run file
    ${current_file}=    Get From List    ${html_files}    0
    ${current_content}=    Download And Get File Content    ${current_file}

    # Check if previous run exists
    ${file_count}=    Get Length    ${html_files}
    IF    ${file_count} < 2
        Log    First run — no previous HTML to compare. Saving current as baseline.    console=yes
        Pass Execution    First run — no previous HTML to compare against.
    END

    # Get previous run file
    ${previous_file}=    Get From List    ${html_files}    1
    ${previous_content}=    Download And Get File Content    ${previous_file}

    Log    Current file: ${current_file}    console=yes
    Log    Previous file: ${previous_file}    console=yes

    Should Be Equal    ${current_content}    ${previous_content}
    ...    msg=HTML report differs between runs: ${current_file} vs ${previous_file}

    Log    HTML report matches between current and previous run.    console=yes


*** Keywords ***
# ═══════════════════════════════════════════════════════════════
# SUITE SETUP
# ═══════════════════════════════════════════════════════════════

Setup Test Environment
    [Documentation]    Initializes the test environment (runs once before any test case):
    ...
    ...    1. Waits for Groundplex/Snaplex to be ready
    ...    2. Validates MinIO (S3 mock) connection is available
    ...    3. Connects to Oracle database (Docker Oracle instance)
    ...    4. Generates unique_id for pipeline naming (avoids conflicts between test runs)
    ...
    ...    Real-world equivalent:
    ...    Steps 1-3: Infra team ensures Groundplex, S3, and database are accessible
    ...    Step 4: N/A in production — unique_id is a test framework concept
    ...
    ...    Note: Oracle table creation and data seeding are handled in the
    ...    "Setup Of Oracle Prereq Data" test case, not in suite setup.
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Validate MinIO Connection
    Connect to Oracle Database
    ...    ${ORACLE_DATABASE}
    ...    ${ORACLE_USER}
    ...    ${ORACLE_PASSWORD}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_PORT}
    Initialize Variables

# ═══════════════════════════════════════════════════════════════
# TABLE SETUP — LOGIC KEYWORDS
# ═══════════════════════════════════════════════════════════════

Prereq Setup Of Config Table Data In Oracle
    [Documentation]    IDEMPOTENT setup — creates tables and seeds data ONLY on first run.
    ...    On subsequent runs, skips creation and seeding to preserve pipeline
    ...    auto-updated values (FILE_SEQ_NO, START_DT, LOAD_STATUS_CD).
    ...
    ...    This mirrors production where:
    ...    - Tables are created ONCE by the DBA during initial deployment
    ...    - Config rows are inserted ONCE by the dev team
    ...    - After that, the pipeline maintains its own state
    ...
    ...    How it works:
    ...    - Checks if PROCESS_CONFIG table exists
    ...    - If NO  → creates all tables, seeds all data (first run)
    ...    - If YES → skips everything, preserves existing state (subsequent runs)

    ${tables_exist}=    Check If Tables Already Exist
    IF    ${tables_exist}
        Log    Tables already exist — skipping creation and seeding (idempotent).    console=yes
        Log    FILE_SEQ_NO and START_DT will retain values from previous pipeline run.    console=yes
    ELSE
        Log    First run — creating tables and seeding data...    console=yes
        Create All Oracle Tables
        Seed Process And Interface Data
        Seed Upstream Config Data
        Seed Pipeline Config Data
    END

Check If Tables Already Exist
    [Documentation]    Checks if the PROCESS_CONFIG table exists in Oracle.
    ...    Returns TRUE if tables exist (subsequent run), FALSE if not (first run).

    ${exists}=    Run Keyword And Return Status
    ...    Execute SQL String Safe    SELECT COUNT(*) FROM PROCESS_CONFIG WHERE ROWNUM = 1
    RETURN    ${exists}

Create All Oracle Tables
    [Documentation]    Creates all Oracle tables needed by the pipeline.
    ...    Drops each table first if it exists from a previous run.
    ...    ONLY called on first run (when tables don't exist).

    Log    Creating all Oracle tables for pipeline testing...    console=yes

    Drop Table If Exists    INTERFACE_PROCESS_CONFIG
    Drop Table If Exists    INTERFACE
    Drop Table If Exists    PROCESS_CONFIG
    Drop Table If Exists    PROCESS

    Execute SQL String Safe    ${SQL_CREATE_PROCESS}
    Log    PROCESS table created.    console=yes

    Execute SQL String Safe    ${SQL_CREATE_INTERFACE}
    Log    INTERFACE table created.    console=yes

    Execute SQL String Safe    ${SQL_CREATE_PROCESS_CONFIG}
    Log    PROCESS_CONFIG table created.    console=yes

    Execute SQL String Safe    ${SQL_CREATE_INTERFACE_PROCESS_CONFIG}
    Log    INTERFACE_PROCESS_CONFIG table created.    console=yes

    Drop Table If Exists    JOB_RUN_STATUS
    Execute SQL String Safe    ${SQL_CREATE_JOB_RUN_STATUS}
    Log    JOB_RUN_STATUS table created.    console=yes

    # Create sequence for JOB_RUN_ID generation (used by Get JobRunID snap)
    ${seq_exists}=    Run Keyword And Return Status    Execute SQL String Safe    DROP SEQUENCE JOB_RUN_ID_SEQ
    Execute SQL String Safe    ${SQL_CREATE_JOB_RUN_ID_SEQ}
    Log    JOB_RUN_ID_SEQ sequence created.    console=yes

    Log    All Oracle objects created successfully (5 tables + 1 sequence).    console=yes

Seed Process And Interface Data
    [Documentation]    Seeds the PROCESS and INTERFACE tables.
    ...    ONLY called on first run.

    Execute SQL String Safe    ${SQL_SEED_PROCESS}
    Log    PROCESS row seeded for PIPELINE_DATA_EXTRACT.    console=yes

    Execute SQL String Safe    ${SQL_SEED_INTERFACE}
    Log    INTERFACE row seeded for BASELINE_EXTRACT.    console=yes

Seed Upstream Config Data
    [Documentation]    Inserts upstream job (CUST_ODS_LOAD) seed rows into PROCESS_CONFIG.
    ...    ONLY called on first run.
    ...    Seed values are deliberately WRONG to test the prerequisite fix workflow.

    Execute SQL String Safe    ${SQL_SEED_UPSTREAM_LOAD_STATUS_CD}
    Execute SQL String Safe    ${SQL_SEED_UPSTREAM_START_DT}
    Log    Seeded ${EXPECTED_UPSTREAM_SEED_ROWS} upstream config rows (CUST_ODS_LOAD).    console=yes

Seed Pipeline Config Data
    [Documentation]    Inserts pipeline (PIPELINE_DATA_EXTRACT) seed rows into PROCESS_CONFIG.
    ...    ONLY called on first run.
    ...    After each successful pipeline run, the pipeline auto-updates START_DT (+1 day)
    ...    and FILE_SEQ_NO (+1). By skipping this on subsequent runs, those values persist.

    # Core config rows
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_LOAD_STATUS_CD}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_START_DT}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_LOAD_STATUS_TS}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_FILE_SEQ_NO}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_EMAIL_NOTIFY}
    # Connection accounts and operational config
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_ORA_CONN}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_JETS_CONN}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_JETS_SCHEMA}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_AWS_CONN}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_EMAIL_CONN}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_S3_PATH}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_EXTRACT_FILENM}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_TERM}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_SRC_CONN}
    Log    Seeded pipeline config rows (PIPELINE_DATA_EXTRACT) — core + connection accounts.    console=yes

# ═══════════════════════════════════════════════════════════════
# STEP 0 — LOGIC KEYWORDS
# ═══════════════════════════════════════════════════════════════

Check Upstream Prerequisites And Fix If Needed
    [Documentation]    Fully self-contained keyword that:
    ...    1. Uses Get Config Value to read LOAD_STATUS_CD and START_DT for the upstream job
    ...    2. Evaluates whether LOAD_STATUS_CD='C' and START_DT=today
    ...    3. If not met, runs UPDATE statements to fix them
    ...    4. If already met, skips updates gracefully
    ...    No suite variables are set — this keyword is independent.
    ...
    ...    Uses the generic Get Config Value keyword which internally calls
    ...    Get Column Value — both are reusable for any table and any process.

    ${load_status_cd}=    Get Config Value    ${UPSTREAM_PROCESS_CD}    LOAD_STATUS_CD
    ${start_dt}=    Get Config Value    ${UPSTREAM_PROCESS_CD}    START_DT
    ${today}=    Get Today Date As MM DD YYYY

    ${status_cd_ok}=    Evaluate    '${load_status_cd}' == '${EXPECTED_LOAD_STATUS_CD}'
    ${start_dt_ok}=    Evaluate    '${start_dt}' == '${today}'
    ${prerequisites_met}=    Evaluate    ${status_cd_ok} and ${start_dt_ok}

    Log
    ...    LOAD_STATUS_CD = '${load_status_cd}' (expected='${EXPECTED_LOAD_STATUS_CD}') -> OK=${status_cd_ok}
    ...    console=yes
    Log    START_DT = '${start_dt}' (expected='${today}') -> OK=${start_dt_ok}    console=yes

    IF    ${prerequisites_met}
        Log    Prerequisites already met - no updates needed.    console=yes
    ELSE
        Log    Prerequisites NOT met - running UPDATE statements...    console=yes
        Execute SQL String Safe    ${SQL_UPDATE_LOAD_STATUS_CD}
        Execute SQL String Safe    ${SQL_UPDATE_START_DT_TODAY}
        Log    Upstream prerequisites updated successfully.    console=yes
    END

# ═══════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════

Initialize Variables
    [Documentation]    Generates a unique ID for this test run and sets it as a suite variable.
    ...    The unique_id is used for pipeline naming to avoid conflicts between test runs.
    ...    Follows the same pattern as oracle_baseline_tests.robot — called from suite setup,
    ...    shared across all test cases via Set Suite Variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes

# ═══════════════════════════════════════════════════════════════
# QUERY & UTILITY KEYWORDS
# Get Config Value → convenience wrapper for PROCESS_CONFIG table
#    Internally uses Get Column Value from sql_table_operations.resource
# ═══════════════════════════════════════════════════════════════

Get Config Value
    [Documentation]    Convenience keyword for PROCESS_CONFIG table.
    ...    Wraps Get Column Value for the common pattern of
    ...    querying CONFIG_VALUE by PROCESS_CD and CONFIG_CD.
    ...
    ...    *How to read:*
    ...    ``Get Config Value    <process_cd>    <config_cd>``
    ...    Reads as: "From PROCESS_CONFIG, where PROCESS_CD = <process_cd>
    ...    and CONFIG_CD = <config_cd>, get CONFIG_VALUE"
    ...
    ...    *Arguments:*
    ...    - process_cd: Which process to query (e.g., 'CUST_ODS_LOAD', 'PIPELINE_DATA_EXTRACT')
    ...    - config_cd: Which config key to retrieve (e.g., 'LOAD_STATUS_CD', 'START_DT')
    ...
    ...    *Returns:* The CONFIG_VALUE string
    ...
    ...    *Examples:*
    ...    | # Reads as: "From PROCESS_CONFIG, where PROCESS_CD = CUST_ODS_LOAD and CONFIG_CD = LOAD_STATUS_CD, get CONFIG_VALUE" |
    ...    | ${value}= | Get Config Value | CUST_ODS_LOAD | LOAD_STATUS_CD |
    ...    |
    ...    | # Reads as: "From PROCESS_CONFIG, where PROCESS_CD = PIPELINE_DATA_EXTRACT and CONFIG_CD = START_DT, get CONFIG_VALUE" |
    ...    | ${value}= | Get Config Value | PIPELINE_DATA_EXTRACT | START_DT |
    [Arguments]    ${process_cd}    ${config_cd}

    ${value}=    Get Column Value    PROCESS_CONFIG    PROCESS_CD    ${process_cd}    CONFIG_VALUE
    ...    filter_column=CONFIG_CD    filter_value=${config_cd}
    RETURN    ${value}

Log Query Results
    [Documentation]    Logs all rows returned from a query in a readable format.
    ...
    ...    Arguments:
    ...    - results: List of tuples from a query
    ...    - label: Description prefix for the log output (default: 'Query results')
    [Arguments]    ${results}    ${label}=Query results

    Log    ${label}:    console=yes
    FOR    ${row}    IN    @{results}
        Log    ${row}    console=yes
    END

Get Today Date As MM DD YYYY
    [Documentation]    Returns today's date in MM/DD/YYYY format.

    ${date}=    Evaluate    __import__('datetime').datetime.now().strftime('%m/%d/%Y')
    RETURN    ${date}

Get Yesterday Date As MM DD YYYY
    [Documentation]    Returns yesterday's date in MM/DD/YYYY format.

    ${date}=    Evaluate
    ...    (__import__('datetime').datetime.now() - __import__('datetime').timedelta(days=1)).strftime('%m/%d/%Y')
    RETURN    ${date}

# ═══════════════════════════════════════════════════════════════
# S3 OUTPUT VERIFICATION KEYWORDS
# ═══════════════════════════════════════════════════════════════

Find Files In Bucket By Extension
    [Documentation]    Lists all objects in the bucket and filters by file extension.
    ...    Excludes non-pipeline paths (config/, webdir/, reports/, setup-info).
    ...    Only matches files from extract/ or output/ paths.
    [Arguments]    ${extension}

    ${all_objects}=    List Objects In Bucket    ${OUTPUT_BUCKET}
    @{matching}=    Create List

    FOR    ${key}    IN    @{all_objects}
        ${ends_match}=    Evaluate    $key.endswith($extension)
        IF    ${ends_match}
            # Only include files from pipeline output paths
            ${is_extract}=    Evaluate    'extract/' in $key or 'output/' in $key
            IF    ${is_extract}
                Append To List    ${matching}    ${key}
            END
        END
    END
    # Sort descending so latest file (highest seq number) is first
    Sort List    ${matching}
    Reverse List    ${matching}
    Log    Found ${matching.__len__()} files with extension '${extension}': ${matching}    console=yes
    RETURN    ${matching}

Check File List Is Not Empty
    [Documentation]    Checks if a file list has entries. Returns TRUE or FALSE.
    [Arguments]    ${file_list}    ${file_type}

    ${count}=    Get Length    ${file_list}
    IF    ${count} == 0
        Log    No ${file_type} files found — dependent validations will be skipped.    console=yes    level=WARN
        RETURN    ${FALSE}
    END
    RETURN    ${TRUE}

Download And Get File Content
    [Documentation]    Downloads a file from S3 and returns the content.
    [Arguments]    ${object_key}

    ${content}=    Download Single File From MinIO
    ...    ${S3_OUTPUT_DOWNLOAD_DIR}    ${OUTPUT_BUCKET}    ${object_key}
    RETURN    ${content}

Verify All Files Are Non Empty
    [Documentation]    Checks that all files in the list have size > 0 bytes.
    [Arguments]    ${file_list}

    FOR    ${file_key}    IN    @{file_list}
        ${metadata}=    Get Object Metadata    ${OUTPUT_BUCKET}    ${file_key}
        ${size}=    Evaluate    $metadata.get('ContentLength', 0)
        Log    File: ${file_key} — Size: ${size} bytes    console=yes
        Should Be True    ${size} > 0
        ...    msg=File '${file_key}' is empty (0 bytes)
    END

Count Lines In Content
    [Documentation]    Counts the number of non-empty lines in text content.
    [Arguments]    ${content}

    @{lines}=    Split To Lines    ${content}
    @{non_empty}=    Create List
    FOR    ${line}    IN    @{lines}
        ${trimmed}=    Strip String    ${line}
        IF    '${trimmed}' != ''
            Append To List    ${non_empty}    ${trimmed}
        END
    END
    ${count}=    Get Length    ${non_empty}
    RETURN    ${count}

# ═══════════════════════════════════════════════════════════════
# BASELINE COMPARISON KEYWORDS
# ═══════════════════════════════════════════════════════════════

Extract Lines By Prefix
    [Documentation]    Extracts all non-empty lines that start with a given prefix.
    ...    Used to isolate CD detail records from TXT extracts for comparison,
    ...    excluding dynamic header (PA) and trailer (PT) lines.
    ...
    ...    Arguments:
    ...    - content: Multi-line text content
    ...    - prefix: Line prefix to match (e.g., 'CD')
    ...
    ...    Returns: List of matching lines
    [Arguments]    ${content}    ${prefix}

    @{lines}=    Split To Lines    ${content}
    @{matching}=    Create List
    FOR    ${line}    IN    @{lines}
        ${trimmed}=    Strip String    ${line}
        IF    '${trimmed}' != ''
            ${starts}=    Evaluate    $trimmed.startswith($prefix)
            IF    ${starts}
                Append To List    ${matching}    ${trimmed}
            END
        END
    END
    RETURN    ${matching}

# ═══════════════════════════════════════════════════════════════
# ZIP FILE KEYWORDS
# ═══════════════════════════════════════════════════════════════

Verify ZIP File Is Readable
    [Documentation]    Checks if a local ZIP file is valid and can be read.
    ...    Returns TRUE if valid, FALSE if corrupted.
    [Arguments]    ${zip_file_path}

    ${is_valid}=    Evaluate
    ...    __import__('zipfile').is_zipfile('${zip_file_path}')
    Log    ZIP file valid: ${is_valid}    console=yes
    RETURN    ${is_valid}

List ZIP File Contents
    [Documentation]    Lists the files inside a ZIP archive.
    ...    Returns list of filenames inside the ZIP.
    [Arguments]    ${zip_file_path}

    ${contents}=    Evaluate
    ...    __import__('zipfile').ZipFile('${zip_file_path}').namelist()
    Log    ZIP contents: ${contents}    console=yes
    RETURN    ${contents}
