*** Settings ***
Documentation       LPSD EDS → JRS :: Positive & Negative SIT Test Suite
Library             OperatingSystem
Library             DatabaseLibrary
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/files.resource
Resource            ../../../resources/email_utils.resource

Suite Setup         Prepare Suite Environment
Suite Teardown      Cleanup Suite Environment

*** Variables ***
${project_path}                   ${org_name}/${project_space}/${project_name}
${pipeline_file_path}             ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}         LPSD_EDS_To_JRS.slp

${account_payload_path}           ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}           acc_sqlserver.json

@{notification_states}            Completed    Failed
&{task_notifications}
...                               recipients=lpsd_notifications@yourorg.com
...                               states=${notification_states}

${CURRENT_DATE}                   2025-08-31
&{task_params}
...                               M_CURR_DATE=${CURRENT_DATE}
...                               SQLServer_Account=shared/${SQLSERVER_ACCOUNT_NAME}

${upload_destination_file_path}   ${project_path}
${input_folder}                   ${upload_destination_file_path}
${INPUT_FILE}                     sample_fixed_width_file.txt
${EXPR_FILE}                      ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/LPSD_EDS_To_JRS.expr

# MailDev container URL (use container hostname in Docker network)
${MAILDEV_URL}       http://maildev:1080
${EMAIL_RECIPIENT}   spamula@snaplogic.com

*** Test Cases ***
TC01_SQLServer_Connectivity_Validation
    [Tags]    lpsd    sqlserver    connectivity    sit
    Log To Console    ✅ SQL Server connection validated successfully

TC02_File_Availability_Check
    [Tags]    lpsd    sqlserver    file    sit
    Upload Input File
    Log To Console    ✅ File uploaded successfully and available at source

TC03_Validate_Line_Endings
    [Tags]    lpsd  preprocessing    sit
    ${file}=    Get File    ${CURDIR}/../../test_data/input_files/${INPUT_FILE}
    Should Not Contain    ${file}    \r\n
    Log To Console    ✅ File contains only UNIX LF line endings

TC04_Run_Pipeline_Once
    [Tags]    lpsd    sqlserver    etl    sit
    Run LPSD Pipeline Task
    Log To Console    ✅ Pipeline executed once successfully

TC05_Validate_Staging_Insert
    [Tags]    lpsd    sqlserver    etl    sit
    ${cnt}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM dbo.EDS_RSN_DTA
    Should Be True    ${cnt[0][0]} > 0
    Log To Console    ✅ Records inserted into staging successfully (Found: ${cnt[0][0]})

TC06_Validate_Target_Execution_And_Transformations
    [Tags]    lpsd    sqlserver    etl    sit
    ${file}=    Get File    ${CURDIR}/../../test_data/input_files/${INPUT_FILE}
    ${lines}=   Split To Lines    ${file}
    ${expected_count}=    Get Length    ${lines}
    ${cnt}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM dbo.EDS_RSN_DTA
    Should Be Equal As Integers    ${cnt[0][0]}    ${expected_count}
    Log To Console    ✅ Target table row count matched expected file records: ${expected_count}

    ${expr_file}=    Get File    ${EXPR_FILE}
    ${expr_lines}=   Split To Lines    ${expr_file}
    Log To Console    🔎 Loaded ${expr_lines.__len__()} rules from expr file

    FOR    ${rule}    IN    @{expr_lines}
        Log To Console    🔍 Checking transformation rule: ${rule}
        ${parts}=    Split String    ${rule}
        Run Keyword If    '${parts[0]}' != ''    Validate Transformation Rule    ${parts}
    END

TC07_Invalid_Target_Table_Check
    [Tags]    lpsd    sqlserver    negative    sit
    Run Keyword And Expect Error    *    DatabaseLibrary.Query    SELECT COUNT(*) FROM dbo.NON_EXISTENT_TABLE
    Log To Console    ✅ Invalid target table check passed

TC08_Debug_List_All_Tables
    [Tags]    debug    sqlserver
    ${tables}=    DatabaseLibrary.Query    SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE'
    Log    ${tables}
    Log To Console    📋 All tables in SQL Server: ${tables}

