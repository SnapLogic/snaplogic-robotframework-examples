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
Resource            ../../../resources/common/general.resource
Resource            ../../../resources/common/sql_table_operations.resource    # Generic SQL operations
Resource            ../../test_data/queries/snowflake_queries.resource    # Snowflake SQL queries

Suite Setup         Check connections    # Check if the connection to the snowflake database is successful and snaplex is up
Suite Teardown      Tear Down Connections and Files


*** Variables ***
# Dynamic keys to exclude from CSV comparison (timestamps that change between runs)
@{excluded_columns_for_comparison}
...                                     SnowflakeConnectorPushTime
...                                     unique_event_id
...                                     event_timestamp
...                                     /MARKETING-NOTIFICATIONS/CONTENT
######################### Pipeline1 details ###########################

# Pipeline name and file details
${pipeline_name}                        snowflake_keypair
${pipeline_file_name}                   snowflake_keypair.slp
${sf_acct_keypair}                      ${pipeline_name}_account

# Task Details for created triggered task from the above pipeline
${task_name}                            Task
@{notification_states}                  Completed    Failed
&{task_notifications}
...                                     recipients=newemail@gmail.com
...                                     states=${notification_states}

# Expected input files to be added by user
${input_file1_name}                     test_input_file1.json
${input_file2_name}                     test_input_file2.json
${input_file3_name}                     test_input_file3.json
${input_file1_path}                     ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file1_name}
${input_file2_path}                     ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file2_name}
${input_file3_path}                     ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/${input_file3_name}

# Actual output file is automatcally created after the execution of pipeline
# ${actual_output_file1_name}    snaplogic_integration_test.slp_actual_output_from_snowflake_db.csv
${actual_output_file1_name}             ${pipeline_name}_actual_output_file1.csv
${actual_output_file2_name}             ${pipeline_name}_actual_output_file2.csv
${actual_output_file3_name}             ${pipeline_name}_actual_output_file3.csv
${actual_output_file1_path_from_db}     ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/${actual_output_file1_name}
${actual_output_file2_path_from_db}     ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/${actual_output_file2_name}
${actual_output_file3_path_from_db}     ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/${actual_output_file3_name}

# Expected outputfiles to be added by user#
# ${expected_output_file1_name}    expected_output.csv
# ${expected_output_file1_name}    expected_output_exchanged_rows.csv
${expected_output_file1_name}           expected_output_file1.csv
${expected_output_file2_name}           expected_output_file2.csv
${expected_output_file3_name}           expected_output_file3.csv
${expected_output_file1_path}           ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/${expected_output_file1_name}
${expected_output_file2_path}           ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/${expected_output_file2_name}
${expected_output_file3_path}           ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/${expected_output_file3_name}

&{task_params_set}
...                                     snowflake_acct=../shared/${sf_acct_keypair}
...                                     schema=DEMO
...                                     table=DEMO.TEST_SNAP4
...                                     destination_hint=BRAZE:Subscription
...                                     isTest=test
...                                     test_input_file=${input_file1_path}


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
    ...    • Argument 3: ${sf_acct_username_password} - The name to assign to the account in SnapLogic
    ...    📝 USAGE EXAMPLES:
    ...    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct_username_password}
    ...    /org/project/shared    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME}    prod_snowflake_acct
    [Tags]    snowflake_demo    snowflake_multiple_files
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_S3_DYNAMIC_FILE_NAME}    ${sf_acct_keypair}

Upload test input file
    [Documentation]    Uploads the expression library (.expr file) to the project level shared folder.
    ...    Expression libraries contain reusable custom functions and expressions that can be
    ...    referenced across multiple pipelines in the project.
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Local File Path - The local file path to the expression library file (.expr)
    ...    (e.g., ${CURDIR}/../../test_data/expression_libraries/snowflake/snowflake_library.expr)
    ...    • Argument 2: Destination Path - The destination path in SnapLogic where the file will be uploaded
    [Tags]    snowflake_demo2    snowflake_multiple_files
    [Template]    Upload File Using File Protocol Template
    # local file path    destination_path in snaplogic
    ${input_file1_path}    ${PIPELINES_LOCATION_PATH}
    ${input_file2_path}    ${PIPELINES_LOCATION_PATH}
    ${input_file3_path}    ${PIPELINES_LOCATION_PATH}

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
    [Tags]    snowflake_demo    snowflake_multiple_files
    [Template]    Import Pipelines From Template

    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}

