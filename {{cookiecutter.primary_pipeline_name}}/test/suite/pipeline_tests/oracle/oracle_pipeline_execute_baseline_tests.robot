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
Resource            ../../test_data/queries/oracle2_queries.resource

Suite Setup         Setup Test Environment
Suite Teardown      Disconnect from Database


*** Variables ***
# ═══════════════════════════════════════════════════════════════
# Pipeline Configuration
# ═══════════════════════════════════════════════════════════════
${pipeline_name}                    baseline_data_extract_parent
${pipeline_name_slp}                baseline_data_extract.slp

# ═══════════════════════════════════════════════════════════════
# Upstream Job — Prerequisites Configuration
# ═══════════════════════════════════════════════════════════════
${UPSTREAM_PROCESS_CD}              CUST_ODS_LOAD
${EXPECTED_LOAD_STATUS_CD}          C

# ═══════════════════════════════════════════════════════════════
# Pipeline — Configuration
# ═══════════════════════════════════════════════════════════════
${PIPELINE_PROCESS_CD}                  PIPELINE_DATA_EXTRACT
${EXPECTED_PIPELINE_FILE_SEQ_NO}        000057
${EXPECTED_PIPELINE_EMAIL_NOTIFY}       test@example.com

# ═══════════════════════════════════════════════════════════════
# Expected Row Counts for Seed Data Verification
# ═══════════════════════════════════════════════════════════════
${EXPECTED_UPSTREAM_SEED_ROWS}      2
${EXPECTED_PIPELINE_SEED_ROWS}          5
${EXPECTED_TOTAL_SEED_ROWS}         7

# All SQL (DDL, INSERT, SELECT, UPDATE) is in:
# test/suite/test_data/queries/oracle2_queries.resource


*** Test Cases ***
# ═══════════════════════════════════════════════════════════════
# SETUP VERIFICATION — Confirm seed data is correct
# ═══════════════════════════════════════════════════════════════

Verify Seed Data Row Counts
    [Documentation]    Verifies the correct number of rows were seeded in PROCESS_CONFIG.
    ...    Upstream (CUST_ODS_LOAD): 2 rows
    ...    Pipeline (PIPELINE_DATA_EXTRACT): 5 rows
    ...    Total: 7 rows
    ...
    ...    Real-world scenario:
    ...    In production, the PROCESS_CONFIG table is populated during initial deployment
    ...    and maintained by the pipelines themselves. Before any pipeline runs, a DBA or
    ...    support engineer may verify that the config table has the expected number of
    ...    rows for each process — missing rows would cause the pipeline to fail or
    ...    behave incorrectly. This test automates that sanity check against our test
    ...    environment's seed data.
    ...
    ...    Production equivalent:
    ...    SELECT PROCESS_CD, COUNT(*) FROM PROCESS_CONFIG GROUP BY PROCESS_CD;
    ...
    ...    Uses Row Count Should Be from sql_table_operations.resource
    ...    which handles get count + assert + logging in one call.
    [Tags]    oracle_3    baseline    setup    pipeline

    Log    Verifying seed data row counts in PROCESS_CONFIG table...    console=yes
    Log    Checking upstream rows (CUST_ODS_LOAD): expected ${EXPECTED_UPSTREAM_SEED_ROWS}    console=yes
    Log    Checking Pipeline rows (PIPELINE_DATA_EXTRACT): expected ${EXPECTED_PIPELINE_SEED_ROWS}    console=yes
    Log    Checking total rows: expected ${EXPECTED_TOTAL_SEED_ROWS}    console=yes

    Row Count Should Be
    ...    PROCESS_CONFIG
    ...    ${EXPECTED_UPSTREAM_SEED_ROWS}
    ...    where_clause=PROCESS_CD='${UPSTREAM_PROCESS_CD}'
    Row Count Should Be
    ...    PROCESS_CONFIG
    ...    ${EXPECTED_PIPELINE_SEED_ROWS}
    ...    where_clause=PROCESS_CD='PIPELINE_DATA_EXTRACT'
    Validate Table Data Count    PROCESS_CONFIG    ${EXPECTED_TOTAL_SEED_ROWS}

    # Log all seeded rows for visibility in the test report
    ${all_rows}=    Execute Custom Query
    ...    SELECT PROCESS_CD, CONFIG_CD, CONFIG_VALUE FROM PROCESS_CONFIG ORDER BY PROCESS_CD, CONFIG_CD
    Log Query Results    ${all_rows}    label=All PROCESS_CONFIG seed data

