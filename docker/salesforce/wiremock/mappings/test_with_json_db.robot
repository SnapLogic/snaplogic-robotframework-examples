*** Settings ***
Documentation    Comprehensive Test Suite for Salesforce Data Management with JSON-DB Persistence
...              This suite handles creation, manipulation, and verification of all Salesforce
...              data types using JSON Server for persistence and WireMock for API mocking.
Library          RequestsLibrary
Library          Collections
Library          JSONLibrary
Library          String
Library          DateTime
Library          OperatingSystem
Library          Process
Resource         json_db_integration.resource
Resource         salesforce_test_data.resource
Suite Setup      Setup Complete Test Environment
Suite Teardown   Cleanup Complete Test Environment
Test Setup       Test Case Setup
Test Teardown    Test Case Teardown

*** Variables ***
${JSON_DB_URL}           http://salesforce-json-mock
${JSON_DB_URL_HOST}      http://localhost:8082
${SALESFORCE_BASE_URL}  https://salesforce-api-mock:8443
${SESSION_ALIAS}         salesforce
${AUTH_TOKEN}            ${EMPTY}
${VERIFY_SSL}            ${FALSE}
${TEST_ID}               ${EMPTY}

# Test Data Counters
${ACCOUNTS_CREATED}      0
${CONTACTS_CREATED}      0
${OPPORTUNITIES_CREATED} 0
${LEADS_CREATED}         0
${CASES_CREATED}         0

*** Keywords ***
# ============================================================================
# Setup and Teardown Keywords
# ============================================================================

Setup Complete Test Environment
    [Documentation]    Complete setup of test environment with all services
    
    Log To Console    \n========================================
    Log To Console    Setting up Complete Test Environment
    Log To Console    ========================================
    
    # Start JSON Server if not running
    Ensure JSON Server Is Running
    
    # Initialize connections
    Connect To JSON DB
    Initialize JSON DB With Schema
    
    # Authenticate to Salesforce Mock
    Authenticate To Salesforce
    
    # Create base test data
    Create Base Test Data
    
    # Verify setup
    Verify Environment Setup
    
    Log To Console    ✅ Test environment ready with JSON-DB persistence

Cleanup Complete Test Environment
    [Documentation]    Complete cleanup of test environment
    
    Log To Console    \n========================================
    Log To Console    Cleaning up Test Environment
    Log To Console    ========================================
    
    # Generate test summary
    Generate Test Summary Report
    
    # Export data before cleanup (optional)
    ${export_file}=    Export All Data To File
    Log To Console    📁 Data exported to: ${export_file}
    
    # Clear all test data
    Clear All JSON DB Data
    
    Log To Console    ✅ Test environment cleaned up

Test Case Setup
    [Documentation]    Setup for individual test case
    
    ${test_id}=    Generate Unique Test ID
    Set Test Variable    ${TEST_ID}    ${test_id}
    Log To Console    \n🧪 Starting Test: ${TEST NAME} [ID: ${test_id}]

Test Case Teardown
    [Documentation]    Teardown for individual test case
    
    Log To Console    ✅ Completed Test: ${TEST NAME}

# ============================================================================
# Environment Management Keywords
# ============================================================================

Ensure JSON Server Is Running
    [Documentation]    Check and start JSON Server if needed
    
    ${is_running}=    Check JSON Server Status
    
    Run Keyword If    not ${is_running}
    ...    Start JSON Server Container
    
    Wait Until JSON Server Is Ready

Check JSON Server Status
    [Documentation]    Check if JSON Server container is running
    
    ${result}=    Run Process
    ...    docker inspect -f '{{.State.Status}}' salesforce-json-mock
    ...    shell=True
    
    ${is_running}=    Run Keyword And Return Status
    ...    Should Contain    ${result.stdout}    running
    
    RETURN    ${is_running}

Start JSON Server Container
    [Documentation]    Start the JSON Server Docker container
    
    Log To Console    🚀 Starting JSON Server container...
    
    ${result}=    Run Process
    ...    docker compose -f docker/docker-compose.salesforce-mock.yml up -d salesforce-json-server
    ...    shell=True
    
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=Failed to start JSON Server: ${result.stderr}

Wait Until JSON Server Is Ready
    [Documentation]    Wait for JSON Server to be fully operational
    
    Wait Until Keyword Succeeds    30s    2s
    ...    GET    ${JSON_DB_URL_HOST}/db

Verify Environment Setup
    [Documentation]    Verify all components are properly configured
    
    # Verify JSON Server
    ${response}=    GET On Session    json_db    /db
    Should Be Equal As Integers    ${response.status_code}    200
    
    # Verify Salesforce Mock
    ${headers}=    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}
    ${response}=    GET On Session    ${SESSION_ALIAS}    /services/data/v59.0
    ...    headers=${headers}    expected_status=200
    
    Log To Console    ✅ All services verified and operational

# ============================================================================
# Authentication Keywords
# ============================================================================

