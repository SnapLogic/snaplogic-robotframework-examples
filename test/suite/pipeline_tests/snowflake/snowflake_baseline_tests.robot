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
Resource            ../../../resources/snowflake2/snowflake_keywords_databaselib.resource    # For Snowflake connection
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/files.resource
Resource            ../../../resources/sql_table_operations.resource    # Generic SQL operations
Resource            ../../test_data/queries/snowflake_queries.resource    # Snowflake SQL queries

Suite Setup         Check connections    # Check if the connection to the snowflake database is successful and snaplex is up


*** Variables ***
######################### Pipeline1 details ###########################

# Pipeline name and file details
${pipeline_name}                    snowflake_pl1
${pipeline_file_name}               snowflake1.slp
${sf_acct}                          ${pipeline_name}_account

# Task Details for created triggered task from the above pipeline
${task_name}                        Task
@{notification_states}              Completed    Failed
&{task_notifications}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states}

&{task_params_set}
...                                 snowflake_acct=../shared/${sf_acct}
...                                 schema_name=DEMO
...                                 table_name=DEMO.LIFEEVENTSDATA

# Actual and Expected output file paths for verification
${actual_output_file_from_db}       ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/${pipeline_name}_actual_output_from_snowflake_db.csv    # Actual output files for comparison
${expected_output_file}             ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/snowflake_inserted_data.csv    # Expected Output file (User have to create it)

######################### Pipeline2 details ###########################
# Pipeline name and file details
${pipeline_name2}                   snowflake_pl2
${pipeline_file_name2}              snowflake2.slp
${sf_acct2}                         ${pipeline_name2}_account

# Task Details for created triggered task from the above pipeline
${task_name2}                       Task2
@{notification_states2}             Completed    Failed
&{task_notifications2}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states2}

&{task_params_set2}
...                                 snowflake_acct=../shared/${sf_acct2}
...                                 schema_name=DEMO
...                                 table_name=DEMO.LIFEEVENTSDATA2

# Actual and Expected output file paths for verification
${actual_output_file_from_db2}      ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/${pipeline_name2}_actual_output_from_snowflake_db.csv    # Actual output files for comparison
${expected_output_file2}            ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/snowflake_inserted_data2.csv    # Expected Output file (User have to create it)


*** Test Cases ***
Create Account
    [Documentation]    Creates a Snowflake account in the project space using the provided payload file.
    ...    This test case uses the Create Account From Template keyword to set up account credentials
    ...    and configuration required for subsequent pipeline operations.
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: ${ACCOUNT_LOCATION_PATH} - The path in the SnapLogic project where the account will be created
    ...    (e.g., /org/project/shared) - This should be added in the .env file as a variable
    ...    • Argument 2: ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME} - The JSON payload file containing account credentials
    ...    and configuration (includes connection details, username, password, warehouse, etc.)
    ...    The payload name is added in ../snaplogic-robotframework-examples/env_files/external_accounts/.env.snowflake
    ...    • Argument 3: ${sf_acct} - The name to assign to the account in SnapLogic
    ...    (referenced by pipelines as '../shared/account_name')
    ...
    ...    💡 TO ADD MULTIPLE ACCOUNTS:
    ...    You can create additional accounts by adding more records to this template.
    ...    Each record should pass three arguments:
    ...    1. Account location path (where to create the account)
    ...    2. Payload file name (JSON file with account credentials)
    ...    3. Account name (unique name for the account)
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Create single account
    ...    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct}
    ...
    ...    # Example 2: Create multiple accounts for different environments
    ...    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct}
    ...    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_DEV_PAYLOAD_FILE_NAME}    dev_snowflake_account
    ...    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_TEST_PAYLOAD_FILE_NAME}    test_snowflake_account
    ...
    ...    # Example 3: Create accounts in different locations
    ...    /org/project/shared    snowflake_prod.json    prod_snowflake_acct
    ...    /org/project/dev/shared    snowflake_dev.json    dev_snowflake_acct
    ...
    ...    📋 ASSERTIONS:
    ...    • Account payload file exists and contains valid JSON
    ...    • Account creation API call succeeds
    ...    • Account is created at specified location path
    ...    • Account credentials are securely stored
    ...    • Account is accessible for pipeline execution
    [Tags]    snowflake_demo
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct}

