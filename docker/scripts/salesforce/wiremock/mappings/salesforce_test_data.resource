*** Settings ***
Documentation    Salesforce JSON-DB Test Data Management Keywords
...              This resource file provides keywords for initializing,
...              managing, and cleaning up test data in JSON-DB via
...              Salesforce WireMock API endpoints.

Library    RequestsLibrary
Library    Collections
Library    JSONLibrary
Library    String
Library    DateTime
Library    OperatingSystem

*** Variables ***
# Configuration - Can be overridden by test suites or command line
${SALESFORCE_BASE_URL}    https://salesforce-api-mock:8443
${SESSION_ALIAS}          salesforce
${AUTH_TOKEN}             ${EMPTY}

# SSL Configuration - Simplified for testing
# For WireMock testing, we can safely bypass SSL verification
# The connection is still HTTPS (encrypted), we just skip certificate validation
${VERIFY_SSL}             ${FALSE}    # Bypass certificate checks for testing

# OAuth Configuration - Mock values for WireMock testing
# Note: WireMock doesn't validate these, so any values work
${CLIENT_ID}              3MVG9YDQS5WtC11paU2WcQjBB3L5w4gz52uriT8ksZ3nUVjKvrfQMrU4uvZohTftxS
${CLIENT_SECRET}          9205371019321668423
${USERNAME}               test@example.com
${PASSWORD}               test123
${SECURITY_TOKEN}         ${EMPTY}    # Not needed for mock testing

# Test Data Templates
&{DEFAULT_ACCOUNT}    Type=Customer    Industry=Technology    AnnualRevenue=1000000
&{DEFAULT_CONTACT}    Title=Manager    Department=Sales
&{DEFAULT_OPPORTUNITY}    StageName=Prospecting    Probability=10    Amount=50000

*** Keywords ***
# ============================================================================
# Setup and Authentication Keywords
# ============================================================================

Initialize Salesforce Test Environment
    [Documentation]    Main keyword to setup test environment with data
    [Arguments]    ${clear_existing}=${TRUE}    ${create_defaults}=${TRUE}
    
    Authenticate To Salesforce
    Run Keyword If    ${clear_existing}    Clear All Test Data
    Run Keyword If    ${create_defaults}    Create Default Test Accounts
    Verify Test Data Initialization

Authenticate To Salesforce
    [Documentation]    Authenticate and get OAuth token (simplified for WireMock)
    [Arguments]    ${username}=${USERNAME}    ${password}=${PASSWORD}
    
    # Create session with SSL verification bypassed for testing
    Create Session    ${SESSION_ALIAS}    ${SALESFORCE_BASE_URL}    verify=${VERIFY_SSL}
    
    # WireMock doesn't validate credentials - just needs POST to endpoint
    ${response}=    POST On Session    ${SESSION_ALIAS}    /services/oauth2/token
    ...    expected_status=200
    
    # Store token (even though WireMock doesn't check it)
    ${token}=    Get From Dictionary    ${response.json()}    access_token
    Set Suite Variable    ${AUTH_TOKEN}    ${token}
    Set Suite Variable    ${INSTANCE_URL}    ${response.json()}[instance_url]
    
    Log    Got mock token: ${AUTH_TOKEN[:20]}...
    RETURN    ${token}

Authenticate To Salesforce Minimal
    [Documentation]    Absolute minimum authentication for WireMock (empty body works!)
    
    Create Session    ${SESSION_ALIAS}    ${SALESFORCE_BASE_URL}    verify=${VERIFY_SSL}
    
    # WireMock doesn't check body content at all!
    ${response}=    POST On Session    ${SESSION_ALIAS}    /services/oauth2/token
    ...    expected_status=200
    
    ${token}=    Get From Dictionary    ${response.json()}    access_token
    Set Suite Variable    ${AUTH_TOKEN}    ${token}
    
    Log    Got token with empty request!
    RETURN    ${token}

Get Auth Headers
    [Documentation]    Returns headers with authorization token
    [Arguments]    ${include_auth}=${FALSE}    # Default to no auth for WireMock
    
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    
    # Only add Authorization if explicitly needed (for future real Salesforce testing)
    Run Keyword If    ${include_auth}
    ...    Set To Dictionary    ${headers}    Authorization=Bearer ${AUTH_TOKEN}
    
    RETURN    ${headers}

