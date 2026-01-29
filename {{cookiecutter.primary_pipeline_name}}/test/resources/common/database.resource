*** Settings ***
Documentation       Database Connection Management Resource File
...                 Contains all keywords related to:
...                 - Database connection management (PostgreSQL, Oracle, SQL Server, Redshift)
...                 - Connection testing and validation
...                 - Connection retry and wait utilities
...
...                 Prerequisites:
...                 - DatabaseLibrary must be installed
...                 - Database drivers must be installed (psycopg2, pymssql, oracledb)
...
...                 Usage Example:
...                 | *** Settings ***
...                 | Resource    database_connections.resource
...                 |
...                 | *** Test Cases ***
...                 | Test Database Connection
...                 |    Connect to Postgres Database    mydb    user    pass    localhost    5432
...                 |    ${connected}=    Test Database Connection
...                 |    Should Be True    ${connected}
...                 |    Disconnect from Database

Library             DatabaseLibrary
Library             OperatingSystem
Library             psycopg2
Library             pymssql
Library             DateTime


*** Keywords ***
################## DATABASE CONNECTION MANAGEMENT ##################

Connect to Postgres Database
    [Documentation]    Establishes connection to PostgreSQL database using psycopg2 driver
    ...    Arguments:
    ...    - POSTGRES_DATABASE: Database name
    ...    - POSTGRES_USER: Username for authentication
    ...    - POSTGRES_PASSWORD: Password for authentication
    ...    - POSTGRES_HOST: Database server hostname
    ...    - POSTGRES_PORT: Database server port (default: 5432)
    [Arguments]
    ...    ${POSTGRES_DATABASE}
    ...    ${POSTGRES_USER}
    ...    ${POSTGRES_PASSWORD}
    ...    ${POSTGRES_HOST}
    ...    ${POSTGRES_PORT}=5432

    Log    Connecting to PostgreSQL database...    console=yes
    Log    Host: ${POSTGRES_HOST}:${POSTGRES_PORT}    console=yes
    Log    Database: ${POSTGRES_DATABASE}    console=yes
    Log    User: ${POSTGRES_USER}    console=yes

    Connect To Database
    ...    psycopg2
    ...    ${POSTGRES_DATABASE}
    ...    ${POSTGRES_USER}
    ...    ${POSTGRES_PASSWORD}
    ...    ${POSTGRES_HOST}
    ...    ${POSTGRES_PORT}

    Log    Successfully connected to PostgreSQL database    console=yes

Connect to Oracle Database
    [Documentation]    Sets up Oracle database connection using oracledb driver
    ...    Arguments:
    ...    - ORACLE_DATABASE: Database/Service name
    ...    - ORACLE_USER: Username for authentication
    ...    - ORACLE_PASSWORD: Password for authentication
    ...    - ORACLE_HOST: Database server hostname
    ...    - ORACLE_PORT: Database server port (default: 1521)
    [Arguments]    ${ORACLE_DATABASE}    ${ORACLE_USER}    ${ORACLE_PASSWORD}    ${ORACLE_HOST}    ${ORACLE_PORT}=1521

    Log    Connecting to Oracle database...    console=yes
    Log    Host: ${ORACLE_HOST}:${ORACLE_PORT}    console=yes
    Log    Database: ${ORACLE_DATABASE}    console=yes

    Connect To Database
    ...    oracledb
    ...    ${ORACLE_DATABASE}
    ...    ${ORACLE_USER}
    ...    ${ORACLE_PASSWORD}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_PORT}

    Log    Successfully connected to Oracle database    console=yes

