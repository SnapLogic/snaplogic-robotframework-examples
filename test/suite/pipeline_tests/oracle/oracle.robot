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
Resource            ../../test_data/queries/oracle_queries.resource    # Oracle SQL queries
Resource            ../../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the Oracle database is successful and snaplex is up


*** Variables ***
# Project Configuration

${upload_source_file_path}          ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${container_source_file_path}       opt/snaplogic/test_data/actual_expected_data/expression_libraries

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
...                                 Oracle_Slim_Account=shared/${ORACLE_ACCOUNT_NAME}
&{task_params_updated_set1}
...                                 M_CURR_DATE=10/13/2024
...                                 DOMAIN_NAME=SLIM_DOM3
...                                 Oracle_Slim_Account=shared/${ORACLE_ACCOUNT_NAME}


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    oracle    regression
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}

Upload Files With File Protocol
    [Documentation]    Upload files using file:/// protocol URLs - all options in template format
    [Tags]    oracle    regression
    [Template]    Upload File Using File Protocol Template

    # files exist via Docker mounts:
    # - ./test/suite/test_data/.../expression_libraries -> /opt/snaplogic/expression-libraries

    # file_url    destination_path
    # === From Container Mount Points (files exist via mounts) ===
    # testing the same pattern CAT uses
    file:///opt/snaplogic/test_data/actual_expected_data/expression_libraries/test.expr    ${ACCOUNT_LOCATION_PATH}
    # Similar to CAT tests: /l$11 DEV GEN/.../EAI_Service_DEV/

    # === From App Mount (always available - entire test directory is mounted) ===
    file:///app/test/suite/test_data/actual_expected_data/expression_libraries/test.expr    ${ACCOUNT_LOCATION_PATH}/app_mount

    # === Using CURDIR Relative Paths (resolves to mounted paths) ===
    file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/test.expr    ${ACCOUNT_LOCATION_PATH}/curdir

Upload Files
    [Documentation]    Data-driven test case using template format for multiple file upload scenarios
    ...    Each row represents a different upload configuration
    [Tags]    oracle    regression
    [Template]    Upload Files To SnapLogic From Template

    # source_dir    file_name    destination_path
    ${upload_source_file_path}    test.expr    ${ACCOUNT_LOCATION_PATH}

    # Test with wildcards (upload all .expr files)
    # ${UPLOAD_TEST_FILE_PATH}    *.expr    ${ACCOUNT_LOCATION_PATH}/template/all_json

    # # Test with single character wildcard
    # ${UPLOAD_TEST_FILE_PATH}    employees.?pr    ${ACCOUNT_LOCATION_PATH}/template/csv_pattern

Import Pipelines
    [Documentation]    Imports the    pipeline
    ...    Returns:
    ...    uniquie_id --> which is used untill executinh the tasks
    ...    pipeline_snodeid--> which is used to create the tasks
    [Tags]    oracle    regression
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    oracle    regression
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    oracle    regression
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    M_CURR_DATE=10/12/2024

End to End Pipeline Workflow
    [Tags]    end_to_end_workflow    import_pipeline    oracle2    regression

    # Step 1: Create Account
    Create Account From Template    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

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