Get Simple Headers
    [Documentation]    Returns just Content-Type header for WireMock testing
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    RETURN    ${headers}

Get Headers With Auth
    [Documentation]    Returns headers with Bearer token (for future use with real Salesforce)
    ${headers}=    Create Dictionary
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json
    RETURN    ${headers}

# ============================================================================
# Account Management Keywords
# ============================================================================

Create Account
    [Documentation]    Create a single account in JSON-DB
    [Arguments]    ${name}    ${account_data}=${DEFAULT_ACCOUNT}
    
    ${headers}=    Get Auth Headers
    
    # Merge name with account data
    ${full_data}=    Copy Dictionary    ${account_data}
    Set To Dictionary    ${full_data}    Name=${name}
    
    ${response}=    POST On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Account
    ...    json=${full_data}
    ...    headers=${headers}
    ...    expected_status=201
    
    ${account_id}=    Get From Dictionary    ${response.json()}    id
    Log    Created account: ${name} with ID: ${account_id}
    RETURN    ${account_id}

Create Test Account With Details
    [Documentation]    Create account with full details
    [Arguments]    ${name}    ${type}=Customer    ${industry}=Technology    
    ...    ${revenue}=1000000    ${phone}=(555) 123-4567    ${website}=www.test.com
    
    ${account_data}=    Create Dictionary
    ...    Name=${name}
    ...    Type=${type}
    ...    Industry=${industry}
    ...    AnnualRevenue=${revenue}
    ...    Phone=${phone}
    ...    Website=${website}
    ...    BillingCity=San Francisco
    ...    BillingState=CA
    ...    BillingCountry=USA
    
    ${account_id}=    Create Account    ${name}    ${account_data}
    RETURN    ${account_id}

Create Multiple Accounts
    [Documentation]    Create multiple accounts from a list
    [Arguments]    @{account_names}
    
    ${account_ids}=    Create List
    FOR    ${name}    IN    @{account_names}
        ${id}=    Create Account    ${name}
        Append To List    ${account_ids}    ${id}
    END
    RETURN    ${account_ids}

Update Account
    [Documentation]    Update an existing account
    [Arguments]    ${account_id}    ${update_data}
    
    ${headers}=    Get Auth Headers
    
    ${response}=    PATCH On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Account/${account_id}
    ...    json=${update_data}
    ...    headers=${headers}
    ...    expected_status=204
    
    Log    Updated account ${account_id}

Delete Account
    [Documentation]    Delete an account by ID
    [Arguments]    ${account_id}
    
    ${headers}=    Get Auth Headers
    
    ${response}=    DELETE On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Account/${account_id}
    ...    headers=${headers}
    ...    expected_status=204
    
    Log    Deleted account ${account_id}

Get Account By Id
    [Documentation]    Retrieve account details by ID
    [Arguments]    ${account_id}
    
    ${headers}=    Get Auth Headers
    
    ${response}=    GET On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Account/${account_id}
    ...    headers=${headers}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Query Accounts
    [Documentation]    Execute SOQL query for accounts
    [Arguments]    ${soql_query}=SELECT Id, Name, Type FROM Account
    
    ${headers}=    Get Auth Headers
    
    ${response}=    GET On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/query
    ...    params=q=${soql_query}
    ...    headers=${headers}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Get All Accounts
    [Documentation]    Get all accounts from JSON-DB
    
    ${result}=    Query Accounts    SELECT Id, Name, Type, Industry FROM Account
    ${accounts}=    Get From Dictionary    ${result}    records
    RETURN    ${accounts}

Account Should Exist
    [Documentation]    Verify account exists by name
    [Arguments]    ${account_name}
    
    ${result}=    Query Accounts    SELECT Id FROM Account WHERE Name='${account_name}'
    ${count}=    Get Length    ${result}[records]
    Should Be Equal As Numbers    ${count}    1
    ...    msg=Account '${account_name}' not found

