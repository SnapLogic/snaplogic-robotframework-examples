*** Settings ***
Documentation       Snowflake DatabaseLibrary Keywords - Refactored Version
...                 This is the refactored version with modular keywords

Library             DatabaseLibrary
Library             OperatingSystem
Library             Collections
Library             String
Library             BuiltIn


*** Variables ***
# Copy the existing variables from the original file
${SNOWFLAKE_HOSTNAME}               ${EMPTY}
${SNOWFLAKE_USERNAME}               ${EMPTY}
${SNOWFLAKE_PASSWORD}               ${EMPTY}
${SNOWFLAKE_DATABASE}               ${EMPTY}
${SNOWFLAKE_SCHEMA}                 ${EMPTY}
${SNOWFLAKE_WAREHOUSE}              ${EMPTY}
${SNOWFLAKE_ROLE}                   ${EMPTY}
${SNOWFLAKE_ACCOUNT_IDENTIFIER}     ${EMPTY}
${SNOWFLAKE_CONNECTION_METHOD}      NONE


*** Keywords ***
Connect To Snowflake Via DatabaseLibrary
    [Documentation]    Connect to Snowflake using DatabaseLibrary - Simplified version
    ...    This version uses modular keywords for each connection step
    ...    Returns: Connection details dictionary with status and database info
    [Arguments]    ${account}=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
    ...    ${user}=${SNOWFLAKE_USERNAME}
    ...    ${password}=${SNOWFLAKE_PASSWORD}
    ...    ${database}=${SNOWFLAKE_DATABASE}
    ...    ${schema}=${SNOWFLAKE_SCHEMA}
    ...    ${warehouse}=${SNOWFLAKE_WAREHOUSE}
    ...    ${role}=${SNOWFLAKE_ROLE}

    # Initialize connection details dictionary
    ${connection_details}=    Create Dictionary    method=NONE    status=FAILED    error=${EMPTY}

    Log    ========================================    console=yes
    Log    Connecting to Snowflake via DatabaseLibrary...    console=yes
    Log    User: ${user}    console=yes
    Log    Role: ${role}    console=yes
    Log    Account: ${account}    console=yes
    Log    ========================================    console=yes

    TRY
        # Step 1: Establish the connection
        ${connected}=    Establish Snowflake Connection    
        ...    user=${user}    
        ...    password=${password}    
        ...    account=${account}    
        ...    role=${role}

        # Step 2: Check available resources
        Log    ========================================    console=yes
        Log    Checking available Snowflake resources...    console=yes
        ${db_names}=    Get Available Snowflake Databases
        ${warehouses}=    Get Available Snowflake Warehouses
        Log    ========================================    console=yes

        # Step 3: Setup warehouse
        ${warehouse_status}=    Setup Snowflake Warehouse    ${warehouse}

        # Step 4: Setup database
        ${actual_database}=    Setup Snowflake Database    ${database}    ${db_names}
        
        # Step 5: Setup schema (only if database was set)
        ${actual_schema}=    Set Variable    ${EMPTY}
        IF    '${actual_database}' != '${EMPTY}'
            ${actual_schema}=    Setup Snowflake Schema    ${schema}
        END

        # Step 6: Verify the final context
        ${context}=    Verify Snowflake Context

        # Step 7: Update connection details with success
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    DatabaseLibrary Connection

        Set To Dictionary    ${connection_details}
        ...    method=DatabaseLibrary
        ...    status=SUCCESS
        ...    database=${context}[database]
        ...    schema=${context}[schema]
        ...    warehouse=${context}[warehouse]

        RETURN    ${connection_details}
        
    EXCEPT    AS    ${error}
        # Connection failed
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    FAILED
        Set To Dictionary    ${connection_details}    error=${error}

        Log    ========================================    console=yes
        Log    ❌ Failed to connect to Snowflake    console=yes
        Log    Error: ${error}    console=yes
        Log    ========================================    console=yes
        Log    Troubleshooting tips:    console=yes
        Log    1. Ensure snowflake-connector-python is installed    console=yes
        Log    2. Verify your credentials and network access    console=yes
        Log    3. Check if account format is correct    console=yes
        Log    ========================================    console=yes

        Fail    Could not connect to Snowflake via DatabaseLibrary: ${error}
    END

