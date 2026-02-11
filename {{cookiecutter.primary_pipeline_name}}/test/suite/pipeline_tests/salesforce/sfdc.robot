*** Settings ***
Documentation       Test Suite for MySQL Database Integration with Pipeline Tasks
...                 This suite validates MySQL database integration by:
...                 1. Creating necessary database tables and stored procedures
...                 2. Importing and configuring pipeline tasks
...                 3. Executing tasks and verifying database interactions
...                 4. Testing control date updates and stored procedure execution

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             DatabaseLibrary    # Generic database operations
Library             pymysql    # MySQL specific operations
Library             DependencyLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package
Resource            ../../../resources/common/files.resource    # CSV/JSON file operations
# Suite Setup    Check connections    # Check if the connection to the MySQL database is successful and snaplex is up


*** Variables ***
# Project Configuration

${upload_source_file_path}          ${CURDIR}/../../test_data/actual_expected_data/expression_libraries
${container_source_file_path}       opt/snaplogic/test_data/actual_expected_data/expression_libraries

# MySQL Pipeline and Task Configuration
${ACCOUNT_PAYLOAD_FILE}             acc_salesforce.json
${pipeline_name}                    salesforce
${pipeline_name_slp}                salesforce.slp
${task1}                            SFDC_Task
${task2}                            SFDC_Task2

# MySQL test data configuration
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
...                                 Mysql_Slim_Account=shared/${MYSQL_ACCOUNT_NAME}


*** Test Cases ***
Create Account
    [Documentation]    Creates a MySQL account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    sfdc    regression
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SALESFORCE_ACCOUNT_PAYLOAD_FILE_NAME}    ${SALESFORCE_ACCOUNT_NAME}


*** Keywords ***
Initialize Variables
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
