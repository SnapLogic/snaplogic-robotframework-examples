*** Settings ***
Documentation    Creates Salesforce account(s) and imports Salesforce pipeline(s) into SnapLogic for testing
...              Sets up account credentials using JSON payload templates with Jinja variable substitution,
...              then uploads pipeline definitions (.slp files) to the specified project location
Resource         snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource         ../../../resources/common/general.resource
Resource         ../../../resources/salesforce/salesforce_mock_keywords.resource
Library          Collections

Suite Setup      Setup Salesforce Tests

*** Variables ***
# Pipeline configuration
${pipeline_name}                salesforce_accounts
${pipeline_file_name}           salesforce_accounts.slp

# Task configuration
${task_name}                    Task

&{task_params_set}
...                             sfdc_acct=../shared/${SALESFORCE_ACCOUNT_NAME}

*** Test Cases ***
Create Salesforce Account
    [Documentation]    Creates a Salesforce account in SnapLogic.
    ...    Uses the Create Account From Template keyword to set up
    ...    account credentials for subsequent pipeline operations.
    ...
    ...    Arguments:
    ...    - ${ACCOUNT_LOCATION_PATH}: Path where account is created
    ...    - ${SALESFORCE_ACCOUNT_PAYLOAD_FILE_NAME}: JSON payload file
    ...    - ${SALESFORCE_ACCOUNT_NAME}: Account name in SnapLogic
    [Tags]    salesforce    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SALESFORCE_ACCOUNT_PAYLOAD_FILE_NAME}    ${SALESFORCE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}

Import Salesforce Accounts Pipeline
    [Documentation]    Imports Salesforce Accounts pipeline file (.slp) into the SnapLogic project space.
    ...    This test case uploads the Salesforce Accounts pipeline definition and deploys it
    ...    to the specified location, making it available for task creation and execution.
    ...
    ...    The salesforce_accounts pipeline performs CRUD operations on Salesforce Account objects:
    ...    JSON Generator → Salesforce Create → Mapper → Salesforce Update → Salesforce Read
    ...
    ...    PREREQUISITES:
    ...    - ${unique_id} - Generated from suite setup (Check connections keyword)
    ...    - Pipeline .slp file must exist in src/pipelines/ directory
    ...    - SnapLogic project and folder structure must be in place
    ...    - Salesforce account must be created before pipeline import (use /create-account)
    ...
    ...    ARGUMENT DETAILS:
    ...    - Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    - Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines will be imported
    ...    - Argument 3: ${pipeline_name} - Logical name for the pipeline (without .slp extension)
    ...    - Argument 4: ${pipeline_file_name} - Physical .slp file name to import
    [Tags]    salesforce    pipeline_import
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}

Create Triggered Task
    [Documentation]    Creates a triggered task for Salesforce pipeline execution and returns task metadata.
    ...    Triggered tasks are on-demand pipeline executions configured with
    ...    specific parameters and notification settings.
    ...
    ...    PREREQUISITES:
    ...    - Pipeline must be imported before task creation
    ...    - ${unique_id} - Generated from suite setup
    ...
    ...    ARGUMENT DETAILS:
    ...    - Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    - Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines are stored
    ...    - Argument 3: ${pipeline_name} - Name of the pipeline to create task for
    ...    - Argument 4: ${task_name} - Name to assign to the triggered task
    ...    - Argument 5: ${GROUNDPLEX_NAME} - Name of the Snaplex where task will execute
    ...    - Argument 6: ${task_params_set} - Dictionary of parameters to pass to pipeline execution
    ...    - Argument 7: ${execution_timeout} (Optional) - Timeout in seconds for task execution
    [Tags]    salesforce    task_creation
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=300

Execute Triggered Task
    [Documentation]    Executes the triggered task with specified parameters and monitors completion.
    ...    This test case runs the Salesforce pipeline through the triggered task,
    ...    optionally overriding task parameters for different execution scenarios.
    ...
    ...    PREREQUISITES:
    ...    - task_payload - Returned from Create Triggered Task test case
    ...    - task_snodeid - Returned from Create Triggered Task test case
    ...    - Task must be in ready state before execution
    ...
    ...    ARGUMENT DETAILS:
    ...    - Argument 1: ${unique_id} - Unique identifier matching the task creation
    ...    - Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic path where pipelines are stored
    ...    - Argument 3: ${pipeline_name} - Name of the pipeline associated with the task
    ...    - Argument 4: ${task_name} - Name of the triggered task to execute
    [Tags]    salesforce    task_execution
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}

