---
description: Guide for creating new Robot Framework test cases
---

You are helping a user create new Robot Framework test cases in this SnapLogic pipeline testing project. Follow these conventions and patterns.

## Quick Start Template

Here's a basic test file template to get started:

```robotframework
*** Settings ***
Documentation    Description of what this test suite covers
...              Include prerequisites and dependencies
Resource         ../../resources/common/general.resource
Resource         ../../resources/common/database.resource
Library          Collections
Library          JSONLibrary

Suite Setup      Test Suite Setup
Suite Teardown   Test Suite Teardown

*** Variables ***
${PIPELINE_NAME}       my_pipeline
${UNIQUE_ID}           ${EMPTY}

*** Test Cases ***
Test Pipeline Executes Successfully
    [Documentation]    Verify the pipeline completes without errors
    [Tags]    oracle    smoke    pipeline_name
    [Setup]    Prepare Test Data

    # Given
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${UNIQUE_ID}    ${unique_id}

    # When
    Upload Pipeline    ${PIPELINE_NAME}_${unique_id}
    Execute Pipeline    ${PIPELINE_NAME}_${unique_id}

    # Then
    ${status}=    Get Pipeline Status    ${PIPELINE_NAME}_${unique_id}
    Should Be Equal    ${status}    Completed

    [Teardown]    Cleanup Test Pipeline

*** Keywords ***
Test Suite Setup
    Log To Console    \nInitializing test suite...
    Validate Required Variables

Test Suite Teardown
    Log To Console    \nCleaning up test suite...
    Run Keyword And Ignore Error    Delete All Test Artifacts

Prepare Test Data
    Log    Preparing test data for ${PIPELINE_NAME}

Cleanup Test Pipeline
    Run Keyword And Ignore Error    Delete Pipeline    ${PIPELINE_NAME}_${UNIQUE_ID}

Validate Required Variables
    Variable Should Exist    ${URL}
    Variable Should Exist    ${ORG_NAME}
```

## Step-by-Step: Creating a New Test

### Step 1: Choose the Right Location

```
test/suite/pipeline_tests/
├── oracle/           # Oracle database tests
├── postgres/         # PostgreSQL tests
├── snowflake/        # Snowflake tests
├── kafka/            # Kafka messaging tests
├── salesforce/       # Salesforce mock tests
└── <new_system>/     # Create new folder if needed
```

### Step 2: Create the Test File

**Naming Convention:** `<feature>_<system>.robot`

Examples:
- `data_load_oracle.robot`
- `message_processing_kafka.robot`
- `api_sync_salesforce.robot`

### Step 3: Add Required Settings

```robotframework
*** Settings ***
Documentation    Clear description of the test suite
...              - What pipelines are tested
...              - Prerequisites (services, data)
...              - Expected outcomes

# Import common resources
Resource         ../../resources/common/general.resource
Resource         ../../resources/common/files.resource

# System-specific resources (if any)
Resource         ../../resources/kafka/kafka.resource

# Required libraries
Library          Collections
Library          JSONLibrary
Library          OperatingSystem
```

### Step 4: Define Variables

```robotframework
*** Variables ***
# Test-specific constants
${PIPELINE_NAME}           my_test_pipeline
${EXPECTED_RECORD_COUNT}   100

# Paths (relative to test execution)
${TEST_DATA_PATH}          ${CURDIR}/../test_data

# Timeouts
${PIPELINE_TIMEOUT}        300s
${DB_TIMEOUT}              60s

# Lists and dictionaries
@{EXPECTED_COLUMNS}        id    name    value    timestamp
&{CONNECTION_CONFIG}       host=localhost    port=5432
```

### Step 5: Write Test Cases

```robotframework
*** Test Cases ***
Test Data Load From Source To Target
    [Documentation]    Verifies end-to-end data load from Oracle to Snowflake
    ...                Prerequisites:
    ...                - Oracle container running with test data
    ...                - Snowflake mock container running
    [Tags]    oracle    snowflake    data_load    regression
    [Timeout]    ${PIPELINE_TIMEOUT}

    # Setup
    ${unique_id}=    Get Unique Id

    # Given source data exists
    ${source_count}=    Get Oracle Record Count    source_table
    Should Be True    ${source_count} > 0

    # When pipeline is executed
    Upload And Execute Pipeline    data_load_${unique_id}
    Wait Until Pipeline Completes    data_load_${unique_id}    timeout=300

    # Then data appears in target
    ${target_count}=    Get Snowflake Record Count    target_table
    Should Be Equal As Numbers    ${source_count}    ${target_count}

    [Teardown]    Cleanup Pipeline And Data    data_load_${unique_id}

Test Error Handling For Invalid Data
    [Documentation]    Verifies pipeline handles invalid data gracefully
    [Tags]    oracle    error_handling    negative

    # Given invalid source data
    Insert Invalid Test Record    source_table

    # When pipeline is executed
    ${status}=    Execute Pipeline And Get Status    error_test_pipeline

    # Then pipeline handles error appropriately
    Should Be Equal    ${status}    Failed
    ${error_log}=    Get Pipeline Error Log
    Should Contain    ${error_log}    Invalid data format
```

