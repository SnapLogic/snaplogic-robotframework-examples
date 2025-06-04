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
Resource            ../test_data/queries/oracle_queries.resource    # Oracle SQL queries
Resource            ../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Check connections    # Check if the connection to the Oracle database is successful and snaplex is up


*** Variables ***
# Project Configuration
${project_path}                 ${org_name}/${project_space}/${project_name}
${pipeline_file_path}           ${CURDIR}/../../../src/pipelines

# Oracle_Pipeline and Task Configuration
${ACCOUNT_PAYLOAD_FILE}         acc_oracle.json
${pipeline_name}                oracle
${pipeline_name_slp}            oracle.slp
${task1}                        Oracle_Task
${task2}                        Oracle_Task2

@{notification_states}          Completed    Failed
&{task_notifications}
...                             recipients=newemail@gmail.com
...                             states=${notification_states}

&{task_params_set1}
...                             M_CURR_DATE=10/12/2024
...                             DOMAIN_NAME=SLIM_DOM2
...                             ${ORACLE_ACCOUNT_NAME}=shared/${ORACLE_ACCOUNT_NAME}
&{task_params_updated_set1}
...                             M_CURR_DATE=10/13/2024
...                             DOMAIN_NAME=SLIM_DOM3
...                             ${ORACLE_ACCOUNT_NAME}=shared/${ORACLE_ACCOUNT_NAME}


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    ...    "account_payload_path"    value as assigned to global variable    in __init__.robot file
    [Tags]    create_account    oracle
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Import Pipelines
    [Documentation]    Imports the    pipeline
    ...    Returns:
    ...    uniquie_id --> which is used untill executinh the tasks
    ...    pipeline_snodeid--> which is used to create the tasks
    [Tags]    import_pipeline2    oracle
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    create_triggered_task    oracle
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    create_triggered_task    oracle
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    M_CURR_DATE=10/12/2024

End to End Pipeline Workflow
    [Tags]    end_to_end_workflow    import_pipeline    oracle2

    # Step 1: Create Account
    Create Account From Template    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}    ${env_file_path}

    # Step 2: Import Pipelines
    Import Pipelines From Template    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_name_slp}

    # Step 3: Create Triggered Tasks
    Create Triggered Task From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task1}
    ...    ${task_params_set1}
    ...    ${task_notifications}

    # Step 5: Update Task Parameters
    Run Triggered Task With Parameters From Template
    ...    ${unique_id}
    ...    ${project_path}
    ...    ${pipeline_name}
    ...    ${task1}
    ...    M_CURR_DATE=10/12/2024


*** Keywords ***
Check connections
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to Oracle Database
    ...    ${ORACLE_DBNAME}
    ...    ${ORACLE_DBUSER}
    ...    ${ORACLE_DBPASS}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_DBPORT}
    Initialize Variables

Initialize Variables
    ${unique_id}    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