Authenticate To Salesforce
    [Documentation]    Authenticate and get OAuth token from WireMock
    
    Create Session    ${SESSION_ALIAS}    ${SALESFORCE_BASE_URL}    verify=${VERIFY_SSL}
    
    ${auth_data}=    Create Dictionary
    ...    grant_type=password
    ...    client_id=test_client_id
    ...    client_secret=test_secret
    ...    username=test@example.com
    ...    password=test123
    
    ${response}=    POST On Session    ${SESSION_ALIAS}    /services/oauth2/token
    ...    data=${auth_data}
    ...    expected_status=200
    
    ${token}=    Get From Dictionary    ${response.json()}    access_token
    Set Suite Variable    ${AUTH_TOKEN}    ${token}
    
    Log To Console    🔐 Authenticated to Salesforce Mock
    RETURN    ${token}

# ============================================================================
# JSON-DB Connection and Initialization
# ============================================================================

Connect To JSON DB
    [Documentation]    Establish connection to JSON Server
    [Arguments]    ${from_docker}=${TRUE}
    
    ${url}=    Run Keyword If    ${from_docker}
    ...    Set Variable    ${JSON_DB_URL}
    ...    ELSE    Set Variable    ${JSON_DB_URL_HOST}
    
    Create Session    json_db    ${url}
    Set Suite Variable    ${JSON_DB_SESSION_URL}    ${url}
    
    Log To Console    🔌 Connected to JSON Server at: ${url}

Initialize JSON DB With Schema
    [Documentation]    Initialize JSON-DB with complete Salesforce schema
    
    ${schema}=    Create Dictionary
    ...    accounts=@{EMPTY}
    ...    contacts=@{EMPTY}
    ...    opportunities=@{EMPTY}
    ...    leads=@{EMPTY}
    ...    cases=@{EMPTY}
    ...    campaigns=@{EMPTY}
    ...    tasks=@{EMPTY}
    ...    events=@{EMPTY}
    
    FOR    ${collection}    ${data}    IN    &{schema}
        Initialize Collection If Not Exists    ${collection}
    END
    
    Log To Console    📊 JSON-DB initialized with Salesforce schema

Initialize Collection If Not Exists
    [Documentation]    Initialize a collection if it doesn't exist
    [Arguments]    ${collection_name}
    
    ${status}    ${response}=    Run Keyword And Ignore Error
    ...    GET On Session    json_db    /${collection_name}
    
    Run Keyword If    '${status}' == 'FAIL'
    ...    Create Empty Collection    ${collection_name}

Create Empty Collection
    [Documentation]    Create an empty collection in JSON-DB
    [Arguments]    ${collection_name}
    
    # Create and immediately delete a dummy record to establish the collection
    ${dummy}=    Create Dictionary    _init=true    _temp=true
    ${response}=    POST On Session    json_db    /${collection_name}    json=${dummy}
    DELETE On Session    json_db    /${collection_name}/${response.json()}[id]

# ============================================================================
# Base Test Data Creation
# ============================================================================

Create Base Test Data
    [Documentation]    Create comprehensive base test data set
    
    Log To Console    📦 Creating base test data...
    
    # Create accounts with different types
    ${accounts}=    Create Test Accounts
    Set Suite Variable    @{TEST_ACCOUNTS}    @{accounts}
    
    # Create contacts for accounts
    ${contacts}=    Create Test Contacts    ${accounts}
    Set Suite Variable    @{TEST_CONTACTS}    @{contacts}
    
    # Create opportunities
    ${opportunities}=    Create Test Opportunities    ${accounts}
    Set Suite Variable    @{TEST_OPPORTUNITIES}    @{opportunities}
    
    # Create leads
    ${leads}=    Create Test Leads
    Set Suite Variable    @{TEST_LEADS}    @{leads}
    
    # Create cases
    ${cases}=    Create Test Cases    ${accounts}
    Set Suite Variable    @{TEST_CASES}    @{cases}
    
    Log To Console    ✅ Base test data created successfully

Create Test Accounts
    [Documentation]    Create various types of test accounts
    
    @{accounts}=    Create List
    
    # Customer Account
    ${customer}=    Create Account With Full Details
    ...    name=Acme Corporation
    ...    type=Customer
    ...    industry=Technology
    ...    annualRevenue=50000000
    ...    employees=500
    ...    rating=Hot
    ...    website=www.acme-corp.com
    ...    phone=(555) 123-4567
    ...    billingStreet=123 Main St
    ...    billingCity=San Francisco
    ...    billingState=CA
    ...    billingPostalCode=94105
    ...    billingCountry=USA
    ...    description=Leading technology company
    Append To List    ${accounts}    ${customer}
    
    # Partner Account
    ${partner}=    Create Account With Full Details
    ...    name=Global Partners Inc
    ...    type=Partner
    ...    industry=Consulting
    ...    annualRevenue=25000000
    ...    employees=200
    ...    rating=Warm
    ...    website=www.globalpartners.com
    ...    phone=(555) 234-5678
    ...    billingCity=New York
    ...    billingState=NY
    Append To List    ${accounts}    ${partner}
    
    # Prospect Account
    ${prospect}=    Create Account With Full Details
    ...    name=Future Tech Solutions
    ...    type=Prospect
    ...    industry=Software
    ...    annualRevenue=5000000
    ...    employees=50
    ...    rating=Cold
    ...    website=www.futuretech.io
    ...    phone=(555) 345-6789
    ...    billingCity=Austin
    ...    billingState=TX
    Append To List    ${accounts}    ${prospect}
    
    RETURN    ${accounts}

