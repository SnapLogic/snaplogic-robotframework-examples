*** Comments ***
# DATA PERSISTENCE FLOW:
# =====================
# When using proxy mappings for real data persistence:
#
#    Robot Test / SnapLogic Pipeline
#    ↓
#    POST https://salesforce-api-mock:8443/services/data/v59.0/sobjects/Account
#    ↓
#    WireMock Container (salesforce-api-mock)
#    - Checks /home/wiremock/mappings/ in priority order
#    - Finds: 02-proxy-create-account.json (priority: 1)
#    ↓
#    Proxies Request To: http://salesforce-json-mock/accounts
#    ↓
#    JSON Server Container (salesforce-json-mock)
#    - Receives POST /accounts
#    - Generates ID (e.g., "001000000000004")
#    - Saves to /data/salesforce-db.json
#    ↓
#    Returns Response with ID
#    ↓
#    WireMock transforms response to Salesforce format:
#    {"id": "001000000000004", "success": true, "errors": []}
#    ↓
#    Robot Test / SnapLogic receives response
#
# MAPPING TYPES:
# =============
#
# - Proxy Mappings: Forward to JSON Server (real persistence)
#    Example: 02-proxy-create-account.json - Actually saves data

1. Robot Test sends:
    POST https://salesforce-api-mock:8443/services/data/v59.0/sobjects/Account
    Body: {"Name": "Test Account", "Type": "Customer", ...}
    ↓
2. WireMock matches this mapping (pattern matches, method matches)
    ↓
3. WireMock proxies to:
    POST http://salesforce-json-mock/accounts
    Body: {"Name": "Test Account", "Type": "Customer", ...}
    ↓