# ═══════════════════════════════════════════════════════════════
# STEP 0: Prerequisites Check (Upstream Job Dependency)
# ═══════════════════════════════════════════════════════════════

Check And Fix Upstream Prerequisites
    [Documentation]    Checks upstream job (CUST_ODS_LOAD) prerequisites in PROCESS_CONFIG
    ...    and fixes them if not met. This test is fully self-contained — it queries
    ...    the database, evaluates the state, and runs UPDATE statements if needed.
    ...
    ...    Real-world scenario:
    ...    In production, the upstream pipeline (CUST_ODS_LOAD) pulls claims data from
    ...    external source systems and loads it into Oracle. When it completes, it writes
    ...    LOAD_STATUS_CD='C' and START_DT=today to PROCESS_CONFIG. The pipeline
    ...    checks these values before running — if the upstream job didn't finish or
    ...    didn't run today, the pipeline refuses to start and sends an email notification.
    ...
    ...    When this happens, a developer manually queries the database, identifies the
    ...    problem, runs UPDATE statements to fix the values, and re-runs the pipeline.
    ...    This test automates that entire manual workflow.
    ...
    ...    Checks: LOAD_STATUS_CD must be 'C' and START_DT must be today.
    ...    If not met: runs UPDATE to set LOAD_STATUS_CD='C' and START_DT=today.
    ...    If already met: skips updates gracefully.
    ...
    ...    Manual equivalent:
    ...    SELECT P.PROCESS_CD, P.CONFIG_CD, P.CONFIG_VALUE
    ...    FROM PROCESS_CONFIG P WHERE P.PROCESS_CD = 'CUST_ODS_LOAD'
    ...    AND CONFIG_CD IN ('START_DT', 'LOAD_STATUS_CD');
    ...    -- If wrong:
    ...    UPDATE PROCESS_CONFIG SET CONFIG_VALUE='C' WHERE CONFIG_CD='LOAD_STATUS_CD' AND PROCESS_CD='CUST_ODS_LOAD';
    ...    UPDATE PROCESS_CONFIG SET CONFIG_VALUE=TO_CHAR(SYSDATE,'MM/DD/YYYY') WHERE CONFIG_CD='START_DT' AND PROCESS_CD='CUST_ODS_LOAD';
    [Tags]    oracle_2    baseline    prerequisites    pipeline

    Log    Querying PROCESS_CONFIG for upstream job (CUST_ODS_LOAD) prerequisites...    console=yes
    Log    In production, this checks if the upstream data loading pipeline completed today.    console=yes
    Log    Checking: LOAD_STATUS_CD must be 'C' and START_DT must be today's date    console=yes
    Log    If not met -> run UPDATE statements to fix (simulates developer manual fix).    console=yes
    Log    If already correct -> skip updates.    console=yes
    Check Upstream Prerequisites And Fix If Needed

Verify Upstream Prerequisites
    [Documentation]    Independently queries PROCESS_CONFIG and asserts that upstream job
    ...    prerequisites are correctly set. This test reads directly from the database —
    ...    it does not depend on any other test case or suite variable.
    ...
    ...    Real-world scenario:
    ...    After a developer fixes the upstream job config (or after the upstream pipeline
    ...    re-runs successfully), they query the database one more time to confirm the
    ...    values are correct before re-triggering the pipeline. This test automates
    ...    that final verification step.
    ...
    ...    LOAD_STATUS_CD must be 'C' and START_DT must be today.
    ...    This test MUST pass before pipeline execution can proceed.
    [Tags]    oracle_2    baseline    prerequisites    pipeline

    Log    Querying PROCESS_CONFIG to verify upstream prerequisites are correct...    console=yes

    ${load_status_cd}=    Get Config Value    ${UPSTREAM_PROCESS_CD}    LOAD_STATUS_CD
    ${start_dt}=    Get Config Value    ${UPSTREAM_PROCESS_CD}    START_DT
    ${today}=    Get Today Date As MM DD YYYY

    Log    Verifying LOAD_STATUS_CD = '${load_status_cd}' (expected: '${EXPECTED_LOAD_STATUS_CD}')    console=yes
    Log    Verifying START_DT = '${start_dt}' (expected: '${today}')    console=yes

    Should Be Equal As Strings    ${load_status_cd}    ${EXPECTED_LOAD_STATUS_CD}
    ...    msg=LOAD_STATUS_CD should be '${EXPECTED_LOAD_STATUS_CD}' but got '${load_status_cd}'

    Should Be Equal As Strings    ${start_dt}    ${today}
    ...    msg=START_DT should be '${today}' but got '${start_dt}'

    Log    All upstream prerequisites verified. Ready for pipeline execution.    console=yes