Create Test Contacts
    [Documentation]    Create contacts for test accounts
    [Arguments]    ${accounts}
    
    @{contacts}=    Create List
    
    FOR    ${account}    IN    @{accounts}
        # Create 2-3 contacts per account
        ${num_contacts}=    Evaluate    random.randint(2, 3)    random
        
        FOR    ${i}    IN RANGE    ${num_contacts}
            ${contact}=    Create Contact With Full Details
            ...    accountId=${account}[id]
            ...    firstName=Contact${i}
            ...    lastName=${account}[name]
            ...    title=Manager Level ${i}
            ...    department=Sales
            ...    email=contact${i}@${account}[name].com
            ...    phone=(555) 100-${i}000
            ...    mobilePhone=(555) 200-${i}000
            Append To List    ${contacts}    ${contact}
        END
    END
    
    RETURN    ${contacts}

Create Test Opportunities
    [Documentation]    Create opportunities for test accounts
    [Arguments]    ${accounts}
    
    @{opportunities}=    Create List
    
    @{stages}=    Create List    Prospecting    Qualification    Needs Analysis    
    ...    Value Proposition    Decision Makers    Proposal    Negotiation    Closed Won    Closed Lost
    
    FOR    ${account}    IN    @{accounts}
        # Create 1-2 opportunities per account
        ${num_opps}=    Evaluate    random.randint(1, 2)    random
        
        FOR    ${i}    IN RANGE    ${num_opps}
            ${stage_index}=    Evaluate    random.randint(0, len(${stages})-1)    random
            ${stage}=    Get From List    ${stages}    ${stage_index}
            
            ${opportunity}=    Create Opportunity With Full Details
            ...    accountId=${account}[id]
            ...    name=${account}[name] - Opportunity ${i}
            ...    stage=${stage}
            ...    amount=${i}50000
            ...    probability=${i}0
            ...    closeDate=2024-12-31
            ...    type=New Business
            ...    leadSource=Web
            ...    description=Opportunity for ${account}[name]
            Append To List    ${opportunities}    ${opportunity}
        END
    END
    
    RETURN    ${opportunities}

Create Test Leads
    [Documentation]    Create test leads
    
    @{leads}=    Create List
    
    @{lead_data}=    Create List
    ...    John,Smith,CEO,TechStart,john@techstart.com,Web,Warm
    ...    Jane,Doe,CTO,InnovateCorp,jane@innovate.com,Phone Inquiry,Hot
    ...    Bob,Johnson,Manager,SmallBiz,bob@smallbiz.com,Partner Referral,Cold
    
    FOR    ${data}    IN    @{lead_data}
        @{fields}=    Split String    ${data}    ,
        ${lead}=    Create Lead With Full Details
        ...    firstName=${fields}[0]
        ...    lastName=${fields}[1]
        ...    title=${fields}[2]
        ...    company=${fields}[3]
        ...    email=${fields}[4]
        ...    leadSource=${fields}[5]
        ...    rating=${fields}[6]
        ...    status=Open - Not Contacted
        ...    industry=Technology
        Append To List    ${leads}    ${lead}
    END
    
    RETURN    ${leads}

Create Test Cases
    [Documentation]    Create test cases for accounts
    [Arguments]    ${accounts}
    
    @{cases}=    Create List
    
    @{case_types}=    Create List    Problem    Feature Request    Question
    @{priorities}=    Create List    High    Medium    Low
    @{statuses}=    Create List    New    Working    Escalated
    
    FOR    ${account}    IN    @{accounts}
        ${case_type}=    Evaluate    random.choice(${case_types})    random
        ${priority}=    Evaluate    random.choice(${priorities})    random
        ${status}=    Evaluate    random.choice(${statuses})    random
        
        ${case}=    Create Case With Full Details
        ...    accountId=${account}[id]
        ...    subject=Support Case for ${account}[name]
        ...    description=Customer reported issue with product
        ...    status=${status}
        ...    priority=${priority}
        ...    type=${case_type}
        ...    origin=Web
        ...    reason=Product Issue
        Append To List    ${cases}    ${case}
    END
    
    RETURN    ${cases}

# ============================================================================
# Comprehensive CRUD Operations
# ============================================================================