4. JSON Server creates account and returns:
    Status: 201 (JSON Server's default for POST)
    Body: {"id": "001xxx", "Name": "Test Account", ...all fields...}
    ↓
5. WireMock transforms the response:
    - Body becomes: {"id": "001xxx", "success": true, "errors": []}
    - Status: 201 (WireMock's default for successful POST)
    ↓
6. Robot Test receives transformed response


*** Settings ***
Documentation       Test Case: Create Salesforce Account and Save to JSON-DB
...                 This test demonstrates creating an account through WireMock
...                 which proxies the request to JSON Server for persistence.
...
...                 Architecture:
...                 Robot Test (in container) -> WireMock (salesforce-api-mock:8443/8080) -> JSON Server (salesforce-json-mock:80) -> salesforce-db.json
...
...                 Prerequisites:
...                 1. Start Docker services:
...                 docker-compose -f docker-compose.salesforce-mock.yml up -d
...                 2. Services accessible via Docker network:
...                 - WireMock HTTPS: salesforce-api-mock:8443
...                 - WireMock HTTP: salesforce-api-mock:8080
...                 - JSON Server: salesforce-json-mock:80

Library             RequestsLibrary
Library             JSONLibrary
Library             Collections
Library             DateTime
Library             String
Resource            wiremock_apis.resource

Suite Setup         Setup Test Environment
Suite Teardown      Cleanup Test Environment
Test Setup          Reset Test State
Test Teardown       Log Test Results


*** Variables ***
# JSON Server Configuration (for direct access)
${JSON_SERVER_URL}      http://salesforce-json-mock:80    # JSON Server (internal port 80, not 8082)
${JSON_DB_SESSION}      json-database

# Test Data
${TEST_ACCOUNT_NAME}    Integration Test Company ${TIMESTAMP}
${TIMESTAMP}            ${EMPTY}


*** Test Cases ***
Create Account And Verify In JSON Database
    [Documentation]    Complete test flow for creating a Salesforce account via WireMock
    ...    and verifying it's persisted in JSON Server database.
    ...
    ...    Test Flow:
    ...    1. Authenticate with Salesforce Mock (get token)
    ...    2. Create new account via WireMock API
    ...    3. Verify account exists in JSON Server
    ...    4. Retrieve account via Salesforce API
    ...    5. Query accounts via SOQL
    ...    6. Verify data consistency
    [Tags]    salesforce    account    json-db    integration    sfdc2

    # Step 1: Authenticate and get access token
    ${auth_response}    Authenticate Api    test@example.com    test123
    Should Be Equal As Strings    ${auth_response.status_code}    200
    Log    Authentication successful: ${auth_response.json()}    console=True

    # Step 2: Prepare test account data
    ${account_data}    Create Test Account Data
    Log    Creating account with data: ${account_data}    console=True

    # Step 3: Create account via WireMock (proxies to JSON Server)
    ${create_response}    Create Account Api    ${account_data}
    Should Be Equal As Strings    ${create_response.status_code}    201
    ${account_id}    Get From Dictionary    ${create_response.json()}    id
    Log    Account created successfully with ID: ${account_id}

    # Step 4: Verify account in JSON Server directly
    ${json_db_account}    Get Account From JSON Server    ${account_id}
    Should Not Be Empty    ${json_db_account}
    Verify Account Data In JSON DB    ${json_db_account}    ${account_data}

    # Step 5: Retrieve account via Salesforce API (WireMock)
    ${get_response}    Get Account Api    ${account_id}
    Should Be Equal As Strings    ${get_response.status_code}    200
    ${retrieved_account}    Set Variable    ${get_response.json()}
    Verify Account Data    ${retrieved_account}    ${account_data}

    # Step 6: Query accounts via SOQL
    ${query}    Set Variable    SELECT Id, Name, Type, Industry FROM Account WHERE Id='${account_id}'
    ${query_response}    Execute Query Api    ${query}
    Should Be Equal As Strings    ${query_response.status_code}    200
    ${records}    Get From Dictionary    ${query_response.json()}    records
    Should Not Be Empty    ${records}
    Log    SOQL query returned: ${records}

    # Step 7: Update the account
    ${update_data}    Create Dictionary
    ...    Type=Enterprise Customer
    ...    AnnualRevenue=100000000
    ...    NumberOfEmployees=2500
    ${update_response}    Update Account Api    ${account_id}    ${update_data}
    Should Be Equal As Strings    ${update_response.status_code}    204

    # Step 8: Verify update in JSON Server
    ${updated_account}    Get Account From JSON Server    ${account_id}
    Should Be Equal    ${updated_account['Type']}    Enterprise Customer
    Should Be Equal As Numbers    ${updated_account['AnnualRevenue']}    100000000

    Log    Test completed successfully! Account ${account_id} created and verified.

Test Bulk Account Creation
    [Documentation]    Create multiple accounts and verify batch operations
    [Tags]    salesforce    bulk    json-db

    # Authenticate
    ${auth_response}    Authenticate Api    test@example.com    test123
    Should Be Equal As Strings    ${auth_response.status_code}    200

    # Create multiple accounts
    ${account_ids}    Create List
    FOR    ${i}    IN RANGE    3
        ${account_data}    Create Dictionary
        ...    Name=Bulk Test Account ${i+1}
        ...    Type=Customer
        ...    Industry=Technology
        ...    AnnualRevenue=${1000000 * (${i} + 1)}

        ${response}    Create Account Api    ${account_data}
        Should Be Equal As Strings    ${response.status_code}    201
        ${id}    Get From Dictionary    ${response.json()}    id
        Append To List    ${account_ids}    ${id}
        Log    Created account ${i+1} with ID: ${id}
    END

    # Verify all accounts exist in JSON DB
    ${all_accounts}    Get All Accounts From JSON Server
    FOR    ${id}    IN    @{account_ids}
        ${found}    Account Exists In List    ${all_accounts}    ${id}
        Should Be True    ${found}    Account ${id} not found in JSON DB
    END

    Log    Successfully created ${3} accounts in bulk

Test Account Delete And Verify Removal
    [Documentation]    Create an account, delete it, and verify removal from JSON DB
    [Tags]    salesforce    delete    json-db

    # Authenticate
    ${auth_response}    Authenticate Api    test@example.com    test123
    Should Be Equal As Strings    ${auth_response.status_code}    200

    # Create account
    ${account_data}    Create Dictionary
    ...    Name=Account To Delete
    ...    Type=Prospect
    ...    Industry=Finance

    ${create_response}    Create Account Api    ${account_data}
    ${account_id}    Get From Dictionary    ${create_response.json()}    id

    # Verify it exists
    ${exists_response}    Get Account Api    ${account_id}
    Should Be Equal As Strings    ${exists_response.status_code}    200

    # Delete the account
    ${delete_response}    Delete Account Api    ${account_id}
    Should Be Equal As Strings    ${delete_response.status_code}    204

    # Verify it's removed from JSON DB
    ${all_accounts}    Get All Accounts From JSON Server
    ${found}    Account Exists In List    ${all_accounts}    ${account_id}
    Should Not Be True    ${found}    Account ${account_id} still exists after deletion

    Log    Account ${account_id} successfully deleted and verified

Test Contact Creation With Account
    [Documentation]    Create a contact linked to an account
    [Tags]    salesforce    contact    json-db

    # Authenticate
    ${auth_response}    Authenticate Api    test@example.com    test123
    Should Be Equal As Strings    ${auth_response.status_code}    200

    # Create account first
    ${account_data}    Create Dictionary
    ...    Name=Parent Account for Contact
    ...    Type=Customer
    ...    Industry=Healthcare

    ${account_response}    Create Account Api    ${account_data}
    ${account_id}    Get From Dictionary    ${account_response.json()}    id

    # Create contact linked to account
    ${contact_data}    Create Dictionary
    ...    FirstName=John
    ...    LastName=Doe
    ...    Email=john.doe@example.com
    ...    Phone=(555) 123-4567
    ...    AccountId=${account_id}
    ...    Title=CEO

    ${contact_response}    Create Contact Api    ${contact_data}
    Should Be Equal As Strings    ${contact_response.status_code}    201
    ${contact_id}    Get From Dictionary    ${contact_response.json()}    id
    Log    Contact created with ID: ${contact_id}

    # Verify contact
    ${get_contact}    Get Contact Api    ${contact_id}
    Should Be Equal As Strings    ${get_contact.status_code}    200
    Should Be Equal    ${get_contact.json()['AccountId']}    ${account_id}

    Log    Successfully created contact linked to account

Test Opportunity Creation
    [Documentation]    Create an opportunity and verify
    [Tags]    salesforce    opportunity    json-db

    # Authenticate
    ${auth_response}    Authenticate Api    test@example.com    test123
    Should Be Equal As Strings    ${auth_response.status_code}    200

    # Create account first
    ${account_data}    Create Dictionary
    ...    Name=Account with Opportunity
    ...    Type=Customer

    ${account_response}    Create Account Api    ${account_data}
    ${account_id}    Get From Dictionary    ${account_response.json()}    id

    # Create opportunity
    ${close_date}    Get Current Date    result_format=%Y-%m-%d    increment=30 days
    ${opp_data}    Create Dictionary
    ...    Name=Test Opportunity ${TIMESTAMP}
    ...    AccountId=${account_id}
    ...    StageName=Prospecting
    ...    CloseDate=${close_date}
    ...    Amount=500000

    ${opp_response}    Create Opportunity Api    ${opp_data}
    Should Be Equal As Strings    ${opp_response.status_code}    201
    ${opp_id}    Get From Dictionary    ${opp_response.json()}    id

    # Verify opportunity
    ${get_opp}    Get Opportunity Api    ${opp_id}
    Should Be Equal As Strings    ${get_opp.status_code}    200
    Should Be Equal    ${get_opp.json()['AccountId']}    ${account_id}

    Log    Successfully created opportunity for account


*** Keywords ***
# ============================================================================
# SETUP AND TEARDOWN
# ============================================================================

Setup Test Environment
    [Documentation]    Initialize test environment and sessions

    # Generate timestamp for unique test data
    ${timestamp}    Get Current Date    result_format=%Y%m%d_%H%M%S
    Set Suite Variable    ${TIMESTAMP}    ${timestamp}

    # Create Salesforce session using the resource file keyword
    Create Salesforce Session Api

    # Create JSON Server session for direct access
    Create Session    ${JSON_DB_SESSION}    ${JSON_SERVER_URL}    verify=${FALSE}

    Log    Test environment initialized with timestamp: ${TIMESTAMP}

    # Verify services are running
    Verify Services Are Running

Cleanup Test Environment
    [Documentation]    Clean up test data and close sessions

    # Optional: Clean up test accounts created during tests
    # This is commented out to preserve test data for debugging
    # Cleanup Test Accounts

    Log    Test environment cleanup completed

Reset Test State
    [Documentation]    Reset state before each test
    Log    Starting new test case...

Log Test Results
    [Documentation]    Log results after each test
    Log    Test case completed

Verify Services Are Running
    [Documentation]    Check that WireMock and JSON Server are accessible

    # Check WireMock health
    ${wiremock_health}    GET On Session    ${WIREMOCK_SESSION}    /__admin/health
    ...    expected_status=200
    Log    WireMock is running: ${wiremock_health.json()}

    # Check JSON Server
    ${json_health}    GET On Session    ${JSON_DB_SESSION}    /accounts
    ...    expected_status=200
    Log    JSON Server is running with ${json_health.json().__len__()} existing accounts

# ============================================================================
# JSON SERVER DIRECT OPERATIONS
# ============================================================================

Get Account From JSON Server
    [Documentation]    Get account directly from JSON Server
    [Arguments]    ${account_id}

    ${response}    GET On Session    ${JSON_DB_SESSION}    /accounts/${account_id}
    ...    expected_status=any

    IF    ${response.status_code} == 200
        RETURN    ${response.json()}
    ELSE
        RETURN    ${EMPTY}
    END

Get All Accounts From JSON Server
    [Documentation]    Get all accounts directly from JSON Server

    ${response}    GET On Session    ${JSON_DB_SESSION}    /accounts
    ...    expected_status=200

    RETURN    ${response.json()}

# ============================================================================
# TEST DATA HELPERS
# ============================================================================

Create Test Account Data
    [Documentation]    Create test account data with timestamp

    ${random_num}    Evaluate    random.randint(1000, 9999)    modules=random

    ${account_data}    Create Dictionary
    ...    Name=Test Account ${TIMESTAMP}_${random_num}
    ...    Type=Customer
    ...    Industry=Technology
    ...    Phone=(555) ${random_num}
    ...    Website=https://www.testaccount${random_num}.com
    ...    AnnualRevenue=${random_num}000
    ...    NumberOfEmployees=${random_num}
    ...    BillingStreet=123 Test Street
    ...    BillingCity=San Francisco
    ...    BillingState=CA
    ...    BillingPostalCode=94105
    ...    BillingCountry=USA
    ...    Description=Created by Robot Framework test at ${TIMESTAMP}

    RETURN    ${account_data}

# ============================================================================
# VERIFICATION HELPERS
# ============================================================================

Verify Account Data
    [Documentation]    Verify account data matches expected values
    [Arguments]    ${actual_account}    ${expected_data}

    FOR    ${key}    IN    @{expected_data.keys()}
        ${actual_value}    Get From Dictionary    ${actual_account}    ${key}    ${NONE}
        ${expected_value}    Get From Dictionary    ${expected_data}    ${key}
        Should Be Equal    ${actual_value}    ${expected_value}
        ...    Field ${key} mismatch: expected '${expected_value}' but got '${actual_value}'
    END

Verify Account Data In JSON DB
    [Documentation]    Verify account data in JSON DB matches expected
    [Arguments]    ${json_db_account}    ${expected_data}

    # JSON DB might have different field names or structure
    Should Be Equal    ${json_db_account['Name']}    ${expected_data['Name']}
    Should Be Equal    ${json_db_account['Type']}    ${expected_data['Type']}
    Should Be Equal    ${json_db_account['Industry']}    ${expected_data['Industry']}

    # Verify numeric fields if present
    IF    'AnnualRevenue' in ${expected_data}
        Should Be Equal As Numbers    ${json_db_account['AnnualRevenue']}    ${expected_data['AnnualRevenue']}
    END

Account Exists In List
    [Documentation]    Check if account ID exists in list of accounts
    [Arguments]    ${accounts_list}    ${account_id}

    FOR    ${account}    IN    @{accounts_list}
        IF    '${account['id']}' == '${account_id}'    RETURN    ${TRUE}
    END
    RETURN    ${FALSE}

Cleanup Test Accounts
    [Documentation]    Clean up test accounts created during the test

    # Authenticate first
    ${auth_response}    Authenticate Api    test@example.com    test123

    ${all_accounts}    Get All Accounts From JSON Server

    FOR    ${account}    IN    @{all_accounts}
        # Only delete accounts created by this test run
        ${is_test_account}    Run Keyword And Return Status
        ...    Should Contain    ${account['Name']}    ${TIMESTAMP}

        IF    ${is_test_account}
            Delete Account Api    ${account['id']}
            Log    Cleaned up test account: ${account['Name']}
        END
    END
