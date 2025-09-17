*** Settings ***
Documentation    JSON-DB Integration Resource File
...              This resource provides keywords for real data persistence
...              using json-server as the backend database.

Library    RequestsLibrary
Library    Collections
Library    JSONLibrary
Library    String
Library    DateTime
Library    OperatingSystem
Library    Process

*** Variables ***
# JSON-DB Configuration
${JSON_DB_URL}            http://salesforce-json-mock    # Docker internal
${JSON_DB_URL_EXTERNAL}   http://localhost:8082           # From host
${JSON_DB_SESSION}        json_db
${USE_EXTERNAL}           ${FALSE}    # Set TRUE when running from host

# ID Generation
${ACCOUNT_PREFIX}         001
${CONTACT_PREFIX}         003
${OPPORTUNITY_PREFIX}     006
${LEAD_PREFIX}            00Q
${CASE_PREFIX}            500

# Counters for ID generation
${ACCOUNT_COUNTER}        1
${CONTACT_COUNTER}        1
${OPPORTUNITY_COUNTER}    1
${LEAD_COUNTER}           1
${CASE_COUNTER}           1

*** Keywords ***
# ============================================================================
# JSON-DB Connection Keywords
# ============================================================================

Connect To JSON DB
    [Documentation]    Establish connection to JSON-DB server
    [Arguments]    ${external}=${USE_EXTERNAL}
    
    ${url}=    Set Variable If    ${external}
    ...    ${JSON_DB_URL_EXTERNAL}
    ...    ${JSON_DB_URL}
    
    Create Session    ${JSON_DB_SESSION}    ${url}
    Set Suite Variable    ${JSON_DB_CURRENT_URL}    ${url}
    
    # Verify connection - json-server returns all data at root
    ${status}    ${response}=    Run Keyword And Ignore Error
    ...    GET On Session    ${JSON_DB_SESSION}    /db
    
    Run Keyword If    '${status}' == 'FAIL'
    ...    Log    Note: /db endpoint may not exist, trying /accounts
    
    # Try a simpler endpoint
    ${status}    ${response}=    Run Keyword And Ignore Error
    ...    GET On Session    ${JSON_DB_SESSION}    /accounts
    
    Run Keyword If    '${status}' == 'FAIL'
    ...    Initialize Empty Collections
    
    Log    Connected to JSON-DB at ${url}

Initialize JSON DB
    [Documentation]    Initialize JSON-DB with clean data
    
    Connect To JSON DB
    
    # Initialize collections if they don't exist
    Initialize Empty Collections
    
    # Add initial test accounts
    ${account1}=    Create Dictionary
    ...    id=001000000000001
    ...    name=Acme Corporation
    ...    type=Customer
    ...    industry=Technology
    ...    annualRevenue=50000000
    
    ${account2}=    Create Dictionary
    ...    id=001000000000002
    ...    name=Global Innovations Inc
    ...    type=Partner
    ...    industry=Manufacturing
    ...    annualRevenue=75000000
    
    ${account3}=    Create Dictionary
    ...    id=001000000000003
    ...    name=TechStart Solutions
    ...    type=Prospect
    ...    industry=Software
    ...    annualRevenue=10000000
    
    Add Account To JSON DB    ${account1}
    Add Account To JSON DB    ${account2}
    Add Account To JSON DB    ${account3}
    
    Log    JSON-DB initialized with test data

Initialize Empty Collections
    [Documentation]    Create empty collections if they don't exist
    
    # Initialize each collection with a dummy entry then delete it
    @{collections}=    Create List    accounts    contacts    opportunities    leads    cases
    
    FOR    ${collection}    IN    @{collections}
        ${dummy}=    Create Dictionary    _init=true    name=__init__
        ${status}    ${response}=    Run Keyword And Ignore Error
        ...    POST On Session    ${JSON_DB_SESSION}    /${collection}
        ...    json=${dummy}
        
        # If successful, delete the dummy entry
        Run Keyword If    '${status}' == 'PASS'
        ...    Run Keyword And Ignore Error
        ...    DELETE On Session    ${JSON_DB_SESSION}    /${collection}/${response.json()}[id]
    END

