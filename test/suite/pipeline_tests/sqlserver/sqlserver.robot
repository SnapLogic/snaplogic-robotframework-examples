*** Settings ***
Documentation       Test Suite for SQL Server Database Integration with Pipeline Tasks
...                 This suite validates SQL Server database integration by:
...                 1. Creating necessary database tables and stored procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and stored procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             DatabaseLibrary    # Generic database operations
Library             pymssql    # SQL Server specific operations
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../../test_data/queries/sqlserver_queries.resource    # SQL Server queries
Resource            ../../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the SQL Server database is successful and snaplex is up


*** Variables ***
# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               ${CURDIR}/../../../../src/pipelines

${upload_source_file_path}          ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${container_source_file_path}       opt/snaplogic/test_data/actual_expected_data/expression_libraries
${upload_destination_file_path}     ${org_name}/${project_space}/${project_name}

# SQL Server Pipeline and Task Configuration
${ACCOUNT_PAYLOAD_FILE}             acc_sqlserver.json
${pipeline_name}                    sqlserver
${pipeline_name_slp}                sqlserver.slp
${task1}                            SQLServer_Task
${task2}                            SQLServer_Task2

# SQL Server test data configuration
${CSV_DATA_TO_DB}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/employees.csv    # Source CSV from input_data folder
${JSON_DATA_TO_DB}                  ${CURDIR}/../../test_data/actual_expected_data/input_data/employees.json    # Source JSON from input_data folder
${ACTUAL_DATA_DIR}                  ${CURDIR}/../../test_data/actual_expected_data/actual_output    # Base directory for downloaded files from S3
${EXPECTED_OUTPUT_DIR}              ${CURDIR}/../../test_data/actual_expected_data/expected_output    # Expected output files for comparison

@{notification_states}              Completed    Failed
&{task_notifications}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states}

&{task_params_set1}
...                                 M_CURR_DATE=10/12/2024
...                                 DOMAIN_NAME=SLIM_DOM2
...                                 SQLServer_Slim_Account=shared/${SQLSERVER_ACCOUNT_NAME}
&{task_params_updated_set1}
...                                 M_CURR_DATE=10/13/2024
...                                 DOMAIN_NAME=SLIM_DOM3
...                                 SQLServer_Slim_Account=shared/${SQLSERVER_ACCOUNT_NAME}


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    sqlserver
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

################## DATA SETUP    ##################
# Test execution order:
# 1. Create accounts (SQL Server)
# 2. Create database tables
# 3. Load CSV data (2 rows)
# 4. Load JSON data (2 more rows, total = 4 rows)

Create table for DB Operations
    [Documentation]    Creates the employees table structure in SQL Server database
    ...    📋 ASSERTIONS:
    ...    • SQL table creation statement executes successfully
    ...    • Table structure matches expected schema (id, name, role, salary columns)
    ...    • Database connection is established and functional
    ...    • No SQL syntax or permission errors occur
    [Tags]    sqlserver    data_setup
    [Template]    Execute SQL String
    ${DROP_TABLE_EMPLOYEES}
    ${CREATE_TABLE_EMPLOYEES}
    ${DROP_TABLE_EMPLOYEES2}
    ${CREATE_TABLE_EMPLOYEES2}

Load CSV Data To SQL Server
    [Documentation]    Loads CSV employee data into SQL Server with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • CSV file exists and is readable
    ...    • Auto-detected row count from CSV file (excludes header)
    ...    • Database connection successful
    ...    • All CSV rows successfully inserted into employees table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table truncated before insertion (clean state)
    ...    • CSV column mapping to database columns successful
    [Tags]    sqlserver    data_setup
    [Template]    Load CSV Data Template
    # CSV File    table_name    Truncate Table
    ${CSV_DATA_TO_DB}    employees    ${TRUE}

Load JSON Data To SQL Server
    [Documentation]    Loads JSON employee data into SQL Server with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • JSON file exists and is valid JSON format
    ...    • Auto-detected row count from JSON array elements
    ...    • Database connection maintained
    ...    • All JSON records successfully appended to employees table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table NOT truncated (appends to existing CSV data)
    ...    • JSON field mapping to database columns successful
    ...    • JSON rows
    [Tags]    sqlserver    data_setup
    [Template]    Load JSON Data Template
    # JSON File    table_name    Truncate Table
    ${JSON_DATA_TO_DB}    employees2    ${TRUE}

Import Pipelines
    [Documentation]    Imports the SQL Server pipeline
    ...    Returns:
    ...    unique_id --> which is used until executing the tasks
    ...    pipeline_snodeid --> which is used to create the tasks
    [Tags]    sqlserver
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    sqlserver
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    sqlserver
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    M_CURR_DATE=10/12/2024

################## COMPARISION TESTING    ##################

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing SQL Server export against expected output
    ...    Ensures data processed through SQL Server pipeline matches expectations
    ...    📋 ASSERTIONS:
    ...    • Exported SQL Server CSV file exists locally
    ...    • Expected CSV file exists for comparison
    ...    • File structures are identical (headers match)
    ...    • Row counts are identical (no data loss during processing)
    ...    • All field values match exactly (no data corruption)
    ...    • No extra or missing rows (complete data processing)
    ...    • CSV formatting is preserved through pipeline
    [Tags]    sqlserver
    [Template]    Compare CSV Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${ACTUAL_DATA_DIR}/employee_sqlserver.csv    ${EXPECTED_OUTPUT_DIR}/employee_sqlserver.csv    ${FALSE}    ${TRUE}    IDENTICAL


*** Keywords ***
Check connections
    [Documentation]    Verifies SQL Server database connection and Snaplex availability
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to SQL Server Database
    ...    ${SQLSERVER_DBNAME}
    ...    ${SQLSERVER_DBUSER}
    ...    ${SQLSERVER_DBPASS}
    ...    ${SQLSERVER_HOST}
    ...    ${SQLSERVER_DBPORT}
    Initialize Variables

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
