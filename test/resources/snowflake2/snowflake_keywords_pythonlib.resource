*** Settings ***
Documentation       Snowflake Database Keywords for Robot Framework
...                 This resource file provides keywords for connecting to and interacting with
...                 Snowflake database using the SnowflakeHelper Python library.
...                 These keywords wrap the Python library for easier use in Robot tests.

Library             OperatingSystem
Library             Collections
Library             String
Library             BuiltIn
# Import the SnowflakeHelper class from the correct location
Library             SnowflakeLibrary.py    WITH NAME    SnowflakeLib


*** Variables ***
${SNOWFLAKE_CONNECTION_STATUS}      ${FALSE}    # Track if we're connected
${SNOWFLAKE_ACCOUNT}                %{SNOWFLAKE_ACCOUNT=snaplogic}
${SNOWFLAKE_USER}                   %{SNOWFLAKE_USERNAME=Bigdatasnaplogic}
${SNOWFLAKE_PASSWORD}               %{SNOWFLAKE_PASSWORD=Snaplogic2018}
${SNOWFLAKE_DATABASE}               %{SNOWFLAKE_DATABASE=FDLDB}
${SNOWFLAKE_SCHEMA}                 %{SNOWFLAKE_SCHEMA=DEMO}
${SNOWFLAKE_WAREHOUSE}              %{SNOWFLAKE_WAREHOUSE=ELT_XS_WH}
${SNOWFLAKE_ROLE}                   %{SNOWFLAKE_ROLE=SYSADMIN}


*** Keywords ***
Connect To Snowflake Db
    [Documentation]    Connect to Snowflake (reuses existing connection if available)
    [Arguments]    ${account}=${SNOWFLAKE_ACCOUNT}
    ...    ${user}=${SNOWFLAKE_USER}
    ...    ${password}=${SNOWFLAKE_PASSWORD}
    ...    ${database}=${SNOWFLAKE_DATABASE}
    ...    ${schema}=${SNOWFLAKE_SCHEMA}
    ...    ${warehouse}=${SNOWFLAKE_WAREHOUSE}
    ...    ${role}=${SNOWFLAKE_ROLE}

    # Check if already connected by trying to execute a simple query
    ${is_connected}=    Run Keyword And Return Status
    ...    SnowflakeLib.Execute Snowflake Query    SELECT 1

    IF    ${is_connected}
        Log    ========== REUSING EXISTING SNOWFLAKE CONNECTION ==========    console=yes
        # Get and display current connection context
        ${context}=    SnowflakeLib.Get Current Snowflake Context
        Log    Connected Account: ${context}[account]    console=yes
        Log    Current User: ${context}[user]    console=yes
        Log    Current Database: ${context}[database]    console=yes
        Log    Current Schema: ${context}[schema]    console=yes
        Log    Current Warehouse: ${context}[warehouse]    console=yes
        Log    Current Role: ${context}[role]    console=yes
        Log    ===========================================================    console=yes
    ELSE
        Log    ========== CREATING NEW SNOWFLAKE CONNECTION ==========    console=yes
        Log    Connecting to:    console=yes
        Log    - Account: ${account}    console=yes
        Log    - Database: ${database}    console=yes
        Log    - Schema: ${schema}    console=yes
        Log    - Warehouse: ${warehouse}    console=yes
        Log    - User: ${user}    console=yes
        Log    - Role: ${role}    console=yes

        # Connect if not already connected
        ${connection}=    SnowflakeLib.Connect To Snowflake Db
        ...    ${account}    ${user}    ${password}
        ...    ${database}    ${schema}    ${warehouse}    ${role}

        # Verify new connection and get version
        ${version}=    Get Snowflake Version Wrapper
        Log    Successfully connected to Snowflake version: ${version}    console=yes
        Log    ========================================================    console=yes
    END

Verify Snowflake Connection
    [Documentation]    Verify that the connection to Snowflake is active

    TRY
        ${version}=    SnowflakeLib.Get Snowflake Version
        ${context}=    SnowflakeLib.Get Current Snowflake Context

        Log    Connection verified:    console=yes
        Log    - Version: ${version}    console=yes
        Log    - User: ${context}[user]    console=yes
        Log    - Database: ${context}[database]    console=yes
        Log    - Schema: ${context}[schema]    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    Connection verification failed: ${error}    console=yes
        RETURN    ${FALSE}
    END

