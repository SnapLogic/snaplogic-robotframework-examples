*** Settings ***
Library           OperatingSystem
Library           DatabaseLibrary
Suite Setup       Connect To Database
Suite Teardown    Disconnect From Database

*** Variables ***
${DB_HOST}        your_oracle_host
${DB_PORT}        1521
${DB_NAME}        your_db_name
${DB_USER}        your_db_user
${DB_PASSWORD}    your_db_password

*** Keywords ***
Connect To Database
    Connect To Database    cx_Oracle    ${DB_USER}/${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}

Disconnect From Database
    Disconnect From Database

*** Test Cases ***
Verify Replacement Engine Tracking Table Exists
    ${tables}=    Query    SELECT table_name FROM user_tables WHERE table_name = 'REPLACEMENT_ENGINE_TRACKING'
    Should Not Be Empty    ${tables}

Insert And Verify Tracking Record
    Execute Sql String    INSERT INTO REPLACEMENT_ENGINE_TRACKING (ID, STATUS) VALUES (1, 'STARTED')
    ${result}=    Query    SELECT STATUS FROM REPLACEMENT_ENGINE_TRACKING WHERE ID = 1
    Should Be Equal As Strings    ${result[0][0]}    STARTED

Cleanup Tracking Table
    Execute Sql String    DELETE FROM REPLACEMENT_ENGINE_TRACKING WHERE ID = 1