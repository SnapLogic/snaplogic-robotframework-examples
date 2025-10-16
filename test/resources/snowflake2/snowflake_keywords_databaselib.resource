*** Settings ***
Documentation       Snowflake DatabaseLibrary Keywords
...                 This resource file contains keywords for connecting to and working with
...                 Snowflake using DatabaseLibrary instead of the custom SnowflakeLib.
...                 These keywords enable using generic database templates and provide
...                 compatibility with standard DatabaseLibrary operations.

Library             DatabaseLibrary
Library             OperatingSystem
Library             Collections
Library             String
Library             BuiltIn


*** Variables ***
# Snowflake connection parameters
# SNOWFLAKE_HOSTNAME is used to automatically extract the account identifier
${SNOWFLAKE_HOSTNAME}               %{SNOWFLAKE_HOSTNAME}
${SNOWFLAKE_USER}                   %{SNOWFLAKE_USERNAME=Bigdatasnaplogic}
${SNOWFLAKE_PASSWORD}               %{SNOWFLAKE_PASSWORD}
${SNOWFLAKE_DATABASE}               %{SNOWFLAKE_DATABASE=FDLDB}
${SNOWFLAKE_SCHEMA}                 %{SNOWFLAKE_SCHEMA=DEMO}
${SNOWFLAKE_WAREHOUSE}              %{SNOWFLAKE_WAREHOUSE=ELT_XS_WH}
${SNOWFLAKE_ROLE}                   %{SNOWFLAKE_ROLE=SYSADMIN}

# Connection tracking
${SNOWFLAKE_CONNECTION_METHOD}      NONE
${SNOWFLAKE_ACCOUNT}                ${EMPTY}    # Will be extracted from SNOWFLAKE_HOSTNAME


*** Keywords ***
Extract Snowflake Account Identifier From Hostname
    [Documentation]    Extract the account identifier from SNOWFLAKE_HOSTNAME
    ...    Example: snaplogic.snowflakecomputing.com -> snaplogic
    ...    Returns: Account identifier (first part before the first dot)

    # Split hostname by "." and get the first part
    @{parts}=    Split String    ${SNOWFLAKE_HOSTNAME}    .
    ${account_id}=    Get From List    ${parts}    0

    Log    Extracted Account Identifier: ${account_id}    console=yes
    Log    From Hostname: ${SNOWFLAKE_HOSTNAME}    console=yes

    # Set as suite variable so it can be used throughout
    Set Suite Variable    ${SNOWFLAKE_ACCOUNT_IDENTIFIER}    ${account_id}

    RETURN    ${account_id}

Connect To Snowflake Via DatabaseLibrary
    [Documentation]    Connect to Snowflake using DatabaseLibrary for compatibility with standard templates
    ...    This creates a connection that Load JSON Data Template can use
    ...    Uses Method 1: Custom Params which is the recommended approach
    ...    Returns: Connection details dictionary with status and database info
    [Arguments]    ${account}=${EMPTY}
    ...    ${user}=${SNOWFLAKE_USER}
    ...    ${password}=${SNOWFLAKE_PASSWORD}
    ...    ${database}=${SNOWFLAKE_DATABASE}
    ...    ${schema}=${SNOWFLAKE_SCHEMA}
    ...    ${warehouse}=${SNOWFLAKE_WAREHOUSE}
    ...    ${role}=${SNOWFLAKE_ROLE}

    # Extract account from hostname if not provided
    IF    '${account}' == '${EMPTY}'
        ${account}=    Extract Snowflake Account Identifier From Hostname
    END

    # Initialize connection details
    ${connection_details}=    Create Dictionary    method=NONE    status=FAILED    error=${EMPTY}

    Log    ========================================    console=yes
    Log    Connecting to Snowflake via DatabaseLibrary...    console=yes
    Log    Account: ${account}    console=yes
    Log    Hostname: ${SNOWFLAKE_HOSTNAME}    console=yes
    Log    ========================================    console=yes

    TRY
        # Using the recommended Method 1: Custom Params
        # Note: This keyword shows deprecation warning but still works perfectly
        Connect To Database Using Custom Params
        ...    snowflake.connector
        ...    database='${database}', user='${user}', password='${password}', account='${account}', warehouse='${warehouse}', schema='${schema}', role='${role}'

        # Test the connection and get details
        ${result}=    Query    SELECT CURRENT_DATABASE(), CURRENT_SCHEMA(), CURRENT_WAREHOUSE()

        # Connection successful! Store the details
        ${connection_method}=    Set Variable    Method 1: Custom Params
        Set Suite Variable    ${SNOWFLAKE_CONNECTION_METHOD}    ${connection_method}

        Set To Dictionary    ${connection_details}
        ...    method=Method 1
        ...    status=SUCCESS
        ...    database=${result[0][0]}
        ...    schema=${result[0][1]}
        ...    warehouse=${result[0][2]}

        Log    ========================================    console=yes
        Log    ✅ Successfully connected to Snowflake    console=yes
        Log    Database: ${result[0][0]}    console=yes
        Log    Schema: ${result[0][1]}    console=yes
        Log    Warehouse: ${result[0][2]}    console=yes
        Log    ========================================    console=yes

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
        Log    1. Ensure snowflake-connector-python is installed: pip install snowflake-connector-python    console=yes
        Log    2. Verify your credentials and network access    console=yes
        Log    3. Check if account format is correct (e.g., 'account' or 'account.region')    console=yes
        Log    ========================================    console=yes

        Fail    Could not connect to Snowflake via DatabaseLibrary: ${error}
    END