Upload Expression Library
    [Documentation]    Uploads the expression library (.expr file) to the project level shared folder.
    ...    Expression libraries contain reusable custom functions and expressions that can be
    ...    referenced across multiple pipelines in the project.
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Local File Path - The local file path to the expression library file (.expr)
    ...    (e.g., ${CURDIR}/../../test_data/expression_libraries/snowflake/snowflake_library.expr)
    ...    • Argument 2: Destination Path - The destination path in SnapLogic where the file will be uploaded
    ...    (typically the same as ${ACCOUNT_LOCATION_PATH} for shared resources)
    ...
    ...    💡 TO UPLOAD MULTIPLE EXPRESSION LIBRARIES:
    ...    You can upload additional expression libraries by adding more records to this template.
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Upload single library
    ...    ${CURDIR}/../../test_data/expression_libraries/snowflake/snowflake_library.expr    ${ACCOUNT_LOCATION_PATH}
    ...    ${CURDIR}/../../test_data/expression_libraries/snowflake/snowflake_library2.expr    ${ACCOUNT_LOCATION_PATH}
    [Tags]    snowflake_demo    upload_expression_library
    [Template]    Upload File Using File Protocol Template

    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr    ${ACCOUNT_LOCATION_PATH}

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
    ...    📄 RETURNS:
    ...    • pipeline_snodeid - Unique identifier for the imported pipeline
    ...    • pipeline_path - Full path to the imported pipeline in SnapLogic
    ...
    ...    💡 TO IMPORT MULTIPLE PIPELINES:
    ...    You can import multiple pipeline files by adding more records to this template.
    ...    Each record represents one pipeline import operation.
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Import single pipeline
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    my_pipeline    my_pipeline.slp
    ...    # Example 2: Import to different locations
    ...    ${unique_id}    /org/project/dev/pipelines    dev_pipeline    pipeline_v1.slp
    ...    # Example 3: Import with different unique_ids
    ...    ${unique_id}_test1    ${PIPELINES_LOCATION_PATH}    pipeline_variant_a    pipeline.slp
    [Tags]    snowflake_demo
    [Template]    Import Pipelines From Template

    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name2}    ${pipeline_file_name2}

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
    ...
    ...    📄 RETURNS:
    ...    • task_payload - Complete task configuration for parameter updates
    ...    • task_snodeid - Unique task identifier for execution and updates
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Create task with full parameters including notifications
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}
    ...
    ...    # Example 2: Create task without notifications
    ...    ${unique_id}_2    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}
    ...
    ...    # Example 3: Create multiple tasks for different pipelines
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name2}    ${task_name2}    ${GROUNDPLEX_NAME}    ${task_params_set2}    ${task_notifications2}
    ...
    ...    # Example 4: Create tasks with different parameter sets
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    data_pipeline    daily_task    ${GROUNDPLEX_NAME}    ${daily_params}    ${notifications}
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    data_pipeline    weekly_task    ${GROUNDPLEX_NAME}    ${weekly_params}    ${notifications}
    [Tags]    snowflake_demo    regression
    [Template]    Create Triggered Task From Template

    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}
    ${unique_id}_2    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}