# ============================================================================
# Account CRUD Operations with JSON-DB
# ============================================================================

Create Account In JSON DB
    [Documentation]    Create account with real persistence in JSON-DB
    [Arguments]    ${name}    &{account_data}
    
    # Generate unique ID
    ${id}=    Generate Unique ID    ${ACCOUNT_PREFIX}
    
    # Get current timestamp
    ${timestamp}=    Get Current Timestamp
    
    # Build account data
    ${full_data}=    Create Dictionary
    ...    id=${id}
    ...    name=${name}
    ...    createdDate=${timestamp}
    
    # Add optional fields
    FOR    ${key}    ${value}    IN    &{account_data}
        Set To Dictionary    ${full_data}    ${key}=${value}
    END
    
    # Save to JSON-DB
    ${response}=    POST On Session    ${JSON_DB_SESSION}    /accounts
    ...    json=${full_data}
    ...    expected_status=201
    
    Log    Created account in JSON-DB: ${name} with ID: ${id}
    RETURN    ${id}

Add Account To JSON DB
    [Documentation]    Direct add to JSON-DB (for initialization)
    [Arguments]    ${account_data}
    
    ${response}=    POST On Session    ${JSON_DB_SESSION}    /accounts
    ...    json=${account_data}
    ...    expected_status=201
    
    RETURN    ${response.json()}

Get Account From JSON DB
    [Documentation]    Retrieve account by ID from JSON-DB
    [Arguments]    ${account_id}
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    /accounts/${account_id}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Query Accounts From JSON DB
    [Documentation]    Query accounts with filters
    [Arguments]    ${filter}=${EMPTY}
    
    ${url}=    Set Variable If    '${filter}' != '${EMPTY}'
    ...    /accounts?${filter}
    ...    /accounts
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    ${url}
    ...    expected_status=200
    
    ${accounts}=    Set Variable    ${response.json()}
    
    # Return in Salesforce-like format
    ${result}=    Create Dictionary
    ...    totalSize=${accounts.__len__()}
    ...    done=${TRUE}
    ...    records=${accounts}
    
    RETURN    ${result}

Update Account In JSON DB
    [Documentation]    Update existing account in JSON-DB
    [Arguments]    ${account_id}    &{update_data}
    
    # Get current timestamp
    ${timestamp}=    Get Current Timestamp
    
    # Build update data
    ${data_with_timestamp}=    Create Dictionary    lastModifiedDate=${timestamp}
    FOR    ${key}    ${value}    IN    &{update_data}
        Set To Dictionary    ${data_with_timestamp}    ${key}=${value}
    END
    
    # Update in JSON-DB using PATCH
    ${response}=    PATCH On Session    ${JSON_DB_SESSION}    /accounts/${account_id}
    ...    json=${data_with_timestamp}
    ...    expected_status=200
    
    Log    Updated account ${account_id} in JSON-DB
    RETURN    ${response.json()}

Delete Account From JSON DB
    [Documentation]    Delete account from JSON-DB
    [Arguments]    ${account_id}
    
    DELETE On Session    ${JSON_DB_SESSION}    /accounts/${account_id}
    ...    expected_status=200
    
    Log    Deleted account ${account_id} from JSON-DB

Search Accounts In JSON DB
    [Documentation]    Search accounts by field value
    [Arguments]    ${field}    ${value}
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    /accounts?${field}=${value}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Account Exists In JSON DB
    [Documentation]    Check if account exists by ID
    [Arguments]    ${account_id}
    
    ${status}=    Run Keyword And Return Status
    ...    Get Account From JSON DB    ${account_id}
    
    RETURN    ${status}

Get Account Count In JSON DB
    [Documentation]    Get total number of accounts
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    /accounts
    ...    expected_status=200
    
    ${count}=    Get Length    ${response.json()}
    RETURN    ${count}

# ============================================================================
# Contact Operations
# ============================================================================