# Include all the modular keywords here
Establish Snowflake Connection
    [Documentation]    Establish initial connection to Snowflake using various methods
    [Arguments]    ${user}    ${password}    ${account}    ${role}
    
    Log    Connecting with user=${user}, account=${account}    console=yes
    
    # Method 1: Use the new Connect To Database with custom parameters
    TRY
        Connect To Database
        ...    snowflake.connector
        ...    ${EMPTY}
        ...    ${user}
        ...    ${password}
        ...    ${EMPTY}
        ...    ${EMPTY}
        ...    account=${account}
        ...    role=${role}
        
        Log    ✅ Connected using new Connect To Database syntax (no deprecation warning)    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error1}
        Log    ⚠️ New syntax failed: ${error1}    console=yes
    END
    
    # Method 2: Try with connection string format
    TRY
        ${conn_string}=    Set Variable    account=${account};user=${user};password=${password};role=${role}
        Connect To Database    snowflake.connector    ${conn_string}
        Log    ✅ Connected using connection string format    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error2}
        Log    ⚠️ Connection string method failed: ${error2}    console=yes
    END
    
    # Method 3: Last resort - use deprecated method that we know works
    Log    Using fallback (deprecated) connection method...    console=yes
    Connect To Database Using Custom Params
    ...    snowflake.connector
    ...    user='${user}', password='${password}', account='${account}', role='${role}'
    Log    ⚠️ Connected using deprecated method (will show warning)    console=yes
    RETURN    ${TRUE}

Get Available Snowflake Databases
    [Documentation]    Get list of available databases in Snowflake
    [Return]    ${db_names}
    
    TRY
        ${databases}=    Query    SHOW DATABASES
        ${db_names}=    Create List
        FOR    ${db}    IN    @{databases}
            Append To List    ${db_names}    ${db[1]}
            Log    Available DB: ${db[1]}    console=yes
        END
        RETURN    ${db_names}
    EXCEPT
        Log    Could not list databases    console=yes
        ${empty_list}=    Create List
        RETURN    ${empty_list}
    END

Get Available Snowflake Warehouses
    [Documentation]    Get list of available warehouses in Snowflake
    
    TRY
        ${warehouses}=    Query    SHOW WAREHOUSES
        Log    Available Warehouses:    console=yes
        FOR    ${wh}    IN    @{warehouses}
            Log    - ${wh[0]} (state: ${wh[2]})    console=yes
        END
        RETURN    ${warehouses}
    EXCEPT
        Log    Could not list warehouses    console=yes
        RETURN    ${EMPTY}
    END

Setup Snowflake Warehouse
    [Documentation]    Set up or create the specified warehouse
    [Arguments]    ${warehouse}
    [Return]    ${status}
    
    # Try to use existing warehouse
    TRY
        Log    Setting warehouse: ${warehouse}    console=yes
        Execute Sql String    USE WAREHOUSE ${warehouse}
        Log    ✅ Warehouse set successfully    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${wh_error}
        Log    ⚠️ Could not set warehouse ${warehouse}: ${wh_error}    console=yes
    END
    
    # Try to create warehouse if it doesn't exist
    TRY
        Log    Attempting to create warehouse ${warehouse}...    console=yes
        Execute Sql String    CREATE WAREHOUSE IF NOT EXISTS ${warehouse} WITH WAREHOUSE_SIZE = 'XSMALL'
        Execute Sql String    USE WAREHOUSE ${warehouse}
        Log    ✅ Created and set warehouse ${warehouse}    console=yes
        RETURN    ${TRUE}
    EXCEPT
        Log    ❌ Could not create warehouse    console=yes
        RETURN    ${FALSE}
    END

