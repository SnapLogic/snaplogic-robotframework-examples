*** Settings ***
Documentation       Snowflake Database Integration Tests
...                 These tests demonstrate connecting to Snowflake cloud service
...                 Note: Snowflake runs in the cloud, not in a local Docker container

Library             DatabaseLibrary
Library             OperatingSystem
Library             Collections


*** Variables ***
# Snowflake connection parameters - update these with your account details
${SNOWFLAKE_ACCOUNT}        YOUR_ACCOUNT.YOUR_REGION.YOUR_CLOUD    # e.g., xy12345.us-east-1.aws
${SNOWFLAKE_USER}           YOUR_USERNAME
${SNOWFLAKE_PASSWORD}       YOUR_PASSWORD
${SNOWFLAKE_DATABASE}       TESTDB
${SNOWFLAKE_SCHEMA}         SNAPTEST
${SNOWFLAKE_WAREHOUSE}      COMPUTE_WH
${SNOWFLAKE_ROLE}           SYSADMIN

# Connection string format for snowflake-connector-python
${SNOWFLAKE_CONN_STRING}    snowflake://${SNOWFLAKE_USER}:${SNOWFLAKE_PASSWORD}@${SNOWFLAKE_ACCOUNT}/${SNOWFLAKE_DATABASE}/${SNOWFLAKE_SCHEMA}?warehouse=${SNOWFLAKE_WAREHOUSE}&role=${SNOWFLAKE_ROLE}


*** Test Cases ***
Connect To Snowflake Cloud
    [Documentation]    Test connection to Snowflake cloud service
    [Tags]    snowflake_wip    connection

    # Method 1: Using DatabaseLibrary with snowflake-connector-python
    Connect To Database    snowflake-connector-python
    ...    account=${SNOWFLAKE_ACCOUNT}
    ...    user=${SNOWFLAKE_USER}
    ...    password=${SNOWFLAKE_PASSWORD}
    ...    database=${SNOWFLAKE_DATABASE}
    ...    schema=${SNOWFLAKE_SCHEMA}
    ...    warehouse=${SNOWFLAKE_WAREHOUSE}
    ...    role=${SNOWFLAKE_ROLE}

    # Verify connection
    ${result}=    Query    SELECT CURRENT_VERSION() as version, CURRENT_USER() as user
    Log    Connected to Snowflake: ${result}

    Disconnect From Database

Test Snowflake With Environment Variables
    [Documentation]    Connect using environment variables (more secure)
    [Tags]    snowflake_wip    env

    # Set environment variables (in real tests, these would be set externally)
    Set Environment Variable    SNOWFLAKE_ACCOUNT    ${SNOWFLAKE_ACCOUNT}
    Set Environment Variable    SNOWFLAKE_USER    ${SNOWFLAKE_USER}
    Set Environment Variable    SNOWFLAKE_PASSWORD    ${SNOWFLAKE_PASSWORD}

    # Connect using env vars
    ${account}=    Get Environment Variable    SNOWFLAKE_ACCOUNT
    ${user}=    Get Environment Variable    SNOWFLAKE_USER
    ${password}=    Get Environment Variable    SNOWFLAKE_PASSWORD

    Connect To Database    snowflake-connector-python
    ...    account=${account}
    ...    user=${user}
    ...    password=${password}
    ...    database=${SNOWFLAKE_DATABASE}
    ...    schema=${SNOWFLAKE_SCHEMA}
    ...    warehouse=${SNOWFLAKE_WAREHOUSE}

    Disconnect From Database

Create And Query Test Data
    [Documentation]    Create tables and query data in Snowflake
    [Tags]    snowflake_wip    crud
    [Setup]    Connect To Snowflake

    # Create a test table
    Execute Sql String
    ...    CREATE OR REPLACE TABLE RF_TEST_TABLE (
    ...    id NUMBER,
    ...    name VARCHAR(100),
    ...    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    ...    )

    # Insert test data
    Execute Sql String    INSERT INTO RF_TEST_TABLE (id, name) VALUES (1, 'Robot Test 1')
    Execute Sql String    INSERT INTO RF_TEST_TABLE (id, name) VALUES (2, 'Robot Test 2')

    # Query and verify
    ${result}=    Query    SELECT COUNT(*) as count FROM RF_TEST_TABLE
    Should Be Equal As Integers    ${result[0][0]}    2

    # Clean up
    Execute Sql String    DROP TABLE IF EXISTS RF_TEST_TABLE
    [Teardown]    Disconnect From Database

