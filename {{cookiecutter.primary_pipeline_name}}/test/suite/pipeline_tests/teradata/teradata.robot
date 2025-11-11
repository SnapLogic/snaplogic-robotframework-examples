*** Settings ***
Documentation       Test Suite for Teradata Database Integration with Pipeline Tasks
...                 This suite validates Teradata database integration by:
...                 1. Creating necessary database tables and stored procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and stored procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             DatabaseLibrary    # Generic database operations
Library             teradatasql    # Teradata specific operations
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../../test_data/queries/teradata_queries.resource    # Teradata queries
Resource            ../../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the Teradata database is successful and snaplex is up


*** Variables ***
# Project Configuration

${upload_source_file_path}          ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${container_source_file_path}       opt/snaplogic/test_data/actual_expected_data/expression_libraries

# Teradata Pipeline and Task Configuration
${ACCOUNT_PAYLOAD_FILE}             acc_teradata.json
${pipeline_name}                    teradata
${pipeline_name_slp}                teradata.slp
${task1}                            Teradata_Task
${task2}                            Teradata_Task2

# Teradata test data configuration
${CSV_DATA_TO_DB}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/teradata/employees.csv    # Source CSV from input_data folder
${JSON_DATA_TO_DB}                  ${CURDIR}/../../test_data/actual_expected_data/input_data/teradata/employees.json    # Source JSON from input_data folder
${DEPARTMENTS_CSV}                  ${CURDIR}/../../test_data/actual_expected_data/input_data/teradata/departments.csv    # Departments CSV
${ACTUAL_DATA_DIR}                  ${CURDIR}/../../test_data/actual_expected_data/actual_output    # Base directory for downloaded files from S3
${EXPECTED_OUTPUT_DIR}              ${CURDIR}/../../test_data/actual_expected_data/expected_output    # Expected output files for comparison

@{notification_states}              Completed    Failed
&{task_notifications}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states}

&{task_params_set1}
...                                 M_CURR_DATE=10/12/2024
...                                 DOMAIN_NAME=SLIM_DOM2
...                                 Teradata_Slim_Account=shared/${TERADATA_ACCOUNT_NAME}
&{task_params_updated_set1}
...                                 M_CURR_DATE=10/13/2024
...                                 DOMAIN_NAME=SLIM_DOM3
...                                 Teradata_Slim_Account=shared/${TERADATA_ACCOUNT_NAME}


*** Test Cases ***
Upload Files With File Protocol
    [Documentation]    Demonstrates uploading Teradata JDBC driver files using file:/// protocol
    ...    from directories mounted in the SnapLogic Groundplex container
    ...    📋 ASSERTIONS:
    ...    • Files exist in the mounted directory path
    ...    • File protocol URLs are correctly formed
    ...    • Upload operation succeeds using file:/// protocol
    ...    • Files are accessible in SnapLogic project space
    [Tags]    teradata    teradatajdbc    regression
    [Template]    Upload File Using File Protocol Template
    file:///opt/snaplogic/test_data/accounts_jar_files/teradata/terajdbc4.jar    ${ACCOUNT_LOCATION_PATH}
    file:///opt/snaplogic/test_data/accounts_jar_files/teradata/tdgssconfig.jar    ${ACCOUNT_LOCATION_PATH}

Create Account
    [Documentation]    Creates a Teradata account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    teradata    regression
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${TERADATA_ACCOUNT_PAYLOAD_FILE_NAME}    ${TERADATA_ACCOUNT_NAME}

################## DATA SETUP    ##################
# Test execution order:
# 1. Create accounts (Teradata)
# 2. Create database tables
# 3. Load CSV data (2 rows)
# 4. Load JSON data (2 more rows, total = 4 rows)

