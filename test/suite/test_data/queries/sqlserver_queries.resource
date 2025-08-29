*** Keywords ***
Ensure SQL Server Staging Table
    ${result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    TRUNCATE TABLE JRS_STAGE
    Run Keyword If    '${result[0]}' == 'FAIL'    Create SQL Server Staging Table

Create SQL Server Staging Table
    DatabaseLibrary.Execute Sql String    CREATE TABLE JRS_STAGE (ID INT, NAME VARCHAR(50), CREATE_DATE DATE, VALUE VARCHAR(100))

Ensure SQL Server Target Table
    ${result}=    Run Keyword And Ignore Error    DatabaseLibrary.Execute Sql String    TRUNCATE TABLE JRS_TARGET
    Run Keyword If    '${result[0]}' == 'FAIL'    Create SQL Server Target Table

Create SQL Server Target Table
    DatabaseLibrary.Execute Sql String    CREATE TABLE JRS_TARGET (ID INT, NAME VARCHAR(50), CREATE_DATE DATE, VALUE VARCHAR(100))

Clean SQL Server Staging Table
    DatabaseLibrary.Execute Sql String    DELETE FROM JRS_STAGE

Clean SQL Server Target Table
    DatabaseLibrary.Execute Sql String    DELETE FROM JRS_TARGET

Insert 100 Rows Into SQL Server Staging
    FOR    ${i}    IN RANGE    1    101
        ${sql}=    Catenate    INSERT INTO JRS_STAGE (ID, NAME, CREATE_DATE, VALUE) VALUES (${i}, 'Name_${i}', GETDATE(), 'Value_${i}')
        DatabaseLibrary.Execute Sql String    ${sql}
    END
    Log    Inserted 100 rows into JRS_STAGE

Get SQL Server Staging Count
    ${count}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM JRS_STAGE
    RETURN    ${count[0][0]}

Get SQL Server Target Count
    ${count}=    DatabaseLibrary.Query    SELECT COUNT(*) FROM JRS_TARGET
    RETURN    ${count[0][0]}

Close All Database Connections
    Disconnect From Database