# ═══════════════════════════════════════════════════════════════
# STEP 1: Import Pipeline & Verify Configuration
# ═══════════════════════════════════════════════════════════════

Import Pipeline
    [Documentation]    Imports the Pipeline Claims Extract parent pipeline (.slp file) into
    ...    the SnapLogic project space.
    ...
    ...    Real-world scenario:
    ...    In production, the pipeline is deployed once to the SnapLogic org by the
    ...    development team. In our test environment, we import it fresh each run
    ...    to ensure we're testing with the latest version of the pipeline.
    ...
    ...    Pipeline file: src/pipelines/MRx_CorePlatform_IMS_LAM_Claims_Parent_2026_04_02.slp
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    oracle_2    baseline    import    pipeline
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}

Verify Pipeline Config Exists
    [Documentation]    Verifies that PROCESS_CONFIG has rows for the pipeline
    ...    (PROCESS_CD = 'PIPELINE_DATA_EXTRACT'). If no rows exist, the pipeline
    ...    would fail immediately at startup because it cannot read its own settings.
    ...
    ...    Real-world scenario:
    ...    When a pipeline is deployed for the first time, the development team must
    ...    insert all config rows into PROCESS_CONFIG. If this step is missed or the
    ...    table is empty, the pipeline has no settings and cannot run.
    [Tags]    oracle    baseline    config    pipeline

    Log    Checking that Pipeline config rows exist in PROCESS_CONFIG...    console=yes
    Log    PROCESS_CD = '${PIPELINE_PROCESS_CD}' should have ${EXPECTED_PIPELINE_SEED_ROWS} rows    console=yes

    Row Count Should Be    PROCESS_CONFIG    ${EXPECTED_PIPELINE_SEED_ROWS}    where_clause=PROCESS_CD='${PIPELINE_PROCESS_CD}'

    Log    Pipeline config exists: ${EXPECTED_PIPELINE_SEED_ROWS} rows found.    console=yes

Verify Pipeline Core Settings
    [Documentation]    Verifies the core date/status config values for the pipeline:
    ...    - START_DT must be today (the date to extract data for)
    ...    - LOAD_STATUS_CD must be 'C' (last run completed)
    ...    - LOAD_STATUS_TS must be yesterday (timestamp of last run)
    ...
    ...    Real-world scenario:
    ...    The pipeline reads these values at startup to determine which date's data
    ...    to extract and whether the previous run completed. If START_DT is wrong,
    ...    the pipeline extracts data for the wrong date. If LOAD_STATUS_CD is not 'C',
    ...    it may skip execution thinking the previous run is still in progress.
    [Tags]    oracle    baseline    config    pipeline

    Log    Verifying Pipeline core settings (dates and status)...    console=yes

    ${start_dt}=    Get Config Value    ${PIPELINE_PROCESS_CD}    START_DT
    ${load_status_cd}=    Get Config Value    ${PIPELINE_PROCESS_CD}    LOAD_STATUS_CD
    ${load_status_ts}=    Get Config Value    ${PIPELINE_PROCESS_CD}    LOAD_STATUS_TS
    ${today}=    Get Today Date As MM DD YYYY
    ${yesterday}=    Get Yesterday Date As MM DD YYYY

    Log    START_DT = '${start_dt}' (expected: '${today}')    console=yes
    Log    LOAD_STATUS_CD = '${load_status_cd}' (expected: '${EXPECTED_LOAD_STATUS_CD}')    console=yes
    Log    LOAD_STATUS_TS = '${load_status_ts}' (expected: '${yesterday}')    console=yes

    Should Be Equal As Strings    ${start_dt}    ${today}
    ...    msg=Pipeline START_DT should be '${today}' but got '${start_dt}'

    Should Be Equal As Strings    ${load_status_cd}    ${EXPECTED_LOAD_STATUS_CD}
    ...    msg=Pipeline LOAD_STATUS_CD should be '${EXPECTED_LOAD_STATUS_CD}' but got '${load_status_cd}'

    Should Be Equal As Strings    ${load_status_ts}    ${yesterday}
    ...    msg=Pipeline LOAD_STATUS_TS should be '${yesterday}' but got '${load_status_ts}'

    Log    Pipeline core settings verified. Dates and status are correct.    console=yes