# REMOVED: Select All Records From Table - Use 'Select All From Table' from sql_table_operations.resource
# REMOVED: Select Records With Where Clause - Use 'Select Where' from sql_table_operations.resource

# REMOVED: Get Table Data As Dictionary - Use from sql_table_operations.resource
# REMOVED: Extract Column Values From Dictionary - Use from sql_table_operations.resource
# REMOVED: Extract Multiple Columns From Dictionary - Use from sql_table_operations.resource
# REMOVED: Get Unique Column Values - Use from sql_table_operations.resource
# REMOVED: Filter Dictionary Results By Column Value - Use from sql_table_operations.resource
# REMOVED: Evaluate Column Condition - Use from sql_table_operations.resource

# REMOVED: Test DatabaseLibrary Connection - Use 'Test Database Connection' from sql_table_operations.resource

# DatabaseLibrary Wrapper Keywords for Consistency

# REMOVED: Execute Query Via DatabaseLibrary - Use 'Execute Custom Query' from sql_table_operations.resource
# REMOVED: Execute Command Via DatabaseLibrary - Use 'Execute Custom Command' from sql_table_operations.resource

Get Current Snowflake Context Via DatabaseLibrary
    [Documentation]    Get current database context using DatabaseLibrary

    ${context_query}=    Catenate    SEPARATOR=${SPACE}
    ...    SELECT
    ...    CURRENT_DATABASE() as database,
    ...    CURRENT_SCHEMA() as schema,
    ...    CURRENT_WAREHOUSE() as warehouse,
    ...    CURRENT_USER() as user,
    ...    CURRENT_ROLE() as role,
    ...    CURRENT_VERSION() as version

    ${context}=    Query    ${context_query}

    ${context_dict}=    Create Dictionary
    ...    database=${context[0][0]}
    ...    schema=${context[0][1]}
    ...    warehouse=${context[0][2]}
    ...    user=${context[0][3]}
    ...    role=${context[0][4]}
    ...    version=${context[0][5]}

    Log    Current Snowflake Context:    console=yes
    Log    Database: ${context_dict}[database]    console=yes
    Log    Schema: ${context_dict}[schema]    console=yes
    Log    Warehouse: ${context_dict}[warehouse]    console=yes
    Log    User: ${context_dict}[user]    console=yes
    Log    Role: ${context_dict}[role]    console=yes
    Log    Version: ${context_dict}[version]    console=yes

    RETURN    ${context_dict}

# REMOVED: The following keywords are replaced by generic ones in sql_table_operations.resource:
# - Table Should Exist Via DatabaseLibrary → Use 'Table Should Exist'
# - Table Should Not Exist Via DatabaseLibrary → Use 'Table Should Not Exist'
# - Get Row Count Via DatabaseLibrary → Use 'Get Row Count'
# - Create Table Via DatabaseLibrary → Use 'Create Table'
# - Drop Table Via DatabaseLibrary → Use 'Drop Table'
# - Insert Into Table Via DatabaseLibrary → Use 'Insert Into Table'

Disconnect From Snowflake
    [Documentation]    Disconnect from Snowflake DatabaseLibrary connection

    Disconnect From Database
    Log    Disconnected from Snowflake    console=yes

# Additional Keywords from SnowflakeLib converted to DatabaseLibrary

# REMOVED: Execute Snowflake Query - Use 'Execute Custom Query' from sql_table_operations.resource
# REMOVED: Execute Snowflake Command Wrapper - Use 'Execute Custom Command' from sql_table_operations.resource

Get Snowflake Version Wrapper
    [Documentation]    Get Snowflake version using DatabaseLibrary

    ${result}=    Query    SELECT CURRENT_VERSION()
    ${version}=    Set Variable    ${result[0][0]}
    Log    Snowflake Version: ${version}    console=yes
    RETURN    ${version}

Get Current Snowflake Context
    [Documentation]    Get all current context information using DatabaseLibrary

    ${context_query}=    Catenate    SEPARATOR=${SPACE}
    ...    SELECT
    ...    CURRENT_USER() as user,
    ...    CURRENT_DATABASE() as database,
    ...    CURRENT_SCHEMA() as schema,
    ...    CURRENT_WAREHOUSE() as warehouse,
    ...    CURRENT_ROLE() as role,
    ...    CURRENT_ACCOUNT() as account

    ${result}=    Query    ${context_query}

    ${context}=    Create Dictionary
    ...    user=${result[0][0]}
    ...    database=${result[0][1]}
    ...    schema=${result[0][2]}
    ...    warehouse=${result[0][3]}
    ...    role=${result[0][4]}
    ...    account=${result[0][5]}

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

    ${result}=    Query    SELECT CURRENT_USER()
    RETURN    ${result[0][0]}

