*** Settings ***
Documentation       Test Suite for Oracle Database Integration with Pipeline Tasks
...                 This suite validates Oracle database integration by:
...                 1. Creating necessary database tables and procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the Oracle database is successful and snaplex is up


*** Variables ***
# Project Configuration
${project_path}             ${org_name}/${project_space}/${project_name}
${pipeline_file_path}       ${CURDIR}/../../../src/pipelines
${pipeline_name}            sla_pipeline
${pipeline_name_slp}        sla_pipeline.slp
${task1}                    SLA_Task


*** Test Cases ***
Import Pipelines
    [Documentation]    Imports the SLA pipeline into the SnapLogic environment for testing.
    ...
    ...    This test case performs the initial setup by importing the pipeline file from the
    ...    source directory into the configured project space. This is a prerequisite step
    ...    for all subsequent pipeline operations and task creation.
    ...
    ...    **Returns:**
    ...    - pipeline_snodeid: Pipeline node ID used for subsequent task creation
    ...
    ...    **Expected Results:**
    ...    - Pipeline is successfully imported without errors
    ...    - pipeline node ID are generated and available for use
    [Tags]    import_pipeline2    sla_pipeline
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates a triggered task for the imported SLA pipeline.
    ...
    ...    This test case creates a triggered task that can be executed on-demand to run
    ...    the SLA pipeline. The triggered task serves as an execution endpoint that can
    ...    be invoked programmatically or manually to process data through the pipeline.
    ...
    ...
    ...    **Returns:**
    ...    - task_payload: Task configuration data for parameter updates
    ...    - task_snodeid: Task node ID used for task management operations
    ...
    ...    **Expected Results:**
    ...    - Triggered task is successfully created
    ...    - Task metadata is properly configured and accessible
    ...    - Task is ready for execution
    [Tags]    create_triggered_task    sla_pipeline
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}

Execute Trigger Task Within Certain Time
    [Documentation]    Executes the triggered task and validates completion within specified time limits.
    ...
    ...    This test case executes the previously created triggered task and monitors its
    ...    execution to ensure it completes successfully within the defined time constraints.
    ...    This validates both the pipeline functionality and performance characteristics.
    ...    **Test Configuration:**
    ...    - Maximum execution time: 30 seconds
    ...    - Retry interval: 5 seconds
    ...    - Task path: Project path with unique identifier
    ...
    ...    **Expected Results:**
    ...    - Task executes successfully within the time limit
    ...    - No execution errors or failures occur
    ...    - Task status indicates successful completion
    ...    - Pipeline processes data as expected
    [Tags]    create_triggered_task    sla_pipeline
    Run Triggered Task In Certain Time
    ...    30 Sec
    ...    5 Sec
    ...    ${project_path}
    ...    ${pipeline_name}_${task1}_${unique_id}


*** Keywords ***
Check connections
    Initialize Variables
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}

Initialize Variables
    ${unique_id}    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

Run Triggered Task In Certain Time
    [Documentation]    Executes a SnapLogic triggered task located at the given path, with optional query parameters.
    ...
    ...    This keyword wraps the `Run Triggered Task Api` call with automatic retry logic using
    ...    `Wait Until Keyword Succeeds`. It retries the task execution up to 30 seconds (every 5 seconds)
    ...    in case of transient failures (e.g., network latency or temporary unavailability).
    ...
    ...    Optional parameters can be passed as a URL-style query string (e.g., `param1=value1&param2=value2`).
    ...    This is useful when triggering pipelines that accept runtime parameters via task execution.
    ...
    ...    *Argument Details:*
    ...    - ``path``: Full SnapLogic path to the project where the task resides (e.g., `/org/space/project`)
    ...    - ``task_name``: Name of the triggered task to run
    ...    - ``params`` (optional): Query string with parameters to pass at runtime (e.g., `debug=true&env=dev`)
    ...
    ...    *Returns:*
    ...    - The response object returned from the `Run Triggered Task Api`
    ...
    ...    *Behavior:*
    ...    - Retries the task run for up to 30 seconds (retry interval: 5 seconds)
    ...    - Passes parameters (if provided) to the task at execution time
    ...    - Returns the HTTP response object from the API
    ...    *Example:*
    ...    | ${task_response} | Run Triggered Task | /org/project | My Task | param1=value1&param2=value2 |
    [Arguments]    ${timeout}    ${retry_interval}    ${path}    ${task_name}    ${params}=${EMPTY}
    ${response}    Wait Until Keyword Succeeds
    ...    ${timeout}
    ...    ${retry_interval}
    ...    Run Triggered Task Api
    ...    ${path}
    ...    ${task_name}
    ...    ${params}
    RETURN    ${response}
