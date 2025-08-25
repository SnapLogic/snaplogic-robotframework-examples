*** Settings ***
Library    DatabaseLibrary
Library    oracledb


*** Keywords ***
Ensure Oracle ENGINE_TRACKING Table
    Connect To Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    TRUNCATE TABLE SYSTEM.ENGINE_TRACKING
    Run Keyword If    '${result[0]}' == 'FAIL'    Create Oracle ENGINE_TRACKING Table

Create Oracle ENGINE_TRACKING Table
    ${create_sql}=    Catenate    SEPARATOR= 
    ...    CREATE TABLE SYSTEM.ENGINE_TRACKING (
    ...        ENGINE_ID NUMBER,
    ...        NAME VARCHAR2(50),
    ...        STATUS VARCHAR2(30),
    ...        CREATE_DATE DATE,
    ...        METRIC_NAME VARCHAR2(100),
    ...        METRIC_UNIT VARCHAR2(50),
    ...        PLATFORM VARCHAR2(50),
    ...        MONTH VARCHAR2(6)
    ...    )
    DatabaseLibrary.Execute Sql String    ${create_sql}

Clean Oracle ENGINE_TRACKING
    Connect To Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    DatabaseLibrary.Execute Sql String    DELETE FROM SYSTEM.ENGINE_TRACKING

Get Oracle ENGINE_TRACKING Count
    Connect To Oracle Database    ${ORACLE_DBNAME}    ${ORACLE_DBUSER}    ${ORACLE_DBPASS}    ${ORACLE_HOST}    ${ORACLE_DBPORT}
    ${count}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM SYSTEM.ENGINE_TRACKING
    RETURN    ${count[0][0]}
