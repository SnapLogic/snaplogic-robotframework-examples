*** Settings ***
Documentation       Snowflake DatabaseLibrary Keywords - Flexible Authentication
...                 Supports both password and key pair authentication
...                 Automatically detects authentication type based on available environment variables
...                 No default values - relies on Docker compose env loading

Library             DatabaseLibrary
Library             OperatingSystem
Library             Collections
Library             String
Library             BuiltIn


*** Variables ***
# These variables will be populated from environment files loaded via Docker compose
# Password Authentication Variables
${SNOWFLAKE_HOSTNAME}                           %{SNOWFLAKE_HOSTNAME=${EMPTY}}
${SNOWFLAKE_USERNAME}                           %{SNOWFLAKE_USERNAME=${EMPTY}}
${SNOWFLAKE_PASSWORD}                           %{SNOWFLAKE_PASSWORD=${EMPTY}}
${SNOWFLAKE_DATABASE}                           %{SNOWFLAKE_DATABASE=${EMPTY}}
${SNOWFLAKE_SCHEMA}                             %{SNOWFLAKE_SCHEMA=${EMPTY}}
${SNOWFLAKE_WAREHOUSE}                          %{SNOWFLAKE_WAREHOUSE=${EMPTY}}
${SNOWFLAKE_ROLE}                               %{SNOWFLAKE_ROLE=${EMPTY}}
${SNOWFLAKE_ACCOUNT}                            %{SNOWFLAKE_ACCOUNT=${EMPTY}}

# Key Pair Authentication Variables
${SNOWFLAKE_KEYPAIR_HOSTNAME}                   %{SNOWFLAKE_KEYPAIR_HOSTNAME=${EMPTY}}
${SNOWFLAKE_KEYPAIR_USERNAME}                   %{SNOWFLAKE_KEYPAIR_USERNAME=${EMPTY}}
${SNOWFLAKE_KEYPAIR_PRIVATE_KEY}                %{SNOWFLAKE_KEYPAIR_PRIVATE_KEY=${EMPTY}}
${SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE}     %{SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_DATABASE}                   %{SNOWFLAKE_KEYPAIR_DATABASE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_WAREHOUSE}                  %{SNOWFLAKE_KEYPAIR_WAREHOUSE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_SCHEMA}                     %{SNOWFLAKE_KEYPAIR_SCHEMA=${EMPTY}}
${SNOWFLAKE_KEYPAIR_ROLE}                       %{SNOWFLAKE_KEYPAIR_ROLE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_PORT}                       %{SNOWFLAKE_KEYPAIR_PORT=${EMPTY}}
${SNOWFLAKE_KEYPAIR_ACCOUNT_NAME}               %{SNOWFLAKE_KEYPAIR_ACCOUNT_NAME=${EMPTY}}
${SNOWFLAKE_KEYPAIR_AUTHENTICATION_TYPE}        %{SNOWFLAKE_KEYPAIR_AUTHENTICATION_TYPE=${EMPTY}}
${SNOWFLAKE_ACCOUNT_IDENTIFIER}                 %{SNOWFLAKE_ACCOUNT_IDENTIFIER=${EMPTY}}

# Connection tracking
${SNOWFLAKE_CONNECTION_METHOD}                  NONE


*** Keywords ***
Connect To Snowflake Via DatabaseLibrary
    [Documentation]    Snowflake connection using specified authentication type
    ...    Uses environment variables loaded via Docker compose
    ...    Defaults to password authentication
    ...    Pass 'keypair' as argument for key pair authentication
    ...
    ...    Arguments:
    ...    - auth_type: Authentication type ('password' or 'keypair'), defaults to 'password'
    ...
    ...    Example:
    ...    Connect To Snowflake Via DatabaseLibrary    # Uses password auth
    ...    Connect To Snowflake Via DatabaseLibrary    password    # Explicit password auth
    ...    Connect To Snowflake Via DatabaseLibrary    keypair    # Uses keypair auth
    [Arguments]    ${auth_type}=password

    # Convert to lowercase for case-insensitive comparison
    ${auth_type_lower}=    Convert To Lowercase    ${auth_type}

    Log    ========================================    console=yes
    Log    Authentication Type: ${auth_type_lower}    console=yes
    Log    ========================================    console=yes

    # Connect based on specified authentication type
    IF    '${auth_type_lower}' == 'keypair'
        ${result}=    Connect Using KeyPair Authentication
    ELSE IF    '${auth_type_lower}' == 'password'
        ${result}=    Connect Using Password Authentication
    ELSE
        Fail    Invalid authentication type: '${auth_type}'. Must be 'password' or 'keypair'.
    END

    RETURN    ${result}