Execute Snowflake Query
    [Documentation]    Execute a query and return results
    ...    This wraps the Python library's Execute Snowflake Query
    [Arguments]    ${query}

    # The Python library handles auto-connection
    ${result}=    SnowflakeLib.Execute Snowflake Query    ${query}
    Log    Query executed successfully
    RETURN    ${result}

Execute Snowflake Command Wrapper
    [Documentation]    Execute a command without returning results (DDL, DML)
    ...    This wraps the Python library's Execute Snowflake Command
    [Arguments]    ${command}

    # The Python library handles auto-connection
    ${result}=    SnowflakeLib.Execute Snowflake Command    ${command}
    Log    Command executed: ${result}
    RETURN    ${result}

Disconnect From Snowflake Wrapper
    [Documentation]    Close the Snowflake connection

    ${result}=    SnowflakeLib.Disconnect From Snowflake
    Set Suite Variable    ${SNOWFLAKE_CONNECTION_STATUS}    ${FALSE}
    Log    ${result}    console=yes

Get Snowflake Version Wrapper
    [Documentation]    Get Snowflake version

    ${version}=    SnowflakeLib.Get Snowflake Version
    Log    Snowflake Version: ${version}    console=yes
    RETURN    ${version}

Get Current Snowflake Context
    [Documentation]    Get all current context information

    ${context}=    SnowflakeLib.Get Current Snowflake Context
    Log    Current Snowflake Context:    console=yes
    Log    User: ${context}[user]    console=yes
    Log    Database: ${context}[database]    console=yes
    Log    Schema: ${context}[schema]    console=yes
    Log    Warehouse: ${context}[warehouse]    console=yes
    Log    Role: ${context}[role]    console=yes
    Log    Account: ${context}[account]    console=yes
    RETURN    ${context}

Get Current Snowflake User
    [Documentation]    Get the current connected user

    ${context}=    SnowflakeLib.Get Current Snowflake Context
    RETURN    ${context}[user]

Get Current Snowflake Database
    [Documentation]    Get the current database

    ${context}=    SnowflakeLib.Get Current Snowflake Context
    RETURN    ${context}[database]

Get Current Snowflake Schema
    [Documentation]    Get the current schema

    ${context}=    SnowflakeLib.Get Current Snowflake Context
    RETURN    ${context}[schema]

Get Current Snowflake Warehouse
    [Documentation]    Get the current warehouse

    ${context}=    Get Current Snowflake Context
    RETURN    ${context}[warehouse]

Get Current Snowflake Role
    [Documentation]    Get the current role

    ${context}=    SnowflakeLib.Get Current Snowflake Context
    RETURN    ${context}[role]

Get Current Snowflake Account
    [Documentation]    Get the current account identifier

    ${context}=    SnowflakeLib.Get Current Snowflake Context
    RETURN    ${context}[account]

Create Snowflake Table If Not Exists
    [Documentation]    Create a table if it doesn't already exist
    [Arguments]    ${table_name}    ${table_definition}

    ${result}=    SnowflakeLib.Create Table If Not Exists    ${table_name}    ${table_definition}
    Log    ${result}

Drop Snowflake Table If Exists
    [Documentation]    Drop a table if it exists
    [Arguments]    ${table_name}

    ${result}=    Drop Table If Exists    ${table_name}
    Log    ${result}

Insert Into Snowflake Table
    [Documentation]    Insert data into a Snowflake table
    [Arguments]    ${table_name}    ${columns}    ${values}

    ${insert_statement}=    Set Variable    INSERT INTO ${table_name} (${columns}) VALUES (${values})
    ${result}=    SnowflakeLib.Execute Snowflake Command    ${insert_statement}
    Log    Data inserted into ${table_name}

Get Row Count From Snowflake Table
    [Documentation]    Get the number of rows in a table
    [Arguments]    ${table_name}    ${where_clause}=${EMPTY}

    ${count}=    SnowflakeLib.Get Row Count    ${table_name}    ${where_clause}
    Log    Row count for ${table_name}: ${count}
    RETURN    ${count}

Table Should Exist In Snowflake
    [Documentation]    Verify that a table exists in the current schema
    [Arguments]    ${table_name}

    ${exists}=    SnowflakeLib.Table Should Exist    ${table_name}
    Should Be True    ${exists}    msg=Table ${table_name} does not exist