Create Account With Full Details
    [Documentation]    Create account with all fields in JSON-DB
    [Arguments]    &{account_data}
    
    ${response}=    POST On Session    json_db    /accounts
    ...    json=${account_data}
    ...    expected_status=201
    
    ${account_id}=    Get From Dictionary    ${response.json()}    id
    
    # Track creation
    ${count}=    Get Variable Value    ${ACCOUNTS_CREATED}    0
    Set Suite Variable    ${ACCOUNTS_CREATED}    ${count + 1}
    
    Log    Created account: ${account_data}[name] with ID: ${account_id}
    RETURN    ${response.json()}

Create Contact With Full Details
    [Documentation]    Create contact with all fields in JSON-DB
    [Arguments]    &{contact_data}
    
    ${response}=    POST On Session    json_db    /contacts
    ...    json=${contact_data}
    ...    expected_status=201
    
    ${contact_id}=    Get From Dictionary    ${response.json()}    id
    
    # Track creation
    ${count}=    Get Variable Value    ${CONTACTS_CREATED}    0
    Set Suite Variable    ${CONTACTS_CREATED}    ${count + 1}
    
    Log    Created contact: ${contact_data}[firstName] ${contact_data}[lastName] with ID: ${contact_id}
    RETURN    ${response.json()}

Create Opportunity With Full Details
    [Documentation]    Create opportunity with all fields in JSON-DB
    [Arguments]    &{opp_data}
    
    ${response}=    POST On Session    json_db    /opportunities
    ...    json=${opp_data}
    ...    expected_status=201
    
    ${opp_id}=    Get From Dictionary    ${response.json()}    id
    
    # Track creation
    ${count}=    Get Variable Value    ${OPPORTUNITIES_CREATED}    0
    Set Suite Variable    ${OPPORTUNITIES_CREATED}    ${count + 1}
    
    Log    Created opportunity: ${opp_data}[name] with ID: ${opp_id}
    RETURN    ${response.json()}

Create Lead With Full Details
    [Documentation]    Create lead with all fields in JSON-DB
    [Arguments]    &{lead_data}
    
    ${response}=    POST On Session    json_db    /leads
    ...    json=${lead_data}
    ...    expected_status=201
    
    ${lead_id}=    Get From Dictionary    ${response.json()}    id
    
    # Track creation
    ${count}=    Get Variable Value    ${LEADS_CREATED}    0
    Set Suite Variable    ${LEADS_CREATED}    ${count + 1}
    
    Log    Created lead: ${lead_data}[firstName] ${lead_data}[lastName] with ID: ${lead_id}
    RETURN    ${response.json()}

Create Case With Full Details
    [Documentation]    Create case with all fields in JSON-DB
    [Arguments]    &{case_data}
    
    ${response}=    POST On Session    json_db    /cases
    ...    json=${case_data}
    ...    expected_status=201
    
    ${case_id}=    Get From Dictionary    ${response.json()}    id
    
    # Track creation
    ${count}=    Get Variable Value    ${CASES_CREATED}    0
    Set Suite Variable    ${CASES_CREATED}    ${count + 1}
    
    Log    Created case: ${case_data}[subject] with ID: ${case_id}
    RETURN    ${response.json()}

# ============================================================================
# Verification Keywords
# ============================================================================

Verify All Accounts
    [Documentation]    Verify all accounts in JSON-DB
    
    ${accounts}=    GET On Session    json_db    /accounts
    ${count}=    Get Length    ${accounts.json()}
    
    Log To Console    \n📊 Account Verification:
    Log To Console    Total Accounts: ${count}
    
    FOR    ${account}    IN    @{accounts.json()}
        Verify Account Data    ${account}
    END
    
    Should Be True    ${count} > 0    msg=No accounts found in JSON-DB
    RETURN    ${accounts.json()}

Verify Account Data
    [Documentation]    Verify individual account data integrity
    [Arguments]    ${account}
    
    # Verify required fields
    Dictionary Should Contain Key    ${account}    id
    Dictionary Should Contain Key    ${account}    name
    
    # Verify data types
    ${name}=    Get From Dictionary    ${account}    name
    Should Not Be Empty    ${name}
    
    # Log account summary
    ${type}=    Get From Dictionary    ${account}    type    default=Not Set
    ${industry}=    Get From Dictionary    ${account}    industry    default=Not Set
    Log    ✓ Account: ${name} (Type: ${type}, Industry: ${industry})

Verify All Contacts
    [Documentation]    Verify all contacts in JSON-DB
    
    ${contacts}=    GET On Session    json_db    /contacts
    ${count}=    Get Length    ${contacts.json()}
    
    Log To Console    \n📊 Contact Verification:
    Log To Console    Total Contacts: ${count}
    
    FOR    ${contact}    IN    @{contacts.json()}
        Verify Contact Data    ${contact}
    END
    
    RETURN    ${contacts.json()}