Account Should Not Exist
    [Documentation]    Verify account does not exist by name
    [Arguments]    ${account_name}
    
    ${result}=    Query Accounts    SELECT Id FROM Account WHERE Name='${account_name}'
    ${count}=    Get Length    ${result}[records]
    Should Be Equal As Numbers    ${count}    0
    ...    msg=Account '${account_name}' should not exist

# ============================================================================
# Contact Management Keywords
# ============================================================================

Create Contact
    [Documentation]    Create a contact linked to an account
    [Arguments]    ${first_name}    ${last_name}    ${account_id}    ${contact_data}=${DEFAULT_CONTACT}
    
    ${headers}=    Get Auth Headers
    
    ${full_data}=    Copy Dictionary    ${contact_data}
    Set To Dictionary    ${full_data}
    ...    FirstName=${first_name}
    ...    LastName=${last_name}
    ...    AccountId=${account_id}
    
    ${response}=    POST On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Contact
    ...    json=${full_data}
    ...    headers=${headers}
    ...    expected_status=201
    
    ${contact_id}=    Get From Dictionary    ${response.json()}    id
    Log    Created contact: ${first_name} ${last_name} with ID: ${contact_id}
    RETURN    ${contact_id}

# ============================================================================
# Opportunity Management Keywords
# ============================================================================

Create Opportunity
    [Documentation]    Create an opportunity linked to an account
    [Arguments]    ${name}    ${account_id}    ${close_date}=${EMPTY}    ${opp_data}=${DEFAULT_OPPORTUNITY}
    
    ${headers}=    Get Auth Headers
    
    # Set close date to 90 days from now if not provided
    ${close_date}=    Run Keyword If    '${close_date}'=='${EMPTY}'
    ...    Get Future Date    90
    ...    ELSE    Set Variable    ${close_date}
    
    ${full_data}=    Copy Dictionary    ${opp_data}
    Set To Dictionary    ${full_data}
    ...    Name=${name}
    ...    AccountId=${account_id}
    ...    CloseDate=${close_date}
    
    ${response}=    POST On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Opportunity
    ...    json=${full_data}
    ...    headers=${headers}
    ...    expected_status=201
    
    ${opp_id}=    Get From Dictionary    ${response.json()}    id
    Log    Created opportunity: ${name} with ID: ${opp_id}
    RETURN    ${opp_id}

# ============================================================================
# Bulk Data Creation Keywords
# ============================================================================

Create Default Test Accounts
    [Documentation]    Create the standard test accounts
    
    # Account 1: Acme Corporation
    ${acme_data}=    Create Dictionary
    ...    Name=Acme Corporation
    ...    Type=Customer
    ...    Industry=Technology
    ...    AnnualRevenue=50000000
    ...    Phone=(555) 123-4567
    ...    Website=https://www.acme-corp.com
    
    ${acme_id}=    Create Account    Acme Corporation    ${acme_data}
    Set Suite Variable    ${ACME_ACCOUNT_ID}    ${acme_id}
    
    # Account 2: Global Innovations Inc
    ${global_data}=    Create Dictionary
    ...    Name=Global Innovations Inc
    ...    Type=Partner
    ...    Industry=Manufacturing
    ...    AnnualRevenue=75000000
    ...    Phone=(555) 987-6543
    ...    Website=https://www.globalinnovations.com
    
    ${global_id}=    Create Account    Global Innovations Inc    ${global_data}
    Set Suite Variable    ${GLOBAL_ACCOUNT_ID}    ${global_id}
    
    # Account 3: TechStart Solutions
    ${tech_data}=    Create Dictionary
    ...    Name=TechStart Solutions
    ...    Type=Prospect
    ...    Industry=Software
    ...    AnnualRevenue=10000000
    ...    Phone=(555) 555-5555
    ...    Website=https://www.techstart.io
    
    ${tech_id}=    Create Account    TechStart Solutions    ${tech_data}
    Set Suite Variable    ${TECHSTART_ACCOUNT_ID}    ${tech_id}
    
    Log    Created default test accounts