Verify Pipeline Operational Settings
    [Documentation]    Verifies the operational config values for the pipeline:
    ...    - FILE_SEQ_NO must be '000057' (used in output filenames)
    ...    - EMAIL_NOTIFY must be 'test@example.com' (notification recipients)
    ...
    ...    Real-world scenario:
    ...    Before each run, developers may check these settings to ensure files get
    ...    correct names and notifications reach the right people.
    ...    FILE_SEQ_NO is appended to the output filename
    ...    (e.g., PROD_DC_PFFS_NCPDP_000057_20260406.txt). It increments after each
    ...    successful run. If missing or wrong, the output files get incorrect names
    ...    or overwrite previous extracts.
    ...    EMAIL_NOTIFY determines who receives the completion notification. If empty,
    ...    no one gets notified when the pipeline finishes — failures go undetected.
    ...
    ...    Production equivalent:
    ...    SELECT CONFIG_CD, CONFIG_VALUE FROM PROCESS_CONFIG
    ...    WHERE PROCESS_CD = 'PIPELINE_DATA_EXTRACT'
    ...    AND CONFIG_CD IN ('FILE_SEQ_NO', 'EMAIL_NOTIFY');
    [Tags]    oracle    baseline    config    pipeline

    Log    Verifying Pipeline operational settings (file sequence and notifications)...    console=yes

    ${file_seq_no}=    Get Config Value    ${PIPELINE_PROCESS_CD}    FILE_SEQ_NO
    ${email_notify}=    Get Config Value    ${PIPELINE_PROCESS_CD}    EMAIL_NOTIFY

    Log    FILE_SEQ_NO = '${file_seq_no}' (expected: '${EXPECTED_PIPELINE_FILE_SEQ_NO}')    console=yes
    Log    EMAIL_NOTIFY = '${email_notify}' (expected: '${EXPECTED_PIPELINE_EMAIL_NOTIFY}')    console=yes

    Should Be Equal As Strings    ${file_seq_no}    ${EXPECTED_PIPELINE_FILE_SEQ_NO}
    ...    msg=Pipeline FILE_SEQ_NO should be '${EXPECTED_PIPELINE_FILE_SEQ_NO}' but got '${file_seq_no}'

    Should Be Equal As Strings    ${email_notify}    ${EXPECTED_PIPELINE_EMAIL_NOTIFY}
    ...    msg=Pipeline EMAIL_NOTIFY should be '${EXPECTED_PIPELINE_EMAIL_NOTIFY}' but got '${email_notify}'

    Log    Pipeline operational settings verified. File sequence and notifications are correct.    console=yes


*** Keywords ***
# ═══════════════════════════════════════════════════════════════
# SUITE SETUP
# ═══════════════════════════════════════════════════════════════

