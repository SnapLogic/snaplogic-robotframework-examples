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
Resource            ../../../resources/common/files.resource    # CSV/JSON file operations
Resource            ../../../resources/common/database.resource
Resource            ../../../resources/common/sql_table_operations.resource    # For Clean Table keyword

Suite Setup         Check connections    # Check if the connection to the Oracle database is successful and snaplex is up


*** Variables ***
# Project Configuration

# Pipeline name and file details
${pipeline_name}                        oracle
${pipeline_name_slp}                    oracle2.slp
${oracle_acct_name}                     ${pipeline_name}_acct

# Oracle_Pipeline and Task Configuration
${task1}                                Oracle_Task

@{notification_states}                  Completed    Failed
&{task_notifications}
...                                     recipients=newemail@gmail.com
...                                     states=${notification_states}

&{task_params_set}
...                                     oracle_acct=../shared/${oracle_acct_name}
...                                     schema_name=DEMO
...                                     table_name=DEMO.TEST_TABLE1
...                                     actual_output=file:///opt/snaplogic/test_data/actual_expected_data/actual_output/oracle/table1.csv

${upload_source_file_path}              ${CURDIR}/../../test_data/actual_expected_data/expression_libraries

# Actual output file is automatcally created after the execution of pipeline
# ${actual_output_file1_name}    snaplogic_integration_test.slp_actual_output_from_snowflake_db.csv
${actual_output_file1_name}             ${pipeline_name}_actual_output_file_from_db.csv
${actual_output_file1_path_from_db}     ${CURDIR}/../../test_data/actual_expected_data/actual_output/oracle/${actual_output_file1_name}

# Expected outputfiles to be added by user#
${expected_output_file1_name}           expected_output_file1.csv
${expected_output_file1_path}           ${CURDIR}/../../test_data/actual_expected_data/expected_output/oracle/${expected_output_file1_name}


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    oracle    regression
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${oracle_acct_name}

Upload Files With File Protocol
    [Documentation]    Upload files using file:/// protocol URLs - all options in template format
    [Tags]    oracle    regression
    [Template]    Upload File Using File Protocol Template

    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/oracle/oracle_library.expr    ${ACCOUNT_LOCATION_PATH}

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
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    oracle    regression
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}

Verify Data In Oracle Table
    [Documentation]    Verifies data integrity in Oracle table by querying and validating record counts.
    ...    This test case ensures that the pipeline successfully inserted the expected number
    ...    of records into the target Oracle table.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline execution completed successfully
    ...    • Oracle table exists with data inserted
    ...    • Database connection is established
    ...    • Table is cleaned (truncated) during suite setup for consistent results
    ...
    ...    📋 VERIFICATION DETAILS:
    ...    • Table Name: ${task_params_set}[table_name] - Target table to verify (DEMO.TEST_TABLE1)
    ...    • Schema Name: ${task_params_set}[schema_name] - Schema containing the table (DEMO)
    ...    • Order By Column: DCEVENTHEADERS_USERID - Column used for consistent ordering
    ...    • Expected Record Count: 2 - Number of records expected after pipeline execution
    [Tags]    oracle

    Capture And Verify Number of records From DB Table
    ...    ${task_params_set}[table_name]
    ...    ${task_params_set}[schema_name]
    ...    DCEVENTHEADERS_USERID
    ...    2

Export Oracle Data To CSV
    [Documentation]    Exports data from Oracle table to a CSV file for detailed verification and comparison.
    ...    This test case retrieves all data from the target table and saves it in CSV format,
    ...    enabling file-based validation against expected results.
    ...
    ...    📋 PREREQUISITES:
    ...    • Pipeline execution completed successfully (Execute Triggered Task With Parameters)
    ...    • Oracle table contains data inserted by the pipeline
    ...    • Database connection is established
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: Table Name - ${task_params_set}[table_name] - Source table to export data from (DEMO.TEST_TABLE1)
    ...    • Argument 2: Order By Column - DCEVENTHEADERS_USERID - Column for consistent row ordering
    ...    • Argument 3: Output File Path - ${actual_output_file1_path_from_db} - Local path to save CSV file
    ...
    ...    📋 OUTPUT:
    ...    • CSV file saved to: test/suite/test_data/actual_expected_data/actual_output/oracle/${pipeline_name}_actual_output_file1.csv
    ...    • File contains all rows from the Oracle table ordered by DCEVENTHEADERS_USERID
    [Tags]    oracle

    Export DB Table Data To CSV
    ...    ${task_params_set}[table_name]
    ...    DCEVENTHEADERS_USERID
    ...    ${actual_output_file1_path_from_db}

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing actual Oracle export against expected output.
    ...    This test case performs a comprehensive file comparison to ensure that data processed
    ...    through the Oracle pipeline matches the expected results exactly.
    ...
    ...    📋 PREREQUISITES:
    ...    • Export Oracle Data To CSV test case completed successfully
    ...    • Expected output file exists at: test/suite/test_data/actual_expected_data/expected_output/oracle/expected_output_file1.csv
    ...
    ...    📋 ARGUMENT DETAILS:
    ...    • Argument 1: file1_path - Path to the actual output CSV file from Oracle
    ...    (${actual_output_file1_path_from_db})
    ...    • Argument 2: file2_path - Path to the expected output CSV file (baseline)
    ...    (${expected_output_file1_path})
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
    ...    • Argument 6: exclude_columns (Optional) - List of columns to exclude from comparison
    ...    Useful for dynamic columns like timestamps that change between runs
    ...
    ...    📋 OUTPUT:
    ...    • Test passes if files are IDENTICAL (or match the expected_status)
    ...    • Detailed differences are displayed in console when show_details=${TRUE}
    [Tags]    oracle
    [Template]    Compare CSV Files With Exclusions Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status

    ${actual_output_file1_path_from_db}    ${expected_output_file1_path}    ${FALSE}    ${TRUE}    IDENTICAL


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
    Clean Table    ${task_params_set}[table_name]    ${task_params_set}[schema_name]

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