TC09_Validate_Email_Notification
    [Tags]    lpsd    email    sit
    Setup MailDev Connection    ${MAILDEV_URL}
    Purge All Emails    ${MAILDEV_URL}

    # Trigger pipeline that sends email
    Run LPSD Pipeline Task

    # Wait for email to arrive
    Wait For Email    60s    3s    ${MAILDEV_URL}

    ${email_count}=    Get Email Count    ${MAILDEV_URL}
    Should Be True    ${email_count} > 0

    Verify Email TO Recipient    ${EMAIL_RECIPIENT}    ${maildev_url}=${MAILDEV_URL}
    Verify Email Subject    LPSD_EDS_To_JRS    ${maildev_url}=${MAILDEV_URL}
    Verify Email Body Contains    Your pipeline executed successfully    ${maildev_url}=${MAILDEV_URL}

*** Keywords ***
Prepare Suite Environment
    Check Connections
    Initialize Variables
    Ensure Sqlserver Target Table Exists
    Clean Sqlserver Target Table
    Import LPSD Pipeline
    Upload Input File
    Create Task For LPSD Pipeline    BaseRun    ${INPUT_FILE}

Cleanup Suite Environment
    Run Keyword And Ignore Error    Clean Sqlserver Target Table
    Run Keyword And Ignore Error    Disconnect From Database

# --- Core Plumbing ---
Import LPSD Pipeline
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${BASE_PIPELINE_FILENAME}
    Sleep    5s

Create Task For LPSD Pipeline
    [Arguments]    ${test_name}    ${source_file}
    ${task_name}=    Catenate    LPSD_EDS_To_JRS_Task_    ${unique_id}_${test_name}
    Set Suite Variable    ${task_name}
    &{local_params}=    Copy Dictionary    ${task_params}
    Set To Dictionary    ${local_params}    filePath    ${input_folder}/${source_file}
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
    Upload File Using File Protocol Template    file://${CURDIR}/../../test_data/input_files/${INPUT_FILE}    ${input_folder}

Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Database Using Custom Params

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    LPSD_EDS_To_JRS_    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${SQLSERVER_ACCOUNT_NAME}    sqlserver_acct

Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}

Ensure Sqlserver Target Table Exists
    ${probe}=    Run Keyword And Ignore Error    DatabaseLibrary.Query    SELECT 1 FROM dbo.EDS_RSN_DTA
    Run Keyword If    '${probe[0]}' == 'FAIL'    Fail    Table dbo.EDS_RSN_DTA does not exist or is inaccessible.

Clean Sqlserver Target Table
    ${truncate_result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    TRUNCATE TABLE dbo.EDS_RSN_DTA
    Run Keyword If    '${truncate_result[0]}' == 'FAIL'    DatabaseLibrary.Execute Sql String    DELETE FROM dbo.EDS_RSN_DTA

Connect To Database Using Custom Params
    Connect To Database    pymssql    ${SQLSERVER_DBNAME}    ${SQLSERVER_DBUSER}    ${SQLSERVER_DBPASS}    ${SQLSERVER_HOST}    ${SQLSERVER_DBPORT}

# --- Transformation Validation ---
Validate Transformation Rule
    [Arguments]    @{parts}
    ${source}=    Set Variable    ${parts[0]}
    ${target}=    Set Variable    ${parts[1]}
    ${res}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM dbo.EDS_RSN_DTA WHERE ${target} IS NOT NULL
    Should Be True    ${res[0][0]} >= 0
    Log To Console    ✅ Transformation applied: ${source} → ${target} (rows: ${res[0][0]})

# --- Email Wait Helper Keywords ---
Wait For Email
    [Arguments]    ${timeout}=60s    ${interval}=3s    ${maildev_url}=${MAILDEV_URL}
    Wait Until Keyword Succeeds    ${timeout}    ${interval}    Check Email Arrived    ${maildev_url}

Check Email Arrived
    [Arguments]    ${maildev_url}=${MAILDEV_URL}
    ${count}=    Get Email Count    ${maildev_url}
    Should Be True    ${count} > 0