Create table for DB Operations
    [Documentation]    Creates the employees table structure in Teradata database
    ...    📋 ASSERTIONS:
    ...    • SQL table creation statement executes successfully
    ...    • Table structure matches expected schema (id, name, role, salary columns)
    ...    • Database connection is established and functional
    ...    • No SQL syntax or permission errors occur
    [Tags]    teradata    data_setup    regression
    [Template]    Execute SQL String
    ${DROP_TABLE_EMPLOYEES}
    ${CREATE_TABLE_EMPLOYEES}
    ${DROP_TABLE_EMPLOYEES2}
    ${CREATE_TABLE_EMPLOYEES2}

Create Control Date Table
    [Documentation]    Creates the control date table for managing pipeline execution dates
    ...    📋 ASSERTIONS:
    ...    • Control date table creation successful
    ...    • Table structure includes domain_name, control_date, and last_updated columns
    ...    • Primary key constraint on domain_name established
    ...    • Timestamp auto-update functionality configured
    [Tags]    teradata    data_setup    regression
    [Template]    Execute SQL String
    ${DROP_TABLE_CONTROL_DATE}
    ${CREATE_TABLE_CONTROL_DATE}
    ${INSERT_CONTROL_DATE}

Load CSV Data To Teradata
    [Documentation]    Loads CSV employee data into Teradata with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • CSV file exists and is readable
    ...    • Auto-detected row count from CSV file (excludes header)
    ...    • Database connection successful
    ...    • All CSV rows successfully inserted into employees table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table cleared before insertion (clean state)
    ...    • CSV column mapping to database columns successful
    [Tags]    teradata    data_setup    regression
    [Template]    Load CSV Data Template
    # CSV File    table_name    Clear Table (Teradata uses DELETE instead of TRUNCATE)
    ${CSV_DATA_TO_DB}    employees    ${TRUE}

Load JSON Data To Teradata
    [Documentation]    Loads JSON employee data into Teradata with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • JSON file exists and is valid JSON format
    ...    • Auto-detected row count from JSON array elements
    ...    • Database connection maintained
    ...    • All JSON records successfully inserted into employees2 table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table cleared before insertion (clean state)
    ...    • JSON field mapping to database columns successful
    [Tags]    teradata    regression
    [Template]    Load JSON Data Template
    # JSON File    table_name    Clear Table
    ${JSON_DATA_TO_DB}    employees2    ${TRUE}

Verify Data Load
    [Documentation]    Verifies that data was loaded correctly into Teradata tables
    ...    📋 ASSERTIONS:
    ...    • employees table contains expected number of rows
    ...    • employees2 table contains expected number of rows
    ...    • departments table contains expected number of rows
    ...    • Data integrity maintained during load operations
    [Tags]    teradata    regression
    ${count1}=    Query    ${COUNT_EMPLOYEES}
    ${count2}=    Query    ${COUNT_EMPLOYEES2}
    ${count3}=    Query    SELECT COUNT(*) FROM departments
    Log    Employees table has ${count1[0][0]} rows
    Log    Employees2 table has ${count2[0][0]} rows
    Log    Departments table has ${count3[0][0]} rows
    Should Be Equal As Numbers    ${count1[0][0]}    2    Employees table should have 2 rows from CSV
    Should Be Equal As Numbers    ${count2[0][0]}    2    Employees2 table should have 2 rows from JSON
    Should Be Equal As Numbers    ${count3[0][0]}    4    Departments table should have 4 rows

Import Pipelines
    [Documentation]    Imports the Teradata pipeline
    ...    Returns:
    ...    unique_id --> which is used until executing the tasks
    ...    pipeline_snodeid --> which is used to create the tasks
    [Tags]    teradata    regression
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    teradata    regression
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    teradata    regression
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    M_CURR_DATE=10/12/2024