Table Should Not Exist In Snowflake
    [Documentation]    Verify that a table does not exist in the current schema
    [Arguments]    ${table_name}

    ${query}=    Set Variable
    ...    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '${table_name.upper()}' AND TABLE_SCHEMA = CURRENT_SCHEMA()
    ${result}=    SnowflakeLib.Execute Snowflake Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}

    Should Be Equal As Integers    ${count}    0
    ...    msg=Table ${table_name} exists but should not

Get Snowflake Table Columns
    [Documentation]    Get list of columns for a table
    [Arguments]    ${table_name}

    ${query}=    Set Variable
    ...    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${table_name.upper()}' AND TABLE_SCHEMA = CURRENT_SCHEMA() ORDER BY ORDINAL_POSITION

    ${columns}=    SnowflakeLib.Execute Snowflake Query    ${query}
    Log    Table ${table_name} has ${columns.__len__()} columns
    RETURN    ${columns}

Test Snowflake Connection
    [Documentation]    Test if Snowflake connection is working

    TRY
        ${result}=    SnowflakeLib.Execute Snowflake Query    SELECT 1 as test
        Should Be Equal As Integers    ${result[0][0]}    1
        Log    Snowflake connection test successful    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    Snowflake connection test failed: ${error}    console=yes
        RETURN    ${FALSE}
    END

Use Snowflake Database
    [Documentation]    Switch to a different database
    [Arguments]    ${database_name}

    ${result}=    SnowflakeLib.Use Database    ${database_name}
    Log    Switched to database: ${database_name}
    RETURN    ${result}

Use Snowflake Schema
    [Documentation]    Switch to a different schema
    [Arguments]    ${schema_name}

    ${result}=    SnowflakeLib.Use Schema    ${schema_name}
    Log    Switched to schema: ${schema_name}
    RETURN    ${result}

Use Snowflake Warehouse
    [Documentation]    Switch to a different warehouse
    [Arguments]    ${warehouse_name}

    ${result}=    SnowflakeLib.Use Warehouse    ${warehouse_name}
    Log    Switched to warehouse: ${warehouse_name}
    RETURN    ${result}

Test Time Travel
    [Documentation]    Query data from a past point in time
    [Arguments]    ${table_name}    ${minutes_ago}=5

    ${past_count}=    SnowflakeLib.Test Time Travel    ${table_name}    ${minutes_ago}
    Log    Row count ${minutes_ago} minutes ago: ${past_count}
    RETURN    ${past_count}

Create Stage
    [Documentation]    Create a Snowflake stage for data loading
    [Arguments]    ${stage_name}    ${stage_type}=INTERNAL

    ${result}=    SnowflakeLib.Create Stage    ${stage_name}    ${stage_type}
    Log    ${result}
    RETURN    ${result}

Load Data From Stage
    [Documentation]    Load data from a stage into a table
    [Arguments]    ${stage_name}    ${table_name}    ${file_format}=${None}

    ${result}=    SnowflakeLib.Load Data From Stage    ${stage_name}    ${table_name}    ${file_format}
    Log    Data loaded from stage ${stage_name} to table ${table_name}
    RETURN    ${result}

Run Snowsql Command
    [Documentation]    Execute a command using the SnowSQL Docker container
    ...    Requires SnowSQL Docker container to be running
    [Arguments]    ${command}

    ${output}=    SnowflakeLib.Run Snowsql Command    ${command}
    Log    SnowSQL output: ${output}
    RETURN    ${output}

Execute Snowflake Script
    [Documentation]    Execute multiple SQL statements from a script
    [Arguments]    @{statements}

    FOR    ${statement}    IN    @{statements}
        ${clean_statement}=    Strip String    ${statement}
        IF    '${clean_statement}' == ''    CONTINUE
        IF    $clean_statement.startswith('--')    CONTINUE

        Log    Executing: ${clean_statement}
        TRY
            ${result}=    SnowflakeLib.Execute Snowflake Command    ${clean_statement}
            Log    Statement executed successfully
        EXCEPT    AS    ${error}
            Log    Statement failed: ${error}    WARN
        END
    END

Bulk Insert Into Snowflake
    [Documentation]    Insert multiple rows into a table
    [Arguments]    ${table_name}    ${columns}    @{rows}

    FOR    ${row}    IN    @{rows}
        Insert Into Snowflake Table    ${table_name}    ${columns}    ${row}
    END

    ${count}=    Get Length    ${rows}
    Log    Inserted ${count} rows into ${table_name}

