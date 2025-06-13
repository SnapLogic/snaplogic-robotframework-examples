*** Settings ***
Documentation       Test Suite for Oracle Database Integration with Pipeline Tasks
...                 This suite validates Oracle database integration by:
...                 1. Creating necessary database tables and procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             DatabaseLibrary    # Generic database operations
Library             oracledb    # Oracle specific operations
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../test_data/queries/oracle_queries.resource    # Oracle SQL queries
Resource            ../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the Oracle database is successful and snaplex is up


*** Variables ***
# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               ${CURDIR}/../../../src/pipelines

${upload_source_file_path}          ${CURDIR}/../test_data/actual_expected_data/expression_libraries
${upload_destination_file_path}     ${project_path}

# Oracle_Pipeline and Task Configuration
${ACCOUNT_PAYLOAD_FILE}             acc_oracle.json
${pipeline_name}                    oracle
${pipeline_name_slp}                oracle.slp
${task1}                            Oracle_Task
${task2}                            Oracle_Task2

@{notification_states}              Completed    Failed
&{task_notifications}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states}

&{task_params_set1}
...                                 M_CURR_DATE=10/12/2024
...                                 DOMAIN_NAME=SLIM_DOM2
...                                 ${ORACLE_ACCOUNT_NAME}=shared/${ORACLE_ACCOUNT_NAME}
&{task_params_updated_set1}
...                                 M_CURR_DATE=10/13/2024
...                                 DOMAIN_NAME=SLIM_DOM3
...                                 ${ORACLE_ACCOUNT_NAME}=shared/${ORACLE_ACCOUNT_NAME}


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    create_account    oracle
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Upload Files
    [Documentation]    Data-driven test case using template format for multiple file upload scenarios
    ...    Each row represents a different upload configuration
    [Tags]    oracle    upload_expr_library
    [Template]    Upload Files To SnapLogic From Template

    # source_dir    file_name    destination_path
    ${upload_source_file_path}    test.expr    ${upload_destination_file_path}

    # Test with wildcards (upload all .expr files)
    # ${UPLOAD_TEST_FILE_PATH}    *.expr    ${UPLOAD_DESTINATION_PATH}/template/all_json

    # # Test with single character wildcard
    # ${UPLOAD_TEST_FILE_PATH}    employees.?pr    ${UPLOAD_DESTINATION_PATH}/template/csv_pattern

Import Pipelines
    [Documentation]    Imports the    pipeline
    ...    Returns:
    ...    uniquie_id --> which is used untill executinh the tasks
    ...    pipeline_snodeid--> which is used to create the tasks
    [Tags]    import_pipeline2    oracle
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    create_triggered_task    oracle
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    create_triggered_task    oracle
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    M_CURR_DATE=10/12/2024

End to End Pipeline Workflow
    [Tags]    end_to_end_workflow    import_pipeline    oracle2

    # Step 1: Create Account
    Create Account From Template    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}    ${env_file_path}

    # Step 2: Import Pipelines
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

    # Step 3: Create Triggered Tasks
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task1}
    ...    ${task_params_set1}
    ...    ${task_notifications}

    # Step 5: Update Task Parameters
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task1}
    ...    M_CURR_DATE=10/12/2024


*** Keywords ***
Check connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to Oracle Database
    ...    ${ORACLE_DBNAME}
    ...    ${ORACLE_DBUSER}
    ...    ${ORACLE_DBPASS}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_DBPORT}
    Initialize Variables

Initialize Variables
    ${unique_id}    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

# Upload File Api
#    [Documentation]    Low-level API call to upload a file to SnapLogic File System (SLFS)
#    ...
#    ...    This is the core upload functionality that makes the actual HTTP POST request
#    ...    to SnapLogic's REST API. Generally not called directly - use Upload Files instead.
#    ...
#    ...    *Arguments:*
#    ...    - ``sl_path``: SnapLogic path where the file should be uploaded (without filename)
#    ...    - ``fileName``: Name to use for the uploaded file
#    ...    - ``file_path``: Local filesystem path to the file to upload
#    ...
#    ...    *Returns:*
#    ...    - Response object from the API call
#    ...
#    ...    *Examples:*
#    ...    | ${response} | Upload File Api | project/data | report.csv | /tmp/report.csv |
#    ...    | ${response} | Upload File Api | ${org_name}/shared | config.json | /home/user/config.json |
#    ...
#    ...    *Note:* This keyword expects ${ORG_ADMIN_SESSION} to be available
#    [Arguments]    ${sl_path}    ${fileName}    ${file_path}

#    Log To Console    uploading ${file_path} to ${sl_path}
#    ${file_open_path}    Get File For Streaming Upload    ${file_path}
#    ${files}    Create Dictionary    file    ${file_open_path}
#    ${response}    POST On Session
#    ...    ${ORG_ADMIN_SESSION}
#    ...    /api/1/rest/slfs/${sl_path}/${fileName}
#    ...    files=${files}