Export Assets From a Project
    [Documentation]    Exports pipeline assets from SnapLogic project to a local backup folder.
    ...    This test case creates a backup of all pipeline assets (pipelines, accounts, etc.)
    ...    by exporting them as a ZIP file to a local directory for version control,
    ...    disaster recovery, or migration purposes.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline and related assets exist in the SnapLogic project
    ...    • Local backup directory is writable
    ...    • ${ORG_SNODE_ID} is set (done during suite setup)
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: project_path - Path to the project in SnapLogic
    ...    (e.g., ${PIPELINES_LOCATION_PATH} = shared/pipelines or project_space/project)
    ...    • Argument 2: save_to_file - Local file path where the exported ZIP will be saved
    ...    (e.g., ${CURDIR}/src/exported_assets/snowflake_backup.zip)
    ...    • Argument 3: asset_types (Optional) - Type of assets to export
    ...    (default: All - exports pipelines, accounts, and all other assets)
    ...    Options: All, Pipeline, Account, File, etc.
    ...
    ...    💡 TO EXPORT MULTIPLE PROJECTS OR ASSET TYPES:
    ...    You can add multiple records to export different projects or asset types:
    ...    # Export all assets from pipelines folder
    ...    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/src/exported_assets/all_assets.zip    All
    ...    # Export only pipelines
    ...    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/src/exported_assets/pipelines_only.zip    Pipeline
    ...    # Export from different project paths
    ...    shared/accounts    ${CURDIR}/src/exported_assets/accounts_backup.zip    Account
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Export all assets with timestamp
    ...    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/src/exported_assets/backup_${timestamp}.zip
    ...
    ...    # Example 2: Export only pipelines
    ...    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/src/exported_assets/pipelines.zip    Pipeline
    ...
    ...    # Example 3: Export to different locations
    ...    project_space/dev    ${CURDIR}/backups/dev_backup.zip
    ...    project_space/prod    ${CURDIR}/backups/prod_backup.zip
    ...
    ...    📋 ASSERTIONS:
    ...    • Export API call succeeds with status 200
    ...    • ZIP file is created at the specified location
    ...    • ZIP file contains the expected assets
    [Tags]    export_assets
    [Template]    Export Assets Template
    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/../../../../src/pipelines/snowflake_assets_backup.zip

Import Assets To a project
    [Documentation]    Imports pipeline assets from a backup ZIP file into a SnapLogic project.
    ...    This test case restores pipeline assets from a previously exported backup file,
    ...    allowing you to migrate assets between environments, restore from backups,
    ...    or deploy assets to new project locations.
    ...
    ...    📋 PREREQUISITES:
    ...    • Backup ZIP file exists (created by Export Pipeline Assets test case)
    ...    • Target project path exists in SnapLogic
    ...    • ${ORG_SNODE_ID} is set (done during suite setup)
    ...    • User has permissions to import assets to the target path
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: import_path - Target path in SnapLogic where assets will be imported
    ...    (e.g., ${PIPELINES_LOCATION_PATH}_restored or shared/imported_pipelines)
    ...    Note: This can be the same path (to restore) or different path (to migrate/clone)
    ...    • Argument 2: zip_file_path - Local path to the backup ZIP file to import
    ...    (e.g., ${CURDIR}/../../../../src/pipelines/snowflake_assets_backup.zip)
    ...    • Argument 3: duplicate_check (Optional) - Whether to check for duplicate assets
    ...    (default: false - allows overwriting existing assets)
    ...    Options: true (prevent duplicates), false (allow overwrite)
    ...
    ...    💡 COMMON USE CASES:
    ...    # Use Case 1: Import to new location (migration/cloning) - RECOMMENDED
    ...    shared/imported_pipelines    ${CURDIR}/backup/assets.zip    false
    ...
    ...    # Use Case 2: Restore to original location (overwrite existing)
    ...    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/backup/assets.zip    false
    ...
    ...    # Use Case 3: Import with duplicate check (prevent overwrite)
    ...    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/backup/assets.zip    true
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Import to a different location (recommended to avoid conflicts)
    ...    ${PIPELINES_LOCATION_PATH}_restored    ${CURDIR}/../../../../src/pipelines/snowflake_assets_backup.zip
    ...
    ...    # Example 2: Import to same location with duplicate check
    ...    ${PIPELINES_LOCATION_PATH}    ${CURDIR}/../../../../src/pipelines/snowflake_assets_backup.zip    true
    ...
    ...    📋 ASSERTIONS:
    ...    • ZIP file exists and is readable
    ...    • Import API call succeeds with status 200
    ...    • Assets are imported to the specified location
    ...    • Import result contains success status
    ...
    ...    ⚠️    NOTE: Importing to a NEW location (e.g., ${PIPELINES_LOCATION_PATH}_restored)
    ...    is recommended to avoid conflicts with existing pipelines.
    [Tags]    import_assets
    [Template]    Import Assets Template
    swapna-automation-latest/test    ${CURDIR}/../../../../src/pipelines/snowflake_assets_backup.zip


*** Keywords ***
Check connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to Oracle Database
    ...    ${ORACLE_DATABASE}
    ...    ${ORACLE_USER}
    ...    ${ORACLE_PASSWORD}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_PORT}
    Initialize Variables

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
