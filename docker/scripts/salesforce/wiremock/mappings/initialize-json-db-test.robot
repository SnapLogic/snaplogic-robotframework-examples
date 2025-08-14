*** Settings ***
Library    RequestsLibrary
Library    JSONLibrary
Library    Collections
Suite Setup    Initialize Test Data

*** Variables ***
${BASE_URL}    https://salesforce-api-mock:8443
${AUTH_TOKEN}    mock-access-token
${VERIFY_SSL}    ${FALSE}    # Disable SSL verification for self-signed certs

*** Keywords ***
Initialize Test Data
    [Documentation]    Initialize JSON-DB with test accounts via POST actions
    
    # Disable SSL warnings for self-signed certificates
    Create Session    salesforce    ${BASE_URL}    verify=${VERIFY_SSL}
    
    # Step 1: Authenticate
    ${auth_data}=    Create Dictionary
    ...    grant_type=password
    ...    username=test
    ...    password=test
    
    ${auth_response}=    POST On Session    salesforce    /services/oauth2/token
    ...    data=${auth_data}
    
    ${token}=    Get From Dictionary    ${auth_response.json()}    access_token
    Set Suite Variable    ${AUTH_TOKEN}    ${token}
    
    # Step 2: Clear existing data (optional - depends on your setup)
    Clear All Accounts
    
    # Step 3: Create initial test accounts
    Create Initial Account    Acme Corporation    Customer    Technology    50000000
    Create Initial Account    Global Innovations Inc    Partner    Manufacturing    75000000
    Create Initial Account    TechStart Solutions    Prospect    Software    10000000
    
    Log    Test data initialized successfully

Clear All Accounts
    [Documentation]    Optional: Clear all existing accounts
    ${headers}=    Create Dictionary    Authorization=Bearer ${AUTH_TOKEN}
    
    ${response}=    GET On Session    salesforce    /services/data/v59.0/query
    ...    params=q=SELECT Id FROM Account
    ...    headers=${headers}
    
    FOR    ${account}    IN    @{response.json()['records']}
        DELETE On Session    salesforce    /services/data/v59.0/sobjects/Account/${account['Id']}
        ...    headers=${headers}
    END

Create Initial Account
    [Arguments]    ${name}    ${type}    ${industry}    ${revenue}
    [Documentation]    Create a single account in JSON-DB
    
    ${headers}=    Create Dictionary    
    ...    Authorization=Bearer ${AUTH_TOKEN}
    ...    Content-Type=application/json
    
    ${account_data}=    Create Dictionary
    ...    Name=${name}
    ...    Type=${type}
    ...    Industry=${industry}
    ...    AnnualRevenue=${revenue}
    
    ${response}=    POST On Session    salesforce    /services/data/v59.0/sobjects/Account
    ...    json=${account_data}
    ...    headers=${headers}
    
    Should Be Equal As Strings    ${response.status_code}    201
    Log    Created account: ${name} with ID: ${response.json()['id']}
    RETURN    ${response.json()['id']}

*** Test Cases ***
Test Account Operations
    [Documentation]    Test CRUD operations with initialized data
    
    # Query should return our 3 initialized accounts
    ${response}=    GET    ${BASE_URL}/services/data/v59.0/query
    ...    params=q=SELECT Name FROM Account
    ...    headers=Authorization=Bearer ${AUTH_TOKEN}
    
    ${count}=    Get Length    ${response.json()['records']}
    Should Be Equal As Numbers    ${count}    3
    
    # Add a fourth account
    ${new_account}=    Create Dictionary    Name=Test New Corp    Type=Customer
    ${response}=    POST    ${BASE_URL}/services/data/v59.0/sobjects/Account
    ...    json=${new_account}
    ...    headers=Authorization=Bearer ${AUTH_TOKEN}
    
    # Now query should return 4 accounts
    ${response}=    GET    ${BASE_URL}/services/data/v59.0/query
    ...    params=q=SELECT Name FROM Account
    ...    headers=Authorization=Bearer ${AUTH_TOKEN}
    
    ${count}=    Get Length    ${response.json()['records']}
    Should Be Equal As Numbers    ${count}    4