Test Snowflake Specific Features
    [Documentation]    Test Snowflake-specific SQL features
    [Tags]    snowflake_wip    features
    [Setup]    Connect To Snowflake

    # Test VARIANT data type
    Execute Sql String
    ...    CREATE OR REPLACE TABLE RF_VARIANT_TEST (
    ...    id NUMBER,
    ...    data VARIANT
    ...    )

    # Insert JSON data
    Execute Sql String
    ...    INSERT INTO RF_VARIANT_TEST
    ...    SELECT 1, PARSE_JSON('{"name": "Robot", "type": "Test", "active": true}')

    # Query JSON data
    ${result}=    Query
    ...    SELECT data:name::STRING as name, data:active::BOOLEAN as active
    ...    FROM RF_VARIANT_TEST WHERE id = 1

    Should Be Equal    ${result[0][0]}    Robot
    Should Be True    ${result[0][1]}

    # Test time travel (query data from 1 minute ago)
    ${result}=    Query
    ...    SELECT COUNT(*) FROM RF_VARIANT_TEST AT(OFFSET => -60)

    # Clean up
    Execute Sql String    DROP TABLE IF EXISTS RF_VARIANT_TEST
    [Teardown]    Disconnect From Database

Query Existing Test Data
    [Documentation]    Query pre-existing test data (assumes setup script was run)
    [Tags]    snowflake_wip    query
    [Setup]    Connect To Snowflake

    # Check if test tables exist
    ${tables}=    Query
    ...    SELECT TABLE_NAME
    ...    FROM INFORMATION_SCHEMA.TABLES
    ...    WHERE TABLE_SCHEMA = '${SNOWFLAKE_SCHEMA}'
    ...    AND TABLE_NAME IN ('CUSTOMERS', 'PRODUCTS', 'ORDERS')

    ${table_count}=    Get Length    ${tables}

    IF    ${table_count} > 0
        Query Customer Data
        Query Product Data
        Query Order Data
    ELSE
        Log    Test tables not found. Run setup script first.    WARN
    END
    [Teardown]    Disconnect From Database


*** Keywords ***
Connect To Snowflake
    [Documentation]    Reusable keyword to connect to Snowflake
    Connect To Database    snowflake-connector-python
    ...    account=${SNOWFLAKE_ACCOUNT}
    ...    user=${SNOWFLAKE_USER}
    ...    password=${SNOWFLAKE_PASSWORD}
    ...    database=${SNOWFLAKE_DATABASE}
    ...    schema=${SNOWFLAKE_SCHEMA}
    ...    warehouse=${SNOWFLAKE_WAREHOUSE}
    ...    role=${SNOWFLAKE_ROLE}

Query Customer Data
    [Documentation]    Query customer test data
    ${customers}=    Query    SELECT COUNT(*) FROM CUSTOMERS
    Log    Found ${customers[0][0]} customers

    ${sample}=    Query    SELECT FIRST_NAME, LAST_NAME, EMAIL FROM CUSTOMERS LIMIT 3
    FOR    ${row}    IN    @{sample}
        Log    Customer: ${row[0]} ${row[1]} - ${row[2]}
    END

Query Product Data
    [Documentation]    Query product test data
    ${products}=    Query
    ...    SELECT PRODUCT_NAME, CATEGORY, PRICE
    ...    FROM PRODUCTS
    ...    WHERE CATEGORY = 'Electronics'
    ...    ORDER BY PRICE DESC

    FOR    ${row}    IN    @{products}
        Log    Product: ${row[0]} (${row[1]}) - $${row[2]}
    END

Query Order Data
    [Documentation]    Query order test data with joins
    ${orders}=    Query
    ...    SELECT c.FIRST_NAME || ' ' || c.LAST_NAME as customer,
    ...    o.ORDER_ID, o.TOTAL_AMOUNT, o.STATUS
    ...    FROM ORDERS o
    ...    JOIN CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID
    ...    ORDER BY o.ORDER_DATE DESC
    ...    LIMIT 5

    FOR    ${row}    IN    @{orders}
        Log    Order ${row[1]}: ${row[0]} - $${row[2]} (${row[3]})
    END
