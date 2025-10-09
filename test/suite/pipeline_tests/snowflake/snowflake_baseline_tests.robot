*** Settings ***
Documentation       Snowflake Database Integration Tests
...                 Using snowflake_keywords.resource which wraps the SnowflakeHelper Python library
...                 Environment variables are automatically loaded from .env file via Docker

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
    [Documentation]    Creates an account in the project space using the provided payload file.
    [Tags]    snowflake_demo
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}    ${sf_acct}

Upload Expression Library
    [Documentation]    Uploads the expression library to project level shared folder
    [Tags]    snowflake_demo    upload_expression_library
    [Template]    Upload File Using File Protocol Template
    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr    ${ACCOUNT_LOCATION_PATH}

Import Pipeline
    [Documentation]    Imports the file snowflake pipeline that demonstrates
    ...    reading from and writing to mounted file locations
    ...    📋 ASSERTIONS:
    ...    • Pipeline file (.slp) exists and is readable
    ...    • Pipeline import API call succeeds
    ...    • Unique pipeline ID is generated and returned
    ...    • Pipeline contains file reader and writer snaps configured for mounts
    ...    • Pipeline is successfully deployed to the project space
    [Tags]    snowflake_demo
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_file_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name2}    ${pipeline_file_name2}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    snowflake_demo    regression
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}
    ${unique_id}_2    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    ${GROUNDPLEX_NAME}

Execute Triggered Task
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    snowflake_demo
    [Template]    Run Triggered Task With Parameters From Template
    # ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}    table_name=DEMO.LIFEEVENTSDATA3

Verify Data In Snowflake Table
    [Documentation]    Verifies data in Snowflake table by executing a query and comparing results with expected output
    ...    Table is truncated before pipeline execution to ensure consistent test results
    ...    Retrieved data is exported to CSV for verification
    [Tags]    snowflake_demo

    Capture And Verify Number of records From Snowflake Table
    ...    ${task_params_set}[table_name]
    ...    ${task_params_set}[schema_name]
    ...    DCEVENTHEADERS_USERID
    ...    2

Export Snowflake Data To CSV
    [Documentation]    Exports data from Snowflake table to a CSV file for verification
    [Tags]    snowflake_demo4
    Export Snowflake Table Data To CSV
    ...    ${task_params_set}[table_name]
    ...    DCEVENTHEADERS_USERID
    ...    ${actual_output_file_from_db}

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing MySQL export against expected output
    ...    Ensures data processed through MySQL pipeline matches expectations
    ...    📋 ASSERTIONS:
    ...    • Exported MySQL CSV file exists locally
    ...    • Expected CSV file exists for comparison
    ...    • File structures are identical (headers match)
    ...    • Row counts are identical (no data loss during processing)
    ...    • All field values match exactly (no data corruption)
    ...    • No extra or missing rows (complete data processing)
    ...    • CSV formatting is preserved through pipeline
    [Tags]    snowflake_demo4
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
