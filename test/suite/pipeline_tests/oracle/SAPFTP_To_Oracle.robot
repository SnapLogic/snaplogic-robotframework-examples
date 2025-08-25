*** Settings ***
Documentation    SAPFTP → Oracle :: End-to-End ETL & Integration Suite
Library          OperatingSystem
Library          DatabaseLibrary
Library          oracledb
Library          DependencyLibrary
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../test_data/queries/oracle1_keywords.resource
Resource         ../../../resources/files.resource

Suite Setup      Prepare Suite Environment And Pipeline
Suite Teardown   Cleanup Suite Environment


*** Variables ***
${project_path}                  ${org_name}/${project_space}/${project_name}
${pipeline_file_path}            ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}        Replacement_Engine_Tracking_EOMP.slp
${account_payload_path}          ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}          acc_oracle.json

@{notification_states}           Completed    Failed
&{task_notifications}
...                             recipients=sapftp_notifications@yourorg.com
...                             states=${notification_states}
${CURRENT_DATE}                  2025-08-21
&{task_params}
...                             M_CURR_DATE=${CURRENT_DATE}
...                             Oracle_Account=shared/${ORACLE_ACCOUNT_NAME}

${upload_source_file_path}       ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${upload_destination_file_path}  ${project_path}


*** Test Cases ***
Create Oracle Account
    [Tags]    sapftp    oracle    regression    infra
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Upload Expression Library And Test Data
    [Tags]    sapftp    oracle    regression    infra
    [Template]    Upload File Using File Protocol Template
    file:///opt/snaplogic/test_data/actual_expected_data/expression_libraries/SAPFTP_To_Oracle.expr    ${upload_destination_file_path}
    file:///app/test/suite/test_data/actual_expected_data/expression_libraries/SAPFTP_To_Oracle.expr    ${upload_destination_file_path}/app_mount
    file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/SAPFTP_To_Oracle.expr    ${upload_destination_file_path}/curdir

Upload CSV Test Data Files
    [Tags]    sapftp    oracle    regression    infra
    [Template]    Upload File Using File Protocol Template
    file://${CURDIR}/../../test_data/actual_expected_data/csv/engine_tracking_insert.csv    ${upload_destination_file_path}/csv
    file://${CURDIR}/../../test_data/actual_expected_data/csv/engine_tracking_merge.csv     ${upload_destination_file_path}/csv

TC_001_Oracle_Insert_6_Rows
    [Tags]    sapftp    oracle    etl
    Ensure Oracle ENGINE_TRACKING Table
    Clean Oracle ENGINE_TRACKING
    Create Task For SAPFTP Pipeline    TC_001_Oracle_Insert_6_Rows
    Run SAPFTP Pipeline Task
    ${cnt}=    Get Oracle ENGINE_TRACKING Count
    Should Be Equal As Integers    ${cnt}    6

TC_002_Oracle_Merge_Update_And_Insert
    [Tags]    sapftp    oracle    etl
    Ensure Oracle ENGINE_TRACKING Table
    Create Task For SAPFTP Pipeline    TC_002_Oracle_Merge_Update_And_Insert
    Run SAPFTP Pipeline Task
    ${cnt}=    Get Oracle ENGINE_TRACKING Count
    Should Be Equal As Integers    ${cnt}    10

TC_003_Invalid_Source_File_Path
    [Tags]    sapftp    oracle    negative
    [Template]    Upload File Using File Protocol Template
    file:///nonexistent/path/invalid.csv    ${upload_destination_file_path}/csv/invalid

TC_004_Invalid_Target_Table
    [Tags]    sapftp    oracle    negative
    ${result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    SELECT COUNT(*) FROM SYSTEM.NON_EXISTENT_TABLE
    Should Be Equal    ${result[0]}    FAIL    msg=Invalid target table should fail


*** Keywords ***
Prepare Suite Environment And Pipeline
    Prepare Environment
    Ensure Oracle ENGINE_TRACKING Table
    Clean Oracle ENGINE_TRACKING
    Import SAPFTP Pipeline
    Create Task For SAPFTP Pipeline    suite_run
    Run SAPFTP Pipeline Task

Cleanup Suite Environment
    Clean Oracle ENGINE_TRACKING
    Disconnect From Database

Import SAPFTP Pipeline
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${BASE_PIPELINE_FILENAME}
    Sleep    5s

Create Task For SAPFTP Pipeline
    [Arguments]    ${test_name}
    ${task_name}=    Catenate    SAPFTP_To_Oracle_Task_    ${unique_id}    _${test_name}
    Set Test Variable    ${task_name}
    Create Triggered Task From Template
    ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}    ${task_params}    ${task_notifications}

Run SAPFTP Pipeline Task
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}    M_CURR_DATE=${CURRENT_DATE}

Prepare Environment
    Check Connections
    Initialize Variables

Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    SAPFTP_To_Oracle_    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${pipeline_name_slp}    ${BASE_PIPELINE_FILENAME}
    Set Suite Variable    ${ORACLE_ACCOUNT_NAME}    Oracle_Account_${unique_id}

Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}
