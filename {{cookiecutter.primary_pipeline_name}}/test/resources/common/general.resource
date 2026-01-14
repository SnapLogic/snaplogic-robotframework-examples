*** Settings ***
Documentation       Common Used Keywords for API Testing
...                 This resource file contains high-level keywords that build upon the API keywords.
...                 Keywords cover project setup, account management, file operations, and task execution.

Library             Collections
Library             DateTime
Library             OperatingSystem
Library             JSONLibrary
Library             RequestsLibrary
Resource            files.resource
Resource            sql_table_operations.resource
Resource            database.resource


*** Keywords ***
Get Unique Id
    [Documentation]    Generates a unique ID using the current timestamp.
    ...
    ...    *Returns:*
    ...    - A string containing a unique ID based on the current date and time
    ...
    ...    *Example:*
    ...    | ${unique_id} | Get Unique Id |
    ${UNIQUE_ID}=    Get Current Date    result_format=%Y%m%d%H%M%S%f
    RETURN    ${UNIQUE_ID}

Delete All Tasks For Pipelines
    [Documentation]    Deletes all tasks for multiple pipelines with different unique_ids.
    ...
    ...    *Arguments:*
    ...    - ``pipelines``: List of [unique_id, pipeline_name] pairs
    ...    - ``soft_delete``: Optional boolean flag for soft delete (default: true)
    ...    - ``expected_status``: Expected HTTP status code (default: 200)
    ...
    ...    *Returns:*
    ...    - List of response objects from the API calls
    ...
    ...    *Example:*
    ...    | @{p1}= | Create List | ${ID1} | snowflake_pipeline |
    ...    | @{p2}= | Create List | ${ID2} | kafka_pipeline |
    ...    | @{pipelines}= | Create List | ${p1} | ${p2} |
    ...    | Delete All Tasks For Pipelines | ${pipelines} |
    [Arguments]    ${pipelines}    ${soft_delete}=true    ${expected_status}=200

    ${all_variables}=    Get Variables
    @{responses}=    Create List
    ${total_count}=    Set Variable    0

    FOR    ${pipeline}    IN    @{pipelines}
        ${unique_id}=    Set Variable    ${pipeline}[0]
        ${pipeline_name}=    Set Variable    ${pipeline}[1]
        ${count}=    Set Variable    0

        FOR    ${var_name}    ${var_value}    IN    &{all_variables}
            ${is_match}=    Run Keyword And Return Status
            ...    Should Match    ${var_name}    \${${pipeline_name}_*_${unique_id}_snodeid}

            IF    ${is_match}
                # Extract full task name: pipeline_name_task_name_unique_id
                ${task_name}=    Replace String    ${var_name}    \${    ${EMPTY}
                ${task_name}=    Replace String    ${task_name}    }    ${EMPTY}
                ${task_name}=    Replace String    ${task_name}    _snodeid    ${EMPTY}

                Log    Deleting Task: ${task_name} (snode_id: ${var_value})    console=yes
                ${response}=    Delete Task Api    ${var_value}    ${soft_delete}    ${expected_status}
                Append To List    ${responses}    ${response}
                Log    Successfully deleted Task: ${task_name}    console=yes
                ${count}=    Evaluate    ${count} + 1
            END
        END

        Log    Deleted ${count} task(s) for pipeline: ${pipeline_name}_${unique_id}    console=yes
        ${total_count}=    Evaluate    ${total_count} + ${count}
    END

    Log    Total deleted: ${total_count} task(s) for ${pipelines.__len__()} pipeline(s)    console=yes
    RETURN    ${responses}

