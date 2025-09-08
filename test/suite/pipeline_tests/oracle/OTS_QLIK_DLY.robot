*** Settings ***
Documentation    OTS QLIK DLY :: End-to-End ETL & Integration Suite (PostgreSQL → SnapLogic → Oracle)
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
# ===================================================================
# 🔧 PIPELINE-SPECIFIC CONFIGURATION (Set once at top — easy to change)
# ===================================================================
${PIPELINE_BASE_NAME}             OTS_QLIK_DLY
${PIPELINE_FILENAME}               OTS_QLIK_DLY.slp
${EXPRESSION_FILE_NAME}            OTS_QLIK_DLY.expr

${ORACLE_SCHEMA}                   SYSTEM
${ORACLE_TARGET_TABLE}             OTS_DAILY
${POSTGRES_SOURCE_TABLE}           qlik_ots_daily

${EXPECTED_ROW_COUNT}              100
${CURRENT_DATE}                    2025-07-24

@{REQUIRED_COLUMNS}
...                               ID
...                               NAME
...                               CREATE_DATE
...                               METRIC_NAME
...                               METRIC_UNIT
...                               PLATFORM
...                               MONTH

# ===================================================================
# 🌐 ENVIRONMENT & PATHS (from .env or dynamic)
# ===================================================================
${project_path}                  ${org_name}/${project_space}/${project_name}
${pipeline_file_path}            ${CURDIR}/../../../../src/pipelines
${BASE_PIPELINE_FILENAME}        ${PIPELINE_FILENAME}

${account_payload_path}          ${CURDIR}/../../test_data/accounts_payload
${ACCOUNT_PAYLOAD_FILE}          acc_oracle.json

@{notification_states}           Completed    Failed
&{task_notifications}
...                             recipients=ots_notifications@yourorg.com
...                             states=${notification_states}

&{task_params}
...                             M_CURR_DATE=${CURRENT_DATE}
...                             Oracle_Account=shared/${ORACLE_ACCOUNT_NAME}
...                             Postgres_Account=shared/${POSTGRES_ACCOUNT_NAME}

${upload_source_file_path}       ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${upload_destination_file_path}  ${project_path}


*** Test Cases ***
Create Account
    [Documentation]    Creates the Oracle account required by the OTS → Oracle pipeline.
    [Tags]    ots    oracle    connectivity    infra    e2e
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}


Upload Files With File Protocol
    [Documentation]    Upload expression library file from multiple sources.
    [Tags]    ots    infra    files    e2e
    [Template]    Upload File Using File Protocol Template
    file://${upload_source_file_path}/${EXPRESSION_FILE_NAME}    ${upload_destination_file_path}
    file:///app/test/suite/test_data/actual_expected_data/expression_libraries/${EXPRESSION_FILE_NAME}    ${upload_destination_file_path}/app_mount
    file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/${EXPRESSION_FILE_NAME}    ${upload_destination_file_path}/curdir


TC_Validate_Delete_Before_Insert
    [Documentation]    Confirm ETL deletes legacy rows before inserting new data.
    [Tags]    ots    oracle    delete    regression    e2e
    Ensure Oracle Target Table Exists
    Insert Legacy Row For Deletion Test
    Create Task For OTS Pipeline    TC_Delete_Before_Insert
    Run OTS Pipeline Task
    Wait Until Keyword Succeeds    10 times    1 second    Table Should Exist    ${ORACLE_SCHEMA}    ${ORACLE_TARGET_TABLE}
    Legacy Row Should Be Deleted
    ETL Row Count Should Match Expected


TC_Extraction_From_Postgres
    [Documentation]    Validate that 100 rows are correctly extracted from PostgreSQL.
    [Tags]    ots    etl    postgres    extract    baseflow
    Insert 100 Rows Into Postgres
    ${extract_cnt}=    Get Postgres Row Count
    Should Be Equal As Integers    ${extract_cnt}    ${EXPECTED_ROW_COUNT}


TC_E2E_ETL_100_Rows_Pipeline
    [Documentation]    End-to-end validation: data flows from Postgres → Oracle with correct count.
    [Tags]    ots    etl    oracle    insert    e2e    baseflow
    ${pg_cnt}=    Get Postgres Row Count
    ${oracle_cnt}=    Get Oracle Row Count
    Should Be Equal As Integers    ${pg_cnt}    ${EXPECTED_ROW_COUNT}
    Should Be Equal As Integers    ${oracle_cnt}    ${EXPECTED_ROW_COUNT}


*** Keywords ***
Prepare Suite Environment And Pipeline
    Prepare Environment
    Ensure Oracle Target Table Exists
    Ensure Postgres Source Table Exists
    Clean Oracle Target Table
    Clean Postgres Source Table
    Insert 100 Rows Into Postgres
    Import OTS QLIK DLY Pipeline
    Create Task For OTS Pipeline    suite_run
    Run OTS Pipeline Task


Import OTS QLIK DLY Pipeline
    Import Pipelines From Template
    ...    ${unique_id}
    ...    ${pipeline_file_path}
    ...    ${pipeline_name}
    ...    ${BASE_PIPELINE_FILENAME}
    Sleep    5s


Create Task For OTS Pipeline
    [Arguments]    ${test_name}
    ${task_name}=    Catenate    SEPARATOR=_    ${PIPELINE_BASE_NAME}_Task    ${unique_id}    ${test_name}
    Set Suite Variable    ${task_name}
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${task_params}
    ...    ${task_notifications}


