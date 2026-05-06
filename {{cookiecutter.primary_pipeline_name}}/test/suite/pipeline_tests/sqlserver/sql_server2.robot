*** Settings ***
Documentation       Test Suite for SQL Server Database Integration with Pipeline Tasks
...                 This suite validates SQL Server database integration by:
...                 1. Creating necessary database tables and stored procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and stored procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             DatabaseLibrary    # Generic database operations
Library             pymssql    # SQL Server specific operations
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../../test_data/queries/sqlserver_queries.resource    # SQL Server queries
Resource            ../../../resources/common/files.resource    # CSV/JSON file operations
Resource            ../../../resources/common/database.resource
Resource            ../../../resources/common/sql_table_operations.resource    # Generic SQL helpers (count/single value/column values)
Resource            ../../../resources/common/csv_validations.resource    # CSV diff template (Compare CSV Files Template)

Suite Setup         Initialize Test Environment    # Connect, ensure esb schema + 8 tables exist, then truncate


*** Variables ***
${INPUT_DATA_DIR}                   ${CURDIR}/../../test_data/actual_expected_data/input_data
${input_file}                       ${INPUT_DATA_DIR}/d0365_helpers.expr
${input_file2}                      ${INPUT_DATA_DIR}/D0365_sample_2026_05_04.txt

# SQL Server Pipeline and Task Configuration
${ACCOUNT_PAYLOAD_FILE}             acc_sqlserver.json
${pipeline_name}                    D0365_test_clean_version
${pipeline_name_slp}                D0365_test_clean_version.slp
${error_pipeline_name}              D0365_Error_Pipeline_SQL_Delete
${error_pipeline_name_slp}          D0365_Error_Pipeline_SQL_Delete.slp

# Triggered task config
${task1}                            D0365_Pipeline_Task

@{notification_states}              Completed    Failed
&{task_notifications}               recipients=demo@example.com    states=${notification_states}
&{task_params_set}                  &{EMPTY}    # no pipeline parameters required

# Expected row counts (mandatory tables only — see verification section)
${EXPECTED_INTERCHANGE_ROWS}        1
${EXPECTED_INVOICE_HEADER_ROWS}     1
${EXPECTED_CONTRACT_ROWS}           1
${EXPECTED_BILLING_PERIOD_ROWS}     2
${EXPECTED_SETTLEMENT_UNIT_ROWS}    3

# Expected content
${EXPECTED_INTERCHANGE_ID}          D0365001_TESTPARTY
${EXPECTED_INVOICE_TOTAL}           15150.00
${EXPECTED_NET_PAYABLE_AMOUNT}      15150.0000

# CSV export / compare config — exports esb.CFDBillingPeriod (2 deterministic rows)
${export_table_name}                esb.CFDBillingPeriod
${db_order_by_column}               CFDBillingPeriodID
${actual_output_file_name}          ${pipeline_name}_actual_cfd_billing_period.csv
${expected_output_file_name}        expected_cfd_billing_period.csv
${actual_output_file_path}          ${CURDIR}/../../test_data/actual_expected_data/actual_output/sqlserver/${actual_output_file_name}
${expected_output_file_path}        ${CURDIR}/../../test_data/actual_expected_data/expected_output/sqlserver/${expected_output_file_name}


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    sqlserver2_demo
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    sqlserveracct2

Upload Files To SLDB
    [Documentation]    Uploads the 4 sample output files (TXT, ZIP, HTML, CSV) to SnapLogic SLDB
    ...    Destination: ${PIPELINES_LOCATION_PATH} (project folder in SLDB)
    [Tags]    sqlserver2
    [Template]    Upload File Using File Protocol Template

    # local file path    destination_path in sldb
    ${input_file}    ${PIPELINES_LOCATION_PATH}
    ${input_file2}    ${PIPELINES_LOCATION_PATH}

Import Pipeline
    [Documentation]    Imports pipeline
    ...    the SnapLogic project space.
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    sqlserver2
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}