Get Current Snowflake Database
    [Documentation]    Get the current database

    ${result}=    Query    SELECT CURRENT_DATABASE()
    RETURN    ${result[0][0]}

Get Current Snowflake Schema
    [Documentation]    Get the current schema

    ${result}=    Query    SELECT CURRENT_SCHEMA()
    RETURN    ${result[0][0]}

Get Current Snowflake Warehouse
    [Documentation]    Get the current warehouse

    ${result}=    Query    SELECT CURRENT_WAREHOUSE()
    RETURN    ${result[0][0]}

Get Current Snowflake Role
    [Documentation]    Get the current role

    ${result}=    Query    SELECT CURRENT_ROLE()
    RETURN    ${result[0][0]}

Get Current Snowflake Account
    [Documentation]    Get the current account identifier

    ${result}=    Query    SELECT CURRENT_ACCOUNT()
    RETURN    ${result[0][0]}

# REMOVED: The following Snowflake-specific keywords are replaced by generic ones:
# - Create Snowflake Table If Not Exists → Use 'Create Table If Not Exists' from sql_table_operations.resource
# - Drop Snowflake Table If Exists → Use 'Drop Table' with if_exists=${TRUE} from sql_table_operations.resource
# - Insert Into Snowflake Table → Use 'Insert Into Table' from sql_table_operations.resource
# - Get Row Count From Snowflake Table → Use 'Get Row Count' from sql_table_operations.resource
# - Table Should Exist In Snowflake → Use 'Table Should Exist' from sql_table_operations.resource
# - Table Should Not Exist In Snowflake → Use 'Table Should Not Exist' from sql_table_operations.resource
# - Get Snowflake Table Columns → Use 'Get Table Columns' from sql_table_operations.resource

# REMOVED: Test Snowflake Connection - Use 'Test Database Connection' from sql_table_operations.resource

# REMOVED: The following keywords have been moved to sql_table_operations.resource:
# - Use Snowflake Database → Use 'Use Database' from sql_table_operations.resource
# - Use Snowflake Schema → Use 'Use Schema' from sql_table_operations.resource

Use Snowflake Warehouse
    [Documentation]    Switch to a different warehouse
    [Arguments]    ${warehouse_name}

    Execute Sql String    USE WAREHOUSE ${warehouse_name}
    Log    Switched to warehouse: ${warehouse_name}
    RETURN    ${TRUE}

Test Time Travel
    [Documentation]    Query data from a past point in time
    [Arguments]    ${table_name}    ${minutes_ago}=5

    ${query}=    Catenate    SEPARATOR=${SPACE}
    ...    SELECT COUNT(*) FROM ${table_name}
    ...    AT(OFFSET => -${minutes_ago}*60)

    ${result}=    Query    ${query}
    ${past_count}=    Set Variable    ${result[0][0]}
    Log    Row count ${minutes_ago} minutes ago: ${past_count}
    RETURN    ${past_count}

Create Stage
    [Documentation]    Create a Snowflake stage for data loading
    [Arguments]    ${stage_name}    ${stage_type}=INTERNAL

    IF    '${stage_type}' == 'INTERNAL'
        ${create_stage}=    Set Variable    CREATE OR REPLACE STAGE ${stage_name}
    ELSE
        ${create_stage}=    Set Variable    CREATE OR REPLACE STAGE ${stage_name} STAGE_TYPE = ${stage_type}
    END

    Execute Sql String    ${create_stage}
    Log    Stage ${stage_name} created successfully
    RETURN    ${TRUE}

Load Data From Stage
    [Documentation]    Load data from a stage into a table
    [Arguments]    ${stage_name}    ${table_name}    ${file_format}=${None}

    IF    '${file_format}' == '${None}'
        ${copy_cmd}=    Set Variable
        ...    COPY INTO ${table_name} FROM @${stage_name}
    ELSE
        ${copy_cmd}=    Set Variable
        ...    COPY INTO ${table_name} FROM @${stage_name} FILE_FORMAT = (${file_format})
    END

    Execute Sql String    ${copy_cmd}
    Log    Data loaded from stage ${stage_name} to table ${table_name}
    RETURN    ${TRUE}

# REMOVED: Execute Snowflake Script - Use 'Execute SQL Script' from sql_table_operations.resource
# REMOVED: Bulk Insert Into Snowflake - Use 'Bulk Insert Into Table' from sql_table_operations.resource

# REMOVED: Create Table - Use 'Create Table' from sql_table_operations.resource
# REMOVED: Drop Table - Use 'Drop Table' from sql_table_operations.resource