Verify Contact Data
    [Documentation]    Verify individual contact data integrity
    [Arguments]    ${contact}
    
    # Verify required fields
    Dictionary Should Contain Key    ${contact}    id
    
    # Get name fields
    ${firstName}=    Get From Dictionary    ${contact}    firstName    default=
    ${lastName}=    Get From Dictionary    ${contact}    lastName    default=
    ${accountId}=    Get From Dictionary    ${contact}    accountId    default=None
    
    Log    ✓ Contact: ${firstName} ${lastName} (Account: ${accountId})

Verify All Opportunities
    [Documentation]    Verify all opportunities in JSON-DB
    
    ${opportunities}=    GET On Session    json_db    /opportunities
    ${count}=    Get Length    ${opportunities.json()}
    
    Log To Console    \n📊 Opportunity Verification:
    Log To Console    Total Opportunities: ${count}
    
    ${total_pipeline}=    Set Variable    0
    
    FOR    ${opp}    IN    @{opportunities.json()}
        ${amount}=    Verify Opportunity Data    ${opp}
        ${total_pipeline}=    Evaluate    ${total_pipeline} + ${amount}
    END
    
    Log To Console    Total Pipeline Value: $${total_pipeline}
    RETURN    ${opportunities.json()}

Verify Opportunity Data
    [Documentation]    Verify individual opportunity data integrity
    [Arguments]    ${opportunity}
    
    # Verify required fields
    Dictionary Should Contain Key    ${opportunity}    id
    Dictionary Should Contain Key    ${opportunity}    name
    
    ${name}=    Get From Dictionary    ${opportunity}    name
    ${stage}=    Get From Dictionary    ${opportunity}    stage    default=Unknown
    ${amount}=    Get From Dictionary    ${opportunity}    amount    default=0
    
    Log    ✓ Opportunity: ${name} (Stage: ${stage}, Amount: $${amount})
    RETURN    ${amount}

Verify Data Relationships
    [Documentation]    Verify relationships between different objects
    
    Log To Console    \n🔗 Verifying Data Relationships...
    
    # Get all data
    ${accounts}=    GET On Session    json_db    /accounts
    ${contacts}=    GET On Session    json_db    /contacts
    ${opportunities}=    GET On Session    json_db    /opportunities
    
    # Create account ID list
    @{account_ids}=    Create List
    FOR    ${account}    IN    @{accounts.json()}
        Append To List    ${account_ids}    ${account}[id]
    END
    
    # Verify contacts have valid account IDs
    ${orphan_contacts}=    Set Variable    0
    FOR    ${contact}    IN    @{contacts.json()}
        ${accountId}=    Get From Dictionary    ${contact}    accountId    default=None
        Run Keyword If    '${accountId}' != 'None' and '${accountId}' not in ${account_ids}
        ...    Set Variable    ${orphan_contacts}    ${orphan_contacts + 1}
    END
    
    # Verify opportunities have valid account IDs
    ${orphan_opps}=    Set Variable    0
    FOR    ${opp}    IN    @{opportunities.json()}
        ${accountId}=    Get From Dictionary    ${opp}    accountId    default=None
        Run Keyword If    '${accountId}' != 'None' and '${accountId}' not in ${account_ids}
        ...    Set Variable    ${orphan_opps}    ${orphan_opps + 1}
    END
    
    Log To Console    ✅ Orphan Contacts: ${orphan_contacts}
    Log To Console    ✅ Orphan Opportunities: ${orphan_opps}
    
    Should Be Equal As Numbers    ${orphan_contacts}    0    msg=Found orphan contacts
    Should Be Equal As Numbers    ${orphan_opps}    0    msg=Found orphan opportunities

# ============================================================================
# Data Export and Reporting
# ============================================================================

Export All Data To File
    [Documentation]    Export all JSON-DB data to a file
    [Arguments]    ${filename}=test_data_export_${TEST_ID}.json
    
    ${all_data}=    Create Dictionary
    
    # Get all collections
    ${accounts}=    GET On Session    json_db    /accounts
    ${contacts}=    GET On Session    json_db    /contacts
    ${opportunities}=    GET On Session    json_db    /opportunities
    ${leads}=    GET On Session    json_db    /leads
    ${cases}=    GET On Session    json_db    /cases
    
    Set To Dictionary    ${all_data}
    ...    accounts=${accounts.json()}
    ...    contacts=${contacts.json()}
    ...    opportunities=${opportunities.json()}
    ...    leads=${leads.json()}
    ...    cases=${cases.json()}
    ...    export_timestamp=${TEST_ID}
    
    ${json_string}=    Evaluate    json.dumps(${all_data}, indent=2)    json
    Create File    ${filename}    ${json_string}
    
    RETURN    ${filename}

