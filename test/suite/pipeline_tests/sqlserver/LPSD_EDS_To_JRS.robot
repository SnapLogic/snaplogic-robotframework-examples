*** Settings ***
Documentation    LPSD_EDS_To_JRS :: End-to-End ETL & Integration Suite (SQL Server → SnapLogic → JRS)
Library          OperatingSystem
Library          DatabaseLibrary
Library          pymssql
Library          DependencyLibrary
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../test_data/queries/sqlserver_queries.resource
Resource         ../../../resources/files.resource

Suite Setup      Prepare Suite Environment And Pipeline
Suite Teardown   Cleanup Suite Environment

*** Variables ***
${project_path}                  ${org_name}/${project_space}/${project_name}
${pipeline_file_path}            ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}        LPSD_EDS_To_JRS.slp
${account_payload_path}          ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}          acc_sqlserver.json

@{notification_states}           Completed    Failed
&{task_notifications}
...                             recipients=lpsd_notifications@yourorg.com
...                             states=${notification_states}
${CURRENT_DATE}                  2025-08-20
&{task_params}
...                             M_CURR_DATE=${CURRENT_DATE}
...                             SQLServer_Account=shared/${SQLSERVER_ACCOUNT_NAME}

${upload_source_file_path}       ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${upload_destination_file_path}  ${project_path}


*** Test Cases ***
Create SQL Server Account
    [Tags]    lpsd    sqlserver    regression    infra
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Upload Expression Libraries
    [Tags]    lpsd    sqlserver    regression    infra
    [Template]    Upload File Using File Protocol Template
    file:///opt/snaplogic/test_data/actual_expected_data/expression_libraries/LPSD_EDS_To_JRS.expr    ${upload_destination_file_path}
    file:///app/test/suite/test_data/actual_expected_data/expression_libraries/LPSD_EDS_To_JRS.expr    ${upload_destination_file_path}/app_mount
    file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/LPSD_EDS_To_JRS.expr    ${upload_destination_file_path}/curdir

TC_001A_SQLServer_Insert
    [Tags]    lpsd    sqlserver    etl    regression
    Ensure SQL Server Staging Table
    Clean SQL Server Staging Table
    Insert 100 Rows Into SQL Server Staging
    ${staging_cnt}=    Get SQL Server Staging Count
    Should Be Equal As Integers    ${staging_cnt}    100

TC_001B_SQLServer_Execute
    [Tags]    lpsd    sqlserver    etl    regression
    Ensure SQL Server Target Table
    Clean SQL Server Target Table
    Create Task For LPSD Pipeline    TC_001B_SQLServer_Execute
    Run LPSD Pipeline Task
    ${target_cnt}=    Get SQL Server Target Count
    Should Be Equal As Integers    ${target_cnt}    100

TC_002A_E2E_Pipeline_Insert
    [Tags]    lpsd    sqlserver    pipeline    e2e
    Ensure SQL Server Staging Table
    Clean SQL Server Staging Table
    Insert 100 Rows Into SQL Server Staging
    Create Task For LPSD Pipeline    TC_002A_E2E_Pipeline_Insert
    Run LPSD Pipeline Task
    ${staging_cnt}=    Get SQL Server Staging Count
    Should Be Equal As Integers    ${staging_cnt}    100

TC_002B_E2E_Pipeline_Execute
    [Tags]    lpsd    sqlserver    pipeline    e2e
    Ensure SQL Server Target Table
    Clean SQL Server Target Table
    Create Task For LPSD Pipeline    TC_002B_E2E_Pipeline_Execute
    Run LPSD Pipeline Task
    ${target_cnt}=    Get SQL Server Target Count
    Should Be Equal As Integers    ${target_cnt}    100

TC_003A_Invalid_File
    [Tags]    lpsd    sqlserver    negative    regression
    # Upload a broken expr file or wrong path
    [Template]    Upload File Using File Protocol Template
    file:///nonexistent/path/invalid.expr    ${upload_destination_file_path}/invalid

TC_003B_Invalid_Target_Table
    [Tags]    lpsd    sqlserver    negative    regression
    ${result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    SELECT COUNT(*) FROM JRS_NON_EXISTENT
    Should Be Equal    ${result[0]}    FAIL    msg=Invalid target table should fail


*** Keywords ***
Prepare Suite Environment And Pipeline
    Prepare Environment
    Ensure SQL Server Staging Table
    Ensure SQL Server Target Table
    Clean SQL Server Staging Table
    Clean SQL Server Target Table
    Import LPSD Pipeline
    Create Task For LPSD Pipeline    suite_run
    Run LPSD Pipeline Task

Cleanup Suite Environment
    Clean SQL Server Staging Table
    Clean SQL Server Target Table
    Close All Database Connections

Import LPSD Pipeline
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${BASE_PIPELINE_FILENAME}
    Sleep    5s

Create Task For LPSD Pipeline
    [Arguments]    ${test_name}
    ${task_name}=    Catenate    LPSD_EDS_To_JRS_Task_    ${unique_id}    _${test_name}
    Set Test Variable    ${task_name}
    Create Triggered Task From Template
    ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}    ${task_params}    ${task_notifications}

Run LPSD Pipeline Task
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}    M_CURR_DATE=${CURRENT_DATE}

Prepare Environment
    Check Connections
    Initialize Variables

Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To SQL Server Database    ${SQLSERVER_DBNAME}    ${SQLSERVER_DBUSER}    ${SQLSERVER_DBPASS}    ${SQLSERVER_HOST}    ${SQLSERVER_DBPORT}

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    LPSD_EDS_To_JRS_    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${pipeline_name_slp}    ${BASE_PIPELINE_FILENAME}
    Set Suite Variable    ${SQLSERVER_ACCOUNT_NAME}    SQLServer_Account_${unique_id}

Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}
