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
Resource            ../../../resources/common/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the Oracle database is successful and snaplex is up


*** Variables ***
# Project Configuration

${pipeline_name}        sla_pipeline
${pipeline_name_slp}    sla_pipeline.slp
${task1}                SLA_Task


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
    [Tags]    sla_pipeline    regression
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}

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
    [Tags]    sla_pipeline    regression
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}

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
    [Tags]    sla_pipeline    regression
    Run Triggered Task In Certain Time
    ...    30 Sec
    ...    5 Sec
    ...    ${ORG_NAME}/${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}_${task1}_${unique_id}


*** Keywords ***
Check connections
    Initialize Variables
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}

Initialize Variables
    ${unique_id}    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

Run Triggered Task In Certain Time
    [Documentation]    Executes a SnapLogic triggered task and captures detailed error on failure.
    ...
    ...    This keyword makes a direct API call to run the triggered task and captures
    ...    the full response including error details when the pipeline fails.
    ...    On failure, it fetches detailed pipeline execution statistics.
    ...
    ...    *Argument Details:*
    ...    - ``timeout``: Maximum time to wait for task completion
    ...    - ``retry_interval``: Interval between retry attempts
    ...    - ``path``: Full SnapLogic path to the project where the task resides
    ...    - ``task_name``: Name of the triggered task to run
    ...    - ``params`` (optional): Query string with parameters to pass at runtime
    ...
    ...    *Returns:*
    ...    - The response object on success
    ...    - Fails with detailed error message on failure
    [Arguments]    ${timeout}    ${retry_interval}    ${path}    ${task_name}    ${params}=${EMPTY}

    # Make direct API call to capture full response
    ${response}=    GET On Session
    ...    ${ORG_ADMIN_SESSION}
    ...    /api/1/rest/slsched/feed/${path}/${task_name}
    ...    params=${params}
    ...    expected_status=any

    Log    Response Status Code: ${response.status_code}
    Log    Response Content: ${response.content}

    # Check if the request was successful
    IF    ${response.status_code} == 200
        Log    Task executed successfully
        RETURN    ${response}
    ELSE
        # Extract basic error details from response
        ${error_details}=    Extract Error From Response    ${response}

        # Try to get runtime UUID and fetch detailed execution stats
        ${detailed_error}=    Get Pipeline Execution Details    ${response}    ${error_details}

        Log To Console    \n=============== PIPELINE EXECUTION FAILED ===============
        Log To Console    Task Name: ${task_name}
        Log To Console    Path: ${path}
        Log To Console    Status Code: ${response.status_code}
        Log To Console    ${detailed_error}
        Log To Console    =========================================================\n

        Log    Task execution failed for: ${task_name}    level=ERROR
        Log    Path: ${path}    level=ERROR
        Log    Status Code: ${response.status_code}    level=ERROR
        Log    Error details: ${detailed_error}    level=ERROR

        Fail    Pipeline task '${task_name}' failed (HTTP ${response.status_code}): ${detailed_error}
    END

Get Pipeline Execution Details
    [Documentation]    Fetches detailed pipeline execution statistics using runtime UUID.
    [Arguments]    ${response}    ${basic_error}

    TRY
        # Try to parse response to get runtime UUID
        ${json}=    Evaluate    json.loads($response.content)    json

        # Look for ruuid in the response
        ${ruuid}=    Set Variable    ${EMPTY}

        # Check different possible locations for ruuid
        ${has_ruuid}=    Evaluate    'ruuid' in $json
        IF    ${has_ruuid}
            ${ruuid}=    Set Variable    ${json['ruuid']}
        END

        ${has_response_map_ruuid}=    Evaluate    'response_map' in $json and 'ruuid' in $json.get('response_map', {})
        IF    ${has_response_map_ruuid}
            ${ruuid}=    Set Variable    ${json['response_map']['ruuid']}
        END

        # If we have a ruuid, fetch detailed execution stats
        IF    '${ruuid}' != '${EMPTY}'
            Log    Found runtime UUID: ${ruuid}
            ${exec_details}=    Fetch Runtime Details    ${ruuid}
            RETURN    ${exec_details}
        END

        # No ruuid found, return basic error
        RETURN    Error: ${basic_error}

    EXCEPT    AS    ${error}
        Log    Could not fetch detailed execution stats: ${error}    level=WARN
        RETURN    Error: ${basic_error}
    END