Create Triggered_task
    [Documentation]    Creates a triggered task for pipeline execution and returns task metadata.
    ...    Triggered tasks are scheduled or on-demand pipeline executions configured with
    ...    specific parameters and notification settings.
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
    ...    • Argument 8: ${execution_timeout} (Optional) - Timeout in seconds for task execution
    [Tags]    snowflake_demo    snowflake_multiple_files
    [Template]    Create Triggered Task From Template

    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    execution_timeout=300

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
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file1_name}
    # ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file2_name}
    # ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    test_input_file=${input_file3_name}

Verify Data In Snowflake Table For Pipeline Having keypair Authentication
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

    Capture And Verify Number of records From DB Table
    ...    ${task_params_set}[table]
    ...    ${task_params_set}[schema]
    ...    RECORD_METADATA
    ...    2

Export Snowflake Data To CSV
    [Documentation]    Exports data from Snowflake table to a CSV file for detailed verification and comparison.
    ...    This test case retrieves all data from the target table and saves it in CSV format,
    ...    enabling file-based validation against expected results.
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Table Name - ${task_params_set}[table_name] - Source table to export data from
    ...    • Argument 2: Order By Column - DCEVENTHEADERS_USERID - Column for consistent row ordering
    ...    • Argument 3: Output File Path - ${actual_output_file1_path_from_db} - Local path to save CSV file
    [Tags]    snowflake_demo

    Export DB Table Data To CSV
    ...    ${task_params_set}[table]
    ...    RECORD_METADATA
    ...    ${actual_output_file1_path_from_db}

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing actual Snowflake export against expected output.
    ...    This test case performs a comprehensive file comparison to ensure that data processed
    ...    through the Snowflake pipeline matches the expected results exactly.
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: file1_path - Path to the actual output CSV file from Snowflake
    ...    (e.g., ${actual_output_file1_path_from_db})
    ...    • Argument 2: file2_path - Path to the expected output CSV file (baseline)
    ...    (e.g., ${expected_output_file1_path})
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
    [Template]    Compare CSV Files With Exclusions Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status    exclude_columns    match_key=headers.profile_id

    ${actual_output_file1_path_from_db}    ${expected_output_file1_path}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}
    # ${actual_output_file1_path_from_db}    ${expected_output_file1_path}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}

    # ${actual_output_file1_path_from_db}    ${expected_output_file2_path}    ${TRUE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}    match_key=entityId
    # ${actual_output_file1_path_from_db}    ${expected_output_file2_path}    ${FALSE}    ${TRUE}    IDENTICAL    @{excluded_columns_for_comparison}

Verify Snowflake Pipeline results against each input file sequentially
    [Documentation]    End to End test case executing the full Snowflake pipeline workflow
    ...    with multiple input files. Each file is processed sequentially:
    ...    run pipeline → verify records → export CSV → compare output → clean table.
    [Tags]    snowflake_multiple_files

    # File 1
    Execute Pipeline And Verify Output
    ...    input_file_name=${input_file1_name}
    ...    expected_file_path=${expected_output_file1_path}
    ...    actual_file_path=${actual_output_file1_path_from_db}
    ...    order_by_column=RECORD_METADATA
    ...    expected_record_count=2
    ...    excluded_columns=@{excluded_columns_for_comparison}

    # File 2
    Execute Pipeline And Verify Output
    ...    input_file_name=${input_file2_name}
    ...    expected_file_path=${expected_output_file2_path}
    ...    actual_file_path=${actual_output_file2_path_from_db}
    ...    order_by_column=RECORD_METADATA
    ...    expected_record_count=2
    ...    excluded_columns=@{excluded_columns_for_comparison}

    # File 3
    Execute Pipeline And Verify Output
    ...    input_file_name=${input_file3_name}
    ...    expected_file_path=${expected_output_file3_path}
    ...    actual_file_path=${actual_output_file3_path_from_db}
    ...    order_by_column=RECORD_METADATA
    ...    expected_record_count=2
    ...    excluded_columns=@{excluded_columns_for_comparison}