Connect Using KeyPair Authentication
    [Documentation]    Connect to Snowflake using key pair authentication
    ...    Uses SNOWFLAKE_KEYPAIR_* environment variables

    # Initialize connection details
    ${connection_details}=    Create Dictionary    method=NONE    status=FAILED    error=${EMPTY}

    Log    ========================================    console=yes
    Log    Connecting with Key Pair Authentication    console=yes
    Log    Account: ${SNOWFLAKE_ACCOUNT_IDENTIFIER}    console=yes
    Log    Hostname: ${SNOWFLAKE_KEYPAIR_HOSTNAME}    console=yes
    Log    User: ${SNOWFLAKE_KEYPAIR_USERNAME}    console=yes
    Log    Role: ${SNOWFLAKE_KEYPAIR_ROLE}    console=yes
    Log    Database: ${SNOWFLAKE_KEYPAIR_DATABASE}    console=yes
    Log    Warehouse: ${SNOWFLAKE_KEYPAIR_WAREHOUSE}    console=yes
    Log    Schema: ${SNOWFLAKE_KEYPAIR_SCHEMA}    console=yes
    Log    ========================================    console=yes

    TRY
        # Establish connection
        ${connected}=    Establish Snowflake KeyPair Connection
        ...    user=${SNOWFLAKE_KEYPAIR_USERNAME}
        ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
        ...    private_key=${SNOWFLAKE_KEYPAIR_PRIVATE_KEY}
        ...    private_key_passphrase=${SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE}
        ...    role=${SNOWFLAKE_KEYPAIR_ROLE}

        # Setup database context
        ${context}=    Setup Snowflake Context
        ...    database=${SNOWFLAKE_KEYPAIR_DATABASE}
        ...    schema=${SNOWFLAKE_KEYPAIR_SCHEMA}
        ...    warehouse=${SNOWFLAKE_KEYPAIR_WAREHOUSE}

        # Update connection details
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    KeyPair
        Set To Dictionary    ${connection_details}
        ...    method=KeyPair
        ...    status=SUCCESS
        ...    database=${context}[database]
        ...    schema=${context}[schema]
        ...    warehouse=${context}[warehouse]
        ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
        ...    user=${SNOWFLAKE_KEYPAIR_USERNAME}

        RETURN    ${connection_details}
    EXCEPT    AS    ${error}
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    FAILED
        Set To Dictionary    ${connection_details}    error=${error}
        Log    ❌ Failed to connect with key pair: ${error}    console=yes

        # Provide detailed troubleshooting guidance
        ${error_msg}=    Set Variable
        ...    Could not connect to Snowflake with key pair: ${error}\n\n🔍 Troubleshooting Checklist:\n✓ Verify SNOWFLAKE_KEYPAIR_USERNAME is set correctly\n✓ Verify SNOWFLAKE_KEYPAIR_PRIVATE_KEY path exists or key content is valid\n✓ Verify SNOWFLAKE_ACCOUNT_IDENTIFIER matches your Snowflake account\n✓ Check if private key is encrypted and passphrase is provided (SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE)\n✓ Ensure key format is PEM (should start with -----BEGIN PRIVATE KEY-----)\n✓ Verify the user has key pair authentication enabled in Snowflake (DESC USER username;)\n✓ Confirm the public key is uploaded to Snowflake and matches your private key\n\n💡 Common Issue: "Password is empty" error usually means:\n
        ...    - Private key parameter is not being passed correctly\n
        ...    - Using wrong connection method (try using Connect To Database Using Custom Params)\n
        ...    - Environment variables are not loaded properly
        Fail    ${error_msg}
    END

Connect Using Password Authentication
    [Documentation]    Connect to Snowflake using password authentication
    ...    Uses SNOWFLAKE_* environment variables (without KEYPAIR prefix)

    # Initialize connection details
    ${connection_details}=    Create Dictionary    method=NONE    status=FAILED    error=${EMPTY}

    Log    ========================================    console=yes
    Log    Connecting with Password Authentication    console=yes
    Log    Account: ${SNOWFLAKE_ACCOUNT_IDENTIFIER}    console=yes
    Log    Hostname: ${SNOWFLAKE_HOSTNAME}    console=yes
    Log    User: ${SNOWFLAKE_USERNAME}    console=yes
    Log    Role: ${SNOWFLAKE_ROLE}    console=yes
    Log    Database: ${SNOWFLAKE_DATABASE}    console=yes
    Log    Warehouse: ${SNOWFLAKE_WAREHOUSE}    console=yes
    Log    Schema: ${SNOWFLAKE_SCHEMA}    console=yes
    Log    ========================================    console=yes

    TRY
        # Establish connection
        ${connected}=    Establish Snowflake Password Connection
        ...    user=${SNOWFLAKE_USERNAME}
        ...    password=${SNOWFLAKE_PASSWORD}
        ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
        ...    role=${SNOWFLAKE_ROLE}

        # Setup database context
        ${context}=    Setup Snowflake Context
        ...    database=${SNOWFLAKE_DATABASE}
        ...    schema=${SNOWFLAKE_SCHEMA}
        ...    warehouse=${SNOWFLAKE_WAREHOUSE}

        # Update connection details
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    Password
        Set To Dictionary    ${connection_details}
        ...    method=Password
        ...    status=SUCCESS
        ...    database=${context}[database]
        ...    schema=${context}[schema]
        ...    warehouse=${context}[warehouse]
        ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
        ...    user=${SNOWFLAKE_USERNAME}

        RETURN    ${connection_details}
    EXCEPT    AS    ${error}
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    FAILED
        Set To Dictionary    ${connection_details}    error=${error}
        Log    ❌ Failed to connect with password: ${error}    console=yes
        Fail    Could not connect to Snowflake with password: ${error}
    END

Establish Snowflake KeyPair Connection
    [Documentation]    Internal keyword to establish key pair connection
    ...    Tries multiple connection methods for robustness and backward compatibility
    ...    Method 1: Direct connection with kwargs (modern DatabaseLibrary 5.0+)
    ...    Method 2: Connect To Database Using Custom Params (fallback for older DatabaseLibrary/snowflake-connector versions)
    [Arguments]    ${user}    ${account}    ${private_key}    ${private_key_passphrase}    ${role}

    # Process the private key
    ${clean_key}=    Process Private Key For Connection    ${private_key}

    # Try connection methods
    TRY
        # Method 1: Direct key pair authentication (pass None for password, not empty string)
        IF    '${private_key_passphrase}' != '${EMPTY}'
            Connect To Database Using Custom Params
            ...    snowflake.connector
            ...    user='${user}', account='${account}', role='${role}', private_key='${clean_key}', private_key_passphrase='${private_key_passphrase}'
        ELSE
            Connect To Database Using Custom Params
            ...    snowflake.connector
            ...    user='${user}', account='${account}', role='${role}', private_key='${clean_key}'
        END
        Log    ✅ Connected using key pair authentication    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        # Method 2: Fallback for older DatabaseLibrary/snowflake-connector versions (backward compatibility)
        TRY
            IF    '${private_key_passphrase}' != '${EMPTY}'
                Connect To Database Using Custom Params
                ...    snowflake.connector
                ...    user='${user}', account='${account}', role='${role}',
                ...    private_key='${clean_key}', private_key_passphrase='${private_key_passphrase}'
            ELSE
                Connect To Database Using Custom Params
                ...    snowflake.connector
                ...    user='${user}', account='${account}', role='${role}',
                ...    private_key='${clean_key}'
            END
            Log    ✅ Connected using key pair (custom params)    console=yes
            RETURN    ${TRUE}
        EXCEPT    AS    ${error2}
            # Customize error message to help with troubleshooting
            ${error_msg}=    Set Variable
            ...    Key pair authentication failed: ${error2}\n\nTroubleshooting:\n- Verify SNOWFLAKE_KEYPAIR_USERNAME is set\n- Verify SNOWFLAKE_KEYPAIR_PRIVATE_KEY path is correct or key content is valid\n- Verify SNOWFLAKE_ACCOUNT_IDENTIFIER is correct\n- Check if private key requires passphrase (SNOWFLAKE_KEYPAIR_PRIVATE_KEY_PASSPHRASE)\n- Ensure key format is correct (PEM format)\n- Verify user has key pair authentication enabled in Snowflake
            Fail    ${error_msg}
        END
    END

Establish Snowflake Password Connection
    [Documentation]    Internal keyword to establish password connection
    ...    Tries multiple connection methods for robustness and backward compatibility
    ...    Method 1: Direct connection with kwargs (modern DatabaseLibrary 5.0+)
    ...    Method 2: Connection string format
    ...    Method 3: Connect To Database Using Custom Params (fallback for older DatabaseLibrary/snowflake-connector versions)
    [Arguments]    ${user}    ${password}    ${account}    ${role}

    # Try connection methods
    TRY
        # Method 1: Direct connection
        Connect To Database
        ...    snowflake.connector
        ...    ${EMPTY}
        ...    ${user}
        ...    ${password}
        ...    ${EMPTY}
        ...    ${EMPTY}
        ...    account=${account}
        ...    role=${role}
        Log    ✅ Connected using password authentication    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        # Method 2: Try connection string
        TRY
            ${conn_string}=    Set Variable    account=${account};user=${user};password=${password};role=${role}
            Connect To Database    snowflake.connector    ${conn_string}
            Log    ✅ Connected using connection string    console=yes
            RETURN    ${TRUE}
        EXCEPT    AS    ${error2}
            # Method 3: Fallback for older DatabaseLibrary/snowflake-connector versions (backward compatibility)
            TRY
                Connect To Database Using Custom Params
                ...    snowflake.connector
                ...    user='${user}', password='${password}', account='${account}', role='${role}'
                Log    ✅ Connected using custom params    console=yes
                RETURN    ${TRUE}
            EXCEPT    AS    ${error3}
                Fail    Password authentication failed: ${error3}
            END
        END
    END

Setup Snowflake Context
    [Documentation]    Setup database, schema, and warehouse context for Snowflake queries
    ...    Before running queries in Snowflake, you must specify WHERE to run them:
    ...    - Warehouse: Compute engine that provides resources (CPU/RAM) to run queries
    ...    - Database: Which database to use (e.g., FDLDB, SALES_DB)
    ...    - Schema: Which schema within the database (e.g., INTUIT, PUBLIC, CLAIMS)
    ...
    ...    Smart Features:
    ...    - Auto-creates resources if they don't exist (warehouse, database, schema)
    ...    - Falls back to available resources if specified ones fail
    ...    - Defaults to PUBLIC schema if no schema specified
    ...    - Verifies final context with SQL query to confirm setup
    ...
    ...    Returns: Dictionary with database, schema, and warehouse that were successfully set
    [Arguments]    ${database}    ${schema}    ${warehouse}

    ${context}=    Create Dictionary    database=${EMPTY}    schema=${EMPTY}    warehouse=${EMPTY}

    # Get available resources
    ${db_names}=    Get Available Databases
    ${warehouses}=    Get Available Warehouses

    # Setup warehouse
    IF    '${warehouse}' != '${EMPTY}'
        ${wh_status}=    Setup Warehouse    ${warehouse}
        Set To Dictionary    ${context}    warehouse=${warehouse}
    END

    # Setup database
    IF    '${database}' != '${EMPTY}'
        ${db_status}=    Setup Database    ${database}    ${db_names}
        Set To Dictionary    ${context}    database=${database}
    END

    # Setup schema
    IF    '${schema}' != '${EMPTY}'
        ${schema_status}=    Setup Schema    ${schema}
        Set To Dictionary    ${context}    schema=${schema}
    ELSE IF    '${database}' != '${EMPTY}'
        # Default to PUBLIC if database is set but schema is not
        ${schema_status}=    Setup Schema    PUBLIC
        Set To Dictionary    ${context}    schema=PUBLIC
    END

    # Verify final context
    ${current}=    Verify Current Context
    RETURN    ${current}

Process Private Key For Connection
    [Documentation]    Process private key for connection - handles both file paths and inline keys
    ...    Supports two formats for flexibility across different environments:
    ...    1. File Path: /path/to/key.p8 - Reads the key content from file (secure local development)
    ...    2. Inline String: "-----BEGIN PRIVATE KEY-----\\nMIIE..." - Cleans escaped newlines (CI/CD, Docker)
    ...    This makes tests portable across local, CI/CD pipelines, Docker, and Kubernetes environments
    ...    Returns properly formatted key content ready for Snowflake connection
    [Arguments]    ${private_key}

    # Check if it's a file path
    ${is_file}=    Run Keyword And Return Status    File Should Exist    ${private_key}

    IF    ${is_file}
        ${key_content}=    Get File    ${private_key}
        RETURN    ${key_content}
    END

    # Clean up inline key
    ${clean_key}=    Replace String    ${private_key}    \\n    \n
    RETURN    ${clean_key}

Get Available Databases
    [Documentation]    Get list of available databases

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

Get Available Warehouses
    [Documentation]    Get list of available warehouses

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

Setup Warehouse
    [Documentation]    Setup warehouse
    [Arguments]    ${warehouse}

    TRY
        Execute Sql String    USE WAREHOUSE ${warehouse}
        Log    ✅ Warehouse set: ${warehouse}    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    ⚠️ Could not set warehouse ${warehouse}: ${error}    console=yes
        TRY
            Execute Sql String    CREATE WAREHOUSE IF NOT EXISTS ${warehouse} WITH WAREHOUSE_SIZE = 'XSMALL'
            Execute Sql String    USE WAREHOUSE ${warehouse}
            Log    ✅ Created and set warehouse ${warehouse}    console=yes
            RETURN    ${TRUE}
        EXCEPT
            Log    ❌ Could not create warehouse    console=yes
            RETURN    ${FALSE}
        END
    END

Setup Database
    [Documentation]    Setup database
    [Arguments]    ${database}    ${db_names}

    IF    '${database}' in ${db_names}
        TRY
            Execute Sql String    USE DATABASE ${database}
            Log    ✅ Database set: ${database}    console=yes
            RETURN    ${TRUE}
        EXCEPT    AS    ${error}
            Log    ⚠️ Could not use database ${database}: ${error}    console=yes
        END
    END

    TRY
        Execute Sql String    CREATE DATABASE IF NOT EXISTS ${database}
        Execute Sql String    USE DATABASE ${database}
        Log    ✅ Created and set database ${database}    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    ⚠️ Could not create database ${database}: ${error}    console=yes
        IF    ${db_names}
            ${first_db}=    Get From List    ${db_names}    0
            TRY
                Execute Sql String    USE DATABASE ${first_db}
                Log    ✅ Using existing database ${first_db}    console=yes
                RETURN    ${TRUE}
            EXCEPT
                RETURN    ${FALSE}
            END
        END
        RETURN    ${FALSE}
    END

Setup Schema
    [Documentation]    Setup schema
    [Arguments]    ${schema}

    TRY
        Execute Sql String    USE SCHEMA ${schema}
        Log    ✅ Schema set: ${schema}    console=yes
        RETURN    ${TRUE}
    EXCEPT
        TRY
            Execute Sql String    CREATE SCHEMA IF NOT EXISTS ${schema}
            Execute Sql String    USE SCHEMA ${schema}
            Log    ✅ Created and set schema ${schema}    console=yes
            RETURN    ${TRUE}
        EXCEPT
            TRY
                Execute Sql String    USE SCHEMA PUBLIC
                Log    ℹ️ Using PUBLIC schema    console=yes
                RETURN    ${TRUE}
            EXCEPT
                Log    ❌ Could not set any schema    console=yes
                RETURN    ${FALSE}
            END
        END
    END

Verify Current Context
    [Documentation]    Verify and return current database context

    TRY
        ${result}=    Query    SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE()
        ${context}=    Create Dictionary
        ...    database=${result[0][0]}
        ...    schema=${result[0][1]}
        ...    warehouse=${result[0][2]}

        Log    ========================================    console=yes
        Log    ✅ Current Snowflake Context    console=yes
        Log    Database: ${result[0][0]}    console=yes
        Log    Schema: ${result[0][1]}    console=yes
        Log    Warehouse: ${result[0][2]}    console=yes
        Log    ========================================    console=yes

        RETURN    ${context}
    EXCEPT    AS    ${error}
        Log    ❌ Could not verify context: ${error}    console=yes
        ${empty_context}=    Create Dictionary    database=${EMPTY}    schema=${EMPTY}    warehouse=${EMPTY}
        RETURN    ${empty_context}
    END

Get Current Authentication Type
    [Documentation]    Return the current authentication type being used

    RETURN    ${SNOWFLAKE_CONNECTION_METHOD}

Disconnect From Snowflake
    [Documentation]    Disconnect from Snowflake

    Disconnect From Database
    Log    Disconnected from Snowflake (${SNOWFLAKE_CONNECTION_METHOD} authentication)    console=yes
    Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    NONE
