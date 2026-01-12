*** Settings ***
Documentation       Snowflake Database Integration Tests
...                 Using snowflake_keywords.resource which wraps the SnowflakeHelper Python library
...                 Environment variables are automatically loaded from .env file via Docker
...
...                 📚 Documentation Reference:
...                 For standardized test case documentation format and guidelines, refer to:
...                 README/How To Guides/test_documentation_guides/generic_test_case_documentation_template.md

Library             Collections
Library             OperatingSystem
Resource            ../../../resources/snowflake/snowflake_keywords_databaselib.resource    # For Snowflake connection
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/common/files.resource
Resource            ../../../resources/common/sql_table_operations.resource    # Generic SQL operations
Resource            ../../test_data/queries/snowflake_queries.resource    # Snowflake SQL queries

Suite Setup         Check connections    # Check if the connection to the Snowflake database is successful and snaplex is up


*** Variables ***
${upload_source_files_path}         ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake
${upload_files_for_file_reader}     ${CURDIR}/../../test_data/actual_expected_data/expected_output/file_reader

######################### Pipeline details ###########################
# Pipeline name and file details
${pipeline_name3}                   filereader
${pipeline_file_name3}              filereader.slp

# Task Details for created triggered task from the above pipeline
${task_name3}                       Task3
@{notification_states3}             Completed    Failed
&{task_notifications3}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states3}

&{task_params_set3}
...                                 test_json_file=../shared/test1.json


*** Test Cases ***
Upload Multiple Files
    [Documentation]    Data-driven test case using template format for multiple file upload scenarios
    ...    Each row represents a different upload configuration
    [Tags]    filereader    upload_multiple_files
    [Template]    Upload Files To SnapLogic From Template

    # Test with wildcards (upload all .csv files form a directory)
    ${upload_source_files_path}    *.csv    ${ACCOUNT_LOCATION_PATH}
    ${upload_files_for_file_reader}    *.json    ${ACCOUNT_LOCATION_PATH}

Import Pipeline
    [Documentation]    Imports Snowflake pipeline files (.slp) into the SnapLogic project space.
    ...    This test case uploads pipeline definitions and deploys them to the specified location,
    ...    making them available for task creation and execution.
    ...
    ...    📋 PREREQUISITES:
    ...    • ${unique_id} - Generated from suite setup (Check connections keyword)
    ...    • Pipeline .slp files must exist in the test_data directory
    ...    • SnapLogic project and folder structure must be in place
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: ${unique_id} - Unique test execution identifier for naming/tracking
    ...    (Generated automatically in suite setup)
    ...    • Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic folder path where pipelines will be imported
    ...    (e.g., /org/project/pipelines or /shared/pipelines)
    ...    • Argument 3: ${pipeline_name} - Logical name for the pipeline (without .slp extension)
    ...    (e.g., snowflake_pl1, data_processor, etl_pipeline)
    ...    • Argument 4: ${pipeline_file_name} - Physical .slp file name to import
    ...    (e.g., snowflake1.slp, pipeline.slp)
    ...
    ...    💡 TO IMPORT MULTIPLE PIPELINES:
    ...    You can import multiple pipeline files by adding more records to this template.
    ...    Each record represents one pipeline import operation.
    [Tags]    filereader
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name3}    ${pipeline_file_name3}

Create Triggered_task
    [Documentation]    Creates a triggered task for pipeline execution and returns task metadata.
    ...    Triggered tasks are scheduled or on-demand pipeline executions configured with
    ...    specific parameters and notification settings.
    ...
    ...    📋 PREREQUISITES:
    ...    • unique_id - Generated from Import Pipelines test case
    ...    • pipeline_snodeid - Created during pipeline import
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: ${unique_id} - Unique identifier for test execution (generated in suite setup)
    ...    • Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic path where pipelines are stored
    ...    • Argument 3: ${pipeline_name} - Name of the pipeline to create task for
    ...    • Argument 4: ${task_name} - Name to assign to the triggered task
    ...    • Argument 5: ${GROUNDPLEX_NAME} - Name of the Snaplex where task will execute (optional- can be omitted)
    ...    • Argument 6: ${task_params_set} - Dictionary of parameters to pass to pipeline execution
    ...    (e.g., snowflake_acct, schema_name, table_name)-(optional- can be omitted)
    ...    • Argument 7: ${task_notifications} (Optional) - Dictionary containing notification settings
    ...    (recipients and states for task completion/failure alerts)-(optional- can be omitted)
    [Tags]    filereader    regressionx
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name3}    ${task_name3}    ${GROUNDPLEX_NAME}    ${task_params_set3}

Execute Triggered Task For All Files
    [Documentation]    Executes the triggered task with specified parameters
    [Tags]    filereader
    [Template]    Execute Triggered Task For All Files
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name3}    ${task_name3}    ${upload_files_for_file_reader}


*** Keywords ***
Check connections
    [Documentation]    Verifies snowflake database connection and Snaplex availability
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

Execute Triggered Task For All Files
    [Documentation]    Execute triggered task for every file in the directory
    [Arguments]
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${upload_files_path}
    Log    🚀 Starting execution of triggered task for all files in ${upload_files_path}

    # Get all JSON files from your directory
    @{json_files}=    List Files In Directory    ${upload_files_path}    pattern=*.json

    Log    Found ${json_files.__len__()} JSON files to process    console=yes

    # Execute task for each file
    FOR    ${filename}    IN    @{json_files}
        Log    🚀 Processing: ${filename}    console=yes

        Run Triggered Task With Parameters From Template
        ...    ${unique_id}
        ...    ${PIPELINES_LOCATION_PATH}
        ...    ${pipeline_name}
        ...    ${task_name}
        ...    test_json_file=${upload_files_path}/${filename}    # ← FULL PATH

        Log    ✅ Completed: ${filename}    console=yes
    END