Create Table
    [Documentation]    Create a table in Snowflake with validation and logging
    ...    Handles dropping existing table, creating new one, and verifying structure
    ...    If drop_if_exists is FALSE and table exists, throws an error
    [Arguments]    ${table_name}    ${table_definition}    ${drop_if_exists}=${TRUE}    ${verify_structure}=${TRUE}

    Log    ========== CREATING TABLE ==========    console=yes
    Log    Table Name: ${table_name}    console=yes
    Log    Table Definition: ${table_definition}    console=yes

    # Check if table exists using environment database and schema
    ${query}=    Catenate    SEPARATOR=${SPACE}
    ...    SELECT COUNT(*) FROM ${SNOWFLAKE_DATABASE}.INFORMATION_SCHEMA.TABLES
    ...    WHERE TABLE_NAME = '${table_name.upper()}'
    ...    AND TABLE_SCHEMA = '${SNOWFLAKE_SCHEMA}'
    ...    AND TABLE_CATALOG = '${SNOWFLAKE_DATABASE}'
    ${result}=    SnowflakeLib.Execute Snowflake Query    ${query}
    ${table_exists}=    Set Variable    ${result[0][0] > 0}

    # Handle existing table based on drop_if_exists flag
    IF    ${table_exists}
        IF    ${drop_if_exists}
            # Drop the existing table
            SnowflakeLib.Drop Table If Exists    ${table_name}
            Log    Dropped existing table ${table_name} from schema ${SNOWFLAKE_SCHEMA}    console=yes
        ELSE
            # Throw error if table exists and we're not allowed to drop it
            Fail
            ...    Table ${SNOWFLAKE_DATABASE}.${SNOWFLAKE_SCHEMA}.${table_name} already exists! Set drop_if_exists=TRUE to replace it.
        END
    ELSE
        Log
        ...    Table ${table_name} does not exist in ${SNOWFLAKE_DATABASE}.${SNOWFLAKE_SCHEMA}, creating new table
        ...    console=yes
    END

    # Create the table with fully qualified name
    ${create_query}=    Catenate    SEPARATOR=${SPACE}
    ...    CREATE TABLE ${SNOWFLAKE_DATABASE}.${SNOWFLAKE_SCHEMA}.${table_name}
    ...    ${table_definition}
    Execute Snowflake Command Wrapper    ${create_query}
    Log    Table ${table_name} created successfully in ${SNOWFLAKE_DATABASE}.${SNOWFLAKE_SCHEMA}    console=yes

    # Verify table exists
    ${exists}=    SnowflakeLib.Table Should Exist    ${table_name}
    Should Be True    ${exists}    msg=Failed to create table ${table_name}
    Log    Verified: Table ${table_name} exists in ${SNOWFLAKE_DATABASE}.${SNOWFLAKE_SCHEMA}    console=yes

    # Get and display table structure (optional)
    IF    ${verify_structure}
        ${columns}=    Get Snowflake Table Columns    ${table_name}
        Log    ========== TABLE STRUCTURE ==========    console=yes
        FOR    ${column}    IN    @{columns}
            Log    Column: ${column[0]}, Type: ${column[1]}, Nullable: ${column[2]}    console=yes
        END
        RETURN    ${columns}
    END

    RETURN    ${TRUE}

Select All Records From Table
    [Documentation]    Select all records from a specified table and return the results
    ...    Optionally specify columns to select and order by clause
    [Arguments]    ${table_name}    ${columns}=*    ${order_by}=${EMPTY}    ${log_results}=${TRUE}

    Log    ========== SELECTING RECORDS FROM ${table_name} ==========    console=yes

    # Build the query
    ${query}=    Set Variable    SELECT ${columns} FROM ${table_name}

    # Add ORDER BY clause if specified
    IF    '${order_by}' != '${EMPTY}'
        ${query}=    Set Variable    ${query} ORDER BY ${order_by}
    END

    Log    Executing query: ${query}    console=yes

    # Execute the query
    ${results}=    SnowflakeLib.Execute Snowflake Query    ${query}

    # Get row count
    ${row_count}=    Get Length    ${results}
    Log    Retrieved ${row_count} records from ${table_name}    console=yes

    # Optionally log the results
    IF    ${log_results}
        Log    ========== QUERY RESULTS ==========    console=yes
        ${index}=    Set Variable    ${1}
        FOR    ${row}    IN    @{results}
            Log    Row ${index}: ${row}    console=yes
            ${index}=    Evaluate    ${index} + 1
        END
        Log    ====================================    console=yes
    END

    RETURN    ${results}

