*** Settings ***
Documentation     SAPFTP → Oracle :: SIT Test Suite (Enhanced) :: Insertion Validation Only
Library           OperatingSystem
Library           DatabaseLibrary
Library           oracledb
Library           DependencyLibrary
Resource          snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource          ../../test_data/queries/oracle1_keywords.resource
Resource          ../../../resources/files.resource

Suite Setup       Prepare Suite Environment
Suite Teardown    Cleanup Suite Environment

*** Variables ***
# ===================================================================
# 🔧 PIPELINE-SPECIFIC CONFIGURATION (Set once at top — easy to change)
# ===================================================================
${PIPELINE_BASE_NAME}             SAPFTP_To_Oracle
${PIPELINE_FILENAME}               Replacement_Engine_Tracking_EOMP.slp
${INPUT_FILE_NAME}                 REPLENGTRACK.csv
${ORACLE_TARGET_SCHEMA}            SYSTEM
${ORACLE_TARGET_TABLE}             ENG_RCD_INPUT
${EXPECTED_ROW_COUNT}              3

@{EXPECTED_COLUMNS}
...                               BLD_DT
...                               CTRY
...                               CUSTREF
...                               DFA_FLEX
...                               DLR_CD
...                               DLR_MAIN
...                               DLR_MAIN_NM
...                               DLR_NM
...                               DTA_SRC

${M_CURR_DATE}                     2025-08-21

# ===================================================================
# 🌐 ENVIRONMENT & PATHS (from .env or dynamic)
# ===================================================================
${project_path}                   ${org_name}/${project_space}/${project_name}
${pipeline_file_path}             ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}         ${PIPELINE_FILENAME}

${account_payload_path}           ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}           acc_oracle.json

@{notification_states}            Completed    Failed
&{task_notifications}
...                               recipients=sapftp_notifications@yourorg.com
...                               states=${notification_states}

&{task_params}
...                               M_CURR_DATE=${M_CURR_DATE}
...                               Oracle_Account=shared/${ORACLE_ACCOUNT_NAME}

${upload_destination_file_path}   ${project_path}
${csv_folder}                     ${upload_destination_file_path}/csv
${CSV_FILE}                       ${INPUT_FILE_NAME}


*** Test Cases ***
Create Account
    [Documentation]    Creates the Oracle account required for SAPFTP → Oracle ETL pipeline.
    [Tags]    sapftp    oracle    connectivity    sit
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}


TC02_File_Availability_Check
    [Tags]    sapftp    oracle    file    sit
    Upload Input File
    Log To Console    ✅ File uploaded successfully: ${CSV_FILE}


TC03_PreFlight_Column_Validation
    [Tags]    oracle    preflight    sit
    ${db_columns}=    Get Oracle Table Columns    ${ORACLE_TARGET_SCHEMA}.${ORACLE_TARGET_TABLE}
    :FOR    ${col}    IN    @{EXPECTED_COLUMNS}
    \    Should Contain    ${db_columns}    ${col}
    Log To Console    ✅ All expected columns exist in ${ORACLE_TARGET_TABLE}


TC04_Run_Pipeline_And_Validate_Insertion
    [Tags]    sapftp    oracle    etl    sit
    Run SAPFTP Pipeline Task
    Log To Console    ✅ Pipeline executed successfully
    ${cnt}=    DatabaseLibrary.Query
    ...    SELECT COUNT(*) FROM ${ORACLE_TARGET_SCHEMA}.${ORACLE_TARGET_TABLE}
    Should Be Equal As Integers    ${cnt[0][0]}    ${EXPECTED_ROW_COUNT}
    Log To Console    ✅ Correct number of records (${EXPECTED_ROW_COUNT}) inserted


TC05_Validate_Inserted_Data
    [Tags]    sapftp    oracle    validation    sit
    ${cnt}=    DatabaseLibrary.Query
    ...    SELECT COUNT(*) FROM ${ORACLE_TARGET_SCHEMA}.${ORACLE_TARGET_TABLE}
    Should Be True    ${cnt[0][0]} > 0
    Log To Console    ✅ Data is present in ${ORACLE_TARGET_TABLE}