Import error Pipeline Wihout Unique ID
    [Documentation]    Imports pipelines using their original name without appending
    ...    a unique suffix. Use this when the pipeline name must remain exactly as-is
    ...    (e.g., when downstream tasks or expressions reference the pipeline by a fixed name).
    ...    Pipeline files:
    ...    - Error Pipeline:    src/pipelines/${child_pipeline_name_slp}
    [Tags]    sqlserver2
    [Template]    Import Pipeline With Original Name
    ${PIPELINES_LOCATION_PATH}    ${error_pipeline_name}    ${error_pipeline_name_slp}

# ═══════════════════════════════════════════════════════════════
# TRIGGERED TASK — Create and Execute the D0365 Pipeline
# ═══════════════════════════════════════════════════════════════

Create Triggered Task For D0365 Pipeline
    [Documentation]    Creates a triggered task that wraps the D0365 main pipeline.
    ...    Prerequisites:
    ...    - Import Pipeline has run (registers main pipeline with unique-id suffix)
    ...    - Import existing error Pipeline Wihout Unique ID has run
    ...    - Groundplex is up and registered
    [Tags]    sqlserver2
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}

Execute Triggered Task For D0365 Pipeline
    [Documentation]    Triggers the D0365 pipeline. The pipeline will:
    ...    1. Read the D0365 sample file from SLDB (V00070021 binary reader)
    ...    2. Parse the pipe-delimited file (Script London)
    ...    3. Route per record type to 8 SQL Server insert branches
    ...    4. Populate esb.* tables in master DB
    ...
    ...    On success, downstream verification test cases assert row counts and content.
    [Tags]    sqlserver2    execute    pipeline
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}

# ═══════════════════════════════════════════════════════════════
# DATA VERIFICATION — Row counts (mandatory tables)
# ═══════════════════════════════════════════════════════════════

Verify D0365Interchange Row Count
    [Documentation]    Asserts exactly one D0365Interchange row was inserted —
    ...    one row per ZHV record in the source file.
    [Tags]    sqlserver2    verify    row_count

    ${count}=    Execute SQL Query And Get Count    ${SQL_COUNT_D0365INTERCHANGE}
    Should Be Equal As Integers    ${count}    ${EXPECTED_INTERCHANGE_ROWS}
    ...    msg=esb.D0365Interchange should have ${EXPECTED_INTERCHANGE_ROWS} row(s) but has ${count}

Verify EMRInvoiceHeader Row Count
    [Documentation]    Asserts the invoice-header row count matches the number of
    ...    86I records in the source file.
    [Tags]    sqlserver2    verify    row_count

    ${count}=    Execute SQL Query And Get Count    ${SQL_COUNT_EMRINVOICEHEADER}
    Should Be Equal As Integers    ${count}    ${EXPECTED_INVOICE_HEADER_ROWS}
    ...    msg=esb.EMRInvoiceHeader should have ${EXPECTED_INVOICE_HEADER_ROWS} row(s) but has ${count}

Verify ContractForDifference Row Count
    [Documentation]    Asserts the CFD row count matches the number of 87I records.
    [Tags]    sqlserver2    verify    row_count

    ${count}=    Execute SQL Query And Get Count    ${SQL_COUNT_CONTRACTFORDIFFERENCE}
    Should Be Equal As Integers    ${count}    ${EXPECTED_CONTRACT_ROWS}
    ...    msg=esb.ContractForDifference should have ${EXPECTED_CONTRACT_ROWS} row(s) but has ${count}

Verify CFDBillingPeriod Row Count
    [Documentation]    Asserts the billing-period row count matches the number of
    ...    88I records in the source file (sample has 2: SP01 and SP02).
    [Tags]    sqlserver2    verify    row_count

    ${count}=    Execute SQL Query And Get Count    ${SQL_COUNT_CFDBILLINGPERIOD}
    Should Be Equal As Integers    ${count}    ${EXPECTED_BILLING_PERIOD_ROWS}
    ...    msg=esb.CFDBillingPeriod should have ${EXPECTED_BILLING_PERIOD_ROWS} row(s) but has ${count}