Delete Pipelines
    [Documentation]    Deletes multiple pipelines with different unique_ids.
    ...
    ...    *Arguments:*
    ...    - ``pipelines``: List of [unique_id, pipeline_name] pairs
    ...    - ``expected_status``: Expected HTTP status code (default: 200)
    ...
    ...    *Returns:*
    ...    - List of response objects from the API calls
    ...
    ...    *Example:*
    ...    | @{p1}= | Create List | ${ID1} | snowflake_pipeline |
    ...    | @{p2}= | Create List | ${ID2} | kafka_pipeline |
    ...    | @{pipelines}= | Create List | ${p1} | ${p2} |
    ...    | Delete Pipelines | ${pipelines} |
    [Arguments]    ${pipelines}    ${expected_status}=200

    @{responses}=    Create List

    FOR    ${pipeline}    IN    @{pipelines}
        ${unique_id}=    Set Variable    ${pipeline}[0]
        ${pipeline_name}=    Set Variable    ${pipeline}[1]
        ${full_pipeline_name}=    Set Variable    ${pipeline_name}_${unique_id}
        ${pipeline_snode_id}=    Get Variable Value    ${${full_pipeline_name}_snodeid}

        IF    '${pipeline_snode_id}' != 'None'
            Log    Deleting Pipeline: ${full_pipeline_name} (snode_id: ${pipeline_snode_id})    console=yes
            ${response}=    Delete Pipeline Api    ${pipeline_snode_id}    ${expected_status}
            Append To List    ${responses}    ${response}
            Log    Successfully deleted Pipeline: ${full_pipeline_name}    console=yes
        ELSE
            Log    Pipeline not found: ${full_pipeline_name}    console=yes    level=WARN
        END
    END

    ${count}=    Get Length    ${responses}
    Log    Deleted ${count} pipeline(s)    console=yes
    RETURN    ${responses}

Delete Assets
    [Documentation]    Deletes all assets of a specified type from the given path.
    ...
    ...    *Arguments:*
    ...    - ``path``: Path to the location containing assets to delete
    ...    - ``asset_type``: Type of asset to delete (File, Account, Pipeline, etc.)
    ...
    ...    *Returns:*
    ...    - None
    ...
    ...    *Example:*
    ...    | Delete Assets | my-org/project-space/files | File |
    ...    | Delete Assets | my-org/project-space/accounts | Account |
    ...    | Delete Assets | my-org/project-space/pipelines | Pipeline |
    [Arguments]    ${path}    ${asset_type}
    Log    🗑️ Deleting all ${asset_type}s from ${path}...    console=yes

    ${entries}=    Get Project List    ${ORG_NAME}    ${path}

    FOR    ${entry}    IN    @{entries}
        IF    '${entry}[asset_type]' == '${asset_type}'
            ${asset_name}=    Set Variable    ${entry}[name]

            ${status}    ${msg}=    Run Keyword And Ignore Error
            ...    Delete Asset    ${path}    ${asset_name}    ${asset_type}

            IF    '${status}' == 'PASS'
                Log    ✓ Deleted ${asset_type}: ${asset_name}    console=yes
            ELSE
                Log    ⚠️ Could not delete ${asset_type}: ${asset_name}    console=yes
            END
        END
    END

Delete Asset
    [Documentation]    Deletes a single asset based on its type [To be completed]
    ...
    ...    *Arguments:*
    ...    - ``path``: Path where the asset is located
    ...    - ``asset_name``: Name of the asset to delete
    ...    - ``asset_type``: Type of asset (File, Account, Pipeline, etc.)
    ...
    ...    *Returns:*
    ...    - None
    ...
    ...    *Example:*
    ...    | Delete Asset | my-org/project | my_file.txt | File |
    [Arguments]    ${path}    ${asset_name}    ${asset_type}
    IF    '${asset_type}' == 'File'
        Delete File    ${path}/${asset_name}    soft_delete=${False}
    ELSE IF    '${asset_type}' == 'Account'
        Delete Account By Name And Path    ${asset_name}    ${path}
    ELSE IF    '${asset_type}' == 'Pipeline'
        Delete Pipeline By Name And Path    ${asset_name}    ${path}
    ELSE
        Fail    ❌ Unsupported asset type: ${asset_type}
    END