*** Keywords ***
Check connections
    [Documentation]    Verifies snowflake database connection and Snaplex availability
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

    Log    🔧 Initializing test environment for file mount demonstration
    Log    📋 Test ID: ${unique_id}
    # Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Snowflake Via DatabaseLibrary    keypair
    Clean Table    ${task_params_set}[table]    ${task_params_set}[schema]

Execute Pipeline And Verify Output
    [Documentation]    Executes pipeline with given input file and verifies output against expected file.
    ...    This keyword performs the complete end-to-end workflow:
    ...    1. Runs the triggered task with the specified input file
    ...    2. Verifies the expected number of records in the database
    ...    3. Exports the data to CSV
    ...    4. Compares actual vs expected output (excluding dynamic columns)
    ...    5. Cleans the table for the next iteration
    ...
    ...    Arguments:
    ...    - input_file: Input JSON file name to pass to the pipeline
    ...    - expected_file: Path to expected output CSV file
    ...    - actual_file_path: Path where actual output CSV will be saved
    ...    - order_by_column: Column to use for ordering in export (default: RECORD_METADATA)
    ...    - excluded_columns: List of columns to exclude from comparison (default: ${EXCLUDED_COLUMNS_FOR_COMPARISON})
    ...    - expected_record_count: Number of records expected in the table (default: 2)
    [Arguments]
    ...    ${input_file_name}
    ...    ${expected_file_path}
    ...    ${actual_file_path}
    ...    ${order_by_column}=RECORD_METADATA
    ...    ${expected_record_count}=2
    ...    ${excluded_columns}=@{EMPTY}

    Log    \n========== Processing: ${input_file_name} ==========    console=yes

    # Step 1: Run the pipeline with the input file
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    test_input_file=${input_file_name}

    # Step 2: Verify record count in database
    Capture And Verify Number of records From DB Table
    ...    ${task_params_set}[table]
    ...    ${task_params_set}[schema]
    ...    ${order_by_column}
    ...    ${expected_record_count}

    # Step 3: Export data to CSV
    Export DB Table Data To CSV
    ...    ${task_params_set}[table]
    ...    ${order_by_column}
    ...    ${actual_file_path}

    # Step 4: Compare actual vs expected output
    Compare CSV Files With Exclusions Template
    ...    ${actual_file_path}
    ...    ${expected_file_path}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    IDENTICAL
    ...    @{excluded_columns}

    # Step 5: Clean table for next iteration
    Clean Table    ${task_params_set}[table]    ${task_params_set}[schema]

    Log    ✅ Completed processing: ${input_file_name}    console=yes

Tear Down Connections and Files
    # ================= Delete All pipeline and tasks belonging to Pipelines================
    # @{p1}=    Create List    ${unique_id}    ${pipeline_name}
    # @{p2}=    Create List    ${unique_id2}    ${pipeline_name2}
    # @{pipelines}=    Create List    ${p1}    @{p2}

    # Delete All Tasks For Pipelines    ${pipelines}
    # Delete Pipelines    ${pipelines}

    # ===================================================================

    # Delete Task    ${unique_id}    ${pipeline_name}    ${task_name}
    # Delete Pipeline    ${unique_id}    ${pipeline_name}
    # Delete Account By Name And Path    ${sf_acct_keypair}    ${ACCOUNT_LOCATION_PATH}

    # Delete All Files By Path    ${ACCOUNT_LOCATION_PATH}
    # Delete All Files By Path    ${PIPELINES_LOCATION_PATH}
    # Delete All Accounts By Path    ${ACCOUNT_LOCATION_PATH}
    # Delete All Pipelines By Path    ${PIPELINES_LOCATION_PATH}
    # Delete All Tasks By Path    ${PIPELINES_LOCATION_PATH}
    # Delete All Dirs By Path    ${PIPELINES_LOCATION_PATH}
    Disconnect From Snowflake