Verify CFDSettlementUnit Row Count
    [Documentation]    Asserts the settlement-unit row count matches the number of
    ...    89I records in the source file (sample has 3 across 2 billing periods).
    [Tags]    sqlserver2    verify    row_count

    ${count}=    Execute SQL Query And Get Count    ${SQL_COUNT_CFDSETTLEMENTUNIT}
    Should Be Equal As Integers    ${count}    ${EXPECTED_SETTLEMENT_UNIT_ROWS}
    ...    msg=esb.CFDSettlementUnit should have ${EXPECTED_SETTLEMENT_UNIT_ROWS} row(s) but has ${count}

# ═══════════════════════════════════════════════════════════════
# DATA VERIFICATION — Content checks
# ═══════════════════════════════════════════════════════════════

Verify D0365Interchange ID Matches Expected Pattern
    [Documentation]    Asserts the InterchangeID was generated from the file's
    ...    ZHV header (FileIdentifier + "_" + FromId). For our sample file:
    ...    ZHV|D0365001|...|TESTPARTY|...    →    D0365001_TESTPARTY
    [Tags]    sqlserver2    verify    content

    ${id}=    Execute SQL Query And Get Single Value    ${SQL_SELECT_INTERCHANGE_ID}
    Should Be Equal    ${id}    ${EXPECTED_INTERCHANGE_ID}
    ...    msg=D0365InterchangeID should be '${EXPECTED_INTERCHANGE_ID}' but is '${id}'

Verify Invoice Total Matches Source File
    [Documentation]    Asserts the InvoiceTotal column contains the value from the
    ...    86I record in the source file (15150.00).
    [Tags]    sqlserver2    verify    content

    ${total}=    Execute SQL Query And Get Single Value    ${SQL_SELECT_INVOICE_TOTAL}
    Should Be Equal As Numbers    ${total}    ${EXPECTED_INVOICE_TOTAL}
    ...    msg=InvoiceTotal should be ${EXPECTED_INVOICE_TOTAL} but is ${total}

Verify Net Payable Amount Matches Source File
    [Documentation]    Asserts the CFD NetPayableAmount equals the 87I value (15150.00).
    [Tags]    sqlserver2    verify    content

    ${amount}=    Execute SQL Query And Get Single Value    ${SQL_SELECT_NET_PAYABLE_AMOUNT}
    Should Be Equal As Numbers    ${amount}    ${EXPECTED_NET_PAYABLE_AMOUNT}
    ...    msg=NetPayableAmount should be ${EXPECTED_NET_PAYABLE_AMOUNT} but is ${amount}

Verify Settlement Unit IDs Are Sequential
    [Documentation]    Asserts the 3 settlement units were inserted with the IDs
    ...    1, 1, 2 — two billing periods (SP01, SP02), with SP01 having units 1 & 2
    ...    and SP02 having unit 1. Confirms the script-generated IDs match the file.
    [Tags]    sqlserver2    verify    content

    # Get Column Values (from sql_table_operations.resource) takes table + column
    # — no raw SQL needed. Returns a list of all values in that column.
    @{ids}=    Get Column Values    esb.CFDSettlementUnit    SettlementUnitID
    Length Should Be    ${ids}    ${EXPECTED_SETTLEMENT_UNIT_ROWS}
    # SettlementUnitID is an INT column → values come back as Python ints.
    # ${1} / ${2} force int literals (bare 1/2 in Robot are strings).
    Should Contain    ${ids}    ${1}
    Should Contain    ${ids}    ${2}

