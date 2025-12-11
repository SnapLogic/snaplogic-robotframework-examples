*** Settings ***
Documentation       Snowflake Database Integration Tests
...                 Using snowflake_keywords.resource which wraps the SnowflakeHelper Python library
...                 Environment variables are automatically loaded from .env file via Docker

Library             Collections
Library             OperatingSystem
Resource            ../../../resources/snowflake/snowflake_keywords_databaselib.resource    # For Snowflake connection
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/common/files.resource
Resource            ../../../resources/common/sql_table_operations.resource    # Generic SQL operations
Resource            ../../test_data/queries/snowflake_queries.resource    # Snowflake SQL queries

Suite Setup         Check connections    # Check if the connection to the MySQL database is successful and snaplex is up


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
...                                 schema_name=PUBLIC
...                                 table_name=PUBLIC.TEST

# Actual and Expected output file paths for verification
${actual_output_file_from_db}       ${CURDIR}/../../test_data/actual_expected_data/actual_output/snowflake/${pipeline_name}_actual_output_from_snowflake_db.csv    # Actual output files for comparison
${expected_output_file}             ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake/snowflake_inserted_data.csv    # Expected Output file (User have to create it)


*** Test Cases ***
End to End Verification Of Snowflake Pipeline
    [Documentation]    End to end test case to verify Snowflake pipeline functionality
    ...    including account creation, pipeline import, task creation, task execution,
    ...    data verification in Snowflake table, and exporting data to CSV for validation.
    [Tags]    snowflake_demo_end_to_end    end_to_end
    Clean Table    ${task_params_set}[table_name]    ${task_params_set}[schema_name]

    Create Account From Template
    ...    ${ACCOUNT_LOCATION_PATH}
    ...    ${SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME}
    ...    ${sf_acct}

    Upload File Using File Protocol Template
    ...    ${CURDIR}/../../test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr
    ...    ${ACCOUNT_LOCATION_PATH}

    Import Pipelines From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${pipeline_file_name}

    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task_name}
    ...    ${GROUNDPLEX_NAME}
    ...    ${task_params_set}
    ...    ${task_notifications}

    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${PIPELINES_LOCATION_PATH}
    ...    ${pipeline_name}
    ...    ${task_name}

    Capture And Verify Number of records From Snowflake Table
    ...    ${task_params_set}[table_name]
    ...    ${task_params_set}[schema_name]
    ...    DCEVENTHEADERS_USERID
    ...    2

    Export Snowflake Table Data To CSV
    ...    ${task_params_set}[table_name]
    ...    DCEVENTHEADERS_USERID
    ...    ${actual_output_file_from_db}

    Compare CSV Files Template
    ...    ${actual_output_file_from_db}
    ...    ${expected_output_file}
    ...    ${FALSE}
    ...    ${TRUE}
    ...    IDENTICAL


*** Keywords ***
Check connections
    [Documentation]    Verifies snowflake database connection and Snaplex availability
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

    Log    🔧 Initializing test environment for file mount demonstration
    Log    📋 Test ID: ${unique_id}
    # Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Snowflake Cloud DB

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