Setup Test Environment
    [Documentation]    Initializes the test environment (runs once before any test case):
    ...
    ...    1. Waits for Groundplex/Snaplex to be ready
    ...    2. Connects to Oracle database (Docker Oracle instance)
    ...    3. Creates PROCESS_CONFIG table (drops first if exists from previous run)
    ...    4. Seeds upstream job config data (CUST_ODS_LOAD) — deliberately wrong for testing
    ...    5. Seeds pipeline config data (PIPELINE_DATA_EXTRACT) — correct, for future steps
    ...    6. Generates unique_id for pipeline naming (avoids conflicts between test runs)
    ...
    ...    Real-world equivalent:
    ...    Steps 1-2: DBA ensures database is accessible before testing
    ...    Step 3: DBA creates the config table during initial deployment
    ...    Step 4: Simulates upstream pipeline completing (or failing) — in production,
    ...    the CUST_ODS_LOAD pipeline writes these values automatically
    ...    Step 5: Development team populates Pipeline config during pipeline deployment
    ...    Step 6: N/A in production — unique_id is a test framework concept
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to Oracle Database
    ...    ${ORACLE_DATABASE}
    ...    ${ORACLE_USER}
    ...    ${ORACLE_PASSWORD}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_PORT}
    Create Process Config Table In Oracle
    Seed Upstream Config Data
    Seed Pipeline Config Data
    Initialize Variables

# ═══════════════════════════════════════════════════════════════
# TABLE SETUP — LOGIC KEYWORDS
# ═══════════════════════════════════════════════════════════════

Create Process Config Table In Oracle
    [Documentation]    Creates PROCESS_CONFIG table. Drops first if exists from a previous run.

    Log    Dropping PROCESS_CONFIG table if it exists from a previous run...    console=yes
    Drop Table If Exists    PROCESS_CONFIG
    Log    Creating PROCESS_CONFIG table...    console=yes
    Execute SQL String Safe    ${SQL_CREATE_PROCESS_CONFIG}
    Log    PROCESS_CONFIG table created successfully.    console=yes

Seed Upstream Config Data
    [Documentation]    Inserts upstream job (CUST_ODS_LOAD) seed rows into PROCESS_CONFIG.
    ...
    ...    In production, CUST_ODS_LOAD is a separate SnapLogic pipeline that pulls claims
    ...    data from external source systems and loads it into Oracle tables. When it
    ...    completes, it writes LOAD_STATUS_CD='C' and START_DT=today to PROCESS_CONFIG.
    ...    We simulate this by inserting the rows directly — no actual upstream pipeline runs.
    ...
    ...    Seed values are deliberately WRONG to test the prerequisite fix workflow:
    ...    LOAD_STATUS_CD = 'I' (Incomplete, not 'C') and START_DT = yesterday (not today).

    Execute SQL String Safe    ${SQL_SEED_UPSTREAM_LOAD_STATUS_CD}
    Execute SQL String Safe    ${SQL_SEED_UPSTREAM_START_DT}
    Log    Seeded ${EXPECTED_UPSTREAM_SEED_ROWS} upstream config rows (CUST_ODS_LOAD).    console=yes

Seed Pipeline Config Data
    [Documentation]    Inserts pipeline (PIPELINE_DATA_EXTRACT) seed rows into PROCESS_CONFIG.
    ...
    ...    In production, PIPELINE_DATA_EXTRACT is the baseline data extract pipeline itself.
    ...    It reads from Oracle source tables (ODS_CLAIM_DETAIL, ODS_CLAIM_COB,
    ...    ODS_CLAIM_COMPOUND), applies filters (CLIENT_ID, PLAN_ID, START_DT), and
    ...    generates 4 output files (TXT, ZIP, HTML, CSV) to S3 and SharePoint.
    ...
    ...    These config rows are set up once during initial deployment by the development
    ...    team. After each successful run, the pipeline auto-updates START_DT (+1 day)
    ...    and FILE_SEQ_NO (+1). We seed 5 key config rows needed for testing:
    ...    LOAD_STATUS_CD, START_DT, LOAD_STATUS_TS, FILE_SEQ_NO, EMAIL_NOTIFY.
    ...
    ...    Unlike upstream data, these values are seeded as CORRECT — they are not being
    ...    tested in Step 0. They exist for future steps (pipeline execution and
    ...    post-run verification).

    Execute SQL String Safe    ${SQL_SEED_PIPELINE_LOAD_STATUS_CD}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_START_DT}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_LOAD_STATUS_TS}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_FILE_SEQ_NO}
    Execute SQL String Safe    ${SQL_SEED_PIPELINE_EMAIL_NOTIFY}
    Log    Seeded ${EXPECTED_PIPELINE_SEED_ROWS} Pipeline config rows (PIPELINE_DATA_EXTRACT).    console=yes

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