Create Contact In JSON DB
    [Documentation]    Create contact in JSON-DB
    [Arguments]    ${firstName}    ${lastName}    ${accountId}    &{contact_data}
    
    # Generate unique ID
    ${id}=    Generate Unique ID    ${CONTACT_PREFIX}
    
    # Get current timestamp
    ${timestamp}=    Get Current Timestamp
    
    # Build contact data
    ${full_data}=    Create Dictionary
    ...    id=${id}
    ...    firstName=${firstName}
    ...    lastName=${lastName}
    ...    accountId=${accountId}
    ...    createdDate=${timestamp}
    
    # Add optional fields
    FOR    ${key}    ${value}    IN    &{contact_data}
        Set To Dictionary    ${full_data}    ${key}=${value}
    END
    
    # Save to JSON-DB
    ${response}=    POST On Session    ${JSON_DB_SESSION}    /contacts
    ...    json=${full_data}
    ...    expected_status=201
    
    Log    Created contact: ${firstName} ${lastName} with ID: ${id}
    RETURN    ${id}

Get Contact From JSON DB
    [Documentation]    Retrieve contact by ID from JSON-DB
    [Arguments]    ${contact_id}
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    /contacts/${contact_id}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Query Contacts From JSON DB
    [Documentation]    Query contacts with filters
    [Arguments]    ${filter}=${EMPTY}
    
    ${url}=    Set Variable If    '${filter}' != '${EMPTY}'
    ...    /contacts?${filter}
    ...    /contacts
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    ${url}
    ...    expected_status=200
    
    RETURN    ${response.json()}

# ============================================================================
# Opportunity Operations
# ============================================================================

Create Opportunity In JSON DB
    [Documentation]    Create opportunity in JSON-DB
    [Arguments]    ${name}    ${accountId}    ${stage}    ${amount}    &{opp_data}
    
    # Generate unique ID
    ${id}=    Generate Unique ID    ${OPPORTUNITY_PREFIX}
    
    # Get current timestamp
    ${timestamp}=    Get Current Timestamp
    
    # Build opportunity data
    ${full_data}=    Create Dictionary
    ...    id=${id}
    ...    name=${name}
    ...    accountId=${accountId}
    ...    stage=${stage}
    ...    amount=${amount}
    ...    createdDate=${timestamp}
    
    # Add optional fields
    FOR    ${key}    ${value}    IN    &{opp_data}
        Set To Dictionary    ${full_data}    ${key}=${value}
    END
    
    # Save to JSON-DB
    ${response}=    POST On Session    ${JSON_DB_SESSION}    /opportunities
    ...    json=${full_data}
    ...    expected_status=201
    
    Log    Created opportunity: ${name} with ID: ${id}
    RETURN    ${id}

Get Opportunity From JSON DB
    [Documentation]    Retrieve opportunity by ID from JSON-DB
    [Arguments]    ${opp_id}
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    /opportunities/${opp_id}
    ...    expected_status=200
    
    RETURN    ${response.json()}

Query Opportunities From JSON DB
    [Documentation]    Query opportunities with filters
    [Arguments]    ${filter}=${EMPTY}
    
    ${url}=    Set Variable If    '${filter}' != '${EMPTY}'
    ...    /opportunities?${filter}
    ...    /opportunities
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    ${url}
    ...    expected_status=200
    
    RETURN    ${response.json()}

# ============================================================================
# Lead Operations
# ============================================================================

Create Lead In JSON DB
    [Documentation]    Create lead in JSON-DB
    [Arguments]    ${firstName}    ${lastName}    ${company}    &{lead_data}
    
    # Generate unique ID
    ${id}=    Generate Unique ID    ${LEAD_PREFIX}
    
    # Get current timestamp
    ${timestamp}=    Get Current Timestamp
    
    # Build lead data
    ${full_data}=    Create Dictionary
    ...    id=${id}
    ...    firstName=${firstName}
    ...    lastName=${lastName}
    ...    company=${company}
    ...    createdDate=${timestamp}
    
    # Add optional fields
    FOR    ${key}    ${value}    IN    &{lead_data}
        Set To Dictionary    ${full_data}    ${key}=${value}
    END
    
    # Save to JSON-DB
    ${response}=    POST On Session    ${JSON_DB_SESSION}    /leads
    ...    json=${full_data}
    ...    expected_status=201
    
    Log    Created lead: ${firstName} ${lastName} with ID: ${id}
    RETURN    ${id}