Test Control Date Operations
    [Documentation]    Tests control date table operations for pipeline date management
    ...    📋 ASSERTIONS:
    ...    • Control date can be updated successfully
    ...    • Date format conversion works correctly
    ...    • Select operations return expected format
    [Tags]    teradata    regression
    # Update control date
    Execute SQL String    ${UPDATE_CONTROL_DATE}    12/25/2024    SLIM_DOM1

    # Select and verify
    ${result}=    Query    ${SELECT_CONTROL_DATE}    SLIM_DOM1
    Log    Control date result: ${result[0]}
    Should Be Equal    ${result[0][0]}    SLIM_DOM1
    Should Be Equal    ${result[0][1]}    12/25/2024

Test Teradata Specific Features
    [Documentation]    Tests Teradata-specific database features
    ...    📋 ASSERTIONS:
    ...    • Volatile tables can be created and used
    ...    • Statistics collection works properly
    ...    • Macros can be created and executed
    [Tags]    teradata    regression
    # Test volatile table
    Execute SQL String    ${CREATE_VOLATILE_TABLE}
    ${count}=    Query    SELECT COUNT(*) FROM vt_temp_employees
    Log    Volatile table has ${count[0][0]} rows
    Execute SQL String    ${DROP_VOLATILE_TABLE}

    # Test statistics collection
    Execute SQL String    ${COLLECT_STATS}

    # Test macro creation and execution
    Execute SQL String    ${CREATE_MACRO}
    ${result}=    Query    ${EXEC_MACRO}    1
    Log    Macro result: ${result}
    Execute SQL String    ${DROP_MACRO}

Test Join Operations
    [Documentation]    Tests join operations between employees and departments
    ...    📋 ASSERTIONS:
    ...    • Join queries execute successfully
    ...    • Data relationships are properly maintained
    ...    • Complex queries with multiple tables work
    [Tags]    teradata    regression
    # First, update employees table to add department references
    Execute SQL String    ALTER TABLE employees ADD department_id INTEGER
    Execute SQL String    UPDATE employees SET department_id = 1 WHERE id = 1
    Execute SQL String    UPDATE employees SET department_id = 2 WHERE id = 2

    # Test join query
    ${result}=    Query    SELECT e.name, e.role, d.department_name, d.location
    ...    FROM employees e
    ...    JOIN departments d ON e.department_id = d.department_id

    Log    Join query returned ${result}
    ${row_count}=    Get Length    ${result}
    Should Be Equal As Numbers    ${row_count}    2    Join should return 2 rows

################## COMPARISON TESTING    ##################

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing Teradata export against expected output
    ...    Ensures data processed through Teradata pipeline matches expectations
    ...    📋 ASSERTIONS:
    ...    • Exported Teradata CSV file exists locally
    ...    • Expected CSV file exists for comparison
    ...    • File structures are identical (headers match)
    ...    • Row counts are identical (no data loss during processing)
    ...    • All field values match exactly (no data corruption)
    ...    • No extra or missing rows (complete data processing)
    ...    • CSV formatting is preserved through pipeline
    [Tags]    teradata    regression
    [Template]    Compare CSV Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${ACTUAL_DATA_DIR}/employees_teradata.csv    ${EXPECTED_OUTPUT_DIR}/employees_teradata.csv    ${FALSE}    ${TRUE}    IDENTICAL


*** Keywords ***
Check connections
    [Documentation]    Verifies Teradata database connection and Snaplex availability
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to Teradata Database
    ...    ${TERADATA_HOST}
    ...    ${TERADATA_USER}
    ...    ${TERADATA_PASSWORD}
    ...    ${TERADATA_DBNAME}
    Initialize Variables

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

Connect to Teradata Database
    [Documentation]    Establishes connection to Teradata database using teradatasql
    [Arguments]    ${dbhost}    ${dbuser}    ${dbpass}    ${dbname}
    # Teradata connection using teradatasql driver
    ${connection_string}=    Set Variable
    ...    {"host":"${dbhost}","user":"${dbuser}","password":"${dbpass}","database":"${dbname}"}
    Connect To Database Using Custom Params    teradatasql    ${connection_string}
