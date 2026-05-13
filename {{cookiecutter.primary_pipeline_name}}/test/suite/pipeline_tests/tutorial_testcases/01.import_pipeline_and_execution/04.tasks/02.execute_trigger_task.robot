*** Settings ***
Documentation       Baseline Test Suite — Baseline Data Extract Pipeline

# Standard Libraries
Library             OperatingSystem
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource

Suite Setup         Initialize Variables    # Generates ${unique_id} once for the whole suite


*** Variables ***
${pipeline_name}            oracle
${pipeline_slp_name}        oracle.slp

# Used by the triggered-task examples below
${task1}                    My_Task

# Optional pipeline parameters — passed as a dictionary
&{task_params_set}          oracle_acct=../shared/oracle_acct

# Optional notifications — fires emails on Completed / Failed states
@{notification_states}      Completed    Failed
&{task_notifications}       recipients=demo@example.com    states=${notification_states}

${task_timeout}             300    # seconds


*** Test Cases ***
Create Account
    [Documentation]    Creates accounts in the project space using the provided payload files.
    ...    ACCOUNT_LOCATION_PATH comes from the root ".env" file.
    ...    Each <DB>_ACCOUNT_PAYLOAD_FILE_NAME and <DB>_ACCOUNT_NAME come from the matching
    ...    env_files/database_accounts/.env.<db> file (e.g. .env.sqlserver, .env.oracle, .env.postgres,
    ...    .env.mysql, .env.db2, .env.teradata).
    [Tags]    execute_triggered_task_sample
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    oracle_acct    overwrite_if_exists=${TRUE}

Import Pipeline
    [Documentation]    Imports pipeline
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    execute_triggered_task_sample
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_slp_name}

Import existing Pipeline Wihout Unique ID
    [Documentation]    Imports pipelines using their original name without appending
    ...    a unique suffix. Use this when the pipeline name must remain exactly as-is
    ...    (e.g., when downstream tasks or expressions reference the pipeline by a fixed name).
    [Tags]    execute_triggered_task_sample
    [Template]    Import Pipeline With Original Name
    ${PIPELINES_LOCATION_PATH}    oracle    oracle.slp

Create Triggered Task For Pipeline
    [Documentation]    Creates a triggered task for the    pipeline
    [Tags]    execute_triggered_task_sample
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}    ${task_timeout}

Execute Triggered Task With Parameters
    [Documentation]    Executes the triggered task for the    pipeline.
    [Tags]    execute_triggered_task_sample
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}


*** Keywords ***
Initialize Variables
    [Documentation]    Generates a unique ID for this test run and sets it as a suite variable.
    ...    The unique_id is used for pipeline naming to avoid conflicts between test runs.
    ...    shared across all test cases via Set Suite Variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes
