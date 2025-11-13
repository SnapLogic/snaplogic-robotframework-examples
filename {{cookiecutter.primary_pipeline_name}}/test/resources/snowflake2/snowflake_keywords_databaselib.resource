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
Library             ./SnowflakeConnection.py    #    Helper for private key processing


*** Variables ***
# These variables will be populated from environment files loaded via Docker compose
# Password Authentication Variables
${SNOWFLAKE_HOSTNAME}                                       %{SNOWFLAKE_HOSTNAME=${EMPTY}}
${SNOWFLAKE_USERNAME}                                       %{SNOWFLAKE_USERNAME=${EMPTY}}
${SNOWFLAKE_PASSWORD}                                       %{SNOWFLAKE_PASSWORD=${EMPTY}}
${SNOWFLAKE_DATABASE}                                       %{SNOWFLAKE_DATABASE=${EMPTY}}
${SNOWFLAKE_SCHEMA}                                         %{SNOWFLAKE_SCHEMA=${EMPTY}}
${SNOWFLAKE_WAREHOUSE}                                      %{SNOWFLAKE_WAREHOUSE=${EMPTY}}
${SNOWFLAKE_ROLE}                                           %{SNOWFLAKE_ROLE=${EMPTY}}
${SNOWFLAKE_ACCOUNT}                                        %{SNOWFLAKE_ACCOUNT=${EMPTY}}

# # Key Pair Authentication Variables
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_HOSTNAME}                    %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_HOSTNAME=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_USERNAME}                    %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_USERNAME=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY}                 %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY_PASSPHRASE}      %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY_PASSPHRASE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_DATABASE}                    %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_DATABASE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_WAREHOUSE}                   %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_WAREHOUSE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_SCHEMA}                      %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_SCHEMA=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_ROLE}                        %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_ROLE=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PORT}                        %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PORT=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_ACCOUNT_NAME}                %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_ACCOUNT_NAME=${EMPTY}}
${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_AUTHENTICATION_TYPE}         %{SNOWFLAKE_KEYPAIR_S3_DYNAMIC_AUTHENTICATION_TYPE=${EMPTY}}
${SNOWFLAKE_ACCOUNT_IDENTIFIER}                             %{SNOWFLAKE_ACCOUNT_IDENTIFIER=${EMPTY}}

# Connection tracking
${SNOWFLAKE_CONNECTION_METHOD}                              NONE


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
    ...    Uses SNOWFLAKE_KEYPAIR_S3_DYNAMIC_* environment variables

    # Initialize connection details
    ${connection_details}=    Create Dictionary    method=NONE    status=FAILED    error=${EMPTY}

    Log    ========================================    console=yes
    Log    Connecting with Key Pair Authentication    console=yes
    Log    Account: ${SNOWFLAKE_ACCOUNT_IDENTIFIER}    console=yes
    Log    Hostname: ${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_HOSTNAME}    console=yes
    Log    User: ${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_USERNAME}    console=yes
    Log    Role: ${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_ROLE}    console=yes
    Log    Database: ${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_DATABASE}    console=yes
    Log    Warehouse: ${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_WAREHOUSE}    console=yes
    Log    Schema: ${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_SCHEMA}    console=yes
    Log    ========================================    console=yes

    TRY
        # Establish connection
        ${connected}=    Establish Snowflake KeyPair Connection
        ...    user=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_USERNAME}
        ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
        ...    private_key=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY}
        ...    private_key_passphrase=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY_PASSPHRASE}
        ...    role=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_ROLE}

        # Setup database context
        ${context}=    Setup Snowflake Context
        ...    database=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_DATABASE}
        ...    schema=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_SCHEMA}
        ...    warehouse=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_WAREHOUSE}

        # Update connection details
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    KeyPair
        Set To Dictionary    ${connection_details}
        ...    method=KeyPair
        ...    status=SUCCESS
        ...    database=${context}[database]
        ...    schema=${context}[schema]
        ...    warehouse=${context}[warehouse]
        ...    account=${SNOWFLAKE_ACCOUNT_IDENTIFIER}
        ...    user=${SNOWFLAKE_KEYPAIR_S3_DYNAMIC_USERNAME}

        RETURN    ${connection_details}
    EXCEPT    AS    ${error}
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    FAILED
        Set To Dictionary    ${connection_details}    error=${error}
        Log    ❌ Failed to connect with key pair: ${error}    console=yes

        # Provide detailed troubleshooting guidance
        ${error_msg}=    Set Variable
        ...    Could not connect to Snowflake with key pair: ${error}\n\n🔍 Troubleshooting Checklist:\n✓ Verify SNOWFLAKE_KEYPAIR_S3_DYNAMIC_USERNAME is set correctly\n✓ Verify SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY path exists or key content is valid\n✓ Verify SNOWFLAKE_ACCOUNT_IDENTIFIER matches your Snowflake account\n✓ Check if private key is encrypted and passphrase is provided (SNOWFLAKE_KEYPAIR_S3_DYNAMIC_PRIVATE_KEY_PASSPHRASE)\n✓ Ensure key format is PEM (should start with -----BEGIN PRIVATE KEY-----)\n✓ Verify the user has key pair authentication enabled in Snowflake (DESC USER username;)\n✓ Confirm the public key is uploaded to Snowflake and matches your private key\n\n💡 Common Issue: "Password is empty" error usually means:\n
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
    ...    Uses SnowflakeConnection library to properly handle binary key data
    [Arguments]    ${user}    ${account}    ${private_key}    ${private_key_passphrase}    ${role}

    Log    ========================================    console=yes
    Log    Establishing Key Pair Connection    console=yes
    Log    User: ${user}    console=yes
    Log    Account: ${account}    console=yes
    Log    Role: ${role}    console=yes
    Log    ========================================    console=yes

    TRY
        # Use SnowflakeConnection library to connect (it handles binary key data properly)
        ${result}=    Connect With Keypair
        ...    user=${user}
        ...    account=${account}
        ...    private_key_data=${private_key}
        ...    role=${role}
        ...    private_key_passphrase=${private_key_passphrase}

        # Register this connection with DatabaseLibrary so SQL keywords work
        Register With Database Library

        # Set library search order to prefer SnowflakeConnection over DatabaseLibrary
        BuiltIn.Set Library Search Order    SnowflakeConnection    DatabaseLibrary

        Log    ✅ Connected to Snowflake using key pair authentication    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        ${error_msg}=    Set Variable
        ...    Key pair authentication failed: ${error}\n\n🔍 Troubleshooting Checklist:\n✓ Verify SNOWFLAKE_KEYPAIR_S3_DYNAMIC_USERNAME is set correctly\n✓ Verify SNOWFLAKE_ACCOUNT_IDENTIFIER matches your Snowflake account\n✓ Verify the user has key pair authentication enabled in Snowflake (DESC USER username;)\n✓ Confirm the public key is uploaded to Snowflake and matches your private key\n✓ Check Snowflake user roles and permissions\n✓ Verify network connectivity to Snowflake\n\n💡 To verify key pair in Snowflake, run:\n
        ...    DESC USER <username>;\n
        ...    -- Check RSA_PUBLIC_KEY_FP and RSA_PUBLIC_KEY_2_FP fields
        Fail    ${error_msg}
    END