Execute Triggered Task
    [Documentation]    Executes the triggered task with specified parameters and monitors completion.
    ...    This test case runs the pipeline through the triggered task, optionally overriding
    ...    task parameters for different execution scenarios.
    ...
    ...    📋 PREREQUISITES:
    ...    • task_payload - Returned from Create Triggered_task test case
    ...    • task_snodeid - Returned from Create Triggered_task test case
    ...    • Task must be in ready state before execution
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: ${unique_id} - Unique identifier matching the task creation
    ...    • Argument 2: ${PIPELINES_LOCATION_PATH} - SnapLogic path where pipelines are stored
    ...    • Argument 3: ${pipeline_name} - Name of the pipeline associated with the task
    ...    • Argument 4: ${task_name} - Name of the triggered task to execute
    ...    • Arguments 5+: Optional key=value parameters - Override default task parameters
    ...    (e.g., table_name=DEMO.DIFFERENT_TABLE, schema_name=TEST_SCHEMA)
    ...
    ...    💡 TO EXECUTE MULTIPLE TASK RUNS:
    ...    You can execute the same task multiple times with different parameters.
    ...    Each record represents one task execution:
    ...    - With default parameters (no overrides)
    ...    - With parameter overrides for different scenarios
    ...    - Multiple sequential executions for testing
    ...
    ...    📝 USAGE EXAMPLES:
    ...    # Example 1: Execute with default parameters (no overrides)
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
    ...
    ...    # Example 2: Execute with single parameter override
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    table_name=DEMO.LIFEEVENTSDATA3
    ...
    ...    # Example 3: Execute with multiple parameter overrides
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    schema_name=TEST    table_name=TEST.DATA
    ...
    ...    # Example 4: Execute same task multiple times with different data
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    table_name=DEMO.LIFEEVENTSDATA3
    ...
    ...    # Example 5: Execute different tasks
    ...    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    table_name=DEMO.TABLE1
    ...    ${unique_id}_2    ${PIPELINES_LOCATION_PATH}    ${pipeline_name2}    ${task_name2}    table_name=DEMO.TABLE2
    [Tags]    snowflake_demo
    [Template]    Run Triggered Task With Parameters From Template

    # ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    table_name=DEMO.LIFEEVENTSDATA3

Verify Data In Snowflake Table
    [Documentation]    Verifies data integrity in Snowflake table by querying and validating record counts.
    ...    This test case ensures that the pipeline successfully inserted the expected number
    ...    of records into the target Snowflake table.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline execution completed successfully
    ...    • Snowflake table exists with data inserted
    ...    • Database connection is established
    ...
    ...    📋 VERIFICATION DETAILS:
    ...    • Table Name: ${task_params_set}[table_name] - Target table to verify
    ...    • Schema Name: ${task_params_set}[schema_name] - Schema containing the table
    ...    • Order By Column: DCEVENTHEADERS_USERID - Column used for consistent ordering
    ...    • Expected Record Count: 2 - Number of records expected in the table
    [Tags]    snowflake_demo

    Capture And Verify Number of records From Snowflake Table
    ...    ${task_params_set}[table_name]
    ...    ${task_params_set}[schema_name]
    ...    DCEVENTHEADERS_USERID
    ...    2