*** Keywords ***
Prepare Suite Environment
    Check Connections
    Initialize Variables
    Ensure Oracle Target Table Exists    ${ORACLE_TARGET_SCHEMA}.${ORACLE_TARGET_TABLE}
    Clean Oracle Target Table    ${ORACLE_TARGET_SCHEMA}.${ORACLE_TARGET_TABLE}
    Import SAPFTP Pipeline
    Upload Input File
    Create Task For SAPFTP Pipeline    BaseRun    ${CSV_FILE}


Cleanup Suite Environment
    Run Keyword And Ignore Error    Clean Oracle Target Table    ${ORACLE_TARGET_SCHEMA}.${ORACLE_TARGET_TABLE}
    Run Keyword And Ignore Error    Disconnect From Database


Import SAPFTP Pipeline
    Import Pipelines From Template
    ...    ${unique_id}
    ...    ${pipeline_file_path}
    ...    ${pipeline_name}
    ...    ${BASE_PIPELINE_FILENAME}
    Sleep    5s


Create Task For SAPFTP Pipeline
    [Arguments]    ${test_name}    ${source_file}
    ${task_name}=    Catenate    SEPARATOR=_    ${PIPELINE_BASE_NAME}_Task    ${unique_id}    ${test_name}
    Set Suite Variable    ${task_name}
    &{local_params}=    Copy Dictionary    ${task_params}
    Set To Dictionary    ${local_params}    filePath    ${csv_folder}/${source_file}
    File Should Exist
    ...    ${CURDIR}/../../test_data/actual_expected_data/input_data/${source_file}
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${local_params}
    ...    ${task_notifications}


Run SAPFTP Pipeline Task
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}


Upload Input File
    Upload File Using File Protocol Template
    ...    file://${CURDIR}/../../test_data/actual_expected_data/input_data/${CSV_FILE}
    ...    ${csv_folder}


Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Oracle Database
    ...    ${ORACLE_DBNAME}
    ...    ${ORACLE_DBUSER}
    ...    ${ORACLE_DBPASS}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_DBPORT}


Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    SEPARATOR=_    ${PIPELINE_BASE_NAME}    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${ORACLE_ACCOUNT_NAME}    Oracle_Account_${unique_id}


Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}


Ensure Oracle Target Table Exists
    [Arguments]    ${table_name}
    ${probe}=    Run Keyword And Ignore Error
    ...    DatabaseLibrary.Query
    ...    SELECT 1 FROM ${table_name} WHERE ROWNUM = 1
    Run Keyword If    '${probe[0]}' == 'FAIL'
    ...    Fail    Table ${table_name} does not exist or is inaccessible.


Clean Oracle Target Table
    [Arguments]    ${table_name}
    ${result}=    Run Keyword And Ignore Error
    ...    DatabaseLibrary.Execute Sql String
    ...    TRUNCATE TABLE ${table_name}
    Run Keyword If    '${result[0]}' == 'FAIL'
    ...    DatabaseLibrary.Execute Sql String
    ...    DELETE FROM ${table_name}


Get Oracle Table Columns
    [Arguments]    ${table_name}
    # Extract schema and table
    ${parts}=    Split String    ${table_name}    .
    ${schema}=    Set Variable If    ${parts.__len__()} > 1    ${parts}[0]    SYSTEM
    ${table}=    Set Variable    ${parts}[-1]

    ${columns}=    DatabaseLibrary.Query
    ...    SELECT column_name FROM all_tab_columns WHERE table_name=UPPER('${table}') AND owner=UPPER('${schema}')
    ${column_list}=    Create List
    :FOR    ${row}    IN    @{columns}
    \    Append To List    ${column_list}    ${row[0]}
    RETURN    ${column_list}