Select Records With Where Clause
    [Documentation]    Select records from a table with a WHERE clause condition
    ...    Returns the filtered results
    [Arguments]    ${table_name}    ${where_clause}    ${columns}=*    ${order_by}=${EMPTY}    ${log_results}=${TRUE}

    Log    ========== SELECTING FILTERED RECORDS FROM ${table_name} ==========    console=yes

    # Build the query with WHERE clause
    ${query}=    Set Variable    SELECT ${columns} FROM ${table_name} WHERE ${where_clause}

    # Add ORDER BY clause if specified
    IF    '${order_by}' != '${EMPTY}'
        ${query}=    Set Variable    ${query} ORDER BY ${order_by}
    END

    Log    Executing query: ${query}    console=yes

    # Execute the query
    ${results}=    SnowflakeLib.Execute Snowflake Query    ${query}

    # Get row count
    ${row_count}=    Get Length    ${results}
    Log    Retrieved ${row_count} records matching condition: ${where_clause}    console=yes

    # Optionally log the results
    IF    ${log_results}
        Log    ========== FILTERED RESULTS ==========    console=yes
        ${index}=    Set Variable    ${1}
        FOR    ${row}    IN    @{results}
            Log    Row ${index}: ${row}    console=yes
            ${index}=    Evaluate    ${index} + 1
        END
        Log    ======================================    console=yes
    END

    RETURN    ${results}

Get Table Data As Dictionary
    [Documentation]    Select all records from a table and return as a list of dictionaries
    ...    Each dictionary contains column names as keys and values as the row data
    [Arguments]    ${table_name}    ${order_by}=${EMPTY}

    Log    ========== GETTING TABLE DATA AS DICTIONARY ==========    console=yes

    # First get column names
    ${columns_info}=    Get Snowflake Table Columns    ${table_name}
    @{column_names}=    Create List
    FOR    ${col_info}    IN    @{columns_info}
        Append To List    ${column_names}    ${col_info[0]}
    END
    Log    Column names: ${column_names}    console=yes

    # Get all records
    ${results}=    Select All Records From Table    ${table_name}    order_by=${order_by}    log_results=${FALSE}

    # Convert to list of dictionaries
    @{dict_results}=    Create List
    FOR    ${row}    IN    @{results}
        &{row_dict}=    Create Dictionary
        ${index}=    Set Variable    ${0}
        FOR    ${col_name}    IN    @{column_names}
            Set To Dictionary    ${row_dict}    ${col_name}=${row[${index}]}
            ${index}=    Evaluate    ${index} + 1
        END
        Append To List    ${dict_results}    ${row_dict}
    END

    Log    Converted ${results.__len__()} rows to dictionary format    console=yes
    RETURN    ${dict_results}

Execute Select Query And Verify Count
    [Documentation]    Execute a SELECT query and verify the expected number of records
    ...    Fails if the count doesn't match expected
    [Arguments]    ${table_name}    ${expected_count}    ${where_clause}=${EMPTY}

    # Build appropriate query based on whether WHERE clause is provided
    IF    '${where_clause}' == '${EMPTY}'
        ${results}=    Select All Records From Table    ${table_name}    log_results=${FALSE}
    ELSE
        ${results}=    Select Records With Where Clause    ${table_name}    ${where_clause}    log_results=${FALSE}
    END

    ${actual_count}=    Get Length    ${results}
    Should Be Equal As Integers    ${actual_count}    ${expected_count}
    ...    msg=Expected ${expected_count} records but got ${actual_count} from ${table_name}

    Log    ✓ Verified: ${actual_count} records found (expected: ${expected_count})    console=yes
    RETURN    ${results}

Extract Column Values From Dictionary
    [Documentation]    Extract all values for a specific column from dictionary results
    ...    Returns a list containing only the values for the specified column
    [Arguments]    ${dict_results}    ${column_name}

    @{column_values}=    Create List

    FOR    ${row_dict}    IN    @{dict_results}
        # Check if column exists in the dictionary
        ${has_column}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key
        ...    ${row_dict}
        ...    ${column_name}
        IF    ${has_column}
            Append To List    ${column_values}    ${row_dict}[${column_name}]
        ELSE
            Log    Warning: Column ${column_name} not found in record    WARN
        END
    END

    ${count}=    Get Length    ${column_values}
    Log    Extracted ${count} values for column ${column_name}: ${column_values}    console=yes
    RETURN    ${column_values}