Export Snowflake Data To CSV
    [Documentation]    Exports data from Snowflake table to a CSV file for detailed verification and comparison.
    ...    This test case retrieves all data from the target table and saves it in CSV format,
    ...    enabling file-based validation against expected results.
    ...
    ...    📋 PREREQUISITES:
    ...    • Snowflake table contains data to export
    ...    • Database connection is established
    ...    • Output directory exists and is writable
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Table Name - ${task_params_set}[table_name] - Source table to export data from
    ...    • Argument 2: Order By Column - DCEVENTHEADERS_USERID - Column for consistent row ordering
    ...    • Argument 3: Output File Path - ${actual_output_file_from_db} - Local path to save CSV file
    [Tags]    snowflake_demo

    Export Snowflake Table Data To CSV
    ...    ${task_params_set}[table_name]
    ...    DCEVENTHEADERS_USERID
    ...    ${actual_output_file_from_db}

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing actual Snowflake export against expected output.
    ...    This test case performs a comprehensive file comparison to ensure that data processed
    ...    through the Snowflake pipeline matches the expected results exactly.
    ...
    ...    📋 PREREQUISITES:
    ...    • Actual CSV file exported from Snowflake table
    ...    • Expected CSV file created beforehand with correct data
    ...    • Both files must have the same structure (columns)
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: file1_path - Path to the actual output CSV file from Snowflake
    ...    (e.g., ${actual_output_file_from_db})
    ...    • Argument 2: file2_path - Path to the expected output CSV file (baseline)
    ...    (e.g., ${expected_output_file})
    ...    • Argument 3: ignore_order - Boolean flag to ignore row ordering
    ...    ${TRUE} = Compare without considering row order
    ...    ${FALSE} = Rows must match in exact order
    ...    • Argument 4: show_details - Boolean flag to display detailed differences
    ...    ${TRUE} = Show all differences in console output
    ...    ${FALSE} = Show only summary
    ...    • Argument 5: expected_status - Expected comparison result
    ...    IDENTICAL = Files must match exactly
    ...    DIFFERENT = Files expected to differ
    ...    SUBSET = File1 is subset of File2
    [Tags]    snowflake_demo
    [Template]    Compare CSV Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${actual_output_file_from_db}    ${expected_output_file}    ${FALSE}    ${TRUE}    IDENTICAL

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
    [Tags]    snowflake_demo    export_assets
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
    [Tags]    snowflake_demo    import_assets
    [Template]    Import Assets Template
    swapna-automation-latest/test    ${CURDIR}/../../../../src/pipelines/snowflake_assets_backup.zip


*** Keywords ***
Check connections
    [Documentation]    Verifies snowflake database connection and Snaplex availability
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

    Log    🔧 Initializing test environment for file mount demonstration
    Log    📋 Test ID: ${unique_id}
    # Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Snowflake Cloud DB
    Clean Table    ${task_params_set}[table_name]    ${task_params_set}[schema_name]

Connect To Snowflake Cloud DB
    [Documentation]    Test connection using resource keywords
    ...    No need to set env variables - already loaded from .env
    Connect To Snowflake Via DatabaseLibrary

Clean Table
    [Documentation]    Truncates the Snowflake table before test execution to ensure clean state
    [Arguments]    ${table_name}    ${schema_name}
    Log    🧹 Cleaning Snowflake test table before execution    console=yes

    # Truncate the table - verification is automatic (verify_empty=TRUE by default)
    Truncate Table If Exists    ${table_name}    schema=${schema_name}

Capture And Verify Number of records From Snowflake Table
    [Documentation]    Verifies data in Snowflake table by executing a query and comparing results with expected output
    ...    Table is truncated before pipeline execution to ensure consistent test results
    ...    Retrieved data is exported to CSV for verification
    [Arguments]    ${table_name}    ${schema_name}    ${order_by_column}    ${expected_records_count}
    ${results}=    Select All From Table
    ...    ${table_name}
    ...    order_by=${order_by_column}
    ...    schema=${schema_name}

    ${row_count}=    Get Length    ${results}
    Should Be Equal As Integers    ${row_count}    ${expected_records_count}
    Log
    ...    Retrieved ${row_count} rows from ${task_params_set}[table_name].${task_params_set}[schema_name]
    ...    console=yes

Export Snowflake Table Data To CSV
    [Documentation]    Exports data from Snowflake table to a CSV file for verification
    ...    Retrieved data is exported to CSV for verification
    [Arguments]    ${table_name}    ${order_by_column}    ${output_file}
    # ${timestamp}=    Get Time    epoch
    ${export_result}=    Export Table To CSV
    ...    ${table_name}
    ...    ${output_file}
    ...    include_headers=${TRUE}
    ...    order_by=${order_by_column}

    Log    ✅ Exported ${export_result}[row_count] rows to ${export_result}[file_path]    console=yes
    Log    📁 CSV file location: ${output_file}    console=yes