Run OTS Pipeline Task
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    M_CURR_DATE=${CURRENT_DATE}


Prepare Environment
    Check Connections
    Initialize Variables


Check Connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}


Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}
    ${pipeline_name}=    Catenate    SEPARATOR=_    ${PIPELINE_BASE_NAME}    ${unique_id}
    Set Suite Variable    ${pipeline_name}
    Set Suite Variable    ${ORACLE_ACCOUNT_NAME}    ${PIPELINE_BASE_NAME}_Oracle_Acct_${unique_id}


Get Unique Id
    ${timestamp}=    Get Time    epoch
    RETURN    ${timestamp}


Ensure Oracle Target Table Exists
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${result}=    Run Keyword And Ignore Error
    ...    DatabaseLibrary.Execute Sql String
    ...    TRUNCATE TABLE "${ORACLE_SCHEMA}"."${ORACLE_TARGET_TABLE}"
    Run Keyword If    '${result[0]}' == 'FAIL'
    ...    Create Oracle Target Table


Create Oracle Target Table
    DatabaseLibrary.Execute Sql String
    ...    CREATE TABLE "${ORACLE_SCHEMA}"."${ORACLE_TARGET_TABLE}"
    ...    (ID NUMBER, NAME VARCHAR2(50), CREATE_DATE DATE, METRIC_NAME VARCHAR2(100),
    ...    METRIC_UNIT VARCHAR2(50), PLATFORM VARCHAR2(50), MONTH VARCHAR2(50))


Ensure Postgres Source Table Exists
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    ${result}=    Run Keyword And Ignore Error
    ...    DatabaseLibrary.Execute Sql String
    ...    TRUNCATE TABLE ${POSTGRES_SOURCE_TABLE}
    Run Keyword If    '${result[0]}' == 'FAIL'
    ...    Create Postgres Source Table


Create Postgres Source Table
    DatabaseLibrary.Execute Sql String
    ...    CREATE TABLE ${POSTGRES_SOURCE_TABLE}
    ...    (id INTEGER, name VARCHAR(50), create_date DATE, metric_name VARCHAR(100),
    ...    metric_unit VARCHAR(50), platform VARCHAR(50), month VARCHAR(50))


Clean Oracle Target Table
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    DatabaseLibrary.Execute Sql String    DELETE FROM "${ORACLE_SCHEMA}"."${ORACLE_TARGET_TABLE}"


Clean Postgres Source Table
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    DatabaseLibrary.Execute Sql String    DELETE FROM ${POSTGRES_SOURCE_TABLE}


Insert 100 Rows Into Postgres
    Clean Postgres Source Table
    ${month_str}=    Evaluate    str(datetime.date.today()).replace('-','')[:6]    datetime
    FOR    ${i}    IN RANGE    1    ${EXPECTED_ROW_COUNT}+1
        ${sql}=    Catenate    SEPARATOR=
        ...    INSERT INTO ${POSTGRES_SOURCE_TABLE}
        ...    (id, name, create_date, metric_name, metric_unit, platform, month)
        ...    VALUES (${i}, 'Name_${i}', CURRENT_DATE, 'Metric_${i}', 'Unit_${i}', 'Platform_${i}', '${month_str}')
        DatabaseLibrary.Execute Sql String    ${sql}
    END
    Log    Inserted ${EXPECTED_ROW_COUNT} rows into ${POSTGRES_SOURCE_TABLE}


Insert Legacy Row For Deletion Test
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    DatabaseLibrary.Execute Sql String
    ...    INSERT INTO "${ORACLE_SCHEMA}"."${ORACLE_TARGET_TABLE}" (ID, NAME) VALUES (99999, 'TO_BE_DELETED')
    ${before}=    DatabaseLibrary.Query
    ...    SELECT COUNT(*) FROM "${ORACLE_SCHEMA}"."${ORACLE_TARGET_TABLE}" WHERE ID = 99999
    Should Be Equal As Integers    ${before[0][0]}    1


Legacy Row Should Be Deleted
    ${after}=    DatabaseLibrary.Query
    ...    SELECT COUNT(*) FROM "${ORACLE_SCHEMA}"."${ORACLE_TARGET_TABLE}" WHERE ID = 99999
    Should Be Equal As Integers    ${after[0][0]}    0    msg=Legacy data should be deleted


ETL Row Count Should Match Expected
    ${actual}=    Get Oracle Row Count
    Should Be Equal As Integers    ${actual}    ${EXPECTED_ROW_COUNT}


Get Oracle Row Count
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${count}=    DatabaseLibrary.Query
    ...    SELECT COUNT(*) FROM "${ORACLE_SCHEMA}"."${ORACLE_TARGET_TABLE}"
    RETURN    ${count[0][0]}


Get Postgres Row Count
    Connect To Database    psycopg2    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}    ${POSTGRES_DBPORT}
    ${count}=    DatabaseLibrary.Query
    ...    SELECT COUNT(*) FROM ${POSTGRES_SOURCE_TABLE}
    RETURN    ${count[0][0]}


Table Should Exist
    [Arguments]    ${schema}    ${table}
    Connect to Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${query}=    Catenate
    ...    SELECT 1 FROM ALL_TABLES
    ...    WHERE OWNER = UPPER('${schema}')
    ...    AND TABLE_NAME = UPPER('${table}')
    ${result}=    DatabaseLibrary.Query    ${query}
    Should Not Be Empty    ${result}    msg=Table ${schema}.${table} does not exist!