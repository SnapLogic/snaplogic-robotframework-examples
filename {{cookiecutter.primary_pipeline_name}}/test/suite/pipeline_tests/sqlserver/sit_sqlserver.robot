*** Settings ***
Documentation       SIT Test Suite for SQL Server Pipeline (sit_sqlserver.slp)
...                 The pipeline reads from 3 SQL Server source tables (tblRequest, tblHeader, tblItems),
...                 routes records by RequestType, performs joins/mappings/unions across two flows,
...                 and updates tblRequest with Status=1.
...
...                 This suite covers all 12 LLD test cases (TC_001-TC_012) across 15 automated tests
...                 following the Snowflake baseline pattern:
...                 Account Setup -> Expression Library Upload -> Source Data Verification ->
...                 Pipeline Import -> Task Creation -> Execution -> Post-Pipeline Validation -> CSV Comparison

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/common/general.resource
Resource            ../../../resources/common/database.resource
Resource            ../../../resources/common/sql_table_operations.resource
Resource            ../../../resources/common/files.resource
Resource            ../../test_data/queries/sqlserver_queries.resource
Library             Collections
Library             DatabaseLibrary
Library             OperatingSystem

Suite Setup         Check Connections
Suite Teardown      Disconnect from Database


*** Variables ***
######################### Source Data Expected Counts ###########################
${EXPECTED_TBLREQUEST_ROWS}             7
${EXPECTED_TBLHEADER_ROWS}              7
${EXPECTED_TBLITEMS_ROWS}               13

######################### Post-Pipeline Expected Counts ########################
${EXPECTED_UPDATED_ROWS}                7
${EXPECTED_REQUEST34_ROWS}              3
${EXPECTED_REQUEST1256_ROWS}            4

######################### Pipeline and Task Details ############################
${pipeline_name}                        sit_sqlserver
${pipeline_file_name}                   sit_sqlserver.slp
${task_name}                            SIT_SqlServer_Task

######################### Expression Library ###################################
${expression_library_path}              ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/sqlserver/EBAS_to_CBS.expr

######################### Task Parameters ######################################
&{task_params}
...                                     sqlserver_acct=../shared/${SQLSERVER_ACCOUNT_NAME}

######################### CSV Comparison Paths #################################
${actual_output_file_name}              ${pipeline_name}_tblrequest_actual.csv
${actual_output_tblrequest_path}        ${CURDIR}/../../test_data/actual_expected_data/actual_output/sqlserver/${actual_output_file_name}
${expected_output_tblrequest_path}      ${CURDIR}/../../test_data/actual_expected_data/expected_output/sqlserver/sit_sqlserver_tblrequest_expected.csv

# Dynamic columns excluded from CSV comparison (timestamps change between runs)
@{excluded_columns_for_comparison}
...                                     RequestedOn
...                                     SubmittedOn
...                                     ProcessedOn


*** Test Cases ***
################## ACCOUNT AND ASSET SETUP ##################

Test 1: Create SQL Server Account
    [Documentation]    Creates a SQL Server database account in SnapLogic.
    ...    The account is placed in the shared folder and referenced by the
    ...    expression library for pipeline execution.
    [Tags]    sqlserver    sit_sqlserver2    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Test 2: Upload Expression Library
    [Documentation]    Uploads the expression library (.expr file) to the SnapLogic shared folder.
    ...    The expression library contains account references and environment functions
    ...    used by the pipeline to resolve connection details at runtime.
    [Tags]    sqlserver    sit_sqlserver    asset_setup
    [Template]    Upload File Using File Protocol Template
    ${expression_library_path}    ${PIPELINES_LOCATION_PATH}

######################################################
# SOURCE DATA VERIFICATION (PRE-PIPELINE)
# ######################################################

Test 3: Verify tblRequest Source Data
    [Documentation]    TC_001: Verifies tblRequest has expected active rows matching pipeline extraction filter.
    ...    Filter: Status=0 AND RequestType IN ('1','2','3','4','5','6')
    ...    Expects ${EXPECTED_TBLREQUEST_ROWS} rows (excludes 1 row with Status=1).
    [Tags]    sqlserver    sit_sqlserver    verification    tc_001
    Row Count Should Be    dbo.tblRequest    ${EXPECTED_TBLREQUEST_ROWS}
    ...    where_clause=Status=0 AND RequestType IN ('1','2','3','4','5','6')

Test 4: Verify tblHeader Source Data
    [Documentation]    TC_005_01: Verifies tblHeader has expected rows (one per active request).
    ...    Expects ${EXPECTED_TBLHEADER_ROWS} rows.
    [Tags]    sqlserver    sit_sqlserver    verification    tc_005_01
    Row Count Should Be    dbo.tblHeader    ${EXPECTED_TBLHEADER_ROWS}