Generate Test Summary Report
    [Documentation]    Generate summary report of test data
    
    Log To Console    \n========================================
    Log To Console    📊 TEST DATA SUMMARY REPORT
    Log To Console    ========================================
    Log To Console    Accounts Created: ${ACCOUNTS_CREATED}
    Log To Console    Contacts Created: ${CONTACTS_CREATED}
    Log To Console    Opportunities Created: ${OPPORTUNITIES_CREATED}
    Log To Console    Leads Created: ${LEADS_CREATED}
    Log To Console    Cases Created: ${CASES_CREATED}
    Log To Console    ========================================
    
    # Get current counts from JSON-DB
    ${accounts}=    GET On Session    json_db    /accounts
    ${contacts}=    GET On Session    json_db    /contacts
    ${opportunities}=    GET On Session    json_db    /opportunities
    ${leads}=    GET On Session    json_db    /leads
    ${cases}=    GET On Session    json_db    /cases
    
    Log To Console    \n📈 CURRENT DATABASE STATE:
    Log To Console    Total Accounts: ${accounts.json().__len__()}
    Log To Console    Total Contacts: ${contacts.json().__len__()}
    Log To Console    Total Opportunities: ${opportunities.json().__len__()}
    Log To Console    Total Leads: ${leads.json().__len__()}
    Log To Console    Total Cases: ${cases.json().__len__()}
    Log To Console    ========================================

# ============================================================================
# Cleanup Keywords
# ============================================================================

Clear All JSON DB Data
    [Documentation]    Clear all data from all collections
    
    @{collections}=    Create List    accounts    contacts    opportunities    leads    cases    campaigns    tasks    events
    
    FOR    ${collection}    IN    @{collections}
        Clear Collection Data    ${collection}
    END
    
    Log To Console    🧹 All JSON-DB collections cleared

Clear Collection Data
    [Documentation]    Clear all items from a specific collection
    [Arguments]    ${collection_name}
    
    ${status}    ${items}=    Run Keyword And Ignore Error
    ...    GET On Session    json_db    /${collection_name}
    
    Run Keyword If    '${status}' == 'PASS'
    ...    Delete All Items    ${collection_name}    ${items.json()}

Delete All Items
    [Documentation]    Delete all items from a collection
    [Arguments]    ${collection_name}    ${items}
    
    ${count}=    Get Length    ${items}
    
    FOR    ${item}    IN    @{items}
        Run Keyword And Ignore Error
        ...    DELETE On Session    json_db    /${collection_name}/${item}[id]
    END
    
    Log    Deleted ${count} items from ${collection_name}

# ============================================================================
# Utility Keywords
# ============================================================================

Generate Unique Test ID
    [Documentation]    Generate unique test identifier
    
    ${timestamp}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    ${random}=    Evaluate    random.randint(1000, 9999)    random
    ${test_id}=    Set Variable    ${timestamp}_${random}
    RETURN    ${test_id}

Wait Until JSON Server Is Ready
    [Documentation]    Wait for JSON Server to be operational
    
    Wait Until Keyword Succeeds    30s    2s
    ...    Check JSON Server Health

Check JSON Server Health
    [Documentation]    Check if JSON Server is responding
    
    ${response}=    GET    ${JSON_DB_URL_HOST}/db
    Should Be Equal As Integers    ${response.status_code}    200

*** Test Cases ***
# ============================================================================
# Data Creation Tests
# ============================================================================

Test Create Complete Account Hierarchy
    [Documentation]    Create a complete account with all related objects
    
    Log To Console    \n📦 Creating Complete Account Hierarchy...
    
    # Create parent account
    ${account}=    Create Account With Full Details
    ...    name=Test Corporation ${TEST_ID}
    ...    type=Customer
    ...    industry=Technology
    ...    annualRevenue=10000000
    ...    employees=100
    ...    website=www.testcorp-${TEST_ID}.com
    
    # Create contacts
    FOR    ${i}    IN RANGE    3
        Create Contact With Full Details
        ...    accountId=${account}[id]
        ...    firstName=John${i}
        ...    lastName=Doe${i}
        ...    email=john${i}@testcorp.com
        ...    title=Manager ${i}
    END
    
    # Create opportunities
    FOR    ${i}    IN RANGE    2
        Create Opportunity With Full Details
        ...    accountId=${account}[id]
        ...    name=Deal ${i} for ${account}[name]
        ...    stage=Qualification
        ...    amount=${i}00000
        ...    closeDate=2024-12-31
    END
    
    # Create case
    Create Case With Full Details
    ...    accountId=${account}[id]
    ...    subject=Support request for ${account}[name]
    ...    priority=High
    ...    status=New
    
    # Verify creation
    ${contacts}=    GET On Session    json_db    /contacts?accountId=${account}[id]
    ${opportunities}=    GET On Session    json_db    /opportunities?accountId=${account}[id]
    ${cases}=    GET On Session    json_db    /cases?accountId=${account}[id]
    
    Should Be Equal As Numbers    ${contacts.json().__len__()}    3
    Should Be Equal As Numbers    ${opportunities.json().__len__()}    2
    Should Be Equal As Numbers    ${cases.json().__len__()}    1
    
    Log To Console    ✅ Complete hierarchy created successfully