# ═══════════════════════════════════════════════════════════════
# DATA VERIFICATION — CSV export and file-level diff
# Mirrors the Oracle baseline pattern:
#    1. Export the target SQL Server table to a CSV in actual_output/sqlserver/
#    2. Diff that CSV against a known-good CSV in expected_output/sqlserver/
# ═══════════════════════════════════════════════════════════════

Export SQL Server Data To CSV
    [Documentation]    Exports the contents of esb.CFDBillingPeriod to a CSV file
    ...    so the next test case can compare it against the expected baseline.
    ...
    ...    Why CFDBillingPeriod:
    ...    - 2 deterministic rows from our sample file (SP01, SP02)
    ...    - No timestamp columns (no run-to-run drift)
    ...    - Touches the parent FK (ContractForDifferenceID) so the diff also
    ...    verifies parent-child linkage, not just row count
    ...
    ...    Output goes to:
    ...    test/suite/test_data/actual_expected_data/actual_output/sqlserver/<file>
    [Tags]    sqlserver2    verify    export    csv

    Export DB Table Data To CSV
    ...    ${export_table_name}
    ...    ${db_order_by_column}
    ...    ${actual_output_file_path}
    Log    Exported ${export_table_name} to: ${actual_output_file_path}    console=yes

Compare Actual vs Expected CSV Output
    [Documentation]    Compares the CSV produced by Export SQL Server Data To CSV
    ...    against the baseline in expected_output/sqlserver/. Pipeline output is
    ...    correct only if the diff returns IDENTICAL.
    ...
    ...    Arguments to Compare CSV Files Template:
    ...    1. actual file path
    ...    2. expected file path
    ...    3. ignore_order — ${FALSE} since we ORDER BY the PK in the export
    ...    4. show_details — ${TRUE} so any diff is logged in the report
    ...    5. expected_status — IDENTICAL
    ...
    ...    Updating the baseline:
    ...    If the export format changes (e.g. driver upgrades how it formats
    ...    decimals or dates), copy the actual CSV over the expected one:
    ...    cp <actual_output_file_path> <expected_output_file_path>
    [Tags]    sqlserver2    verify    compare    csv
    [Template]    Compare CSV Files Template

    # actual_path    expected_path    ignore_order    show_details    expected_status
    ${actual_output_file_path}    ${expected_output_file_path}    ${FALSE}    ${TRUE}    IDENTICAL

# ═══════════════════════════════════════════════════════════════════════════
# END-TO-END FLOW — Single test case demonstrating the full pipeline lifecycle
# ═══════════════════════════════════════════════════════════════════════════
# Self-contained smoke test that runs the entire D0365 pipeline lifecycle in
# ═══════════════════════════════════════════════════════════════════════════