Get Lead From JSON DB
    [Documentation]    Retrieve lead by ID from JSON-DB
    [Arguments]    ${lead_id}
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    /leads/${lead_id}
    ...    expected_status=200
    
    RETURN    ${response.json()}

# ============================================================================
# Case Operations
# ============================================================================

Create Case In JSON DB
    [Documentation]    Create case in JSON-DB
    [Arguments]    ${subject}    ${accountId}    &{case_data}
    
    # Generate unique ID
    ${id}=    Generate Unique ID    ${CASE_PREFIX}
    
    # Get current timestamp
    ${timestamp}=    Get Current Timestamp
    
    # Build case data
    ${full_data}=    Create Dictionary
    ...    id=${id}
    ...    subject=${subject}
    ...    accountId=${accountId}
    ...    createdDate=${timestamp}
    
    # Add optional fields
    FOR    ${key}    ${value}    IN    &{case_data}
        Set To Dictionary    ${full_data}    ${key}=${value}
    END
    
    # Save to JSON-DB
    ${response}=    POST On Session    ${JSON_DB_SESSION}    /cases
    ...    json=${full_data}
    ...    expected_status=201
    
    Log    Created case: ${subject} with ID: ${id}
    RETURN    ${id}

Get Case From JSON DB
    [Documentation]    Retrieve case by ID from JSON-DB
    [Arguments]    ${case_id}
    
    ${response}=    GET On Session    ${JSON_DB_SESSION}    /cases/${case_id}
    ...    expected_status=200
    
    RETURN    ${response.json()}

# ============================================================================
# Bulk Operations
# ============================================================================

Bulk Create Accounts In JSON DB
    [Documentation]    Create multiple accounts efficiently
    [Arguments]    @{account_names}
    
    ${created_ids}=    Create List
    
    FOR    ${name}    IN    @{account_names}
        ${id}=    Create Account In JSON DB    ${name}
        Append To List    ${created_ids}    ${id}
    END
    
    RETURN    ${created_ids}

Clear All JSON DB Data
    [Documentation]    Remove all data from JSON-DB
    
    @{collections}=    Create List    accounts    contacts    opportunities    leads    cases
    
    FOR    ${collection}    IN    @{collections}
        Clear Collection    ${collection}
    END
    
    Log    Cleared all data from JSON-DB

Clear Collection
    [Documentation]    Clear all items from a specific collection
    [Arguments]    ${collection_name}
    
    # Get all items
    ${status}    ${response}=    Run Keyword And Ignore Error
    ...    GET On Session    ${JSON_DB_SESSION}    /${collection_name}
    
    Run Keyword If    '${status}' == 'PASS'
    ...    Delete All Items From Collection    ${collection_name}    ${response.json()}

Delete All Items From Collection
    [Documentation]    Delete all items from a collection
    [Arguments]    ${collection_name}    ${items}
    
    FOR    ${item}    IN    @{items}
        Run Keyword And Ignore Error
        ...    DELETE On Session    ${JSON_DB_SESSION}    /${collection_name}/${item}[id]
    END

# ============================================================================
# Utility Keywords
# ============================================================================

Generate Unique ID
    [Documentation]    Generate unique Salesforce-like ID
    [Arguments]    ${prefix}
    
    # Use timestamp and random for uniqueness
    ${timestamp}=    Get Current Date    result_format=%Y%m%d%H%M%S
    ${random}=    Evaluate    random.randint(100, 999)    random
    
    # Create ID with prefix
    ${id}=    Set Variable    ${prefix}${timestamp}${random}
    
    # Ensure it's 18 characters (Salesforce standard)
    ${id}=    Evaluate    "${id}".ljust(18, '0')[:18]
    
    RETURN    ${id}

Get Current Timestamp
    [Documentation]    Get current timestamp in ISO format
    ${timestamp}=    Get Current Date    result_format=%Y-%m-%dT%H:%M:%S.%fZ
    RETURN    ${timestamp}

