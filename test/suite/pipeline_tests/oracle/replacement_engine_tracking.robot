*** Settings ***
Resource    ../../resources/snaplogic_keywords.resource
Library     DatabaseLibrary
Suite Setup       Import Pipeline    ${PIPELINE_FILE}    ${PROJECT_PATH}
Suite Teardown    Delete Pipeline    ${PIPELINE_NAME}    ${PROJECT_PATH}
Test Setup        Create Task For Pipeline    ${PIPELINE_NAME}
Test Teardown     Delete Task    ${TASK_NAME}

*** Variables ***
${PIPELINE_FILE}      ${CURDIR}/../../../src/pipelines/Replacement_Engine_Tracking_EOMP_2025_08_21.slp
${PIPELINE_NAME}      Replacement_Engine_Tracking_EOMP
${PROJECT_PATH}       SL-CATRobotPOC/SaiProjectSpace2/Saikiran_Dev_Test

# Oracle connection (from .env)
${ORACLE_HOST}        oracle-db
${ORACLE_PORT}        1521
${ORACLE_DB}          FREEPDB1
${ORACLE_USER}        SYSTEM
${ORACLE_PASS}        Oracle123
${ORACLE_DRIVER}      oracle.jdbc.driver.OracleDriver
${ORACLE_JAR}         /drivers/ojdbc8.jar    # make sure jar exists inside docker

*** Keywords ***
Connect To Oracle
    Connect To Database    cx_Oracle    ${ORACLE_USER}/${ORACLE_PASS}@${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_DB}

Disconnect Oracle
    Disconnect From Database

Validate Record Exists
    [Arguments]    ${id}    ${expected_name}    ${expected_value}
    ${rows}=    Query    SELECT NAME, VALUE FROM ENGINE_TRACKING WHERE ID=${id}
    Should Be Equal As Strings    ${rows[0][0]}    ${expected_name}
    Should Be Equal As Integers   ${rows[0][1]}    ${expected_value}

*** Test Cases ***
TC_001_Oracle_Insert_Path
    [Documentation]    Validate Insert path of SAPFTP → Oracle Insert
    ${params}=    Create Dictionary
    ...    Oracle_Account=shared/oracle_acct
    ...    Input_File=${CURDIR}/../../../test_data/replacement_engine_tracking/insert_test.csv
    ${resp}=    Run Triggered Task Api With Params    ${TASK_NAME}    ${params}
    Should Contain    ${resp}    Completed
    Connect To Oracle
    Validate Record Exists    1001    Engine_A    500
    Validate Record Exists    1002    Engine_B    700
    Validate Record Exists    1003    Engine_C    900
    Disconnect Oracle

TC_002_Oracle_Merge_Path
    [Documentation]    Validate Merge path of RUUID → Oracle Merge
    ${params}=    Create Dictionary
    ...    Oracle_Account=shared/oracle_acct
    ...    Input_File=${CURDIR}/../../../test_data/replacement_engine_tracking/merge_test.csv
    ${resp}=    Run Triggered Task Api With Params    ${TASK_NAME}    ${params}
    Should Contain    ${resp}    Completed
    Connect To Oracle
    # Validate updated record
    Validate Record Exists    1002    Engine_B    750
    # Validate new merged record
    Validate Record Exists    1004    Engine_D    600
    Disconnect Oracle
