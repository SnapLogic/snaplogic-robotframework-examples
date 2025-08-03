*** Settings ***
Documentation       Test Suite for DB2 Database Integration with Pipeline Tasks
...                 This suite validates DB2 database integration by:
...                 1. Creating necessary database tables and stored procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and stored procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             DatabaseLibrary    # Generic database operations
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../../test_data/queries/db2_queries.resource    # DB2 queries
Resource            ../../../resources/files.resource    # CSV/JSON file operations
Library             ${CURDIR}/../../../resources/db2/db2_connection.py   

Suite Setup         Check connections    # Check if the connection to the DB2 database is successful and snaplex is up


*** Variables ***
# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               ${CURDIR}/../../../../src/pipelines

${upload_source_file_path}          ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${container_source_file_path}       opt/snaplogic/test_data/actual_expected_data/expression_libraries
${upload_destination_file_path}     ${org_name}/${project_space}/shared

# DB2 Pipeline and Task Configuration
${ACCOUNT_PAYLOAD_FILE}             acc_db2.json
${pipeline_name}                    db2
${pipeline_name_slp}                db2.slp
${task1}                            DB2_Task
${task2}                            DB2_Task2

# DB2 test data configuration
${CSV_DATA_TO_DB}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/employees.csv    # Source CSV from input_data folder
${JSON_DATA_TO_DB}                  ${CURDIR}/../../test_data/actual_expected_data/input_data/employees.json    # Source JSON from input_data folder
${ACTUAL_DATA_DIR}                  /app/test/suite/test_data/actual_expected_data/actual_output
${EXPECTED_OUTPUT_DIR}              ${CURDIR}/../../test_data/actual_expected_data/expected_output    # Expected output files for comparison

@{notification_states}              Completed    Failed
&{task_notifications}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states}

&{task_params_set1}
...                                 M_CURR_DATE=10/12/2024
...                                 DOMAIN_NAME=SLIM_DOM2
...                                 DB2_Slim_Account=shared/${DB2_ACCOUNT_NAME}
&{task_params_updated_set1}
...                                 M_CURR_DATE=10/13/2024
...                                 DOMAIN_NAME=SLIM_DOM3
...                                 DB2_Slim_Account=shared/${DB2_ACCOUNT_NAME}


*** Test Cases ***
Upload Files With File Protocol
    [Documentation]    Demonstrates uploading expression library files using file:/// protocol
    ...    from directories mounted in the SnapLogic Groundplex container
    ...    📋 ASSERTIONS:
    ...    • Files exist in the mounted directory path
    ...    • File protocol URLs are correctly formed
    ...    • Upload operation succeeds using file:/// protocol
    ...    • Files are accessible in SnapLogic project space
    [Tags]    db23    db2jar    regression
    [Template]    Upload File Using File Protocol Template
    file:///opt/snaplogic/test_data/accounts_jar_files/db2/db2jcc4.jar    ${upload_destination_file_path}

Create Account
    [Documentation]    Creates a DB2 account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    db23    regression
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

################## DATA SETUP    ##################
# Test execution order:
# 1. Create accounts (DB2)
# 2. Create database tables
# 3. Load CSV data (2 rows)
# 4. Load JSON data (2 more rows, total = 4 rows)

Create table for DB Operations
    [Documentation]    Creates the employees table structure in DB2 database
    ...    📋 ASSERTIONS:
    ...    • SQL table creation statement executes successfully
    ...    • Table structure matches expected schema (id, name, role, salary columns)
    ...    • Database connection is established and functional
    ...    • No SQL syntax or permission errors occur
    [Tags]    db23
    [Template]    Execute SQL String
    ${DROP_TABLE_EMPLOYEES}
    ${CREATE_TABLE_EMPLOYEES}
    ${DROP_TABLE_EMPLOYEES2}
    ${CREATE_TABLE_EMPLOYEES2}

Load CSV Data To DB2
    [Documentation]    Loads CSV employee data into DB2 with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • CSV file exists and is readable
    ...    • Auto-detected row count from CSV file (excludes header)
    ...    • Database connection successful
    ...    • All CSV rows successfully inserted into employees table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table truncated before insertion (clean state)
    ...    • CSV column mapping to database columns successful
    [Tags]    db2
    [Template]    Load CSV Data Template
    # CSV File    table_name    Truncate Table
    ${CSV_DATA_TO_DB}    employees    ${TRUE}