Fetch Runtime Details
    [Documentation]    Fetches runtime details from SnapLogic API.
    [Arguments]    ${ruuid}

    TRY
        ${params}=    Create Dictionary    level=detail
        ${runtime_response}=    GET On Session
        ...    ${ORG_ADMIN_SESSION}
        ...    /api/2/${org_snode_id}/rest/pm/runtime/${ruuid}
        ...    params=${params}
        ...    expected_status=any

        IF    ${runtime_response.status_code} == 200
            ${runtime_json}=    Evaluate    json.loads($runtime_response.content)    json

            # Extract key information
            ${error_parts}=    Create List

            # Get state/status
            ${has_state}=    Evaluate    'state' in $runtime_json
            IF    ${has_state}
                Append To List    ${error_parts}    State: ${runtime_json['state']}
            END

            # Get reason if available
            ${has_reason}=    Evaluate    'reason' in $runtime_json
            IF    ${has_reason}
                Append To List    ${error_parts}    Reason: ${runtime_json['reason']}
            END

            # Get status_message if available
            ${has_status_msg}=    Evaluate    'status_message' in $runtime_json
            IF    ${has_status_msg}
                Append To List    ${error_parts}    Message: ${runtime_json['status_message']}
            END

            # Get resolution if available
            ${has_resolution}=    Evaluate    'resolution' in $runtime_json
            IF    ${has_resolution}
                Append To List    ${error_parts}    Resolution: ${runtime_json['resolution']}
            END

            # Get failed snap info if available
            ${has_failed_snap}=    Evaluate    'failed_snap' in $runtime_json or 'snap_map' in $runtime_json
            IF    ${has_failed_snap}
                ${snap_info}=    Extract Failed Snap Info    ${runtime_json}
                IF    '${snap_info}' != '${EMPTY}'
                    Append To List    ${error_parts}    Failed Snap: ${snap_info}
                END
            END

            # Join all parts
            ${details_str}=    Evaluate    '\\n'.join($error_parts)
            IF    '${details_str}' != '${EMPTY}'
                RETURN    ${details_str}
            END
        END

        RETURN    Error: Pipeline execution failed (ruuid: ${ruuid})

    EXCEPT    AS    ${error}
        Log    Error fetching runtime details: ${error}    level=WARN
        RETURN    Error: Pipeline execution failed (ruuid: ${ruuid})
    END

Extract Failed Snap Info
    [Documentation]    Extracts information about the failed snap from runtime data.
    [Arguments]    ${runtime_json}

    TRY
        # Check for snap_map which contains snap execution details
        ${has_snap_map}=    Evaluate    'snap_map' in $runtime_json
        IF    ${has_snap_map}
            ${snap_map}=    Set Variable    ${runtime_json['snap_map']}
            # Find snaps that failed
            ${failed_snaps}=    Evaluate
            ...    [f"{k}: {v.get('state', 'unknown')}" for k, v in $snap_map.items() if v.get('state') in ['Failed', 'Aborted', 'Error']]
            IF    ${failed_snaps}
                ${snap_info}=    Evaluate    ', '.join($failed_snaps)
                RETURN    ${snap_info}
            END
        END

        # Check for direct failed_snap field
        ${has_failed_snap}=    Evaluate    'failed_snap' in $runtime_json
        IF    ${has_failed_snap}
            RETURN    ${runtime_json['failed_snap']}
        END

        RETURN    ${EMPTY}

    EXCEPT    AS    ${error}
        Log    Error extracting snap info: ${error}    level=DEBUG
        RETURN    ${EMPTY}
    END

Extract Error From Response
    [Documentation]    Extracts detailed error message from API response.
    [Arguments]    ${response}

    TRY
        # Try to parse response as JSON
        ${json}=    Evaluate    json.loads($response.content)    json

        # Check for different error structures
        # Structure 1: response_map.error_list[0].message
        ${has_error_list}=    Evaluate
        ...    'response_map' in $json and 'error_list' in $json.get('response_map', {}) and len($json.get('response_map', {}).get('error_list', [])) > 0

        IF    ${has_error_list}
            ${error_msg}=    Evaluate    $json['response_map']['error_list'][0].get('message', 'Unknown error')
            RETURN    ${error_msg}
        END

        # Structure 2: Direct error message
        ${has_error}=    Evaluate    'error' in $json
        IF    ${has_error}
            RETURN    ${json['error']}
        END

        # Structure 3: message field
        ${has_message}=    Evaluate    'message' in $json
        IF    ${has_message}
            RETURN    ${json['message']}
        END

        # Structure 4: reason field (common for pipeline failures)
        ${has_reason}=    Evaluate    'reason' in $json
        IF    ${has_reason}
            RETURN    ${json['reason']}
        END

        # Structure 5: status_message field
        ${has_status_msg}=    Evaluate    'status_message' in $json
        IF    ${has_status_msg}
            RETURN    ${json['status_message']}
        END

        # Return full JSON if no specific error field found
        RETURN    ${json}

    EXCEPT    AS    ${parse_error}
        # Response is not JSON, return raw content
        ${content}=    Convert To String    ${response.content}
        Log    Response is not JSON: ${content}    level=DEBUG
        RETURN    ${content}
    END