Connect to SQL Server Database
    [Documentation]    Sets up SQL Server database connection using pymssql driver
    ...    Arguments:
    ...    - SQLSERVER_DATABASE: Database name
    ...    - SQLSERVER_USER: Username for authentication
    ...    - SQLSERVER_PASSWORD: Password for authentication
    ...    - SQLSERVER_HOST: Database server hostname
    ...    - SQLSERVER_PORT: Database server port (default: 1433)
    [Arguments]
    ...    ${SQLSERVER_DATABASE}
    ...    ${SQLSERVER_USER}
    ...    ${SQLSERVER_PASSWORD}
    ...    ${SQLSERVER_HOST}
    ...    ${SQLSERVER_PORT}=1433

    Log    Connecting to SQL Server database...    console=yes
    Log    Host: ${SQLSERVER_HOST}:${SQLSERVER_PORT}    console=yes
    Log    Database: ${SQLSERVER_DATABASE}    console=yes

    Connect To Database
    ...    pymssql
    ...    ${SQLSERVER_DATABASE}
    ...    ${SQLSERVER_USER}
    ...    ${SQLSERVER_PASSWORD}
    ...    ${SQLSERVER_HOST}
    ...    ${SQLSERVER_PORT}

    Log    Successfully connected to SQL Server database    console=yes

Connect to Redshift Database
    [Documentation]    Sets up Amazon Redshift database connection using psycopg2 driver
    ...    Redshift is PostgreSQL-compatible, so we use psycopg2 driver
    ...    Arguments:
    ...    - REDSHIFT_DATABASE: Database name
    ...    - REDSHIFT_USER: Username for authentication
    ...    - REDSHIFT_PASSWORD: Password for authentication
    ...    - REDSHIFT_HOST: Database server hostname (cluster endpoint)
    ...    - REDSHIFT_PORT: Database server port (default: 5439)
    [Arguments]
    ...    ${REDSHIFT_DATABASE}
    ...    ${REDSHIFT_USER}
    ...    ${REDSHIFT_PASSWORD}
    ...    ${REDSHIFT_HOST}
    ...    ${REDSHIFT_PORT}=5439

    Log    Connecting to Redshift database...    console=yes
    Log    Host: ${REDSHIFT_HOST}:${REDSHIFT_PORT}    console=yes
    Log    Database: ${REDSHIFT_DATABASE}    console=yes
    Log    User: ${REDSHIFT_USER}    console=yes

    Connect To Database
    ...    psycopg2
    ...    ${REDSHIFT_DATABASE}
    ...    ${REDSHIFT_USER}
    ...    ${REDSHIFT_PASSWORD}
    ...    ${REDSHIFT_HOST}
    ...    ${REDSHIFT_PORT}

    Log    Successfully connected to Redshift database    console=yes

Connect to Database Generic
    [Documentation]    Generic database connection supporting multiple database types
    ...    Arguments:
    ...    - db_module: Database driver module (e.g., psycopg2, pymssql, oracledb)
    ...    - db_name: Database name
    ...    - db_user: Username for authentication
    ...    - db_pass: Password for authentication
    ...    - db_host: Database server hostname
    ...    - db_port: Database server port
    [Arguments]    ${db_module}    ${db_name}    ${db_user}    ${db_pass}    ${db_host}    ${db_port}

    Log    Connecting to ${db_module} database...    console=yes
    Log    Host: ${db_host}:${db_port}    console=yes
    Log    Database: ${db_name}    console=yes
    Log    User: ${db_user}    console=yes

    Connect To Database
    ...    ${db_module}
    ...    ${db_name}
    ...    ${db_user}
    ...    ${db_pass}
    ...    ${db_host}
    ...    ${db_port}

    Log    Successfully connected to ${db_module} database    console=yes

# NOTE: For Snowflake connections, use 'Disconnect From Snowflake' keyword from
# snowflake_keywords_databaselib.resource instead. That keyword handles both:
#   1. SnowflakeConnection.py direct connection (Close Connection)
#   2. DatabaseLibrary connection (Disconnect From Database)
#   3. Resets SNOWFLAKE_CONNECTION_METHOD variable
# This keyword only closes DatabaseLibrary connections (Postgres, Oracle, SQL Server, etc.)

Disconnect from Database
    [Documentation]    Safely disconnects from current database
    ...    Generic keyword for Postgres, Oracle, SQL Server, etc.
    ...    For Snowflake, use 'Disconnect From Snowflake' from snowflake_keywords_databaselib.resource

    # Close DatabaseLibrary connection
    TRY
        DatabaseLibrary.Disconnect From Database
    EXCEPT
        Log    No active database connection to close    console=yes
    END

