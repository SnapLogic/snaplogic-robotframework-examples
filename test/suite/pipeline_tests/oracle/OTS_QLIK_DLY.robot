*** Settings ***
Documentation    OTS QLIK DLY :: End-to-End ETL & Integration Suite (PostgreSQL → SnapLogic → Oracle, SYSTEM.OTS_DAILY)
Library          OperatingSystem
Library          DatabaseLibrary
Library          oracledb
Library          psycopg2
Library          DependencyLibrary
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../test_data/queries/oracle_queries.resource
Resource         ../../test_data/queries/postgres_queries.resource
Resource         ../../../resources/files.resource
Suite Setup      Prepare Suite Environment And Pipeline

*** Variables ***
${project_path}                  ${org_name}/${project_space}/${project_name}
${pipeline_file_path}            ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}        OTS_QLIK_DLY.slp
${account_payload_path}          ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}          acc_oracle.json

@{notification_states}           Completed    Failed
&{task_notifications}
...                             recipients=ots_notifications@yourorg.com
...                             states=${notification_states}
${CURRENT_DATE}                  2025-07-24
&{task_params}
...                             M_CURR_DATE=${CURRENT_DATE}
...                             Oracle_Account=shared/${ORACLE_ACCOUNT_NAME}
...                             Postgres_Account=shared/${POSTGRES_ACCOUNT_NAME}
${upload_source_file_path}       ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${upload_destination_file_path}  ${project_path}

*** Test Cases ***

Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    [Tags]    ots    oracle    regression    infra
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Upload Files With File Protocol
    [Documentation]    Upload files using file:/// protocol URLs - all options in template format
    [Tags]    ots    oracle    regression    infra
    [Template]    Upload File Using File Protocol Template
    file:///opt/snaplogic/test_data/actual_expected_data/expression_libraries/OTS_QLIK_DLY.expr    ${upload_destination_file_path}
    file:///app/test/suite/test_data/actual_expected_data/expression_libraries/OTS_QLIK_DLY.expr    ${upload_destination_file_path}/app_mount
    file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/OTS_QLIK_DLY.expr    ${upload_destination_file_path}/curdir

TC_Validate_Delete_Before_Insert
    [Documentation]    TC_001 Confirm ETL deletes legacy Oracle rows before insert.
    [Tags]    ots    oracle    delete    regression
    Ensure Oracle OTS_DAILY Table
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    DatabaseLibrary.Execute Sql String    INSERT INTO "SYSTEM"."OTS_DAILY" (ID, NAME) VALUES (99999, 'TO_BE_DELETED')
    ${count_legacy_before}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM "SYSTEM"."OTS_DAILY" WHERE ID=99999
    Should Be Equal As Integers    ${count_legacy_before[0][0]}    1
    Insert 100 Rows Into Postgres
    Create Task For OTS Pipeline    TC_Validate_Delete_Before_Insert
    Run OTS Pipeline Task
    Wait Until Keyword Succeeds    10 times    1 second    Table Should Exist    SYSTEM    OTS_DAILY
     to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${count_legacy_after}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM "SYSTEM"."OTS_DAILY" WHERE ID=99999
    Should Be Equal As Integers    ${count_legacy_after[0][0]}    0    msg=Legacy data should be deleted
    ${etl_row_count}=    Get Oracle OTS_DAILY Count
    Should Be Equal As Integers    ${etl_row_count}    100    msg=ETL rows inserted as expected

TC_Extraction_From_Postgres
    [Documentation]    Data extracted from Postgres matches input; no truncation.
    [Tags]    ots    etl    postgres    extract    baseflow
    Insert 100 Rows Into Postgres
    ${extract_cnt}=    Get Postgres QLIK_OTS_DAILY Count
    Should Be Equal As Integers    ${extract_cnt}    100

TC_E2E_ETL_100_Rows_Pipeline
    [Documentation]    Confirm Oracle target table gets ETL data inserted; no dups.
    [Tags]    ots    etl    oracle    insert    e2e    baseflow
    ${pg_cnt}=    Get Postgres QLIK_OTS_DAILY Count
    ${oracle_cnt}=    Get Oracle OTS_DAILY Count
    Should Be Equal As Integers    ${pg_cnt}    100
    Should Be Equal As Integers    ${oracle_cnt}    100