Extract Multiple Columns From Dictionary
    [Documentation]    Extract values for multiple columns from dictionary results
    ...    Returns a dictionary with column names as keys and lists of values
    [Arguments]    ${dict_results}    @{column_names}

    &{extracted_data}=    Create Dictionary

    # Initialize lists for each column
    FOR    ${col_name}    IN    @{column_names}
        @{col_values}=    Create List
        Set To Dictionary    ${extracted_data}    ${col_name}=${col_values}
    END

    # Extract values for each record
    FOR    ${row_dict}    IN    @{dict_results}
        FOR    ${col_name}    IN    @{column_names}
            ${has_column}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key
            ...    ${row_dict}
            ...    ${col_name}
            IF    ${has_column}
                Append To List    ${extracted_data}[${col_name}]    ${row_dict}[${col_name}]
            END
        END
    END

    Log    Extracted data for columns ${column_names}: ${extracted_data}    console=yes
    RETURN    ${extracted_data}

Get Unique Column Values
    [Documentation]    Extract unique values for a specific column from dictionary results
    ...    Returns a list of unique values (removes duplicates)
    [Arguments]    ${dict_results}    ${column_name}

    # First extract all values
    @{all_values}=    Extract Column Values From Dictionary    ${dict_results}    ${column_name}

    # Convert to set to remove duplicates, then back to list
    ${unique_values}=    Evaluate    list(set(${all_values}))
    ${unique_values}=    Evaluate    sorted(${unique_values})    # Sort for consistency

    ${count}=    Get Length    ${unique_values}
    Log    Found ${count} unique values for ${column_name}: ${unique_values}    console=yes
    RETURN    ${unique_values}

Filter Dictionary Results By Column Value
    [Documentation]    Filter dictionary results based on a column value condition
    ...    Returns only the records that match the condition
    [Arguments]    ${dict_results}    ${column_name}    ${operator}    ${value}

    @{filtered_results}=    Create List

    FOR    ${row_dict}    IN    @{dict_results}
        ${has_column}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key
        ...    ${row_dict}
        ...    ${column_name}
        IF    ${has_column}
            ${match}=    Evaluate Column Condition    ${row_dict}[${column_name}]    ${operator}    ${value}
            IF    ${match}
                Append To List    ${filtered_results}    ${row_dict}
            END
        END
    END

    ${count}=    Get Length    ${filtered_results}
    Log    Found ${count} records where ${column_name} ${operator} ${value}    console=yes
    RETURN    ${filtered_results}

Evaluate Column Condition
    [Documentation]    Helper keyword to evaluate conditions for filtering
    [Arguments]    ${actual_value}    ${operator}    ${expected_value}

    IF    '${operator}' == '=='
        ${result}=    Evaluate    '${actual_value}' == '${expected_value}'
    ELSE IF    '${operator}' == '!='
        ${result}=    Evaluate    '${actual_value}' != '${expected_value}'
    ELSE IF    '${operator}' == '>'
        ${result}=    Evaluate    ${actual_value} > ${expected_value}
    ELSE IF    '${operator}' == '>='
        ${result}=    Evaluate    ${actual_value} >= ${expected_value}
    ELSE IF    '${operator}' == '<'
        ${result}=    Evaluate    ${actual_value} < ${expected_value}
    ELSE IF    '${operator}' == '<='
        ${result}=    Evaluate    ${actual_value} <= ${expected_value}
    ELSE IF    '${operator}' == 'IN'
        ${result}=    Evaluate    '${actual_value}' in ${expected_value}
    ELSE IF    '${operator}' == 'LIKE'
        ${result}=    Evaluate    '${expected_value}' in '${actual_value}'
    ELSE
        ${result}=    Fail    Unsupported operator: ${operator}
    END

    RETURN    ${result}

Drop Table
    [Documentation]    Drop a table and verify it no longer exists
    [Arguments]    ${table_name}    ${fail_if_not_exists}=${FALSE}

    Log    ========== DROPPING TABLE ==========    console=yes

    IF    ${fail_if_not_exists}
        # First check if table exists
        ${exists}=    SnowflakeLib.Table Should Exist    ${table_name}
        Should Be True    ${exists}    msg=Cannot drop table ${table_name} - it doesn't exist
    END

    # Drop the table
    SnowflakeLib.Drop Table If Exists    ${table_name}
    Log    Table ${table_name} dropped    console=yes

    # Verify it's gone
    Table Should Not Exist In Snowflake    ${table_name}
    Log    Verified: Table ${table_name} no longer exists    console=yes

    RETURN    ${TRUE}
