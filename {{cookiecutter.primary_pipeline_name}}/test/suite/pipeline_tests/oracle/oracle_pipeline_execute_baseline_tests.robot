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
${pipeline_name}                        prime_oracle_baseline_tests3
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

    # local file path    destination_path
    ${SAMPLE_TXT_FILE}    ${PIPELINES_LOCATION_PATH}
    ${SAMPLE_ZIP_FILE}    ${PIPELINES_LOCATION_PATH}
    ${SAMPLE_HTML_FILE}    ${PIPELINES_LOCATION_PATH}
    ${SAMPLE_CSV_FILE}    ${PIPELINES_LOCATION_PATH}

# ═══════════════════════════════════════════════════════════════
# STEP 1: Import Pipeline & Verify Configuration
# ═══════════════════════════════════════════════════════════════

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
    Execute SQL String Safe
    ...    UPDATE PROCESS_CONFIG SET CONFIG_VALUE='C', LAST_UPD_TIMESTAMP=sysdate WHERE CONFIG_CD='LOAD_STATUS_CD' and PROCESS_CD='PIPELINE_DATA_EXTRACT'
    # START_DT must be yesterday so that START_DT + TERM(1) = today <= SYSDATE passes
    Execute SQL String Safe
    ...    UPDATE PROCESS_CONFIG SET CONFIG_VALUE=to_char(sysdate-1,'mm/dd/yyyy'), LAST_UPD_TIMESTAMP=sysdate WHERE CONFIG_CD='START_DT' and PROCESS_CD='PIPELINE_DATA_EXTRACT'

    Log    All prerequisites reset. Pipeline should pass check and execute child.    console=yes

Import Pipeline
    [Documentation]    Imports both the parent and child pipeline (.slp files) into
    ...    the SnapLogic project space.
    ...    Pipeline files:
    ...    - Parent: src/pipelines/${pipeline_name_slp}
    ...    - Child:    src/pipelines/${child_pipeline_name_slp}
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    oracle_23    baseline    import    pipeline
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}

Import existing child Pipeline
    [Documentation]    Imports pipelines using their original name without appending
    ...    a unique suffix. Use this when the pipeline name must remain exactly as-is
    ...    (e.g., when downstream tasks or expressions reference the pipeline by a fixed name).
    ...    Pipeline files:
    ...    - Parent: src/pipelines/${pipeline_name_slp}
    ...    - Child:    src/pipelines/${child_pipeline_name_slp}
    [Tags]    oracle_2    baseline    import    pipeline    no_suffix
    [Template]    Import Pipeline With Original Name
    # ${PIPELINES_LOCATION_PATH}    ${child_pipeline_name}    ${child_pipeline_name_slp}    duplicate_check=true
    # ${PIPELINES_LOCATION_PATH}    ${child_pipeline_name}    ${child_pipeline_name_slp}    duplicate_check=true

    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}
    ${PIPELINES_LOCATION_PATH}    ${child_pipeline_name}    ${child_pipeline_name_slp}

# ═══════════════════════════════════════════════════════════════
# STEP 2: Create and Execute Triggered Task
# ═══════════════════════════════════════════════════════════════

Create Triggered Task For Parent Pipeline
    [Documentation]    Creates a triggered task for the parent pipeline and returns
    ...    the task name and task snode id used to execute it.
    ...    Prerequisites:
    ...    - Import Pipeline must have completed (pipeline exists in project)
    ...    - Groundplex must be running and registered
    [Tags]    baseline    task    pipeline
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}

Create Triggered Task For Pipelines WithOut UniqueID Appended
    [Documentation]    Creates a triggered task for the parent pipeline that was imported
    ...    without a unique suffix (via Import Pipeline With Original Name).
    ...    The task name still includes unique_id to avoid collisions across runs,
    ...    but the pipeline snode lookup uses the original pipeline name (no suffix).
    ...    Prerequisites:
    ...    - Import existing child Pipeline must have completed
    ...    - Groundplex must be running and registered
    [Tags]    oracle_2    oracle_existing_pl    baseline    task    pipeline    no_suffix
    [Template]    Create Triggered Task For Original Pipeline Name
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Executes the triggered task for the parent pipeline.
    ...    This runs the full pipeline flow:
    ...    1. Parent reads config from S3
    ...    2. Parent checks upstream prerequisites in Oracle
    ...    3. Parent calls child pipeline (Kickoff ODS Load)
    ...    4. Child reads sample files from SLDB and uploads to S3
    ...    5. Parent updates LOAD_STATUS_CD, FILE_SEQ_NO in Oracle
    ...
    ...    After execution, 4 files should appear in MinIO:
    ...    - EXTRACT_{FILE_DATE}_{FILE_SEQ_NO}.txt
    ...    - EXTRACT_{FILE_DATE}_{FILE_SEQ_NO}.zip
    ...    - EXTRACT_{FILE_DATE}_{FILE_SEQ_NO}.csv
    ...    - EXTRACT_{FILE_DATE}_{FILE_SEQ_NO}.html
    [Tags]    oracle_2    oracle_existing_pl    baseline    execute    pipeline
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}