*** Keywords ***
Prepare Suite Environment And Pipeline
    Prepare Environment
    Ensure Oracle OTS_DAILY Table
    Ensure Postgres QLIK_OTS_DAILY Table
    Clean Oracle OTS_DAILY
    Clean Postgres QLIK_OTS_DAILY
    Insert 100 Rows Into Postgres
    Import OTS QLIK DLY Pipeline
    Create Task For OTS Pipeline    suite_run
    Run OTS Pipeline Task

Import OTS QLIK DLY Pipeline
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${BASE_PIPELINE_FILENAME}
    Sleep    5s

Create Task For OTS Pipeline
    [Arguments]    ${test_name}
    ${task_name}=    Catenate    OTS_QLIK_DLY_Task_    ${unique_id}    _${test_name}
    Set Test Variable    ${task_name}
    Create Triggered Task From Template
    ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}    ${task_params}    ${task_notifications}

Run OTS Pipeline Task
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}    M_CURR_DATE=${CURRENT_DATE}

Prepare Environment
    Check ConnectionsConnect
    Initialize Variables

Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    OTS_QLIK_DLY_    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${pipeline_name_slp}    ${BASE_PIPELINE_FILENAME}

Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}

Ensure Oracle OTS_DAILY Table
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    TRUNCATE TABLE "SYSTEM"."OTS_DAILY"
    Run Keyword If    '${result[0]}' == 'FAIL'    Create Oracle OTS_DAILY Table

Create Oracle OTS_DAILY Table
    DatabaseLibrary.Execute Sql String    CREATE TABLE "SYSTEM"."OTS_DAILY" (ID NUMBER, NAME VARCHAR2(50), CREATE_DATE DATE, METRIC_NAME VARCHAR2(100), METRIC_UNIT VARCHAR2(50), PLATFORM VARCHAR2(50), MONTH VARCHAR2(50))

Ensure Postgres QLIK_OTS_DAILY Table
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    ${result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    TRUNCATE TABLE qlik_ots_daily
    Run Keyword If    '${result[0]}' == 'FAIL'    Create QLIK_OTS_DAILY Table

Create QLIK_OTS_DAILY Table
    DatabaseLibrary.Execute Sql String    CREATE TABLE qlik_ots_daily (id INTEGER, name VARCHAR(50), create_date DATE, metric_name VARCHAR(100), metric_unit VARCHAR(50), platform VARCHAR(50), month VARCHAR(50))

Clean Oracle OTS_DAILY
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    DatabaseLibrary.Execute Sql String    DELETE FROM "SYSTEM"."OTS_DAILY"

Clean Postgres QLIK_OTS_DAILY
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    DatabaseLibrary.Execute Sql String    DELETE FROM qlik_ots_daily

Insert 100 Rows Into Postgres
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    DatabaseLibrary.Execute Sql String    DELETE FROM qlik_ots_daily
    ${month_str}=    Evaluate    str(datetime.date.today()).replace("-","")[:6]    datetime
    FOR    ${i}    IN RANGE    1    101
        ${sql}=    Catenate    INSERT INTO qlik_ots_daily (id, name, create_date, metric_name, metric_unit, platform, month) VALUES (${i}, 'Name_${i}', CURRENT_DATE, 'Metric_${i}', 'Unit_${i}', 'Platform_${i}', '${month_str}')
        DatabaseLibrary.Execute Sql String    ${sql}
    END
    Log    Inserted 100 rows into qlik_ots_daily with all required fields

Get Oracle OTS_DAILY Count
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${count}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM "SYSTEM"."OTS_DAILY"
    RETURN    ${count[0][0]}

Get Postgres QLIK_OTS_DAILY Count
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    ${count}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM qlik_ots_daily
    RETURN    ${count[0][0]}

Table Should Exist
    [Arguments]    ${schema}    ${table}
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${query}=    Catenate    SELECT 1 FROM ALL_TABLES WHERE OWNER=UPPER('${schema}') AND TABLE_NAME=UPPER('${table}')
    ${result}=    DatabaseLibrary.Query    ${query}
    Should Not Be Empty    ${result}    msg=Table ${schema}.${table} does not exist!

Close All Connections
    Close All Connections
