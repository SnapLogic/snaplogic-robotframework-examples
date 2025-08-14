*** Settings ***
Documentation    SnapLogic Pipeline Integration Tests with Salesforce Mock
...              These tests verify SnapLogic pipeline behavior with JSON-DB backed mocks
Resource         salesforce_test_data.resource
Library          Process
Library          OperatingSystem
Suite Setup      Setup SnapLogic Test Environment
Suite Teardown   Cleanup SnapLogic Test Environment
Test Timeout     5 minutes

*** Variables ***
${SNAPLOGIC_URL}           https://elastic.snaplogic.com/api/1/rest/pipeline
${PIPELINE_RUNTIME_PATH}    /snaplogic/projects/salesforce-test/pipelines
${PIPELINE_TIMEOUT}         60

*** Keywords ***
Setup SnapLogic Test Environment
    [Documentation]    Initialize test environment for SnapLogic pipelines
    
    # Initialize Salesforce mock with test data
    Initialize Salesforce Test Environment    clear_existing=${TRUE}    create_defaults=${TRUE}
    
    # Verify mock is accessible
    ${headers}=    Get Auth Headers
    ${response}=    GET On Session    ${SESSION_ALIAS}    /services/data/v59.0
    ...    headers=${headers}    expected_status=200
    Log    Salesforce mock is accessible
    
    # Set pipeline variables
    Set Suite Variable    ${PIPELINE_ENV}    test
    Set Suite Variable    ${MOCK_ENDPOINT}    ${SALESFORCE_BASE_URL}

Cleanup SnapLogic Test Environment
    [Documentation]    Clean up after all tests
    Clear All Test Data
    Log    Test environment cleaned up

Execute SnapLogic Pipeline
    [Documentation]    Execute a SnapLogic pipeline and return results
    [Arguments]    ${pipeline_name}    ${parameters}=${EMPTY}
    
    Log    Executing pipeline: ${pipeline_name}
    
    # In real implementation, this would call SnapLogic API
    # For testing with mock, we simulate pipeline operations
    ${result}=    Run Keyword    Simulate ${pipeline_name}    ${parameters}
    RETURN    ${result}

Simulate Salesforce Read Pipeline
    [Documentation]    Simulate a SnapLogic Salesforce Read pipeline
    [Arguments]    ${parameters}
    
    # Pipeline would:
    # 1. Authenticate (already done in setup)
    # 2. Query accounts
    ${accounts}=    Query Accounts    SELECT Id, Name, Type, Industry, AnnualRevenue FROM Account
    
    # 3. Transform data (simulate SnapLogic transformation)
    ${transformed}=    Transform Account Data    ${accounts}
    
    # 4. Return results
    RETURN    ${transformed}

Simulate Salesforce Write Pipeline
    [Documentation]    Simulate a SnapLogic Salesforce Write pipeline
    [Arguments]    ${parameters}
    
    # Pipeline would:
    # 1. Read input data
    ${input_data}=    Get From Dictionary    ${parameters}    input_data
    
    # 2. Create accounts
    ${created_ids}=    Create List
    FOR    ${record}    IN    @{input_data}
        ${id}=    Create Account    ${record}[Name]    ${record}
        Append To List    ${created_ids}    ${id}
    END
    
    # 3. Return success response
    ${result}=    Create Dictionary    success=${TRUE}    created=${created_ids}
    RETURN    ${result}

Transform Account Data
    [Documentation]    Simulate SnapLogic data transformation
    [Arguments]    ${raw_data}
    
    ${records}=    Get From Dictionary    ${raw_data}    records
    ${transformed}=    Create List
    
    FOR    ${record}    IN    @{records}
        ${transformed_record}=    Create Dictionary
        ...    id=${record}[Id]
        ...    account_name=${record}[Name]
        ...    account_type=${record}[Type]
        ...    industry=${record.get('Industry', 'Unknown')}
        ...    annual_revenue=${record.get('AnnualRevenue', 0)}
        Append To List    ${transformed}    ${transformed_record}
    END
    
    RETURN    ${transformed}

Verify Pipeline Output
    [Documentation]    Verify pipeline output matches expected format
    [Arguments]    ${output}    ${expected_count}
    
    ${count}=    Get Length    ${output}
    Should Be Equal As Numbers    ${count}    ${expected_count}
    
    # Verify structure
    FOR    ${record}    IN    @{output}
        Dictionary Should Contain Key    ${record}    id
        Dictionary Should Contain Key    ${record}    account_name
    END

*** Test Cases ***
Test SnapLogic Read Pipeline With Default Data
    [Documentation]    Test reading accounts through SnapLogic pipeline
    [Tags]    SnapLogic    Read
    
    # Execute read pipeline
    ${parameters}=    Create Dictionary    object=Account    limit=100
    ${result}=    Execute SnapLogic Pipeline    Salesforce Read Pipeline    ${parameters}
    
    # Verify results include default test accounts
    ${account_names}=    Evaluate    [r['account_name'] for r in $result]
    Should Contain    ${account_names}    Acme Corporation
    Should Contain    ${account_names}    Global Innovations Inc
    Should Contain    ${account_names}    TechStart Solutions
    
    # Verify count
    Verify Pipeline Output    ${result}    3