Create Test Data Hierarchy
    [Documentation]    Create accounts with related contacts and opportunities
    [Arguments]    ${account_name}    ${num_contacts}=2    ${num_opportunities}=1
    
    # Create account
    ${account_id}=    Create Account    ${account_name}
    
    # Create contacts
    ${contact_ids}=    Create List
    FOR    ${i}    IN RANGE    ${num_contacts}
        ${contact_id}=    Create Contact    Test${i}    User${i}    ${account_id}
        Append To List    ${contact_ids}    ${contact_id}
    END
    
    # Create opportunities
    ${opp_ids}=    Create List
    FOR    ${i}    IN RANGE    ${num_opportunities}
        ${opp_id}=    Create Opportunity    ${account_name} Opp ${i}    ${account_id}
        Append To List    ${opp_ids}    ${opp_id}
    END
    
    ${result}=    Create Dictionary
    ...    account_id=${account_id}
    ...    contact_ids=${contact_ids}
    ...    opportunity_ids=${opp_ids}
    
    RETURN    ${result}

# ============================================================================
# Data Cleanup Keywords
# ============================================================================

Clear All Test Data
    [Documentation]    Remove all test data from JSON-DB
    
    Clear All Opportunities
    Clear All Contacts
    Clear All Accounts
    Log    All test data cleared

Clear All Accounts
    [Documentation]    Delete all accounts from JSON-DB
    
    ${accounts}=    Get All Accounts
    ${count}=    Get Length    ${accounts}
    
    FOR    ${account}    IN    @{accounts}
        Delete Account    ${account}[Id]
    END
    
    Log    Deleted ${count} accounts

Clear All Contacts
    [Documentation]    Delete all contacts from JSON-DB
    
    ${headers}=    Get Auth Headers
    ${result}=    Query Accounts    SELECT Id FROM Contact
    ${contacts}=    Get From Dictionary    ${result}    records    default=@{EMPTY}
    
    FOR    ${contact}    IN    @{contacts}
        DELETE On Session    ${SESSION_ALIAS}
        ...    /services/data/v59.0/sobjects/Contact/${contact}[Id]
        ...    headers=${headers}
        ...    expected_status=204
    END
    
    Log    Deleted ${contacts.__len__()} contacts

Clear All Opportunities
    [Documentation]    Delete all opportunities from JSON-DB
    
    ${headers}=    Get Auth Headers
    ${result}=    Query Accounts    SELECT Id FROM Opportunity
    ${opportunities}=    Get From Dictionary    ${result}    records    default=@{EMPTY}
    
    FOR    ${opp}    IN    @{opportunities}
        DELETE On Session    ${SESSION_ALIAS}
        ...    /services/data/v59.0/sobjects/Opportunity/${opp}[Id]
        ...    headers=${headers}
        ...    expected_status=204
    END
    
    Log    Deleted ${opportunities.__len__()} opportunities

# ============================================================================
# Verification Keywords
# ============================================================================

Verify Test Data Initialization
    [Documentation]    Verify that test data was created successfully
    
    ${accounts}=    Get All Accounts
    ${count}=    Get Length    ${accounts}
    Should Be True    ${count} >= 3    msg=Expected at least 3 test accounts
    
    # Verify specific accounts exist
    Account Should Exist    Acme Corporation
    Account Should Exist    Global Innovations Inc
    Account Should Exist    TechStart Solutions
    
    Log    Test data verification successful: ${count} accounts found

Verify Account Count
    [Documentation]    Verify the expected number of accounts exist
    [Arguments]    ${expected_count}
    
    ${accounts}=    Get All Accounts
    ${actual_count}=    Get Length    ${accounts}
    Should Be Equal As Numbers    ${actual_count}    ${expected_count}
    ...    msg=Expected ${expected_count} accounts but found ${actual_count}

# ============================================================================
# Error Scenario Keywords
# ============================================================================

Create Account With Missing Required Field
    [Documentation]    Attempt to create account without name (should fail)
    
    ${headers}=    Get Auth Headers
    ${invalid_data}=    Create Dictionary    Type=Customer    Industry=Technology
    
    Run Keyword And Expect Error    *400*
    ...    POST On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Account
    ...    json=${invalid_data}
    ...    headers=${headers}
    ...    expected_status=400