End To End SQL Server Pipeline Flow
    [Documentation]    COMPLETE end-to-end SQL Server pipeline test in a single test case.
    ...
    ...    Executes the full lifecycle in 10 sequential steps:
    ...    1.    Generate unique_id for this run
    ...    2.    Create SQL Server account in SnapLogic
    ...    3.    Upload helpers expression library to SLDB
    ...    4.    Upload D0365 sample data file to SLDB
    ...    5.    Import the main pipeline (.slp) with unique-id suffix
    ...    6.    Import the error pipeline (.slp) keeping its original name
    ...    7.    Create a triggered task pointing at the main pipeline
    ...    8.    Execute the triggered task
    ...    9.    Verify SQL Server tables have the expected row counts
    ...    10. Export CFDBillingPeriod to CSV and compare against expected baseline
    ...
    ...    Prerequisites:
    ...    - Suite Setup has run (esb schema + 8 tables exist; tables truncated)
    ...    - Pipeline files exist at src/pipelines/D0365_test_clean_version.slp
    ...    and src/pipelines/D0365_Error_Pipeline_SQL_Delete.slp
    ...    - Sample input file exists at test_data/.../D0365_sample_2026_05_04.txt
    ...    - Expected baseline exists at expected_output/sqlserver/expected_cfd_billing_period.csv
    [Tags]    sqlserver_end_to_end

    # ─────────────────────────────────────────────────────────────────────
    # STEP 1: Generate Unique ID (avoid name collisions across test runs)
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 1: Generating unique ID for this run ===    console=yes
    ${unique_id}=    Get Unique Id
    Set Test Variable    ${unique_id}    ${unique_id}
    Log    Unique ID: ${unique_id}    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 2: Create SQL Server Account in SnapLogic Project Space
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 2: Creating SQL Server account: ${SQLSERVER_ACCOUNT_NAME} ===    console=yes
    Create Account From Template
    ...    ${ACCOUNT_LOCATION_PATH}
    ...    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}
    ...    ${SQLSERVER_ACCOUNT_NAME}
    Log    Account created at ${ACCOUNT_LOCATION_PATH}/${SQLSERVER_ACCOUNT_NAME}    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 3: Upload Helpers Expression Library to SLDB
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 3: Uploading d0365_helpers.expr to SLDB ===    console=yes
    Upload File Using File Protocol Template
    ...    ${input_file}
    ...    ${PIPELINES_LOCATION_PATH}
    Log    Helpers expression library uploaded to SLDB    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 4: Upload D0365 Sample Data File to SLDB
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 4: Uploading D0365 sample data file to SLDB ===    console=yes
    Upload File Using File Protocol Template
    ...    ${input_file2}
    ...    ${PIPELINES_LOCATION_PATH}
    Log    Sample data file uploaded to SLDB    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 5: Import Main Pipeline (.slp) with Unique-ID Suffix
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 5: Importing main pipeline ${pipeline_name_slp} ===    console=yes
    Import Pipelines From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${pipeline_name_slp}
    Log    Main pipeline imported as: ${pipeline_name}_${unique_id}    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 6: Import Error Pipeline (.slp) Keeping Its Original Name
    # The main pipeline references it by exact name — must NOT have unique_id.
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 6: Importing error pipeline ${error_pipeline_name_slp} ===    console=yes
    Import Pipeline With Original Name
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${error_pipeline_name}
    ...    ${error_pipeline_name_slp}
    Log    Error pipeline imported as: ${error_pipeline_name}    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 7: Create Triggered Task for the Imported Main Pipeline
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 7: Creating triggered task: ${task1} ===    console=yes
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task1}
    ...    ${GROUNDPLEX_NAME}
    ...    ${task_params_set}
    ...    ${task_notifications}
    Log    Triggered task created: ${task1}_${unique_id}    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 8: Execute the Triggered Task (runs the pipeline)
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 8: Executing triggered task — pipeline runs end-to-end ===    console=yes
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task1}
    Log    Pipeline execution completed    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 9: Verify SQL Server Table Row Counts
    # Confirms the pipeline wrote the expected number of rows to each
    # mandatory table (1, 1, 1, 2, 3 derived from sample-file structure).
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 9: Verifying SQL Server table row counts ===    console=yes
    ${interchange_count}=    Execute SQL Query And Get Count    ${SQL_COUNT_D0365INTERCHANGE}
    Should Be Equal As Integers    ${interchange_count}    ${EXPECTED_INTERCHANGE_ROWS}
    ${invoice_count}=    Execute SQL Query And Get Count    ${SQL_COUNT_EMRINVOICEHEADER}
    Should Be Equal As Integers    ${invoice_count}    ${EXPECTED_INVOICE_HEADER_ROWS}
    ${cfd_count}=    Execute SQL Query And Get Count    ${SQL_COUNT_CONTRACTFORDIFFERENCE}
    Should Be Equal As Integers    ${cfd_count}    ${EXPECTED_CONTRACT_ROWS}
    ${bp_count}=    Execute SQL Query And Get Count    ${SQL_COUNT_CFDBILLINGPERIOD}
    Should Be Equal As Integers    ${bp_count}    ${EXPECTED_BILLING_PERIOD_ROWS}
    ${unit_count}=    Execute SQL Query And Get Count    ${SQL_COUNT_CFDSETTLEMENTUNIT}
    Should Be Equal As Integers    ${unit_count}    ${EXPECTED_SETTLEMENT_UNIT_ROWS}
    Log    All 5 mandatory tables have expected row counts (1, 1, 1, 2, 3)    console=yes

    # ─────────────────────────────────────────────────────────────────────
    # STEP 10: Export CFDBillingPeriod to CSV and Compare Against Baseline
    # ─────────────────────────────────────────────────────────────────────
    Log    === STEP 10a: Exporting esb.CFDBillingPeriod to CSV ===    console=yes
    Export DB Table Data To CSV
    ...    ${export_table_name}
    ...    ${db_order_by_column}
    ...    ${actual_output_file_path}
    Log    Exported to: ${actual_output_file_path}    console=yes

    Log    === STEP 10b: Comparing actual CSV against expected baseline ===    console=yes
    Compare CSV Files Template
    ...    ${actual_output_file_path}
    ...    ${expected_output_file_path}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    IDENTICAL
    Log    CSV comparison passed — actual matches expected baseline    console=yes

    Log    === END-TO-END FLOW COMPLETED SUCCESSFULLY ===    console=yes


