---
name: robot-expert
description: Robot Framework expert for SnapLogic pipeline testing conventions. Use when the user asks about best practices, naming conventions, tags, variable patterns, or database/messaging test patterns.
user-invocable: true
---

You are an expert in Robot Framework and specifically the conventions used in this SnapLogic pipeline testing project. Follow these guidelines when working with Robot Framework test files.

## File Structure and Organization

### Directory Layout
```
test/
├── suite/                      # Test suites
│   ├── __init__.robot          # Suite setup (loads env, validates, sets up project)
│   ├── pipeline_tests/         # Tests by system type
│   │   ├── oracle/
│   │   ├── postgres/
│   │   ├── snowflake/
│   │   ├── kafka/
│   │   └── ...
│   └── test_data/              # Test data files
│       └── accounts_payload/   # Account JSON configs
├── resources/                  # Shared keywords
│   └── common/
│       ├── general.resource    # General utilities
│       ├── database.resource   # Database operations
│       ├── files.resource      # File operations
│       └── sql_table_operations.resource
└── libraries/                  # Custom Python libraries
```

## Test File Conventions

### Standard Test File Structure
```robotframework
*** Settings ***
Documentation    Brief description of what this test suite covers
Resource         ../resources/common/general.resource
Library          Collections
Library          JSONLibrary

Suite Setup      Custom Suite Setup
Suite Teardown   Custom Suite Teardown

*** Variables ***
${PIPELINE_NAME}    my_pipeline
@{REQUIRED_TAGS}    oracle    database

*** Test Cases ***
Test Pipeline Executes Successfully
    [Documentation]    Verify pipeline completes without errors
    [Tags]    oracle    smoke    pipeline_execution
    Given Pipeline Is Uploaded    ${PIPELINE_NAME}
    When Pipeline Is Executed
    Then Pipeline Status Should Be    Completed

*** Keywords ***
Custom Suite Setup
    Log To Console    Starting test suite...

Custom Suite Teardown
    Delete Test Artifacts
```

### Naming Conventions
- **Test Files**: `<feature>_<system>.robot` (e.g., `data_load_oracle.robot`)
- **Test Cases**: Use BDD style with Given/When/Then where appropriate
- **Keywords**: Use Title Case with spaces (e.g., `Upload Pipeline To Project`)
- **Variables**: UPPER_CASE with underscores (e.g., `${PIPELINE_NAME}`)
- **Tags**: lowercase with underscores (e.g., `oracle`, `smoke`, `data_load`)

## Tags System

### Standard Tags
| Tag | Purpose |
|-----|---------|
| `oracle`, `postgres`, `snowflake`, etc. | System type |
| `smoke` | Quick validation tests |
| `regression` | Full regression suite |
| `createplex` | Groundplex setup |
| `verify_project_space_exists` | Project validation |
| `export_assets`, `import_assets` | Asset operations |
| `upload_pipeline` | Pipeline upload tests |

### Using Tags
```bash
# Run single tag
make robot-run-tests TAGS="oracle"

# Run multiple tags (OR logic)
make robot-run-tests TAGS="oracle,postgres"
```

## Common Keywords

### Environment Setup (from __init__.robot)
```robotframework
Load Environment Variables      # Loads all .env files
Validate Environment Variables  # Checks required vars exist
Set Up Global Variables         # Makes paths globally available
```

### Pipeline Operations
```robotframework
# Upload and execute pipeline
Upload Pipeline    ${pipeline_path}    ${project_path}
Execute Pipeline    ${pipeline_snode_id}    ${snaplex_label}
Get Pipeline Status    ${runtime_path}

# Cleanup
Delete Pipeline Api    ${snode_id}
Delete Pipelines    ${pipelines_list}
Delete All Tasks For Pipelines    ${pipelines}
```

### Asset Operations
```robotframework
Delete Assets    ${path}    ${asset_type}
Delete Asset    ${path}    ${asset_name}    ${asset_type}
Get Project List    ${org}    ${path}
```

### Utility Keywords
```robotframework
Get Unique Id    # Returns timestamp-based unique ID
```

## Variable Patterns

### Global Variables (from __init__.robot)
```robotframework
${URL}                          # SnapLogic URL
${ORG_ADMIN_USER}               # Admin username
${ORG_ADMIN_PASSWORD}           # Admin password
${ORG_NAME}                     # Organization name
${PROJECT_SPACE}                # Project space name
${PROJECT_NAME}                 # Project name
${GROUNDPLEX_NAME}              # Groundplex name
${account_payload_path}         # Path to account JSON files
${pipeline_payload_path}        # Path to pipeline files
${env_file_path}                # Path to .env file
```

### Dynamic Variables
```robotframework
# Pipeline snode_id pattern: ${pipeline_name}_${unique_id}_snodeid
${my_pipeline_20240101_snodeid}

# Task snode_id pattern: ${pipeline_name}_${task_name}_${unique_id}_snodeid
${my_pipeline_task1_20240101_snodeid}
```

## Best Practices

### 1. Always Use Tags
```robotframework
Test My Feature
    [Tags]    oracle    smoke    feature_name
    # Test implementation
```

### 2. Document Tests
```robotframework
Test Data Transformation
    [Documentation]    Verifies that the pipeline correctly transforms
    ...                source data from Oracle to the target format.
    ...                Prerequisites: Oracle container running
    [Tags]    oracle    transformation
```

### 3. Use Setup/Teardown
```robotframework
*** Test Cases ***
Test With Cleanup
    [Setup]    Prepare Test Data
    [Teardown]    Cleanup Test Artifacts
    # Test steps
```

### 4. Handle Errors Gracefully
```robotframework
Safe Delete Pipeline
    ${status}    ${msg}=    Run Keyword And Ignore Error
    ...    Delete Pipeline Api    ${snode_id}
    IF    '${status}' == 'FAIL'
        Log    Pipeline deletion failed: ${msg}    level=WARN
    END
```

### 5. Log Important Information
```robotframework
Log To Console    Starting pipeline execution...
Log    Pipeline ID: ${pipeline_id}    level=INFO
```

## Database Test Patterns

### Oracle Test Example
```robotframework
*** Test Cases ***
Test Oracle Data Load
    [Tags]    oracle    data_load
    [Setup]    Start Oracle Container

    # Prepare source data
    Insert Test Data Into Oracle    ${test_data}

    # Execute pipeline
    ${unique_id}=    Get Unique Id
    Upload And Execute Pipeline    oracle_load_${unique_id}

    # Verify results
    Verify Target Table Has Records    ${expected_count}

    [Teardown]    Cleanup Oracle Test Data
```

## Messaging Test Patterns

### Kafka Test Example
```robotframework
*** Test Cases ***
Test Kafka Message Processing
    [Tags]    kafka    messaging
    [Setup]    Ensure Kafka Topics Exist

    # Publish test messages
    Publish Messages To Kafka    ${topic}    ${messages}

    # Execute consumer pipeline
    Execute Kafka Consumer Pipeline

    # Verify processing
    Verify Messages Processed    ${expected_count}
```

## Writing New Tests

When creating a new test:

1. **Choose the right location**: `test/suite/pipeline_tests/<system>/`
2. **Use existing resources**: Import from `test/resources/common/`
3. **Add appropriate tags**: System type + test type + feature
4. **Include documentation**: What the test does and prerequisites
5. **Handle cleanup**: Use teardown to clean up test artifacts
6. **Follow naming conventions**: Consistent with existing tests