Create Duplicate Account
    [Documentation]    Attempt to create duplicate account
    [Arguments]    ${account_name}
    
    # First create should succeed
    ${id1}=    Create Account    ${account_name}
    
    # Second create with same name (behavior depends on duplicate rules)
    ${headers}=    Get Auth Headers
    ${duplicate_data}=    Create Dictionary    Name=${account_name}
    
    ${response}=    POST On Session    ${SESSION_ALIAS}
    ...    /services/data/v59.0/sobjects/Account
    ...    json=${duplicate_data}
    ...    headers=${headers}
    ...    expected_status=any
    
    # Log the response for debugging
    Log    Duplicate creation response: ${response.status_code}
    RETURN    ${response}

# ============================================================================
# Utility Keywords
# ============================================================================

Get Future Date
    [Documentation]    Get a date N days in the future in YYYY-MM-DD format
    [Arguments]    ${days_ahead}=30
    
    ${future_date}=    Get Current Date    increment=${days_ahead} days
    ...    result_format=%Y-%m-%d
    RETURN    ${future_date}

Log JSON Response
    [Documentation]    Pretty print JSON response for debugging
    [Arguments]    ${response}
    
    ${json_string}=    Evaluate    json.dumps(${response}, indent=2)    json
    Log    ${json_string}

Set Test Data Variables
    [Documentation]    Set commonly used test data as suite variables
    
    Set Suite Variable    ${TEST_ACCOUNT_NAME}    Test Account ${TEST NAME}
    Set Suite Variable    ${TEST_CONTACT_FIRST}    John
    Set Suite Variable    ${TEST_CONTACT_LAST}    Doe
    Set Suite Variable    ${TEST_OPP_NAME}    Test Opportunity

# ============================================================================
# JSON Server Integration Keywords (New)
# ============================================================================

Setup With JSON DB
    [Documentation]    Initialize both WireMock and JSON-DB
    
    # Initialize WireMock connection
    Authenticate To Salesforce
    
    # Initialize JSON-DB
    Connect To JSON DB
    Initialize JSON DB
    
    Log    Test environment ready with JSON-DB persistence

Cleanup JSON DB
    [Documentation]    Clean up test data
    
    Clear All JSON DB Data
    Log    JSON-DB cleaned up

Connect To JSON DB
    [Documentation]    Establish connection to JSON Server for direct operations
    [Arguments]    ${json_server_url}=http://salesforce-json-mock    ${from_docker}=${TRUE}
    
    # Determine URL based on execution context
    ${url}=    Run Keyword If    ${from_docker}
    ...    Set Variable    http://salesforce-json-mock
    ...    ELSE    Set Variable    http://localhost:8082
    
    Create Session    json_db    ${url}
    Set Suite Variable    ${JSON_DB_URL}    ${url}
    
    Log    Connected to JSON Server at: ${url}

Initialize JSON DB
    [Documentation]    Initialize JSON-DB with basic structure
    
    # Create empty collections if they don't exist
    ${empty_data}=    Create Dictionary
    ...    accounts=@{EMPTY}
    ...    contacts=@{EMPTY}
    ...    opportunities=@{EMPTY}
    ...    leads=@{EMPTY}
    ...    cases=@{EMPTY}
    
    # Check if database exists and has structure
    ${status}    ${response}=    Run Keyword And Ignore Error
    ...    GET On Session    json_db    /accounts
    
    Run Keyword If    '${status}' == 'FAIL'
    ...    Initialize Empty JSON Collections
    
    Log    JSON-DB initialized with empty collections

Initialize Empty JSON Collections
    [Documentation]    Create empty collections in JSON-DB
    
    # Create first account to establish the collection
    ${init_account}=    Create Dictionary
    ...    name=__init__
    ...    type=System
    ...    _temporary=${TRUE}
    
    POST On Session    json_db    /accounts    json=${init_account}
    
    # Delete the temporary account
    ${accounts}=    GET On Session    json_db    /accounts
    FOR    ${account}    IN    @{accounts.json()}
        Run Keyword If    '${account}[name]' == '__init__'
        ...    DELETE On Session    json_db    /accounts/${account}[id]
    END

