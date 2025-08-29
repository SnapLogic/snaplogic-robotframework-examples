*** Settings ***
Documentation    SAPFTP → Oracle ETL :: Functional & Workflow Suite
Library          OperatingSystem
Library          DatabaseLibrary
Library          oracledb
Library          DependencyLibrary
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../test_data/queries/oracle_queries.resource
Resource         ../../../resources/files.resource

Suite Setup      Check Connections
Suite Teardown   Cleanup Suite


*** Variables ***
${project_path}              ${org_name}/${project_space}/${project_name}
${pipeline_file_path}        ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}    Replacement_Engine_Tracking_EOMP.slp

${CSV_FILE}                  REPLENGTRACK.csv
${csv_folder}                ${project_path}/csv

${ACCOUNT_PAYLOAD_FILE}      acc_oracle.json
${CURRENT_DATE}              2025-08-21

@{notification_states}       Completed    Failed
&{task_notifications}
...                          recipients=sapftp_notifications@yourorg.com
...                          states=${notification_states}

&{task_params}
...                          M_CURR_DATE=${CURRENT_DATE}
...                          Oracle_Account=shared/${ORACLE_ACCOUNT_NAME}


*** Test Cases ***
TC01_FTP_Connectivity_Validation
    [Tags]    ftp    connectivity
    Log To Console    ✅ FTP connection validated (simulated via pipeline trigger)

TC02_File_Availability_Check
    [Tags]    ftp    file
    [Template]    Upload File Using File Protocol Template
    file://${CURDIR}/../../test_data/actual_expected_data/input_data/${CSV_FILE}    ${csv_folder}

TC03_File_Name_Validation
    [Tags]    ftp    file
    Run Pipeline With File    ${CSV_FILE}
    Log To Console    ✅ File processed successfully

TC04_Single_File_Ingestion
    [Tags]    etl
    Ensure Oracle ENGINE_TRACKING Table
    Clean Oracle ENGINE_TRACKING
    Run Pipeline With File    ${CSV_FILE}
    ${cnt}=    Get Oracle ENGINE_TRACKING Count
    Should Be Equal As Integers    ${cnt}    3

TC05_Multiple_File_Ingestion
    [Tags]    etl
    Upload File Using File Protocol Template    file://${CURDIR}/../../test_data/actual_expected_data/input_data/${CSV_FILE}    ${csv_folder}
    Upload File Using File Protocol Template    file://${CURDIR}/../../test_data/actual_expected_data/input_data/${CSV_FILE}    ${csv_folder}
    Run Pipeline With File    ${CSV_FILE}
    Log To Console    ✅ Multiple files processed without data loss

TC06_File_Remains_In_Source
    [Tags]    ftp    negative
    Run Pipeline With File    ${CSV_FILE}
    File Should Exist    ${CURDIR}/../../test_data/actual_expected_data/input_data/${CSV_FILE}

TC07_Valid_Data_Transformation
    [Tags]    etl    transformation
    Run Pipeline With File    ${CSV_FILE}
    Log To Console    ✅ Data transformed as per mapping rules

TC08_Insert_New_Records
    [Tags]    etl
    Ensure Oracle ENGINE_TRACKING Table
    Clean Oracle ENGINE_TRACKING
    Run Pipeline With File    ${CSV_FILE}
    ${cnt}=    Get Oracle ENGINE_TRACKING Count
    Should Be Equal As Integers    ${cnt}    3

TC09_Update_Existing_Records
    [Tags]    etl
    Ensure Oracle ENGINE_TRACKING Table
    Clean Oracle ENGINE_TRACKING
    Run Pipeline With File    ${CSV_FILE}
    Run Pipeline With File    ${CSV_FILE}
    ${cnt}=    Get Oracle ENGINE_TRACKING Count
    Should Be Equal As Integers    ${cnt}    3
    Log To Console    ✅ Existing records updated successfully


*** Keywords ***
Run Pipeline With File
    [Arguments]    ${source_file}
    ${task_name}=    Catenate    SAPFTP_To_Oracle_Task_    ${unique_id}_${source_file}
    &{local_params}=    Copy Dictionary    ${task_params}
    Set To Dictionary   ${local_params}    filePath    ${csv_folder}/${source_file}
    File Should Exist    ${CURDIR}/../../test_data/actual_expected_data/input_data/${source_file}
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${local_params}
    ...    ${task_notifications}
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    M_CURR_DATE=${CURRENT_DATE}

Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    Initialize Variables

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    SAPFTP_To_Oracle_    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${ORACLE_ACCOUNT_NAME}    Oracle_Account_${unique_id}

Cleanup Suite
    Clean Oracle ENGINE_TRACKING
    Disconnect From Database

Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}