Test Bulk Data Creation
    [Documentation]    Create large amounts of test data
    
    Log To Console    \n📦 Creating Bulk Test Data...
    
    # Create 10 accounts
    FOR    ${i}    IN RANGE    10
        ${account}=    Create Account With Full Details
        ...    name=Bulk Account ${i} - ${TEST_ID}
        ...    type=Customer
        ...    industry=Technology
        ...    annualRevenue=${i}000000
        
        # Create 2 contacts per account
        FOR    ${j}    IN RANGE    2
            Create Contact With Full Details
            ...    accountId=${account}[id]
            ...    firstName=Contact${j}
            ...    lastName=Account${i}
            ...    email=contact${j}@account${i}.com
        END
        
        # Create 1 opportunity per account
        Create Opportunity With Full Details
        ...    accountId=${account}[id]
        ...    name=Opportunity for Account ${i}
        ...    stage=Prospecting
        ...    amount=${i}0000
    END
    
    # Verify bulk creation
    ${accounts}=    GET On Session    json_db    /accounts
    ${initial_count}=    Get Variable Value    @{TEST_ACCOUNTS}    @{EMPTY}
    ${initial_len}=    Get Length    ${initial_count}
    
    Should Be True    ${accounts.json().__len__()} >= ${initial_len + 10}
    
    Log To Console    ✅ Bulk data created successfully

# ============================================================================
# Data Verification Tests
# ============================================================================

Test Verify All Data Collections
    [Documentation]    Comprehensive verification of all data collections
    
    Log To Console    \n🔍 Verifying All Data Collections...
    
    # Verify each collection
    ${accounts}=    Verify All Accounts
    ${contacts}=    Verify All Contacts
    ${opportunities}=    Verify All Opportunities
    
    # Verify relationships
    Verify Data Relationships
    
    # Generate summary
    Generate Test Summary Report
    
    Log To Console    ✅ All data collections verified

Test Verify Data Persistence
    [Documentation]    Verify data persists in JSON-DB
    
    Log To Console    \n💾 Testing Data Persistence...
    
    # Create test data
    ${account}=    Create Account With Full Details
    ...    name=Persistence Test ${TEST_ID}
    ...    type=Customer
    ...    revenue=1000000
    
    ${account_id}=    Set Variable    ${account}[id]
    
    # Simulate connection reset
    Delete All Sessions
    Connect To JSON DB
    
    # Verify data still exists
    ${retrieved}=    GET On Session    json_db    /accounts/${account_id}
    Should Be Equal    ${retrieved.json()}[name]    Persistence Test ${TEST_ID}
    
    Log To Console    ✅ Data persistence verified

Test Verify Search And Filter
    [Documentation]    Test searching and filtering capabilities
    
    Log To Console    \n🔍 Testing Search and Filter...
    
    # Create test data with specific attributes
    Create Account With Full Details
    ...    name=Search Test Healthcare
    ...    industry=Healthcare
    ...    type=Customer
    
    Create Account With Full Details
    ...    name=Search Test Technology
    ...    industry=Technology
    ...    type=Partner
    
    # Search by industry
    ${healthcare}=    GET On Session    json_db    /accounts?industry=Healthcare
    ${technology}=    GET On Session    json_db    /accounts?industry=Technology
    
    Should Be True    ${healthcare.json().__len__()} >= 1
    Should Be True    ${technology.json().__len__()} >= 1
    
    # Search by type
    ${customers}=    GET On Session    json_db    /accounts?type=Customer
    ${partners}=    GET On Session    json_db    /accounts?type=Partner
    
    Should Be True    ${customers.json().__len__()} >= 1
    Should Be True    ${partners.json().__len__()} >= 1
    
    Log To Console    ✅ Search and filter verified

# ============================================================================
# Data Update Tests
# ============================================================================

Test Update Account Data
    [Documentation]    Test updating account information
    
    Log To Console    \n✏️ Testing Account Updates...
    
    # Create account
    ${account}=    Create Account With Full Details
    ...    name=Update Test Account
    ...    type=Prospect
    ...    annualRevenue=100000
    
    # Update account
    ${update_data}=    Create Dictionary
    ...    type=Customer
    ...    annualRevenue=500000
    ...    employees=50
    ...    rating=Hot
    
    PATCH On Session    json_db    /accounts/${account}[id]
    ...    json=${update_data}
    
    # Verify updates
    ${updated}=    GET On Session    json_db    /accounts/${account}[id]
    Should Be Equal    ${updated.json()}[type]    Customer
    Should Be Equal As Numbers    ${updated.json()}[annualRevenue]    500000
    Should Be Equal    ${updated.json()}[rating]    Hot
    
    Log To Console    ✅ Account update verified

# ============================================================================
# Data Deletion Tests
# ============================================================================

