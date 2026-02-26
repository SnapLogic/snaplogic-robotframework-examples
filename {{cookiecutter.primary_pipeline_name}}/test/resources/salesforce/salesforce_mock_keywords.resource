*** Settings ***
Documentation       Keywords for verifying Salesforce pipeline operations via the Django mock server.
...                 Uses the Django mock's in-memory database and SOQL query engine to verify
...                 that the pipeline created, updated, and read records correctly.
...
...                 The Django mock stores all records in memory. After pipeline execution,
...                 we query the mock to verify the final state of the data.
...
...                 Key Django Mock Endpoints:
...                 • GET    /health    → Health check
...                 • GET    /__admin/db    → View all data in memory
...                 • POST /__admin/reset    → Clear all data (fresh start)
...                 • GET    /services/data/{V}/query?q=...    → SOQL query

Library             RequestsLibrary
Library             Collections
Library             String
Library             JSONLibrary


*** Variables ***
# Django mock server URL (HTTP inside Docker network)
# Container name: salesforce-api-mock, internal HTTP port: 8080
${SALESFORCE_MOCK_URL}              http://salesforce-api-mock:8080
# SALESFORCE_API_VERSION is loaded from env_files/mock_service_accounts/.env.salesforce
# by __init__.robot's Load Environment Variables keyword during Suite Setup.
# Value: "59.0" — we prepend "v" to match real Salesforce API URL format (e.g., v59.0).
${SALESFORCE_MOCK_API_VERSION}      v${SALESFORCE_API_VERSION}


*** Keywords ***
# ============================================================================
#    CONNECTION & HEALTH
# ============================================================================

Verify Salesforce Mock Is Healthy
    [Documentation]    Checks that the Django Salesforce mock server is running and accessible.
    ...    Calls: GET /health
    ...
    ...    *Returns:*
    ...    - The health check response JSON (status, timestamp, objects, totalRecords)
    ...
    ...    *Example:*
    ...    | ${health}= | Verify Salesforce Mock Is Healthy |
    [Arguments]    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${response}=    GET    ${mock_url}/health    expected_status=200
    ${health}=    Set Variable    ${response.json()}
    Log
    ...    Salesforce Django mock is healthy at ${mock_url} - Objects: ${health}[objects], Records: ${health}[totalRecords]
    ...    console=yes
    RETURN    ${health}

Reset Salesforce Mock Data
    [Documentation]    Clears all records from the Django mock server's in-memory database.
    ...    Call this in suite setup to ensure a clean slate before pipeline execution.
    ...
    ...    Calls: POST /__admin/reset
    ...
    ...    *Example:*
    ...    | Reset Salesforce Mock Data |
    [Arguments]    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${response}=    POST    ${mock_url}/__admin/reset    expected_status=200
    Log    Salesforce mock data cleared    console=yes

# ============================================================================
#    DATA INSPECTION (Admin)
# ============================================================================

Get All Salesforce Mock Data
    [Documentation]    Retrieves the entire in-memory database from the Django mock server.
    ...    Returns all objects and their records. Useful for debugging test failures.
    ...
    ...    Calls: GET /__admin/db
    ...
    ...    *Returns:*
    ...    - Dictionary of all objects and their records
    ...
    ...    *Example:*
    ...    | ${db}= | Get All Salesforce Mock Data |
    ...    | Log | ${db} |
    [Arguments]    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${response}=    GET    ${mock_url}/__admin/db    expected_status=200
    ${data}=    Set Variable    ${response.json()}
    Log    Mock DB snapshot retrieved    console=yes
    RETURN    ${data}

# ============================================================================
#    SOQL QUERY KEYWORDS (Core)
# ============================================================================

Query Salesforce Mock Records
    [Documentation]    Executes a SOQL query against the Django mock server.
    ...    Uses the standard Salesforce SOQL query endpoint supported by the mock.
    ...
    ...    Calls: GET /services/data/{V}/query?q={soql}
    ...
    ...    *Arguments:*
    ...    - ``soql_query``: SOQL query string (e.g., SELECT Id, Name FROM Account)
    ...
    ...    *Returns:*
    ...    - Query response dictionary with: totalSize, done, records[]
    ...
    ...    *Example:*
    ...    | ${result}= | Query Salesforce Mock Records | SELECT Id, Name FROM Account |
    ...    | Log | Total records: ${result}[totalSize] |
    [Arguments]    ${soql_query}    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${params}=    Create Dictionary    q=${soql_query}
    ${response}=    GET    ${mock_url}/services/data/${SALESFORCE_MOCK_API_VERSION}/query
    ...    params=${params}    expected_status=200
    ${result}=    Set Variable    ${response.json()}
    Log    SOQL query returned ${result}[totalSize] record(s): ${soql_query}    console=yes
    RETURN    ${result}

# ============================================================================
#    SALESFORCE ACCOUNT VERIFICATION KEYWORDS
# ============================================================================

Get Salesforce Account Records From Mock
    [Documentation]    Queries all Account records from the Django mock server using SOQL.
    ...    Returns the list of Account records from the query response.
    ...
    ...    *Arguments:*
    ...    - ``fields``: Comma-separated field names to select (default: Id,Name,Industry)
    ...
    ...    *Returns:*
    ...    - List of Account record dictionaries
    ...
    ...    *Example:*
    ...    | ${accounts}= | Get Salesforce Account Records From Mock |
    ...    | ${count}= | Get Length | ${accounts} |
    [Arguments]    ${fields}=Id,Name,Industry    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${soql}=    Set Variable    SELECT ${fields} FROM Account
    ${result}=    Query Salesforce Mock Records    ${soql}    ${mock_url}
    RETURN    ${result}[records]