Test SnapLogic Write Pipeline
    [Documentation]    Test writing accounts through SnapLogic pipeline
    [Tags]    SnapLogic    Write
    
    # Prepare input data
    ${input_data}=    Create List
    ${account1}=    Create Dictionary
    ...    Name=Pipeline Test Account 1
    ...    Type=Customer
    ...    Industry=Technology
    Append To List    ${input_data}    ${account1}
    
    ${account2}=    Create Dictionary
    ...    Name=Pipeline Test Account 2
    ...    Type=Partner
    ...    Industry=Manufacturing
    Append To List    ${input_data}    ${account2}
    
    # Execute write pipeline
    ${parameters}=    Create Dictionary    input_data=${input_data}
    ${result}=    Execute SnapLogic Pipeline    Salesforce Write Pipeline    ${parameters}
    
    # Verify success
    Should Be True    ${result}[success]
    ${created_count}=    Get Length    ${result}[created]
    Should Be Equal As Numbers    ${created_count}    2
    
    # Verify accounts exist in JSON-DB
    Account Should Exist    Pipeline Test Account 1
    Account Should Exist    Pipeline Test Account 2

Test SnapLogic Update Pipeline
    [Documentation]    Test updating accounts through SnapLogic pipeline
    [Tags]    SnapLogic    Update
    
    # Create account to update
    ${account_id}=    Create Account    Update Pipeline Test
    
    # Simulate update pipeline
    ${update_data}=    Create Dictionary
    ...    Id=${account_id}
    ...    Phone=(555) 111-2222
    ...    Website=www.updated.com
    
    Update Account    ${account_id}    ${update_data}
    
    # Verify update
    ${updated}=    Get Account By Id    ${account_id}
    Should Be Equal    ${updated}[Phone]    (555) 111-2222
    Should Be Equal    ${updated}[Website]    www.updated.com

Test SnapLogic Delete Pipeline
    [Documentation]    Test deleting accounts through SnapLogic pipeline
    [Tags]    SnapLogic    Delete
    
    # Create accounts to delete
    ${id1}=    Create Account    Delete Test 1
    ${id2}=    Create Account    Delete Test 2
    
    # Verify they exist
    Account Should Exist    Delete Test 1
    Account Should Exist    Delete Test 2
    
    # Simulate delete pipeline
    Delete Account    ${id1}
    Delete Account    ${id2}
    
    # Verify deletion
    Account Should Not Exist    Delete Test 1
    Account Should Not Exist    Delete Test 2

Test SnapLogic Pipeline With Query Filters
    [Documentation]    Test pipeline with SOQL query filters
    [Tags]    SnapLogic    Query
    
    # Create test data with specific types
    Create Account    Customer Account 1    ${{'Type': 'Customer'}}
    Create Account    Customer Account 2    ${{'Type': 'Customer'}}
    Create Account    Partner Account 1    ${{'Type': 'Partner'}}
    
    # Query only customers
    ${customers}=    Query Accounts    SELECT Name FROM Account WHERE Type='Customer'
    ${customer_records}=    Get From Dictionary    ${customers}    records
    
    # Should have at least 3 customers (1 from default + 2 new)
    ${count}=    Get Length    ${customer_records}
    Should Be True    ${count} >= 3

Test SnapLogic Pipeline Error Handling
    [Documentation]    Test pipeline behavior with errors
    [Tags]    SnapLogic    ErrorHandling
    
    # Test with invalid account (missing required field)
    ${invalid_data}=    Create Dictionary    Type=Customer    # Missing Name
    
    Run Keyword And Expect Error    *400*
    ...    Create Account    ${EMPTY}    ${invalid_data}
    
    # Test with non-existent account
    Run Keyword And Expect Error    *404*
    ...    Get Account By Id    NONEXISTENT123
    
    # Verify pipeline can continue after error
    ${valid_id}=    Create Account    Valid After Error Test
    Should Not Be Empty    ${valid_id}

Test SnapLogic Bulk Operations
    [Documentation]    Test pipeline with bulk operations
    [Tags]    SnapLogic    Bulk
    
    # Create many accounts to test bulk handling
    FOR    ${i}    IN RANGE    1    21
        Create Account    Bulk Test Account ${i}
    END
    
    # Query with limit
    ${limited}=    Query Accounts    SELECT Name FROM Account LIMIT 10
    ${records}=    Get From Dictionary    ${limited}    records
    ${count}=    Get Length    ${records}
    Should Be Equal As Numbers    ${count}    10
    
    # Query all (should be 20 + 3 default = 23)
    ${all}=    Query Accounts    SELECT Name FROM Account WHERE Name LIKE 'Bulk Test%'
    ${bulk_records}=    Get From Dictionary    ${all}    records
    ${bulk_count}=    Get Length    ${bulk_records}
    Should Be Equal As Numbers    ${bulk_count}    20

Test SnapLogic Pipeline With Relationships
    [Documentation]    Test pipeline handling related objects
    [Tags]    SnapLogic    Relationships
    
    # Create account with related objects
    ${hierarchy}=    Create Test Data Hierarchy
    ...    account_name=Relationship Pipeline Test
    ...    num_contacts=5
    ...    num_opportunities=3
    
    # In real SnapLogic, would query with relationship
    # SELECT Id, Name, (SELECT Id FROM Contacts) FROM Account
    
    # Verify all objects created
    Account Should Exist    Relationship Pipeline Test
    ${contact_count}=    Get Length    ${hierarchy}[contact_ids]
    Should Be Equal As Numbers    ${contact_count}    5
    ${opp_count}=    Get Length    ${hierarchy}[opportunity_ids]
    Should Be Equal As Numbers    ${opp_count}    3