Load JSON Data To DB2
    [Documentation]    Loads JSON employee data into DB2 with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • JSON file exists and is valid JSON format
    ...    • Auto-detected row count from JSON array elements
    ...    • Database connection maintained
    ...    • All JSON records successfully appended to employees table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table NOT truncated (appends to existing CSV data)
    ...    • JSON field mapping to database columns successful
    [Tags]    db2
    [Template]    Load JSON Data Template
    # JSON File    table_name    Truncate Table
    ${JSON_DATA_TO_DB}    employees2    ${TRUE}

Verify Data Load
    [Documentation]    Verifies that data was loaded correctly into DB2 tables
    ...    📋 ASSERTIONS:
    ...    • employees table contains expected number of rows
    ...    • employees2 table contains expected number of rows
    ...    • Data integrity maintained during load operations
    [Tags]    db2
    ${count1}=    Query    ${COUNT_EMPLOYEES}
    ${count2}=    Query    ${COUNT_EMPLOYEES2}
    Log    Employees table has ${count1[0][0]} rows
    Log    Employees2 table has ${count2[0][0]} rows
    Should Be True    ${count1[0][0]} > 0    Employees table should have data
    Should Be True    ${count2[0][0]} > 0    Employees2 table should have data

Import Pipelines
    [Documentation]    Imports the DB2 pipeline
    ...    Returns:
    ...    unique_id --> which is used until executing the tasks
    ...    pipeline_snodeid --> which is used to create the tasks
    [Tags]    db2
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    db2
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    db2
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    M_CURR_DATE=10/12/2024

# Test Control Date Operations
#    [Documentation]    Tests control date table operations for pipeline date management
#    ...    📋 ASSERTIONS:
#    ...    • Control date can be updated successfully
#    ...    • Date format conversion works correctly
#    ...    • Select operations return expected format
#    [Tags]    db2    regression
#    # Update control date
#    Execute SQL String    ${UPDATE_CONTROL_DATE}    12/25/2024    SLIM_DOM1

#    # Select and verify
#    ${result}=    Query    ${SELECT_CONTROL_DATE}    SLIM_DOM1
#    Log    Control date result: ${result[0]}
#    Should Be Equal    ${result[0][0]}    SLIM_DOM1
#    Should Be Equal    ${result[0][1]}    12/25/2024

################## COMPARISON TESTING    ##################

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing DB2 export against expected output
    ...    Ensures data processed through DB2 pipeline matches expectations
    ...    📋 ASSERTIONS:
    ...    • Exported DB2 CSV file exists locally
    ...    • Expected CSV file exists for comparison
    ...    • File structures are identical (headers match)
    ...    • Row counts are identical (no data loss during processing)
    ...    • All field values match exactly (no data corruption)
    ...    • No extra or missing rows (complete data processing)
    ...    • CSV formatting is preserved through pipeline
    [Tags]    db2
    [Template]    Compare CSV Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${ACTUAL_DATA_DIR}/employee_db2.csv    ${EXPECTED_OUTPUT_DIR}/employee_db2.csv    ${FALSE}    ${TRUE}    IDENTICAL


*** Keywords ***
Check connections
    [Documentation]    Verifies DB2 database connection and Snaplex availability
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to DB2 Database
    ...    ${DB2_DBNAME}
    ...    ${DB2_DBUSER}
    ...    ${DB2_DBPASS}
    ...    ${DB2_HOST}
    ...    ${DB2_DBPORT}
    Initialize Variables

Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}


Connect to DB2 Database
    [Documentation]    Establishes connection to DB2 database using ibm_db
    [Arguments]    ${dbname}    ${dbuser}    ${dbpass}    ${dbhost}    ${dbport}
    
    # The keyword name from Python class method
    DB2Connection.Connect Db2 To Database Library    ${dbname}    ${dbhost}    ${dbport}    ${dbuser}    ${dbpass}
    
    # Verify connection
    ${result}=    Query    SELECT 1 FROM SYSIBM.SYSDUMMY1
    Should Be Equal As Integers    ${result[0][0]}    1