*** Settings ***
Documentation       Test Suite for File Mount Protocol Demonstration
...                 This test suite validates file upload and processing capabilities using
...                 file:/// protocol with mounted directories in SnapLogic environment:
...                 • Upload files from mounted directories using file protocol
...                 • Import and execute pipelines that read/write from mounted locations
...                 • Demonstrate file access patterns between containers

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             Process    # Process execution for Docker commands
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords
Resource            ../../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Initialize Test Environment


*** Variables ***
# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               /app/src/pipelines
${upload_destination_file_path}     ${org_name}/shared

# File Mount Pipeline Configuration
${pipeline_name}                    filereader_filewriter
${pipeline_slp}                     filereader_writer_mount_files.slp
${task_name}                        filereader_writer_mount_files_csv_Task


*** Test Cases ***
################## FILE MOUNT PROTOCOL DEMONSTRATION ##################

Upload Files With File Protocol
    [Documentation]    Demonstrates uploading expression library files using file:/// protocol
    ...    from directories mounted in the SnapLogic Groundplex container
    ...    📋 ASSERTIONS:
    ...    • Files exist in the mounted directory path
    ...    • File protocol URLs are correctly formed
    ...    • Upload operation succeeds using file:/// protocol
    ...    • Files are accessible in SnapLogic project space
    [Tags]    file_mount    upload
    [Template]    Upload File Using File Protocol Template

    # IMPORTANT: File paths depend on which container processes the file:// URL
    #
    # 1. If SnapLogic Groundplex processes the file:// URL:
    #    Use: /opt/snaplogic/test_data (this is where files are mounted in groundplex)
    #
    # 2. If Test Runner container processes the file:// URL:
    #    Use: /app/test/suite/test_data (this is where files are mounted in test container)
    #
    # Since the upload operation is initiated from the test container but processed
    # by SnapLogic, we need to use the path that SnapLogic (groundplex) can access:

    # === Using Groundplex mount paths (files are actually at this path in groundplex) ===
    file:///opt/snaplogic/test_data/actual_expected_data/expression_libraries/mount_poc_source.expr    ${upload_destination_file_path}
    file:///opt/snaplogic/test_data/actual_expected_data/expression_libraries/mount_poc_target.expr    ${upload_destination_file_path}

    # === From App Mount (always available - entire test directory is mounted) ===
    # file:///app/test/suite/test_data/actual_expected_data/expression_libraries/test.expr    ${upload_destination_file_path}

    # === Using CURDIR Relative Paths (resolves to mounted paths) ===
    # file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/test.expr    ${upload_destination_file_path}

Import Pipelines
    [Documentation]    Imports the file reader/writer pipeline that demonstrates
    ...    reading from and writing to mounted file locations
    ...    📋 ASSERTIONS:
    ...    • Pipeline file (.slp) exists and is readable
    ...    • Pipeline import API call succeeds
    ...    • Unique pipeline ID is generated and returned
    ...    • Pipeline contains file reader and writer snaps configured for mounts
    ...    • Pipeline is successfully deployed to the project space
    [Tags]    file_mount
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_slp}

Create Triggered_task
    [Documentation]    Creates a triggered task for the file mount demonstration pipeline
    ...    This task will enable the pipeline to be executed on demand
    ...    📋 ASSERTIONS:
    ...    • Task creation API call succeeds
    ...    • Task name and configuration are accepted
    ...    • Task is linked to the correct pipeline
    ...    • Task snode ID is generated and returned
    ...    • Task is ready for execution
    [Tags]    file_mount
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}

Execute Triggered Task
    [Documentation]    Executes the file mount pipeline to demonstrate reading from
    ...    and writing to mounted file locations through SnapLogic
    ...    📋 ASSERTIONS:
    ...    • Task execution API call succeeds
    ...    • Pipeline runs without errors
    ...    • File reader successfully reads from mounted source location
    ...    • File writer successfully writes to mounted target location
    ...    • Task completes within expected timeframe
    ...    • No pipeline execution errors or timeouts
    [Tags]    file_mount
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task_name}


*** Keywords ***
Initialize Test Environment
    [Documentation]    Sets up the test environment for file mount demonstrations
    ...    Creates unique ID for test run and verifies Groundplex availability

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

    Log    🔧 Initializing test environment for file mount demonstration
    Log    📋 Test ID: ${unique_id}

    # Verify Groundplex is available
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}

    Log    ✅ Test environment initialized successfully
