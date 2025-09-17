*** Settings ***
Documentation    Example test suite using Salesforce test data resource
Resource         salesforce_test_data.resource
Suite Setup      Initialize Salesforce Test Environment
Suite Teardown   Clear All Test Data
Test Setup       Log    Starting test: ${TEST NAME}
Test Teardown    Log    Completed test: ${TEST NAME}

*** Test Cases ***
Test Basic Account CRUD Operations
    [Documentation]    Test Create, Read, Update, Delete operations
    [Tags]    CRUD    Smoke
    
    # Create
    ${account_id}=    Create Account    CRUD Test Account
    Should Not Be Empty    ${account_id}
    
    # Read
    ${account}=    Get Account By Id    ${account_id}
    Should Be Equal    ${account}[Name]    CRUD Test Account
    
    # Update
    ${update_data}=    Create Dictionary    Phone=(555) 999-8888
    Update Account    ${account_id}    ${update_data}
    
    # Verify Update
    ${updated}=    Get Account By Id    ${account_id}
    Should Be Equal    ${updated}[Phone]    (555) 999-8888
    
    # Delete
    Delete Account    ${account_id}
    
    # Verify Deletion
    Run Keyword And Expect Error    *404*
    ...    Get Account By Id    ${account_id}

Test Account Query Operations
    [Documentation]    Test SOQL query functionality
    [Tags]    Query
    
    # Initial accounts already created in suite setup
    
    # Query all accounts
    ${all_accounts}=    Get All Accounts
    ${count}=    Get Length    ${all_accounts}
    Should Be True    ${count} >= 3
    
    # Query specific account
    ${result}=    Query Accounts    SELECT Id, Name FROM Account WHERE Name='Acme Corporation'
    ${records}=    Get From Dictionary    ${result}    records
    Should Be Equal    ${records}[0][Name]    Acme Corporation
    
    # Query by type
    ${customers}=    Query Accounts    SELECT Name FROM Account WHERE Type='Customer'
    Log    Customer accounts: ${customers}

Test Account With Related Records
    [Documentation]    Test creating accounts with contacts and opportunities
    [Tags]    Relationships
    
    # Create account with related data
    ${hierarchy}=    Create Test Data Hierarchy    
    ...    account_name=Hierarchy Test Account
    ...    num_contacts=3
    ...    num_opportunities=2
    
    # Verify creation
    Should Not Be Empty    ${hierarchy}[account_id]
    ${contact_count}=    Get Length    ${hierarchy}[contact_ids]
    Should Be Equal As Numbers    ${contact_count}    3
    ${opp_count}=    Get Length    ${hierarchy}[opportunity_ids]
    Should Be Equal As Numbers    ${opp_count}    2
    
    Log    Created account hierarchy: ${hierarchy}

Test Bulk Account Creation
    [Documentation]    Test creating multiple accounts at once
    [Tags]    Bulk
    
    # Create multiple accounts
    @{account_names}=    Create List
    ...    Bulk Test 1
    ...    Bulk Test 2
    ...    Bulk Test 3
    ...    Bulk Test 4
    ...    Bulk Test 5
    
    ${account_ids}=    Create Multiple Accounts    @{account_names}
    
    # Verify all created
    ${count}=    Get Length    ${account_ids}
    Should Be Equal As Numbers    ${count}    5
    
    # Verify they exist in database
    FOR    ${name}    IN    @{account_names}
        Account Should Exist    ${name}
    END

Test Error Scenarios
    [Documentation]    Test error handling for invalid operations
    [Tags]    ErrorHandling
    
    # Test missing required field
    Run Keyword And Expect Error    *
    ...    Create Account With Missing Required Field
    
    # Test invalid account ID
    Run Keyword And Expect Error    *404*
    ...    Get Account By Id    INVALID_ID_12345
    
    # Test duplicate handling (if enabled in mock)
    ${response}=    Create Duplicate Account    Duplicate Test Account
    Log    Duplicate response: ${response.status_code}

Test Data Persistence Across Tests
    [Documentation]    Verify data persists between test cases
    [Tags]    Persistence
    
    # This test relies on data from suite setup
    Account Should Exist    Acme Corporation
    Account Should Exist    Global Innovations Inc
    Account Should Exist    TechStart Solutions
    
    # Add new account
    ${new_id}=    Create Account    Persistence Test Account
    Set Suite Variable    ${PERSISTENCE_TEST_ID}    ${new_id}

Test Data Cleanup
    [Documentation]    Test selective data cleanup
    [Tags]    Cleanup
    
    # Create test data
    ${account_id}=    Create Account    Cleanup Test Account
    ${contact_id}=    Create Contact    Jane    Smith    ${account_id}
    
    # Verify creation
    Account Should Exist    Cleanup Test Account
    
    # Clean up just this account
    Delete Account    ${account_id}
    
    # Verify cleanup
    Account Should Not Exist    Cleanup Test Account
    
    # Default accounts should still exist
    Account Should Exist    Acme Corporation