Add Dictionary Items
    [Documentation]    Add multiple items to a dictionary
    [Arguments]    ${target_dict}    &{items}
    
    FOR    ${key}    ${value}    IN    &{items}
        Set To Dictionary    ${target_dict}    ${key}=${value}
    END

Should Be Number
    [Documentation]    Verify that value is a number
    [Arguments]    ${value}    ${msg}=Value must be a number
    
    ${is_number}=    Run Keyword And Return Status
    ...    Evaluate    isinstance(${value}, (int, float))
    
    Run Keyword If    not ${is_number}
    ...    Fail    ${msg}

# ============================================================================
# Validation Keywords
# ============================================================================

Validate Account Data
    [Documentation]    Validate account data before saving
    [Arguments]    ${account_data}
    
    # Check required fields
    Dictionary Should Contain Key    ${account_data}    name
    ...    msg=Account name is required
    
    # Validate field types if present
    ${revenue}=    Get From Dictionary    ${account_data}    annualRevenue    default=0
    Should Be Number    ${revenue}    msg=AnnualRevenue must be a number
    
    # Check name is not empty
    ${name}=    Get From Dictionary    ${account_data}    name
    Should Not Be Empty    ${name}    msg=Account name cannot be empty

Check For Duplicate Account
    [Documentation]    Check if account with same name exists
    [Arguments]    ${account_name}
    
    ${existing}=    Search Accounts In JSON DB    name    ${account_name}
    
    ${count}=    Get Length    ${existing}
    Run Keyword If    ${count} > 0
    ...    Log    Warning: Account with name '${account_name}' already exists

# ============================================================================
# Integration with WireMock
# ============================================================================

Sync WireMock With JSON DB
    [Documentation]    Update WireMock responses to use JSON-DB data
    
    # This would require custom WireMock extensions or
    # updating mapping files dynamically
    Log    Sync between WireMock and JSON-DB would require custom extensions
    
Create Account With Both Systems
    [Documentation]    Create in both JSON-DB (persistence) and via WireMock (testing)
    [Arguments]    ${name}    &{account_data}
    
    # Create in JSON-DB for persistence
    ${db_id}=    Create Account In JSON DB    ${name}    &{account_data}
    
    # Also call WireMock endpoint for integration testing
    ${headers}=    Create Dictionary    Content-Type=application/json
    ${full_data}=    Create Dictionary    name=${name}
    FOR    ${key}    ${value}    IN    &{account_data}
        Set To Dictionary    ${full_data}    ${key}=${value}
    END
    
    ${status}    ${response}=    Run Keyword And Ignore Error
    ...    POST On Session    salesforce    /services/data/v59.0/sobjects/Account
    ...    json=${full_data}
    ...    headers=${headers}
    
    Run Keyword If    '${status}' == 'FAIL'
    ...    Log    Note: WireMock endpoint not available, data saved to JSON-DB only
    
    # Return the JSON-DB ID (the real one)
    RETURN    ${db_id}

# ============================================================================
# Data Export/Import Keywords
# ============================================================================

Export JSON DB To File
    [Documentation]    Export all JSON-DB data to a file
    [Arguments]    ${filename}=json_db_export.json
    
    ${all_data}=    Create Dictionary
    
    # Get all collections
    @{collections}=    Create List    accounts    contacts    opportunities    leads    cases
    
    FOR    ${collection}    IN    @{collections}
        ${status}    ${response}=    Run Keyword And Ignore Error
        ...    GET On Session    ${JSON_DB_SESSION}    /${collection}
        
        Run Keyword If    '${status}' == 'PASS'
        ...    Set To Dictionary    ${all_data}    ${collection}=${response.json()}
        ...    ELSE
        ...    Set To Dictionary    ${all_data}    ${collection}=@{EMPTY}
    END
    
    # Add metadata
    ${timestamp}=    Get Current Timestamp
    Set To Dictionary    ${all_data}    exportTimestamp=${timestamp}
    
    # Write to file
    ${json_string}=    Evaluate    json.dumps(${all_data}, indent=2)    json
    Create File    ${filename}    ${json_string}
    
    Log    Exported JSON-DB to: ${filename}
    RETURN    ${filename}