Wait For Pipeline Output Files In S3
    [Documentation]    Waits for the child pipeline to finish uploading NEW files to S3.
    ...    Compares the current TXT file count against the snapshot taken before
    ...    execution. Proceeds only when the count increases (new files detected).
    ...    Prevents false positives from files left by previous runs.
    [Tags]    oracle_2    baseline    execute    pipeline

    ${new_count}=    Wait Until New S3 Files Appear
    ...    ${OUTPUT_BUCKET}
    ...    ${TXT_EXTENSION}
    ...    ${S3_TXT_COUNT_BEFORE}
    ...    timeout=90
    ...    interval=5
    Log    S3 TXT file count: before=${S3_TXT_COUNT_BEFORE}, after=${new_count}    console=yes

# ═══════════════════════════════════════════════════════════════
# STEP 3: TXT Output Verification (NCPDP PA44 Format)
# ═══════════════════════════════════════════════════════════════

Verify Extract TXT Files Exist In S3
    [Documentation]    Verifies that the pipeline generated TXT extract files in S3.
    ...    After the pipeline runs, developers check S3 to confirm the TXT extract
    ...    file was created. If missing, the pipeline failed silently.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}    ${file_count}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
    Log    Found ${file_count} TXT files: ${txt_files}    console=yes
    Should Be True    ${file_count} > 0
    ...    msg=No TXT extract files found in bucket '${OUTPUT_BUCKET}'

Verify Specific TXT Extract File Naming Pattern
    [Documentation]    Verifies the latest TXT extract file in S3 follows the expected
    ...    naming convention: EXTRACT_YYYYMMDD_NNNNNN.txt
    ...    This confirms the pipeline dynamically generated the filename from
    ...    FILE_DATE and FILE_SEQ_NO (both sourced from Oracle PROCESS_CONFIG).
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}    ${count}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
    Should Be True    ${count} > 0    msg=No TXT files found in bucket '${OUTPUT_BUCKET}'
    ${latest_file}=    Get From List    ${txt_files}    0
    Log    Latest TXT file: ${latest_file}    console=yes
    Should Match Regexp    ${latest_file}    extract/EXTRACT_\\d{8}_\\d{6}\\.txt
    ...    msg=Latest TXT file '${latest_file}' doesn't match expected pattern EXTRACT_YYYYMMDD_NNNNNN.txt

Verify Extract Files Are Non Empty
    [Documentation]    Verifies all TXT extract files have content (size > 0 bytes).
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to validate — skipping.
    Verify All Files Are Non Empty In Bucket    ${OUTPUT_BUCKET}    ${txt_files}

