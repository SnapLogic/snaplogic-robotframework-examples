*** Settings ***
Documentation     LPSD EDS → JRS :: Negative SIT Test Suite (Expected Failure - Validate Error Handling)
Library           OperatingSystem
Library           DatabaseLibrary
Library           DependencyLibrary
Resource          snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource          ../../../resources/files.resource
Resource          ../../../resources/email_utils.resource

Suite Setup       Prepare Suite Environment
Suite Teardown    Cleanup Suite Environment

*** Variables ***
# ===================================================================
# 🔧 PIPELINE-SPECIFIC CONFIGURATION (Set once at top — easy to change)
# ===================================================================
${PIPELINE_BASE_NAME}             LPSD_EDS_To_JRS
${PIPELINE_FILENAME}               LPSD_EDS_To_JRS.slp
${INPUT_FILE_NAME}                 sample_fixed_width_file.txt
${REJECTION_FILE_NAME}             error_data.txt
${SQL_TARGET_TABLE}                EDS_RSN_DTA
${M_CURR_DATE}                     2025-08-31

# ===================================================================
# 🌐 ENVIRONMENT VARIABLES (from .env — shared across suites)
# ===================================================================
${MAILDEV_URL}                    http://maildev-test:1080
${EMAIL_RECIPIENT}                ${EMAIL_ID}    # from .env
${ERROR_EMAIL_RECIPIENT}          spamula@snaplogic.com

# Project & Pipeline Paths
${project_path}                   ${org_name}/${project_space}/${project_name}
${pipeline_file_path}             ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}         ${PIPELINE_FILENAME}

# Account Payload
${account_payload_path}           ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}           acc_sqlserver.json

# Notification Settings
@{notification_states}            Completed    Failed
&{task_notifications}
...                               recipients=${ERROR_EMAIL_RECIPIENT}
...                               states=${notification_states}

# Pipeline Parameters
&{task_params}
...                               M_CURR_DATE=${M_CURR_DATE}
...                               SQLServer_Account=shared/${SQLSERVER_ACCOUNT_NAME}
...                               SMTP_HOST=maildev-test
...                               SMTP_PORT=1025
...                               EMAIL_FROM=test@snaplogic.com
...                               EMAIL_TO=${EMAIL_RECIPIENT}

# File Upload Settings
${upload_destination_file_path}   ${project_path}
${input_folder}                   ${upload_destination_file_path}
${INPUT_FILE}                     ${INPUT_FILE_NAME}

# Rejection File Path
${REJECTION_FILE_PATH}            ${project_path}/${REJECTION_FILE_NAME}


*** Test Cases ***
TC01_SQLServer_Connectivity_Validation
    [Tags]    lpsd    sqlserver    connectivity    negative    sit
    Log    ✅ SQL Server connection validated successfully


TC02_File_Availability_Check
    [Tags]    lpsd    file    negative    sit
    Upload Input File
    Log To Console    ✅ File uploaded successfully: ${INPUT_FILE}


TC03_Validate_Line_Endings
    [Tags]    lpsd    preprocessing    negative    sit
    ${file}=    Get File    ${CURDIR}/../../test_data/input_files/${INPUT_FILE}
    Should Not Contain    ${file}    \r\n
    Log To Console    ✅ File contains only UNIX LF line endings


TC04_Run_Pipeline_Once
    [Tags]    lpsd    etl    negative    sit
    Run LPSD Pipeline Task
    Log To Console    ✅ Pipeline executed (expected to fail due to schema error)


TC05_Validate_No_Records_Inserted
    [Tags]    lpsd    sqlserver    negative    validation
    Sleep    30 seconds
    ${query}=    Catenate    SEPARATOR=\n
    ...    SELECT COUNT(*) FROM ${SQL_TARGET_TABLE}
    ${cnt}=    DatabaseLibrary.Query    ${query}
    ${actual_count}=    Convert To Integer    ${cnt[0][0]}
    Should Be Equal As Integers    ${actual_count}    0
    Log To Console    ✅ No records in ${SQL_TARGET_TABLE} (expected)