### Step 6: Implement Keywords

```robotframework
*** Keywords ***
Upload And Execute Pipeline
    [Documentation]    Uploads pipeline and starts execution
    [Arguments]    ${pipeline_name}

    ${pipeline_path}=    Set Variable    ${pipeline_payload_path}/${pipeline_name}.slp
    Upload Pipeline    ${pipeline_path}    ${PROJECT_SPACE}/${PROJECT_NAME}

    ${snode_id}=    Get Pipeline Snode Id    ${pipeline_name}
    Set Test Variable    ${PIPELINE_SNODE_ID}    ${snode_id}

    Execute Pipeline Api    ${snode_id}    ${GROUNDPLEX_NAME}

Wait Until Pipeline Completes
    [Documentation]    Waits for pipeline to complete with timeout
    [Arguments]    ${pipeline_name}    ${timeout}=300

    ${status}=    Set Variable    Running
    ${end_time}=    Evaluate    time.time() + ${timeout}    time

    WHILE    '${status}' == 'Running'
        ${status}=    Get Pipeline Status    ${pipeline_name}
        ${current_time}=    Evaluate    time.time()    time
        IF    ${current_time} > ${end_time}
            Fail    Pipeline timeout after ${timeout} seconds
        END
        Sleep    5s
    END

    RETURN    ${status}

Cleanup Pipeline And Data
    [Documentation]    Cleans up test artifacts
    [Arguments]    ${pipeline_name}

    Run Keyword And Ignore Error    Delete Pipeline By Name    ${pipeline_name}
    Run Keyword And Ignore Error    Delete Test Data    ${pipeline_name}
```

## Tag Guidelines

### Required Tags
Every test should have:
1. **System tag**: `oracle`, `postgres`, `kafka`, etc.
2. **Test type tag**: `smoke`, `regression`, `negative`
3. **Feature tag**: `data_load`, `transformation`, `api_sync`

### Tag Examples
```robotframework
# Smoke test for Oracle data load
[Tags]    oracle    smoke    data_load

# Regression test for Kafka with error handling
[Tags]    kafka    regression    error_handling    messaging

# Integration test spanning multiple systems
[Tags]    oracle    snowflake    integration    etl
```

## Common Patterns

### Pattern 1: Setup-Execute-Verify-Cleanup
```robotframework
Test Pattern Example
    [Setup]    Initialize Test Environment

    # Arrange
    Prepare Source Data

    # Act
    Execute Pipeline

    # Assert
    Verify Target Data

    [Teardown]    Cleanup All Test Data
```

### Pattern 2: Data-Driven Tests
```robotframework
*** Test Cases ***
Test Multiple Data Scenarios
    [Template]    Execute And Verify Pipeline
    # input_file    expected_count    expected_status
    small_data.csv     100    Completed
    medium_data.csv    1000   Completed
    empty_data.csv     0      Completed
    invalid_data.csv   0      Failed

*** Keywords ***
Execute And Verify Pipeline
    [Arguments]    ${input_file}    ${expected_count}    ${expected_status}
    Load Test Data    ${input_file}
    ${status}=    Execute Pipeline    data_processor
    Should Be Equal    ${status}    ${expected_status}
    ${count}=    Get Output Record Count
    Should Be Equal As Numbers    ${count}    ${expected_count}
```

### Pattern 3: Parallel-Safe Tests
```robotframework
*** Test Cases ***
Parallel Safe Test
    [Tags]    parallel_safe

    # Use unique identifiers to avoid conflicts
    ${unique_id}=    Get Unique Id
    ${pipeline_name}=    Set Variable    test_pipeline_${unique_id}
    ${table_name}=    Set Variable    test_table_${unique_id}

    # All resources are unique to this test run
    Create Test Table    ${table_name}
    Upload Pipeline    ${pipeline_name}
    Execute And Verify    ${pipeline_name}    ${table_name}

    [Teardown]    Cleanup Unique Resources    ${pipeline_name}    ${table_name}
```

## Checklist Before Committing

- [ ] Test has clear documentation
- [ ] Appropriate tags are assigned
- [ ] Setup and teardown handle cleanup
- [ ] Variables use meaningful names
- [ ] Error handling is in place
- [ ] Test runs successfully locally
- [ ] Test is idempotent (can run multiple times)
- [ ] No hardcoded credentials or secrets