Verify Salesforce Account Record Count
    [Documentation]    Verifies that the expected number of Account records exist in the mock.
    ...
    ...    *Arguments:*
    ...    - ``expected_count``: Expected number of Account records
    ...    - ``fields``: Comma-separated field names to select
    ...
    ...    *Returns:*
    ...    - List of Account records
    ...
    ...    *Example:*
    ...    | ${accounts}= | Verify Salesforce Account Record Count | 1 |
    [Arguments]    ${expected_count}    ${fields}=Id,Name,Industry    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${accounts}=    Get Salesforce Account Records From Mock    ${fields}    ${mock_url}
    ${actual_count}=    Get Length    ${accounts}
    Should Be Equal As Integers    ${actual_count}    ${expected_count}
    ...    msg=Expected ${expected_count} Account record(s) but found ${actual_count} in mock DB
    Log    Verified ${expected_count} Account record(s) exist in mock    console=yes
    RETURN    ${accounts}

Verify Salesforce Record Field Value
    [Documentation]    Verifies that a specific field in a record has the expected value.
    ...
    ...    *Arguments:*
    ...    - ``records``: List of record dictionaries (from a SOQL query)
    ...    - ``record_index``: Index of the record to check (0-based)
    ...    - ``field_name``: Name of the field to verify
    ...    - ``expected_value``: Expected value of the field
    ...
    ...    *Example:*
    ...    | ${accounts}= | Get Salesforce Account Records From Mock |
    ...    | Verify Salesforce Record Field Value | ${accounts} | 0 | Name | Acme Corp |
    [Arguments]    ${records}    ${record_index}    ${field_name}    ${expected_value}
    ${record}=    Get From List    ${records}    ${record_index}
    Dictionary Should Contain Key    ${record}    ${field_name}
    ...    msg=Field '${field_name}' not found in record. Available keys: ${record.keys()}
    ${actual_value}=    Get From Dictionary    ${record}    ${field_name}
    Should Be Equal As Strings    ${actual_value}    ${expected_value}
    ...    msg=Record field '${field_name}': expected '${expected_value}' but got '${actual_value}'
    Log    Record[${record_index}] ${field_name} = '${actual_value}'    console=yes

# ============================================================================
#    GENERIC OBJECT VERIFICATION (Any Salesforce Object)
# ============================================================================

Get Salesforce Object Records From Mock
    [Documentation]    Queries records of any Salesforce object type from the Django mock.
    ...
    ...    *Arguments:*
    ...    - ``object_name``: Salesforce object type (Account, Contact, Lead, etc.)
    ...    - ``fields``: Comma-separated field names to select
    ...
    ...    *Returns:*
    ...    - List of record dictionaries
    ...
    ...    *Example:*
    ...    | ${contacts}= | Get Salesforce Object Records From Mock | Contact | Id,FirstName,LastName |
    [Arguments]    ${object_name}    ${fields}=Id,Name    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${soql}=    Set Variable    SELECT ${fields} FROM ${object_name}
    ${result}=    Query Salesforce Mock Records    ${soql}    ${mock_url}
    RETURN    ${result}[records]

Verify Salesforce Object Record Count
    [Documentation]    Verifies that the expected number of records exist for any object type.
    ...
    ...    *Arguments:*
    ...    - ``object_name``: Salesforce object type (Account, Contact, Lead, etc.)
    ...    - ``expected_count``: Expected number of records
    ...    - ``fields``: Comma-separated field names to select
    ...
    ...    *Returns:*
    ...    - List of records
    ...
    ...    *Example:*
    ...    | ${contacts}= | Verify Salesforce Object Record Count | Contact | 3 | Id,FirstName,LastName |
    [Arguments]    ${object_name}    ${expected_count}    ${fields}=Id,Name    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${records}=    Get Salesforce Object Records From Mock    ${object_name}    ${fields}    ${mock_url}
    ${actual_count}=    Get Length    ${records}
    Should Be Equal As Integers    ${actual_count}    ${expected_count}
    ...    msg=Expected ${expected_count} ${object_name} record(s) but found ${actual_count} in mock DB
    Log    Verified ${expected_count} ${object_name} record(s) in mock    console=yes
    RETURN    ${records}

Log Salesforce Mock Database Summary
    [Documentation]    Logs a summary of all data currently in the Django mock server.
    ...    Useful for debugging — shows which objects have records and how many.
    ...
    ...    *Example:*
    ...    | Log Salesforce Mock Database Summary |
    [Arguments]    ${mock_url}=${SALESFORCE_MOCK_URL}
    ${db}=    Get All Salesforce Mock Data    ${mock_url}
    ${objects}=    Get Dictionary Keys    ${db}
    FOR    ${obj}    IN    @{objects}
        ${records}=    Set Variable    ${db}[${obj}]
        ${count}=    Get Length    ${records}
        IF    ${count} > 0
            Log    ${obj}: ${count} record(s)    console=yes
            Log    ${records}    console=yes
        END
    END
