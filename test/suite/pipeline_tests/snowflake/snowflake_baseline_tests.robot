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
Suite Teardown      Delete All Files    # Clean up all all files after execution


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

######################### Pipeline3 details ###########################
${sf_acct3}                         SF_account_key_pair_s3Dynamic


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
    ...    • Argument 3: ${sf_acct} - The name to assign to the account in SnapLogic
    ...    📝 USAGE EXAMPLES:
    ...    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct}
    ...    /org/project/shared    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    prod_snowflake_acct
    [Tags]    snowflake_demo3
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct}
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    ${sf_acct2}
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_S3_DYNAMIC_FILE_NAME}    ${sf_acct3}

Upload Files
    [Documentation]    Uploads the expression library (.expr file) to the project level shared folder.
    ...    Expression libraries contain reusable custom functions and expressions that can be
    ...    referenced across multiple pipelines in the project.
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Local File Path - The local file path to the expression library file (.expr)
    ...    (e.g., ${CURDIR}/../../test_data/expression_libraries/snowflake/snowflake_library.expr)
    ...    • Argument 2: Destination Path - The destination path in SnapLogic where the file will be uploaded
    ...    (typically the same as ${ACCOUNT_LOCATION_PATH} for shared resources)
    [Tags]    snowflake_demo2    upload_expression_library
    [Template]    Upload File Using File Protocol Template
    # file path    destination_path
    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr    ${ACCOUNT_LOCATION_PATH}
    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library2.expr    ${ACCOUNT_LOCATION_PATH}

Delete Files
    [Documentation]    Delete files with different soft_delete and status settings
    [Tags]    delete_snowflake_files
    [Template]    Delete File
    # project_path    soft_delete(Have it in recyclebin or not)
    ${ACCOUNT_LOCATION_PATH}/snowflake_library.expr    ${True}
    ${ACCOUNT_LOCATION_PATH}/snowflake_library2.expr    ${False}

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
    [Tags]    snowflake_demo
    [Template]    Run Triggered Task With Parameters From Template

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
    # Connect To Snowflake Via DatabaseLibrary
    Connect To Snowflake Via DatabaseLibrary    keypair

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

Delete All Files
    [Documentation]    Deletes uploaded expression library files from the project
    Log    🗑️ Deleting expression library files...    console=yes

    @{files}=    Create List
    ...    snowflake_library.expr
    ...    snowflake_library2.expr

    FOR    ${file}    IN    @{files}
        ${status}    ${response}=    Run Keyword And Ignore Error
        ...    Delete File    ${ACCOUNT_LOCATION_PATH}/${file}    soft_delete=${False}

        IF    '${status}' == 'PASS'
            Log    ✓ Deleted: ${file}    console=yes
        ELSE
            Log    ⚠️ Could not delete: ${file} (may not exist)    console=yes
        END
    END