TC06_Validate_Email_Notification
    [Tags]    lpsd    email    sit
    Setup MailDev Connection    ${MAILDEV_URL}
    Purge All Emails    ${MAILDEV_URL}

    Wait Until Keyword Succeeds    180s    6s    Run LPSD Pipeline Task

    Wait For Email    120s    5s    ${MAILDEV_URL}

    ${email_count}=    Get Email Count    ${MAILDEV_URL}
    Should Be True    ${email_count} > 0    msg=No email was sent

    Verify Email TO Recipient    ${ERROR_EMAIL_RECIPIENT}    ${True}    ${MAILDEV_URL}

    Log To Console    ✅ Email notification received and validated successfully


TC07_Debug_List_All_Tables
    [Tags]    debug    sqlserver
    ${tables}=    DatabaseLibrary.Query
    ...    SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'
    Log List    ${tables}
    Log To Console    📋 All tables in SQL Server: ${tables}


*** Keywords ***
Prepare Suite Environment
    Check Connections
    Initialize Variables
    Ensure Target Table Exists    ${SQL_TARGET_TABLE}
    Clean Target Table    ${SQL_TARGET_TABLE}
    Import LPSD Pipeline
    Upload Input File
    Create Task For LPSD Pipeline    BaseRun    ${INPUT_FILE}


Cleanup Suite Environment
    Run Keyword And Ignore Error    Clean Target Table    ${SQL_TARGET_TABLE}
    Run Keyword And Ignore Error    Disconnect From Database


Import LPSD Pipeline
    Import Pipelines From Template
    ...    ${unique_id}
    ...    ${pipeline_file_path}
    ...    ${pipeline_name}
    ...    ${BASE_PIPELINE_FILENAME}
    Sleep    5s


Create Task For LPSD Pipeline
    [Arguments]    ${test_name}    ${source_file}
    ${task_name}=    Catenate    SEPARATOR=_    ${PIPELINE_BASE_NAME}_Task    ${unique_id}    ${test_name}
    Set Suite Variable    ${task_name}
    &{local_params}=    Copy Dictionary    ${task_params}
    Set To Dictionary    ${local_params}    filePath    ${input_folder}/${source_file}
    Set To Dictionary    ${local_params}    execution_timeout    300
    File Should Exist    ${CURDIR}/../../test_data/input_files/${source_file}
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${local_params}
    ...    ${task_notifications}


Run LPSD Pipeline Task
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}


Upload Input File
    Upload File Using File Protocol Template
    ...    file://${CURDIR}/../../test_data/input_files/${INPUT_FILE}
    ...    ${input_folder}


Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Database Using Custom Params


Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    SEPARATOR=_    ${PIPELINE_BASE_NAME}    ${unique_id}
    Set Suite Variable    ${pipeline_name}


Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}


Ensure Target Table Exists
    [Arguments]    ${table_name}
    ${probe}=    Run Keyword And Ignore Error
    ...    DatabaseLibrary.Query
    ...    SELECT 1 FROM ${table_name}
    Run Keyword If    '${probe[0]}' == 'FAIL'
    ...    Fail    Table ${table_name} does not exist or is inaccessible.


Clean Target Table
    [Arguments]    ${table_name}
    ${result}=    Run Keyword And Ignore Error
    ...    DatabaseLibrary.Execute Sql String
    ...    TRUNCATE TABLE ${table_name}
    Run Keyword If    '${result[0]}' == 'FAIL'
    ...    DatabaseLibrary.Execute Sql String
    ...    DELETE FROM ${table_name}


Connect To Database Using Custom Params
    Connect To Database
    ...    pymssql
    ...    ${SQLSERVER_DBNAME}
    ...    ${SQLSERVER_DBUSER}
    ...    ${SQLSERVER_DBPASS}
    ...    ${SQLSERVER_HOST}
    ...    ${SQLSERVER_DBPORT}


Wait For Email
    [Arguments]    ${timeout}=120s    ${interval}=5s    ${maildev_url}=${MAILDEV_URL}
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Check Email Arrived    ${maildev_url}


Check Email Arrived
    [Arguments]    ${maildev_url}=${MAILDEV_URL}
    ${count}=    Get Email Count    ${maildev_url}
    Should Be True    ${count} > 0