Setup Snowflake Database
    [Documentation]    Set up or create the specified database
    [Arguments]    ${database}    ${db_names}
    [Return]    ${actual_database}
    
    # Check if requested database exists
    IF    '${database}' in ${db_names}
        TRY
            Log    Database ${database} exists, using it...    console=yes
            Execute Sql String    USE DATABASE ${database}
            Log    ✅ Database set to ${database}    console=yes
            RETURN    ${database}
        EXCEPT    AS    ${db_error}
            Log    ⚠️ Could not use existing database ${database}: ${db_error}    console=yes
        END
    ELSE
        Log    ⚠️ Database ${database} does not exist    console=yes
    END
    
    # Try to create the database
    TRY
        Log    Attempting to create database ${database}...    console=yes
        Execute Sql String    CREATE DATABASE IF NOT EXISTS ${database}
        Execute Sql String    USE DATABASE ${database}
        Log    ✅ Created and set database ${database}    console=yes
        RETURN    ${database}
    EXCEPT    AS    ${create_error}
        Log    ⚠️ Could not create database ${database}: ${create_error}    console=yes
    END
    
    # Fall back to first available database
    IF    ${db_names}
        ${first_db}=    Get From List    ${db_names}    0
        TRY
            Log    Using first available database: ${first_db}    console=yes
            Execute Sql String    USE DATABASE ${first_db}
            Log    ✅ Using database ${first_db} instead    console=yes
            RETURN    ${first_db}
        EXCEPT
            Log    ❌ Could not use any database    console=yes
        END
    END
    
    RETURN    ${EMPTY}

Setup Snowflake Schema
    [Documentation]    Set up or create the specified schema
    [Arguments]    ${schema}
    [Return]    ${actual_schema}
    
    # Try to use requested schema
    TRY
        Log    Setting schema: ${schema}    console=yes
        Execute Sql String    USE SCHEMA ${schema}
        Log    ✅ Schema set successfully    console=yes
        RETURN    ${schema}
    EXCEPT    AS    ${schema_error}
        Log    ⚠️ Could not set schema ${schema}: ${schema_error}    console=yes
    END
    
    # Try to create schema
    TRY
        Log    Attempting to create schema ${schema}...    console=yes
        Execute Sql String    CREATE SCHEMA IF NOT EXISTS ${schema}
        Execute Sql String    USE SCHEMA ${schema}
        Log    ✅ Created and set schema ${schema}    console=yes
        RETURN    ${schema}
    EXCEPT
        Log    ⚠️ Could not create schema ${schema}    console=yes
    END
    
    # Fall back to PUBLIC schema
    TRY
        Execute Sql String    USE SCHEMA PUBLIC
        Log    ℹ️ Using PUBLIC schema instead    console=yes
        RETURN    PUBLIC
    EXCEPT
        Log    ❌ Could not set any schema    console=yes
        RETURN    ${EMPTY}
    END

Verify Snowflake Context
    [Documentation]    Verify and log the current Snowflake context
    [Return]    ${context_details}
    
    TRY
        ${result}=    Query    SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE()
        
        ${context_details}=    Create Dictionary
        ...    database=${result[0][0]}
        ...    schema=${result[0][1]}
        ...    warehouse=${result[0][2]}
        
        Log    ========================================    console=yes
        Log    ✅ Successfully connected to Snowflake    console=yes
        Log    Database: ${result[0][0]}    console=yes
        Log    Schema: ${result[0][1]}    console=yes
        Log    Warehouse: ${result[0][2]}    console=yes
        Log    ========================================    console=yes
        
        RETURN    ${context_details}
    EXCEPT    AS    ${error}
        Log    ❌ Could not verify context: ${error}    console=yes
        ${empty_context}=    Create Dictionary    database=${EMPTY}    schema=${EMPTY}    warehouse=${EMPTY}
        RETURN    ${empty_context}
    END