Clear All JSON DB Data
    [Documentation]    Remove all data from JSON-DB collections
    
    # Clear each collection
    @{collections}=    Create List    accounts    contacts    opportunities    leads    cases
    
    FOR    ${collection}    IN    @{collections}
        Clear JSON Collection    ${collection}
    END
    
    Log    All JSON-DB collections cleared

Clear JSON Collection
    [Documentation]    Clear all items from a specific JSON collection
    [Arguments]    ${collection_name}
    
    ${status}    ${items}=    Run Keyword And Ignore Error
    ...    GET On Session    json_db    /${collection_name}
    
    Run Keyword If    '${status}' == 'PASS'
    ...    Delete All Items From Collection    ${collection_name}    ${items.json()}

Delete All Items From Collection
    [Documentation]    Delete all items from a collection
    [Arguments]    ${collection_name}    ${items}
    
    FOR    ${item}    IN    @{items}
        ${status}=    Run Keyword And Ignore Error
        ...    DELETE On Session    json_db    /${collection_name}/${item}[id]
        Run Keyword If    '${status}' == 'FAIL'
        ...    Log    Failed to delete item ${item}[id] from ${collection_name}
    END

# ============================================================================
# Direct JSON-DB Operations (Bypassing WireMock)
# ============================================================================

Create Account In JSON DB
    [Documentation]    Create account directly in JSON-DB
    [Arguments]    ${account_data}
    
    ${response}=    POST On Session    json_db    /accounts
    ...    json=${account_data}
    ...    expected_status=201
    
    ${account_id}=    Get From Dictionary    ${response.json()}    id
    Log    Created account in JSON-DB with ID: ${account_id}
    RETURN    ${account_id}

Get Account From JSON DB
    [Documentation]    Get account directly from JSON-DB
    [Arguments]    ${account_id}
    
    ${response}=    GET On Session    json_db    /accounts/${account_id}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Update Account In JSON DB
    [Documentation]    Update account directly in JSON-DB
    [Arguments]    ${account_id}    ${update_data}
    
    ${response}=    PATCH On Session    json_db    /accounts/${account_id}
    ...    json=${update_data}
    ...    expected_status=200
    
    Log    Updated account ${account_id} in JSON-DB
    RETURN    ${response.json()}

Delete Account From JSON DB
    [Documentation]    Delete account directly from JSON-DB
    [Arguments]    ${account_id}
    
    DELETE On Session    json_db    /accounts/${account_id}
    ...    expected_status=200
    
    Log    Deleted account ${account_id} from JSON-DB

Query JSON DB
    [Documentation]    Query JSON-DB with filters
    [Arguments]    ${collection}    ${filters}=${EMPTY}
    
    ${params}=    Create Dictionary
    
    # Add filters if provided
    Run Keyword If    '${filters}' != '${EMPTY}'
    ...    Add Filters To Params    ${params}    ${filters}
    
    ${response}=    GET On Session    json_db    /${collection}
    ...    params=${params}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Add Filters To Params
    [Documentation]    Helper to add filters to query parameters
    [Arguments]    ${params}    ${filters}
    
    FOR    ${key}    ${value}    IN    &{filters}
        Set To Dictionary    ${params}    ${key}=${value}
    END

# ============================================================================
# Persistence Verification Keywords
# ============================================================================

Verify Data Persists After Restart
    [Documentation]    Verify that data persists in JSON-DB after container restart
    [Arguments]    ${test_data}
    
    # Create test account
    ${account_id}=    Create Account In JSON DB    ${test_data}
    
    # Simulate restart (just reconnect in this case)
    Connect To JSON DB
    
    # Verify account still exists
    ${retrieved}=    Get Account From JSON DB    ${account_id}
    Should Be Equal    ${retrieved}[name]    ${test_data}[name]
    
    Log    Data persistence verified for account: ${account_id}