Verify Salesforce Pipeline Has No Errors
    [Documentation]    Validates that the Salesforce pipeline execution completed without errors.
    ...    Passes the full task name to Validate Pipeline Has No Errors, which internally:
    ...    1. Retrieves the runtime ID from task history
    ...    2. Sets ${runtime_id} as a suite variable for downstream test cases
    ...    3. Logs snap statistics summary table
    ...    4. Checks all snaps for error documents
    ...
    ...    Pipeline flow: JSON Generator → Salesforce Create → Mapper → Salesforce Update → Salesforce Read
    ...
    ...    PREREQUISITES:
    ...    - Execute Triggered Task must have completed successfully
    ...    - Task snode_id must be available as a suite variable
    [Tags]    salesforce    verification
    Validate Pipeline Has No Errors    ${pipeline_name}    ${task_name}    ${unique_id}

Verify Salesforce CRUD Snap Document Counts
    [Documentation]    Validates document counts for each snap in the Salesforce CRUD pipeline.
    ...    Verifies that data was successfully created and updated by checking that each
    ...    snap in the pipeline processed the expected number of documents.
    ...
    ...    Pipeline flow verified:
    ...    • JSON Generator: Generates input records (output should match expected record count)
    ...    • Salesforce Create: Creates Account records in Salesforce (mock)
    ...    • Mapper: Transforms created records for update operation
    ...    • Salesforce Update: Updates the created Account records
    ...    • Salesforce Read: Reads back the updated records for verification
    ...
    ...    PREREQUISITES:
    ...    - ${runtime_id} must be set from the previous verification test case
    ...
    ...    NOTE: Snap labels below must match the actual snap labels in the pipeline.
    ...    Run 'Log Snap Statistics Summary' first to identify exact snap labels.
    ...    Adjust expected counts based on the number of records your pipeline processes.
    [Tags]    salesforce    verification
    # Verify JSON Generator produced expected output documents
    Validate Snap Document Count    ${runtime_id}    JSON Generator    expected_output=1    expected_error=0
    # Verify Salesforce Create processed all input records with no errors
    Validate Snap Document Count    ${runtime_id}    Salesforce Create    expected_input=1    expected_output=1    expected_error=0
    # Verify Mapper transformed all records
    Validate Snap Document Count    ${runtime_id}    Mapper    expected_input=1    expected_output=1    expected_error=0
    # Verify Salesforce Update applied updates with no errors
    Validate Snap Document Count    ${runtime_id}    Salesforce Update    expected_input=1    expected_output=1    expected_error=0
    # Verify Salesforce Read retrieved all updated records
    Validate Snap Document Count    ${runtime_id}    Salesforce Read    expected_input=1    expected_output=1    expected_error=0

Verify Account Records Exist In Salesforce Mock
    [Documentation]    Queries the Django Salesforce mock server to verify that Account records
    ...    were created by the pipeline. Uses SOQL to query the mock's in-memory database
    ...    and validates the expected number of records exist.
    ...
    ...    Pipeline flow: JSON Generator → Salesforce Create → Mapper → Salesforce Update → Salesforce Read
    ...    After execution, the mock's in-memory DB should contain the created/updated Account records.
    ...
    ...    PREREQUISITES:
    ...    - Execute Triggered Task must have completed successfully
    ...    - Django Salesforce mock must be running and accessible
    [Tags]    salesforce    mock_verification
    # Query Account records from Django mock and verify count
    ${accounts}=    Verify Salesforce Account Record Count    expected_count=1
    Set Suite Variable    ${sfdc_account_records}    ${accounts}
    # Log the full record for debugging
    Log    Account record from mock: ${accounts}[0]    console=yes

Verify Account Record Field Values In Salesforce Mock
    [Documentation]    Verifies the final field values of Account records in the Django mock server.
    ...    After the full pipeline runs (Create → Mapper → Update → Read),
    ...    the records in the mock contain the FINAL state — including any updates
    ...    applied by the Mapper and Salesforce Update snaps.
    ...
    ...    Expected final values (after Mapper → Update):
    ...    - Name: Updated Name_Slim (transformed by Mapper from original "Slim1")
    ...    - Industry: Technology (unchanged from Create)
    ...
    ...    PREREQUISITES:
    ...    - 'Verify Account Records Exist In Salesforce Mock' must have run first
    ...    - ${sfdc_account_records} suite variable must be set
    [Tags]    salesforce    mock_verification
    # Verify the final field values after the pipeline's Create → Update cycle
    Verify Salesforce Record Field Value    ${sfdc_account_records}    0    Name    Updated Name_Slim
    Verify Salesforce Record Field Value    ${sfdc_account_records}    0    Industry    Technology
    Log    Account verified: Final state shows updated fields from Mapper → Salesforce Update    console=yes

*** Keywords ***
Setup Salesforce Tests
    [Documentation]    Generates a unique test execution ID and verifies Django mock server connectivity
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Test ID: ${unique_id}    console=yes
    # Verify Django Salesforce mock is accessible and clear in-memory data for clean test run
    Verify Salesforce Mock Is Healthy
    Reset Salesforce Mock Data