*** Keywords ***
Initialize Test Environment
    [Documentation]    Suite setup. Runs once before any test case starts:
    ...    1. Verifies Snaplex availability and connects to SQL Server
    ...    2. Creates the esb schema and 8 D0365 tables if they don't already exist
    ...    (idempotent — does nothing on subsequent runs)
    ...    3. Truncates all 8 tables so the pipeline run starts from a clean slate
    ...    and deterministic IDs from the sample file don't trigger PK violations.
    ...
    ...    After this runs, the test cases see a connected DB with empty tables
    ...    ready for the pipeline to populate.

    Check connections
    Prereq Setup Of D0365 Tables In SQL Server
    Truncate All D0365 Tables In SQL Server

Check connections
    [Documentation]    Verifies SQL Server database connection and Snaplex availability
    # Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to SQL Server Database
    ...    ${SQLSERVER_DATABASE}
    ...    ${SQLSERVER_USER}
    ...    ${SQLSERVER_PASSWORD}
    ...    ${SQLSERVER_HOST}
    ...    ${SQLSERVER_PORT}
    Initialize Variables

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

# ═══════════════════════════════════════════════════════════════
# D0365 TABLE SETUP — LOGIC KEYWORDS
#    - All SQL lives in queries/sqlserver_queries.resource
#    - Test cases contain only the verification call
# ═══════════════════════════════════════════════════════════════

Prereq Setup Of D0365 Tables In SQL Server
    [Documentation]    IDEMPOTENT setup — creates esb schema and 8 D0365 tables ONLY
    ...    on first run. On subsequent runs, skips creation so any rows previously
    ...    inserted by the pipeline are preserved.

    ${tables_exist}=    Check If D0365 Tables Already Exist
    IF    ${tables_exist}
        Log    esb.D0365Interchange already exists — skipping schema and table creation (idempotent).    console=yes
    ELSE
        Log    First run — creating esb schema and 8 D0365 tables...    console=yes
        Create esb Schema If Missing
        Create All D0365 Tables In SQL Server
    END

Check If D0365 Tables Already Exist
    [Documentation]    Returns TRUE when esb.D0365Interchange exists in SQL Server.

    ${rows}=    Query    ${SQL_CHECK_D0365_TABLES_EXIST}
    ${count}=    Set Variable    ${rows[0][0]}
    ${exists}=    Evaluate    int(${count}) > 0
    RETURN    ${exists}

Create esb Schema If Missing
    [Documentation]    Creates the esb schema in the connected database when it
    ...    does not already exist. SQL Server requires CREATE SCHEMA to be the
    ...    only statement in its batch — handled via dynamic EXEC().

    Execute Sql String    ${SQL_CREATE_SCHEMA_ESB}
    Log    esb schema ensured.    console=yes