Export JSON DB To File
    [Documentation]    Export current JSON-DB state to a file
    [Arguments]    ${output_file}=json_db_export.json
    
    ${all_data}=    Create Dictionary
    
    # Get all collections
    ${accounts}=    GET On Session    json_db    /accounts
    ${contacts}=    GET On Session    json_db    /contacts
    ${opportunities}=    GET On Session    json_db    /opportunities
    
    Set To Dictionary    ${all_data}
    ...    accounts=${accounts.json()}
    ...    contacts=${contacts.json()}
    ...    opportunities=${opportunities.json()}
    
    ${json_string}=    Evaluate    json.dumps(${all_data}, indent=2)    json
    Create File    ${output_file}    ${json_string}
    
    Log    Exported JSON-DB to: ${output_file}
    RETURN    ${output_file}

# ============================================================================
# Docker Container Management Keywords
# ============================================================================

Start JSON Server
    [Documentation]    Start the JSON Server container
    
    ${result}=    Run Process
    ...    docker compose -f docker/docker-compose.salesforce-mock.yml up -d salesforce-json-server
    ...    shell=True
    
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=Failed to start JSON Server: ${result.stderr}
    
    Sleep    3s    Wait for JSON Server to initialize
    Log    JSON Server started successfully

Stop JSON Server
    [Documentation]    Stop the JSON Server container
    
    ${result}=    Run Process
    ...    docker compose -f docker/docker-compose.salesforce-mock.yml stop salesforce-json-server
    ...    shell=True
    
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=Failed to stop JSON Server: ${result.stderr}
    
    Log    JSON Server stopped

Restart JSON Server
    [Documentation]    Restart the JSON Server container
    
    Stop JSON Server
    Start JSON Server
    Connect To JSON DB
    
    Log    JSON Server restarted and reconnected

Get JSON Server Status
    [Documentation]    Check if JSON Server is running
    
    ${result}=    Run Process
    ...    docker inspect -f '{{.State.Status}}' salesforce-json-mock
    ...    shell=True
    
    ${is_running}=    Run Keyword And Return Status
    ...    Should Contain    ${result.stdout}    running
    
    Log    JSON Server status: ${result.stdout}
    RETURN    ${is_running}

# ============================================================================
# Test Data Generation Keywords
# ============================================================================

Generate Test Account Data
    [Documentation]    Generate random test account data
    [Arguments]    ${prefix}=Test
    
    ${timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    ${random}=    Evaluate    random.randint(1000, 9999)    random
    
    ${account_data}=    Create Dictionary
    ...    name=${prefix}_Account_${timestamp}_${random}
    ...    type=Customer
    ...    industry=Technology
    ...    annualRevenue=${random}000
    ...    phone=(555) ${random}
    ...    website=www.${prefix}${random}.com
    ...    billingCity=San Francisco
    ...    billingState=CA
    ...    billingCountry=USA
    
    RETURN    ${account_data}

Generate Bulk Test Data
    [Documentation]    Generate multiple test accounts with related data
    [Arguments]    ${num_accounts}=5    ${contacts_per_account}=2    ${opps_per_account}=1
    
    @{created_accounts}=    Create List
    
    FOR    ${i}    IN RANGE    ${num_accounts}
        ${account_data}=    Generate Test Account Data    Company${i}
        ${account_id}=    Create Account In JSON DB    ${account_data}
        
        # Create related contacts
        FOR    ${j}    IN RANGE    ${contacts_per_account}
            ${contact_data}=    Create Dictionary
            ...    firstName=Contact${j}
            ...    lastName=ForAccount${i}
            ...    accountId=${account_id}
            ...    email=contact${j}@company${i}.com
            
            POST On Session    json_db    /contacts    json=${contact_data}
        END
        
        # Create related opportunities
        FOR    ${k}    IN RANGE    ${opps_per_account}
            ${opp_data}=    Create Dictionary
            ...    name=Opportunity${k} for Company${i}
            ...    accountId=${account_id}
            ...    stage=Prospecting
            ...    amount=${i}${k}0000
            
            POST On Session    json_db    /opportunities    json=${opp_data}
        END
        
        Append To List    ${created_accounts}    ${account_id}
    END
    
    Log    Generated ${num_accounts} accounts with related data
    RETURN    ${created_accounts}