# Upload Files
#    [Documentation]    Main keyword for uploading single or multiple files to SnapLogic
#    ...
#    ...    This is the primary upload keyword that handles both individual files and
#    ...    batch uploads. It provides comprehensive error handling, file validation,
#    ...    and detailed result reporting.
#    ...
#    ...    *Arguments:*
#    ...    - ``files``: Either a single file path (string) or list of file paths
#    ...    - ``destination``: SnapLogic destination path where files will be uploaded
#    ...    - ``rename_to``: Optional new name for the file (only applies to single file uploads)
#    ...
#    ...    *Returns:*
#    ...    Always returns a list of result dictionaries, even for single file uploads.
#    ...    Each dictionary contains:
#    ...    - ``file``: Original local file path
#    ...    - ``uploaded_as``: Filename used in SnapLogic
#    ...    - ``destination``: Upload destination path
#    ...    - ``success``: Boolean indicating upload success (True/False)
#    ...    - ``message``: Descriptive success or error message
#    ...
#    ...    *Examples:*
#    ...    | # Single file upload
#    ...    | @{results} | Upload Files | /tmp/report.csv | project/reports |
#    ...    | Should Be True | ${results}[0][success] |
#    ...
#    ...    | # Single file upload with rename
#    ...    | @{results} | Upload Files | /tmp/data.csv | project/archive | data_2025.csv |
#    ...
#    ...    | # Multiple files upload
#    ...    | @{files} | Create List | /tmp/file1.json | /tmp/file2.xml | /tmp/file3.csv |
#    ...    | @{results} | Upload Files | ${files} | project/batch |
#    ...    | FOR | ${result} | IN | @{results} |
#    ...    |    Should Be True | ${result}[success] | ${result}[message] |
#    ...    | END |
#    ...
#    ...    | # Upload with error handling
#    ...    | @{results} | Upload Files | /tmp/maybe_missing.txt | project/uploads |
#    ...    | IF | not ${results}[0][success] |
#    ...    |    Log | Upload failed: ${results}[0][message] | WARN |
#    ...    | END |
#    ...
#    ...    *Error Handling:*
#    ...    - File not found: Returns success=False with "File not found" message
#    ...    - Upload failure: Returns success=False with error details
#    ...    - Never throws exceptions - always returns result dictionary
#    ...
#    ...    *Performance Notes:*
#    ...    - Files are uploaded sequentially, not in parallel
#    ...    - Large files may take time - check SnapLogic timeout settings
#    ...    - No built-in retry logic - implement at test level if needed
#    [Arguments]    ${files}    ${destination}    ${rename_to}=${EMPTY}

#    @{upload_list}    Create List

#    # Check if input is a single file (string) or list
#    ${is_single_file}    Run Keyword And Return Status    Should Be String    ${files}

#    IF    ${is_single_file}
#    # Single file - add to list
#    Append To List    ${upload_list}    ${files}
#    ELSE
#    # Multiple files - use the list as is
#    @{upload_list}    Copy List    ${files}
#    END

#    # Process all files
#    @{results}    Create List
#    FOR    ${file_path}    IN    @{upload_list}
#    # Handle file naming
#    IF    '${rename_to}' != '${EMPTY}' and ${is_single_file}
#    ${upload_name}    Set Variable    ${rename_to}
#    ELSE
#    ${path}    ${upload_name}    Split Path    ${file_path}
#    END

#    # Check if file exists
#    ${file_exists}    Run Keyword And Return Status    File Should Exist    ${file_path}

#    IF    not ${file_exists}
#    ${status}    Set Variable    ${False}
#    ${response}    Set Variable    File not found: ${file_path}
#    ELSE
#    # Log upload attempt
#    Log    Uploading file: ${file_path} to ${destination}/${upload_name}

#    # Attempt to upload file
#    ${upload_status}    ${response}    Run Keyword And Ignore Error
#    ...    Upload File Api    ${destination}    ${upload_name}    ${file_path}

#    # Set status and response based on upload result
#    IF    '${upload_status}' == 'PASS'
#    ${status}    Set Variable    ${True}
#    ${response}    Set Variable    Upload successful: ${upload_name}
#    ELSE
#    ${status}    Set Variable    ${False}
#    ${response}    Set Variable    Upload failed: ${response}
#    END
#    END

#    # Create result dictionary
#    ${result}    Create Dictionary
#    ...    file=${file_path}
#    ...    uploaded_as=${upload_name}
#    ...    destination=${destination}
#    ...    success=${status}
#    ...    message=${response}

#    Append To List    ${results}    ${result}

#    # Log result
#    IF    ${status}
#    Log    Successfully uploaded ${upload_name}
#    ELSE
#    Log    Failed to upload ${upload_name}: ${response}    ERROR
#    END
#    END

#    RETURN    @{results}