Import JSON DB From File
    [Documentation]    Import data from JSON file to JSON-DB
    [Arguments]    ${filename}
    
    File Should Exist    ${filename}
    
    ${file_content}=    Get File    ${filename}
    ${data}=    Evaluate    json.loads('''${file_content}''')    json
    
    # Clear existing data
    Clear All JSON DB Data
    
    # Import each collection
    @{collections}=    Create List    accounts    contacts    opportunities    leads    cases
    
    FOR    ${collection}    IN    @{collections}
        ${items}=    Get From Dictionary    ${data}    ${collection}    default=@{EMPTY}
        Import Collection Items    ${collection}    ${items}
    END
    
    Log    Imported data from: ${filename}

Import Collection Items
    [Documentation]    Import items into a specific collection
    [Arguments]    ${collection_name}    ${items}
    
    FOR    ${item}    IN    @{items}
        POST On Session    ${JSON_DB_SESSION}    /${collection_name}
        ...    json=${item}
        ...    expected_status=201
    END
    
    ${count}=    Get Length    ${items}
    Log    Imported ${count} items into ${collection_name}

# ============================================================================
# Container Management Keywords
# ============================================================================

Ensure JSON Server Is Running
    [Documentation]    Check and start JSON Server if needed
    
    ${is_running}=    Check JSON Server Status
    
    Run Keyword If    not ${is_running}
    ...    Start JSON Server
    
    Wait Until JSON Server Ready

Check JSON Server Status
    [Documentation]    Check if JSON Server container is running
    
    ${result}=    Run Process
    ...    docker inspect -f '{{.State.Status}}' salesforce-json-mock
    ...    shell=True
    
    ${is_running}=    Run Keyword And Return Status
    ...    Should Contain    ${result.stdout}    running
    
    RETURN    ${is_running}

Start JSON Server
    [Documentation]    Start the JSON Server container
    
    ${result}=    Run Process
    ...    docker compose -f docker/docker-compose.salesforce-mock.yml up -d salesforce-json-server
    ...    shell=True
    
    Should Be Equal As Integers    ${result.rc}    0
    ...    msg=Failed to start JSON Server: ${result.stderr}
    
    Sleep    3s    Wait for JSON Server to initialize

Stop JSON Server
    [Documentation]    Stop the JSON Server container
    
    ${result}=    Run Process
    ...    docker compose -f docker/docker-compose.salesforce-mock.yml stop salesforce-json-server
    ...    shell=True
    
    Log    JSON Server stopped

Wait Until JSON Server Ready
    [Documentation]    Wait for JSON Server to be ready
    
    Wait Until Keyword Succeeds    30s    2s
    ...    Connect To JSON DB

# ============================================================================
# Statistics and Reporting Keywords
# ============================================================================

Get Collection Statistics
    [Documentation]    Get statistics for all collections
    
    ${stats}=    Create Dictionary
    
    @{collections}=    Create List    accounts    contacts    opportunities    leads    cases
    
    FOR    ${collection}    IN    @{collections}
        ${status}    ${response}=    Run Keyword And Ignore Error
        ...    GET On Session    ${JSON_DB_SESSION}    /${collection}
        
        ${count}=    Run Keyword If    '${status}' == 'PASS'
        ...    Get Length    ${response.json()}
        ...    ELSE
        ...    Set Variable    0
        
        Set To Dictionary    ${stats}    ${collection}=${count}
    END
    
    Log    Collection Statistics: ${stats}
    RETURN    ${stats}

Get Pipeline Value
    [Documentation]    Calculate total pipeline value from opportunities
    
    ${opportunities}=    Query Opportunities From JSON DB
    
    ${total}=    Set Variable    0
    
    FOR    ${opp}    IN    @{opportunities}
        ${amount}=    Get From Dictionary    ${opp}    amount    default=0
        ${total}=    Evaluate    ${total} + ${amount}
    END
    
    Log    Total Pipeline Value: $${total}
    RETURN    ${total}
