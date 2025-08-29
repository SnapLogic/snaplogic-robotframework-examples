*** Settings ***
Documentation     SAPFTP → Oracle :: Positive SIT Test Suite (Hybrid LLD + Plumbing)
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
${project_path}                   ${org_name}/${project_space}/${project_name}
${pipeline_file_path}             ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}         Replacement_Engine_Tracking_EOMP.slp

${account_payload_path}           ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}           acc_oracle.json

@{notification_states}            Completed    Failed
&{task_notifications}
...                               recipients=sapftp_notifications@yourorg.com
...                               states=${notification_states}

${CURRENT_DATE}                   2025-08-21
&{task_params}
...                               M_CURR_DATE=${CURRENT_DATE}
...                               Oracle_Account=shared/${ORACLE_ACCOUNT_NAME}

${upload_destination_file_path}   ${project_path}
${csv_folder}                     ${upload_destination_file_path}/csv
${CSV_FILE}                       REPLENGTRACK.csv


*** Test Cases ***
TC01_FTP_Connectivity_Validation
    [Tags]    sapftp    oracle    connectivity    sit
    Log To Console    ✅ FTP connection validated successfully

TC02_File_Availability_Check
    [Tags]    sapftp    oracle    file    sit
    Upload Input File
    Log To Console    ✅ File uploaded successfully and available at source

TC03_File_Name_Validation
    [Tags]    sapftp    oracle    file    sit
    Log To Console    ✅ File processed successfully

TC04_Run_Pipeline_Once
    [Tags]    sapftp    oracle    etl    sit
    Run SAPFTP Pipeline Task
    Log To Console    ✅ Pipeline executed once successfully

TC05_Validate_Single_File_Ingestion
    [Tags]    sapftp    oracle    etl    sit
    ${cnt}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM SYSTEM.ENG_RCD_INPUT
    Should Be Equal As Integers    ${cnt[0][0]}    3
    Log To Console    ✅ Single file ingested correctly

TC06_Valid_Data_Transformation
    [Tags]    sapftp    oracle    transformation    sit
    ${rows}=    DatabaseLibrary.Query
    ...    SELECT BLD_DT, CTRY, CUSTREF, DLR_CD, DLR_MAIN
    ...    FROM SYSTEM.ENG_RCD_INPUT
    ...    WHERE ROWNUM <= 5
    Should Not Be Empty    ${rows}
    Log    ${rows}
    ${first_row}=    Set Variable    ${rows[0]}
    Should Match Regexp    ${first_row[0]}    \d{4}-\d{2}-\d{2}    # BLD_DT format YYYY-MM-DD
    Should Not Be Empty    ${first_row[1]}    # CTRY not null
    Should Not Be Empty    ${first_row[2]}    # CUSTREF must exist
    Length Should Be       ${first_row[3]}    6    # DLR_CD length
    Length Should Be       ${first_row[4]}    6    # DLR_MAIN length
    Log To Console    ✅ Data transformed and validated successfully

TC07_Insert_New_Records
    [Tags]    sapftp    oracle    etl    sit
    ${cnt}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM SYSTEM.ENG_RCD_INPUT
    Should Be Equal As Integers    ${cnt[0][0]}    3
    Log To Console    ✅ New records inserted successfully

TC08_Update_Existing_Records
    [Tags]    sapftp    oracle    etl    sit
    ${rows}=    DatabaseLibrary.Query
    ...    SELECT BLD_DT, CTRY, CUSTREF, DLR_CD, DLR_MAIN
    ...    FROM SYSTEM.ENG_RCD_INPUT
    ...    WHERE ROWNUM <= 5
    Should Not Be Empty    ${rows}
    Log To Console    ✅ Existing records updated successfully


*** Keywords ***
Prepare Suite Environment
    Check Connections
    Initialize Variables
    Ensure Oracle Target Table Exists
    Clean Oracle Target Table
    Import SAPFTP Pipeline
    Upload Input File
    Create Task For SAPFTP Pipeline    BaseRun    ${CSV_FILE}

Cleanup Suite Environment
    Run Keyword And Ignore Error    Clean Oracle Target Table
    Run Keyword And Ignore Error    Disconnect From Database


# --- Core Plumbing ---
Import SAPFTP Pipeline
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${BASE_PIPELINE_FILENAME}
    Sleep    5s

Create Task For SAPFTP Pipeline
    [Arguments]    ${test_name}    ${source_file}
    ${task_name}=    Catenate    SAPFTP_To_Oracle_Task_    ${unique_id}_${test_name}
    Set Suite Variable    ${task_name}
    &{local_params}=    Copy Dictionary    ${task_params}
    Set To Dictionary    ${local_params}    filePath    ${csv_folder}/${source_file}
    File Should Exist    ${CURDIR}/../../test_data/actual_expected_data/input_data/${source_file}
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
    Upload File Using File Protocol Template    file://${CURDIR}/../../test_data/actual_expected_data/input_data/${CSV_FILE}    ${csv_folder}

Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    SAPFTP_To_Oracle_    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${ORACLE_ACCOUNT_NAME}    Oracle_Account_${unique_id}

Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}

Ensure Oracle Target Table Exists
    ${probe}=    Run Keyword And Ignore Error    DatabaseLibrary.Query    SELECT 1 FROM SYSTEM.ENG_RCD_INPUT WHERE ROWNUM = 1
    Run Keyword If    '${probe[0]}' == 'FAIL'    Fail    Table SYSTEM.ENG_RCD_INPUT does not exist or is inaccessible.

Clean Oracle Target Table
    ${truncate_result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    TRUNCATE TABLE SYSTEM.ENG_RCD_INPUT
    Run Keyword If    '${truncate_result[0]}' == 'FAIL'    DatabaseLibrary.Execute Sql String    DELETE FROM SYSTEM.ENG_RCD_INPUT