# Upload Files To SnapLogic From Template
#    [Documentation]    Template-friendly keyword for data-driven file upload testing
#    ...
#    ...    Designed for use with Robot Framework's [Template] syntax to define
#    ...    multiple upload scenarios in a clean, tabular format. Supports wildcards
#    ...    for batch uploads and validates all uploads succeed.
#    ...
#    ...    *Arguments:*
#    ...    - ``source_dir``: Local directory containing files to upload
#    ...    - ``file_name``: File name or pattern (supports * and ? wildcards)
#    ...    - ``dest_path``: Destination path in SnapLogic
#    ...
#    ...    *Wildcard Support:*
#    ...    - ``*`` matches any number of characters (e.g., *.json matches all JSON files)
#    ...    - ``?`` matches single character (e.g., file?.txt matches file1.txt, file2.txt)
#    ...
#    ...    *Examples:*
#    ...    | # Using as template
#    ...    | [Template] | Upload Files To SnapLogic From Template |
#    ...    | /tmp/data | employees.csv | project/hr/data |
#    ...    | /tmp/data | *.json | project/configs |
#    ...    | /tmp/logs | app_2025_??.log | project/logs |
#    ...
#    ...    | # Direct call
#    ...    | Upload Files To SnapLogic From Template | /tmp | report.pdf | shared/reports |
#    ...
#    ...    *Note:* This keyword expects ALL uploads to succeed and will fail the test
#    ...    if any file fails to upload
#    [Arguments]    ${source_dir}    ${file_name}    ${dest_path}

#    # Handle wildcards in file pattern
#    IF    '*' in '${file_name}' or '?' in '${file_name}'
#    ${files_to_upload}    Find Files With Pattern    ${source_dir}    ${file_name}
#    ELSE
#    ${files_to_upload}    Create List    ${source_dir}/${file_name}
#    END

#    # Log upload attempt
#    ${file_count}    Get Length    ${files_to_upload}
#    Log    \nUploading ${file_count} file(s) matching: ${file_name} from ${source_dir}    console=True

#    # Upload files - no retry
#    @{results}    Upload Files
#    ...    ${files_to_upload}
#    ...    ${dest_path}
#    ...    ${EMPTY}

#    # Verify all uploads succeeded
#    ${success_count}    Set Variable    ${0}
#    ${fail_count}    Set Variable    ${0}
#    @{failed_files}    Create List

#    FOR    ${result}    IN    @{results}
#    IF    ${result}[success]
#    ${success_count}    Evaluate    ${success_count} + 1
#    Log    ✓ Successfully uploaded: ${result}[uploaded_as]
#    ELSE
#    ${fail_count}    Evaluate    ${fail_count} + 1
#    Append To List    ${failed_files}    ${result}[file]
#    Log    ✗ Failed to upload: ${result}[file] - ${result}[message]    ERROR
#    END
#    END

#    # All uploads should succeed
#    Should Be Equal As Numbers    ${fail_count}    0
#    ...    Failed to upload ${fail_count} file(s): ${failed_files}. Check file paths and permissions.

#    Log    \nUpload Summary: All ${success_count} file(s) uploaded successfully!

# Find Files With Pattern
#    [Documentation]    Finds all files in a directory matching a given pattern
#    ...
#    ...    Supports wildcards for flexible file matching. Used internally by
#    ...    upload keywords to handle pattern-based uploads.
#    ...
#    ...    *Arguments:*
#    ...    - ``directory``: Directory path to search in
#    ...    - ``pattern``: File pattern with optional wildcards
#    ...
#    ...    *Wildcard Support:*
#    ...    - ``*`` matches zero or more characters
#    ...    - ``?`` matches exactly one character
#    ...
#    ...    *Returns:*
#    ...    - List of full paths to matching files
#    ...
#    ...    *Examples:*
#    ...    | @{files} | Find Files With Pattern | /tmp/data | *.csv |
#    ...    | @{logs} | Find Files With Pattern | /var/log | app_2025_??.log |
#    ...    | @{configs} | Find Files With Pattern | /etc | config.* |
#    ...
#    ...    *Error Handling:*
#    ...    - Fails if no files match the pattern
#    ...    - Case-sensitive matching (depends on filesystem)
#    [Arguments]    ${directory}    ${pattern}

#    @{all_files}    List Files In Directory    ${directory}
#    @{matching_files}    Create List

#    FOR    ${file}    IN    @{all_files}
#    ${matches}    Run Keyword And Return Status    Should Match    ${file}    ${pattern}
#    IF    ${matches}
#    ${full_path}    Set Variable    ${directory}/${file}
#    Append To List    ${matching_files}    ${full_path}
#    END
#    END

#    ${count}    Get Length    ${matching_files}
#    Should Be True    ${count} > 0    No files found matching pattern: ${pattern} in ${directory}

#    RETURN    ${matching_files}