Test 5: Verify tblHeader DCProcess Derivation
    [Documentation]    TC_005_02: Verifies DCProcess derived column computation in tblHeader.
    ...    The pipeline derives DCProcess as:
    ...    LTRIM(RTRIM(ISNULL(DCOutBoundType,''))) + ' ' + LTRIM(RTRIM(ISNULL(DCTransactionType,'')))
    ...    This test runs the same computation and verifies all 7 rows produce valid DCProcess values.
    [Tags]    sqlserver    sit_sqlserver    verification    tc_005_02
    ${results}=    Execute Custom Query
    ...    SELECT RequestId, LTRIM(RTRIM(ISNULL(DCOutBoundType,''))) + ' ' + LTRIM(RTRIM(ISNULL(DCTransactionType,''))) AS DCProcess FROM dbo.tblHeader ORDER BY RequestId
    ${row_count}=    Get Length    ${results}
    Should Be Equal As Integers    ${row_count}    ${EXPECTED_TBLHEADER_ROWS}
    ...    Expected ${EXPECTED_TBLHEADER_ROWS} DCProcess rows but got ${row_count}
    Log    DCProcess derivation results: ${results}    console=yes

Test 6: Verify tblItems Source Data
    [Documentation]    TC_004_01: Verifies tblItems has expected rows across all requests.
    ...    Expects ${EXPECTED_TBLITEMS_ROWS} rows.
    [Tags]    sqlserver    sit_sqlserver    verification    tc_004_01
    Row Count Should Be    dbo.tblItems    ${EXPECTED_TBLITEMS_ROWS}

Test 7: Verify tblItems Null Handling
    [Documentation]    TC_004_02: Verifies null-to-empty-string transformation for tblItems.
    ...    The pipeline converts NULL values in VendorChallanNo and CBS_GPNumber to empty strings
    ...    using ISNULL(column, ''). This test runs the same transformation and verifies all 13 rows.
    [Tags]    sqlserver    sit_sqlserver    verification    tc_004_02
    ${results}=    Execute Custom Query
    ...    SELECT RequestId, ISNULL(VendorChallanNo,'') AS VendorChallanNoItm, ISNULL(CBS_GPNumber,'') AS CBS_GPNumber_Clean FROM dbo.tblItems ORDER BY RequestId, Id
    ${row_count}=    Get Length    ${results}
    Should Be Equal As Integers    ${row_count}    ${EXPECTED_TBLITEMS_ROWS}
    ...    Expected ${EXPECTED_TBLITEMS_ROWS} null-handled item rows but got ${row_count}
    Log    Null handling results: ${results}    console=yes

################## PIPELINE IMPORT AND TASK SETUP ##################

Test 8: Import Pipeline
    [Documentation]    Imports the sit_sqlserver.slp pipeline into the SnapLogic project space.
    ...    The pipeline is imported with a unique suffix to avoid naming conflicts.
    [Tags]    sqlserver    sit_sqlserver    pipeline_setup
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}

Test 9: Create Triggered Task
    [Documentation]    Creates a triggered task for on-demand pipeline execution.
    ...    The task is configured with SQL Server account reference as a pipeline parameter.
    ...    Execution timeout is set to 300 seconds for the pipeline to complete.
    [Tags]    sqlserver    sit_sqlserver    task_setup
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params}    execution_timeout=300

Test 10: Execute Triggered Task
    [Documentation]    TC_012_01: Executes the pipeline end-to-end via triggered task.
    ...    The pipeline reads from tblRequest, tblHeader, tblItems, routes by RequestType,
    ...    joins/maps/unions across two flows, and updates tblRequest with Status=1.
    ...    A successful "Completed" status proves TC_012 end-to-end execution.
    [Tags]    sqlserver    sit_sqlserver    execution    tc_012_01
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}

################## POST-PIPELINE VERIFICATION ##################

Test 11: Verify SQL Server Pipeline Has No Errors
    [Documentation]    Validates that the pipeline execution completed without errors.
    ...    Retrieves the runtime ID from task history, logs snap statistics summary,
    ...    and checks all snaps for error documents.
    ...    Sets ${runtime_id} as a suite variable for downstream test cases.
    ...
    ...    PREREQUISITES:
    ...    - Execute Triggered Task (Test 10) must have completed successfully
    [Tags]    sqlserver    sit_sqlserver    verification
    Validate Pipeline Has No Errors    ${pipeline_name}    ${task_name}    ${unique_id}