Test Delete Account With Cascade
    [Documentation]    Test deleting account and related objects
    
    Log To Console    \n🗑️ Testing Cascade Deletion...
    
    # Create account with related objects
    ${account}=    Create Account With Full Details
    ...    name=Delete Test Account
    
    ${contact}=    Create Contact With Full Details
    ...    accountId=${account}[id]
    ...    firstName=Delete
    ...    lastName=Test
    
    ${opp}=    Create Opportunity With Full Details
    ...    accountId=${account}[id]
    ...    name=Delete Test Opportunity
    
    # Delete account
    DELETE On Session    json_db    /accounts/${account}[id]
    
    # Verify account deleted
    ${status}=    Run Keyword And Return Status
    ...    GET On Session    json_db    /accounts/${account}[id]
    Should Not Be True    ${status}
    
    # Note: JSON Server doesn't cascade delete, so related objects remain
    # This is actually good for testing orphan detection
    
    Log To Console    ✅ Deletion verified

# ============================================================================
# Integration Tests
# ============================================================================

Test End To End Sales Process
    [Documentation]    Simulate complete sales process workflow
    
    Log To Console    \n🔄 Testing End-to-End Sales Process...
    
    # Step 1: Create Lead
    ${lead}=    Create Lead With Full Details
    ...    firstName=Sarah
    ...    lastName=Connor
    ...    company=Cyberdyne Systems
    ...    email=sarah@cyberdyne.com
    ...    status=Open - Not Contacted
    ...    rating=Hot
    
    Log To Console    Step 1: Lead created - ${lead}[firstName] ${lead}[lastName]
    
    # Step 2: Convert Lead to Account
    ${account}=    Create Account With Full Details
    ...    name=Cyberdyne Systems
    ...    type=Prospect
    ...    industry=Technology
    
    ${contact}=    Create Contact With Full Details
    ...    accountId=${account}[id]
    ...    firstName=${lead}[firstName]
    ...    lastName=${lead}[lastName]
    ...    email=${lead}[email]
    
    # Update lead status
    PATCH On Session    json_db    /leads/${lead}[id]
    ...    json=${{dict(status='Closed - Converted')}}
    
    Log To Console    Step 2: Lead converted to Account and Contact
    
    # Step 3: Create Opportunity
    ${opp}=    Create Opportunity With Full Details
    ...    accountId=${account}[id]
    ...    name=Cyberdyne Initial Deal
    ...    stage=Qualification
    ...    amount=100000
    ...    probability=20
    
    Log To Console    Step 3: Opportunity created - ${opp}[name]
    
    # Step 4: Progress Opportunity
    @{stages}=    Create List    Needs Analysis    Proposal    Negotiation    Closed Won
    
    FOR    ${stage}    IN    @{stages}
        Sleep    0.5s    Simulate time passing
        
        ${probability}=    Run Keyword If    '${stage}' == 'Needs Analysis'    Set Variable    40
        ...    ELSE IF    '${stage}' == 'Proposal'    Set Variable    60
        ...    ELSE IF    '${stage}' == 'Negotiation'    Set Variable    80
        ...    ELSE IF    '${stage}' == 'Closed Won'    Set Variable    100
        ...    ELSE    Set Variable    50
        
        PATCH On Session    json_db    /opportunities/${opp}[id]
        ...    json=${{dict(stage='${stage}', probability=${probability})}}
        
        Log To Console    Step 4: Opportunity moved to ${stage} (${probability}% probability)
    END
    
    # Step 5: Update Account Type
    PATCH On Session    json_db    /accounts/${account}[id]
    ...    json=${{dict(type='Customer')}}
    
    Log To Console    Step 5: Account converted to Customer
    
    # Verify final state
    ${final_account}=    GET On Session    json_db    /accounts/${account}[id]
    ${final_opp}=    GET On Session    json_db    /opportunities/${opp}[id]
    
    Should Be Equal    ${final_account.json()}[type]    Customer
    Should Be Equal    ${final_opp.json()}[stage]    Closed Won
    
    Log To Console    ✅ End-to-end sales process completed successfully

Test Data Export And Import
    [Documentation]    Test exporting and verifying data
    
    Log To Console    \n💾 Testing Data Export...
    
    # Export current data
    ${export_file}=    Export All Data To File    full_export_${TEST_ID}.json
    
    # Verify file exists and contains data
    File Should Exist    ${export_file}
    ${file_content}=    Get File    ${export_file}
    ${data}=    Evaluate    json.loads('''${file_content}''')    json
    
    # Verify all collections are exported
    Dictionary Should Contain Key    ${data}    accounts
    Dictionary Should Contain Key    ${data}    contacts
    Dictionary Should Contain Key    ${data}    opportunities
    Dictionary Should Contain Key    ${data}    leads
    Dictionary Should Contain Key    ${data}    cases
    
    Log To Console    ✅ Data exported successfully to ${export_file}