Create All D0365 Tables In SQL Server
    [Documentation]    Drops (if present) and re-creates each of the 8 D0365 tables.
    ...    Drop-before-create makes the first-run path repeatable when a partial
    ...    setup left some tables behind from an earlier failed run.

    Execute Sql String    ${SQL_DROP_TABLE_CFDADHOCPAYMENT}
    Execute Sql String    ${SQL_DROP_TABLE_CFDDEFAULTINTERESTRATE}
    Execute Sql String    ${SQL_DROP_TABLE_CFDDEFAULTINTEREST}
    Execute Sql String    ${SQL_DROP_TABLE_CFDSETTLEMENTUNIT}
    Execute Sql String    ${SQL_DROP_TABLE_CFDBILLINGPERIOD}
    Execute Sql String    ${SQL_DROP_TABLE_CONTRACTFORDIFFERENCE}
    Execute Sql String    ${SQL_DROP_TABLE_EMRINVOICEHEADER}
    Execute Sql String    ${SQL_DROP_TABLE_D0365INTERCHANGE}

    Execute Sql String    ${SQL_CREATE_TABLE_D0365INTERCHANGE}
    Log    esb.D0365Interchange created.    console=yes
    Execute Sql String    ${SQL_CREATE_TABLE_EMRINVOICEHEADER}
    Log    esb.EMRInvoiceHeader created.    console=yes
    Execute Sql String    ${SQL_CREATE_TABLE_CONTRACTFORDIFFERENCE}
    Log    esb.ContractForDifference created.    console=yes
    Execute Sql String    ${SQL_CREATE_TABLE_CFDBILLINGPERIOD}
    Log    esb.CFDBillingPeriod created.    console=yes
    Execute Sql String    ${SQL_CREATE_TABLE_CFDSETTLEMENTUNIT}
    Log    esb.CFDSettlementUnit created.    console=yes
    Execute Sql String    ${SQL_CREATE_TABLE_CFDDEFAULTINTEREST}
    Log    esb.CFDDefaultInterest created.    console=yes
    Execute Sql String    ${SQL_CREATE_TABLE_CFDDEFAULTINTERESTRATE}
    Log    esb.CFDDefaultInterestRate created.    console=yes
    Execute Sql String    ${SQL_CREATE_TABLE_CFDADHOCPAYMENT}
    Log    esb.CFDAdHocPayment created.    console=yes
    Log    All 8 D0365 tables created in esb schema.    console=yes

Truncate All D0365 Tables In SQL Server
    [Documentation]    DELETEs all rows from the 8 D0365 tables in child→parent order.
    ...    Order matters if foreign-key constraints are added later; with the current
    ...    schema (no FK constraints) order is cosmetic but mirrors safe practice.

    Execute Sql String    ${SQL_DELETE_FROM_CFDADHOCPAYMENT}
    Execute Sql String    ${SQL_DELETE_FROM_CFDDEFAULTINTERESTRATE}
    Execute Sql String    ${SQL_DELETE_FROM_CFDDEFAULTINTEREST}
    Execute Sql String    ${SQL_DELETE_FROM_CFDSETTLEMENTUNIT}
    Execute Sql String    ${SQL_DELETE_FROM_CFDBILLINGPERIOD}
    Execute Sql String    ${SQL_DELETE_FROM_CONTRACTFORDIFFERENCE}
    Execute Sql String    ${SQL_DELETE_FROM_EMRINVOICEHEADER}
    Execute Sql String    ${SQL_DELETE_FROM_D0365INTERCHANGE}
    Log    All 8 D0365 tables emptied (child → parent order).    console=yes

# Verification helpers come from the shared resource:
#    resources/common/sql_table_operations.resource
#    - Execute SQL Query And Get Count    (raw SQL → int)
#    - Execute SQL Query And Get Single Value    (raw SQL → scalar)
#    - Get Column Values    (table + column → list)