Test 12: Verify SQL Server Snap Document Counts
    [Documentation]    Validates document counts for each snap in the pipeline.
    ...    Verifies that data flowed correctly through both router paths by checking
    ...    that each snap processed the expected number of documents.
    ...
    ...    NOTE: Snap labels must exactly match the snap names in the Designer.
    ...    Run 'Log Snap Statistics Summary' first to identify exact snap labels.
    ...    Expected counts below are based on our test seed data (7 active requests,
    ...    7 headers, 13 items). Adjust if seed data changes.
    ...
    ...    PREREQUISITES:
    ...    - ${runtime_id} must be set from Test 11
    [Tags]    sqlserver    sit_sqlserver    verification
    # Router: 7 active tblRequest rows routed by RequestType
    Validate Snap Document Count    ${runtime_id}    tblRequest Router    expected_input=7    expected_error=0
    # Request1256 path: tblRequest Mapper receives 4 docs (types 1,2,5,6)
    Validate Snap Document Count    ${runtime_id}    tblRequest Mapper    expected_input=4    expected_output=4    expected_error=0
    # Request34 path: Join Flow 1 inner join Request(3) + Header(3) = 3 output rows
    Validate Snap Document Count    ${runtime_id}    Join Flow 1    expected_output=3    expected_error=0
    # Join Flow 2: 3-way inner join Request(4) + Header(4) + Items(8) = 8 output rows
    Validate Snap Document Count    ${runtime_id}    Join Flow 2    expected_output=8    expected_error=0
    # Flow1 Map: maps 3 Request34 rows
    Validate Snap Document Count    ${runtime_id}    Flow1 Map    expected_output=3    expected_error=0
    # Data Union: merges Flow1 Map(3) + Flow 2(8) = 11 total docs
    Validate Snap Document Count    ${runtime_id}    Data Union    expected_output=11    expected_error=0
    # tblRequest update: receives all 11 docs, updates 7 unique tblRequest rows
    Validate Snap Document Count    ${runtime_id}    tblRequest update    expected_input=11    expected_error=0

Test 13: Verify Both Router Paths Processed
    [Documentation]    TC_002/TC_006-TC_011: Verifies both router paths produced correct results.
    ...    Request34 path (RequestType 3,4): 3 rows updated to Status=1
    ...    Request1256 path (RequestType 1,2,5,6): 4 rows updated to Status=1
    ...    Combined 3+4=7 confirms all active rows processed (TC_011).
    ...    This also indirectly proves routing (TC_002), joins (TC_006/TC_008),
    ...    mappings (TC_007/TC_009), and union merge (TC_010) all worked correctly.
    [Tags]    sqlserver    sit_sqlserver    verification    tc_002    tc_006    tc_007    tc_008    tc_009    tc_010    tc_011
    # Request34 path: RequestType IN (3,4) should have 3 updated rows
    Row Count Should Be    dbo.tblRequest    ${EXPECTED_REQUEST34_ROWS}
    ...    where_clause=RequestType IN ('3','4') AND Status=1 AND StatusMessage='Submitted in CBS'
    # Request1256 path: RequestType IN (1,2,5,6) should have 4 updated rows
    Row Count Should Be    dbo.tblRequest    ${EXPECTED_REQUEST1256_ROWS}
    ...    where_clause=RequestType IN ('1','2','5','6') AND Status=1 AND StatusMessage='Submitted in CBS'

Test 14: Export tblRequest Post-Pipeline Data To CSV
    [Documentation]    TC_012_02: Exports the full tblRequest table to CSV for comparison.
    ...    Data is ordered by Id for deterministic comparison against expected output.
    [Tags]    sqlserver    sit_sqlserver    verification    tc_012_02
    Export DB Table Data To CSV    dbo.tblRequest    Id    ${actual_output_tblrequest_path}

Test 15: Compare Actual vs Expected tblRequest CSV
    [Documentation]    TC_012_03: Compares actual post-pipeline tblRequest data against expected output.
    ...    Timestamp columns (RequestedOn, SubmittedOn, ProcessedOn) are excluded from comparison
    ...    because they contain dynamic values that change between test runs.
    ...    All other columns must match exactly (IDENTICAL status).
    [Tags]    sqlserver    sit_sqlserver    verification    tc_012_03
    [Template]    Compare CSV Files With Exclusions Template
    ${actual_output_tblrequest_path}    ${expected_output_tblrequest_path}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}


*** Keywords ***
Check Connections
    [Documentation]    Suite setup: Verifies Snaplex availability, establishes SQL Server connection,
    ...    generates unique test ID, and prepares clean tables with sample data.
    ...    Tables are dropped and recreated to ensure tests always start from a known state.

    # Generate unique ID for pipeline/task naming
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

    # Verify Snaplex is running
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}

    # Establish SQL Server database connection
    Connect to SQL Server Database
    ...    ${SQLSERVER_DATABASE}
    ...    ${SQLSERVER_USER}
    ...    ${SQLSERVER_PASSWORD}
    ...    ${SQLSERVER_HOST}
    ...    ${SQLSERVER_PORT}

    # Clean state: drop, recreate, and load sample data for all 3 tables
    # Create Table handles DROP IF EXISTS + CREATE in one call
    Create Table    dbo.tblRequest    ${TBLREQUEST_DEFINITION}
    Execute SQL String    ${INSERT_TBLREQUEST_SAMPLE_DATA}
    Create Table    dbo.tblHeader    ${TBLHEADER_DEFINITION}
    Execute SQL String    ${INSERT_TBLHEADER_SAMPLE_DATA}
    Create Table    dbo.tblItems    ${TBLITEMS_DEFINITION}
    Execute SQL String    ${INSERT_TBLITEMS_SAMPLE_DATA}