################## CONNECTION TESTING AND VALIDATION ##################

Test Database Connection
    [Documentation]    Tests database connection with a simple query
    ...    Returns TRUE if connection is active and responsive
    ...    Returns FALSE if connection test fails
    ...    Arguments:
    ...    - test_query: Optional test query (default: SELECT 1)
    [Arguments]    ${test_query}=SELECT 1

    Log    Testing database connection...    console=yes

    TRY
        ${result}=    Query    ${test_query}
        Log    Database connection test passed    console=yes
        Log    Test query result: ${result}    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    Database connection test failed: ${error}    console=yes
        RETURN    ${FALSE}
    END

Wait For Database Connection
    [Documentation]    Waits for database to become available with retry logic
    ...    Useful for scenarios where database may be starting up
    ...    Arguments:
    ...    - timeout: Maximum time to wait (default: 30s)
    ...    - retry_interval: Time between retry attempts (default: 2s)
    [Arguments]    ${timeout}=30s    ${retry_interval}=2s

    Log    Waiting for database connection (timeout: ${timeout})...    console=yes

    ${end_time}=    Add Time To Date    ${NOW}    ${timeout}

    WHILE    True
        ${current_time}=    Get Current Date
        ${time_exceeded}=    Evaluate    '${current_time}' > '${end_time}'

        IF    ${time_exceeded}
            Fail    Database connection timeout after ${timeout}
        END

        ${connected}=    Test Database Connection
        IF    ${connected}
            Log    Database connection established    console=yes
            BREAK
        END

        Log    Database not ready, retrying in ${retry_interval}...    console=yes
        Sleep    ${retry_interval}
    END

################## DATABASE-SPECIFIC EXECUTION ##################

Execute SQL On Database
    [Documentation]    Execute SQL on a specific database connection
    ...    Automatically connects, executes, and remains connected
    ...    Arguments:
    ...    - sql: SQL statement to execute
    ...    - database_type: Type of database ('postgres', 'oracle', 'sqlserver', or 'redshift')
    ...    Note: Uses global variables for connection parameters (POSTGRES_*, ORACLE_*, SQLSERVER_*, REDSHIFT_*)
    [Arguments]    ${sql}    ${database_type}

    # Close any existing connection to avoid warnings
    Run Keyword And Ignore Error    Disconnect From Database

    # Execute based on database type
    IF    '${database_type}' == 'postgres'
        Connect to Postgres Database
        ...    ${POSTGRES_DATABASE}
        ...    ${POSTGRES_USER}
        ...    ${POSTGRES_PASSWORD}
        ...    ${POSTGRES_HOST}
        ...    ${POSTGRES_PORT}
        Execute SQL String    ${sql}
    ELSE IF    '${database_type}' == 'oracle'
        Connect to Oracle Database
        ...    ${ORACLE_DATABASE}
        ...    ${ORACLE_USER}
        ...    ${ORACLE_PASSWORD}
        ...    ${ORACLE_HOST}
        ...    ${ORACLE_PORT}
        Execute SQL String    ${sql}
    ELSE IF    '${database_type}' == 'sqlserver'
        Connect to SQL Server Database
        ...    ${SQLSERVER_DATABASE}
        ...    ${SQLSERVER_USER}
        ...    ${SQLSERVER_PASSWORD}
        ...    ${SQLSERVER_HOST}
        ...    ${SQLSERVER_PORT}
        Execute SQL String    ${sql}
    ELSE IF    '${database_type}' == 'redshift'
        Connect to Redshift Database
        ...    ${REDSHIFT_DATABASE}
        ...    ${REDSHIFT_USER}
        ...    ${REDSHIFT_PASSWORD}
        ...    ${REDSHIFT_HOST}
        ...    ${REDSHIFT_PORT}
        Execute SQL String    ${sql}
    ELSE
        Fail    Unknown database type: ${database_type}. Use 'postgres', 'oracle', 'sqlserver', or 'redshift'
    END