Establish Snowflake Password Connection
    [Documentation]    Internal keyword to establish password connection
    ...    Uses SnowflakeConnection library to properly handle the connection
    [Arguments]    ${user}    ${password}    ${account}    ${role}

    Log    ========================================    console=yes
    Log    🔐 ESTABLISHING PASSWORD CONNECTION    console=yes
    Log    User: ${user}    console=yes
    Log    Account: ${account}    console=yes
    Log    Role: ${role}    console=yes
    Log    ========================================    console=yes

    TRY
        # Use SnowflakeConnection library to connect (consistent with key pair authentication)
        ${result}=    Connect With Password
        ...    user=${user}
        ...    password=${password}
        ...    account=${account}
        ...    role=${role}

        # Register this connection with DatabaseLibrary so SQL keywords work
        Register With Database Library

        # Set library search order to prefer SnowflakeConnection over DatabaseLibrary
        BuiltIn.Set Library Search Order    SnowflakeConnection    DatabaseLibrary

        Log    ✅ Connected to Snowflake using password authentication    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        ${error_msg}=    Set Variable
        ...    Password authentication failed: ${error}\n\n🔍 Troubleshooting Checklist:\n✓ Verify SNOWFLAKE_USERNAME is set correctly\n✓ Verify SNOWFLAKE_PASSWORD is correct\n✓ Verify SNOWFLAKE_ACCOUNT_IDENTIFIER matches your Snowflake account\n✓ Check user roles and permissions\n✓ Verify network connectivity to Snowflake
        Fail    ${error_msg}
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

Get Available Databases
    [Documentation]    Get list of available databases

    TRY
        ${databases}=    SnowflakeConnection.Query    SHOW DATABASES
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
        ${warehouses}=    SnowflakeConnection.Query    SHOW WAREHOUSES
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
        SnowflakeConnection.Execute SQL String    USE WAREHOUSE ${warehouse}
        Log    ✅ Warehouse set: ${warehouse}    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    ⚠️ Could not set warehouse ${warehouse}: ${error}    console=yes
        TRY
            SnowflakeConnection.Execute SQL String
            ...    CREATE WAREHOUSE IF NOT EXISTS ${warehouse} WITH WAREHOUSE_SIZE = 'XSMALL'
            SnowflakeConnection.Execute SQL String    USE WAREHOUSE ${warehouse}
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
            SnowflakeConnection.Execute SQL String    USE DATABASE ${database}
            Log    ✅ Database set: ${database}    console=yes
            RETURN    ${TRUE}
        EXCEPT    AS    ${error}
            Log    ⚠️ Could not use database ${database}: ${error}    console=yes
        END
    END

    TRY
        SnowflakeConnection.Execute SQL String    CREATE DATABASE IF NOT EXISTS ${database}
        SnowflakeConnection.Execute SQL String    USE DATABASE ${database}
        Log    ✅ Created and set database ${database}    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    ⚠️ Could not create database ${database}: ${error}    console=yes
        IF    ${db_names}
            ${first_db}=    Get From List    ${db_names}    0
            TRY
                SnowflakeConnection.Execute SQL String    USE DATABASE ${first_db}
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
        SnowflakeConnection.Execute SQL String    USE SCHEMA ${schema}
        Log    ✅ Schema set: ${schema}    console=yes
        RETURN    ${TRUE}
    EXCEPT
        TRY
            SnowflakeConnection.Execute SQL String    CREATE SCHEMA IF NOT EXISTS ${schema}
            SnowflakeConnection.Execute SQL String    USE SCHEMA ${schema}
            Log    ✅ Created and set schema ${schema}    console=yes
            RETURN    ${TRUE}
        EXCEPT
            TRY
                SnowflakeConnection.Execute SQL String    USE SCHEMA PUBLIC
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
        ${result}=    SnowflakeConnection.Query    SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE()
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

    # Close SnowflakeConnection
    TRY
        Close Connection
        Log    Disconnected from Snowflake (${SNOWFLAKE_CONNECTION_METHOD} authentication)    console=yes
    EXCEPT
        Log    No active SnowflakeConnection to close    console=yes
    END

    # Also disconnect DatabaseLibrary if it has connections
    TRY
        Disconnect From Database
    EXCEPT
        Log    No DatabaseLibrary connections to close    console=yes
    END

    Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    NONE