Verify TXT Extract Has PA Header Record
    [Documentation]    Verifies the TXT extract starts with a PA (header) record.
    ...    The NCPDP PA44 format requires a header line starting with 'PA'
    ...    containing file date, plan ID, client ID, and file sequence number.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${txt_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
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

    ${txt_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
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

    ${txt_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
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

    ${txt_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${txt_files}    TXT extract
    Pass Execution If    not ${has_files}    No TXT files to validate — skipping.

    ${first_file}=    Get From List    ${txt_files}    0
    ${content}=    Download And Get File Content    ${first_file}
    ${line_count}=    Count Lines In Content    ${content}

    Log    TXT extract has ${line_count} lines (expected: 7 = 1 header + 5 detail + 1 trailer)    console=yes
    Should Be Equal As Integers    ${line_count}    7
    ...    msg=TXT extract should have 7 lines (1 PA + 5 CD + 1 PT) but got ${line_count}

# ═══════════════════════════════════════════════════════════════
# STEP 4: Previous Run Comparison
# Per logic: "We do compare against previous for same data-set runs"
# Mirrors production workflow:
#    1. Before pipeline runs → save existing S3 files as "previous run"
#    2. Pipeline runs → creates new files
#    3. After pipeline runs → compare current vs previous
#    4. If no previous run exists → skip comparison (first run)
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
    ...    If no previous run exists (first run), the test FAILS with a message
    ...    to run a second time. Two runs are needed to have a current vs previous pair.
    [Tags]    oracle_2    baseline    s3_output    comparison    pipeline

    # Logic: download latest two TXT files, extract only CD-prefixed lines
    ${current_details}
    ...    ${previous_details}
    ...    ${current_file}
    ...    ${previous_file}
    ...    ${file_count}=
    ...    Get Current And Previous File Content From Bucket
    ...    ${OUTPUT_BUCKET}
    ...    ${S3_OUTPUT_DOWNLOAD_DIR}
    ...    ${TXT_EXTENSION}
    ...    line_prefix=CD

    # Verification only
    Log    Comparing CD records: ${current_file} vs ${previous_file}    console=yes
    Should Be Equal    ${current_details}    ${previous_details}
    ...    msg=CD detail records differ between current (${current_file}) and previous (${previous_file}) run.

# ═══════════════════════════════════════════════════════════════
# STEP 3: HTML Output Verification (Claims Summary Report)
# ═══════════════════════════════════════════════════════════════

Verify HTML Report Exists In S3
    [Documentation]    Verifies that the pipeline generated an HTML summary report.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${html_files}    ${file_count}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${HTML_EXTENSION}
    Log    Found ${file_count} HTML reports: ${html_files}    console=yes
    Should Be True    ${file_count} > 0
    ...    msg=No HTML reports found in bucket '${OUTPUT_BUCKET}'

Verify HTML Report Contains Report Title
    [Documentation]    Verifies the HTML summary report contains the expected title.
    [Tags]    oracle_2    baseline    s3_output    content    pipeline

    ${html_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${HTML_EXTENSION}
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

    ${html_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${HTML_EXTENSION}
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

    ${html_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${HTML_EXTENSION}
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

    ${html_files}    ${_}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${HTML_EXTENSION}
    ${has_files}=    Check File List Is Not Empty    ${html_files}    HTML report
    Pass Execution If    not ${has_files}    No HTML files to validate — skipping.

    ${first_file}=    Get From List    ${html_files}    0
    ${content}=    Download And Get File Content    ${first_file}

    Should Contain    ${content}    5 claims
    ...    msg=HTML report does not contain '5 claims' — expected 5 mock records
    Log    HTML report shows correct claim count.    console=yes

Compare HTML Output Against Previous Run
    [Documentation]    Compares the current HTML summary report against the previous run's report.
    ...    Full content is compared (no line-prefix filtering) since the HTML report
    ...    contains static summary data (claim counts, status, totals) that should be
    ...    identical across runs using the same dataset.
    ...
    ...    Real-world scenario:
    ...    After each run, developers compare the current HTML summary against the previous
    ...    run's summary. If the reports differ, it means the pipeline logic changed or
    ...    source data was modified unexpectedly.
    ...
    ...    If no previous run exists (first run), the test FAILS with a message
    ...    to run a second time. Two runs are needed to have a current vs previous pair.
    [Tags]    oracle_2    baseline    s3_output    comparison    pipeline

    # Logic: download latest two HTML files, compare full content
    ${current_content}
    ...    ${previous_content}
    ...    ${current_file}
    ...    ${previous_file}
    ...    ${file_count}=
    ...    Get Current And Previous File Content From Bucket
    ...    ${OUTPUT_BUCKET}
    ...    ${S3_OUTPUT_DOWNLOAD_DIR}
    ...    ${HTML_EXTENSION}

    # Verification only
    Log    Comparing HTML reports: ${current_file} vs ${previous_file}    console=yes
    Should Be Equal    ${current_content}    ${previous_content}
    ...    msg=HTML reports differ between current (${current_file}) and previous (${previous_file}) run.


*** Keywords ***
# ═══════════════════════════════════════════════════════════════
# SUITE SETUP
# ═══════════════════════════════════════════════════════════════

Initialize Variables
    [Documentation]    Generates a unique ID for this test run and sets it as a suite variable.
    ...    The unique_id is used for pipeline naming to avoid conflicts between test runs.
    ...    Follows the same pattern as oracle_baseline_tests.robot — called from suite setup,
    ...    shared across all test cases via Set Suite Variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes

Snapshot S3 File Count
    [Documentation]    Records how many TXT files exist in S3 before pipeline execution.
    ...    Used by Wait For Pipeline Output Files to detect when NEW files appear.

    ${_}    ${count_before}=    Find Files In Bucket By Extension    ${OUTPUT_BUCKET}    ${TXT_EXTENSION}
    Set Suite Variable    ${S3_TXT_COUNT_BEFORE}    ${count_before}
    Log    S3 TXT file count at suite start: ${count_before}    console=yes

Try Lookup Existing Pipeline
    [Documentation]    Attempts to look up the pipeline snode_id from SnapLogic.
    ...    If the pipeline exists, caches the snode_id so import can be skipped.
    ...    If not found, logs a message and continues — the import test case will set it later.

    ${lookup_ok}=    Run Keyword And Return Status
    ...    Lookup Existing Pipeline    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}
    IF    ${lookup_ok}
        Log    Pipeline '${pipeline_name}' found — snode_id cached for downstream use.    console=yes
    ELSE
        Log    Pipeline '${pipeline_name}' not found — will be set by Import test case.    console=yes
    END

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
    Snapshot S3 File Count
    Try Lookup Existing Pipeline

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
    ...    - If NO    → creates all tables, seeds all data (first run)
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

# ═══════════════════════════════════════════════════════════════
# S3 OUTPUT VERIFICATION — Local Wrapper
# (bucket + download dir are test-specific; generic keyword in minio.resource)
# ═══════════════════════════════════════════════════════════════

Download And Get File Content
    [Documentation]    Thin wrapper — downloads from this test's OUTPUT_BUCKET to S3_OUTPUT_DOWNLOAD_DIR.
    [Arguments]    ${object_key}

    ${content}=    minio.Download And Get File Content
    ...    ${OUTPUT_BUCKET}
    ...    ${S3_OUTPUT_DOWNLOAD_DIR}
    ...    ${object_key}
    RETURN    ${content}
