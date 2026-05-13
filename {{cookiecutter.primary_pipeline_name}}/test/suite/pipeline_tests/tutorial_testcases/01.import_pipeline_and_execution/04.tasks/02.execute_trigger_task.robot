*** Settings ***
Documentation       Baseline Test Suite — Baseline Data Extract Pipeline

# Standard Libraries
Library             OperatingSystem
Library             DependencyLibrary    # Enables `Depends On Test` for test-to-test ordering
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource

Suite Setup         Initialize Variables    # Generates ${unique_id} once for the whole suite


*** Variables ***
${pipeline_name}                    filereader
${pipeline_slp_name}                sample_filereader_pl.slp

# Used by the triggered-task examples below
${task1}                            My_Task

# Optional pipeline parameters — passed as a dictionary
&{task_params_set}                  filereader_acct=../shared/filereader_acct2
...                                 file_name=acct_params.json

# Optional notifications — fires emails on Completed / Failed states
@{notification_states}              Completed    Failed
&{task_notifications}               recipients=demo@example.com    states=${notification_states}

${task_timeout}                     300    # seconds

# Where to save the captured trigger response. Shared by:
#    - "Execute Trigger Task And Save Response To Local Folder" (writes the file)
#    - "Verify Captured Response File Exists" (reads/asserts the file)
#
# Same actual_output convention used by oracle_baseline_tests.robot and postgres_to_s3.robot.
# The directory is auto-created by the library keyword if it doesn't exist.
${captured_response_dir}            ${CURDIR}/../../../../test_data/actual_expected_data/actual_output/filereader
${captured_response_filename}       filereader_response.json


*** Test Cases ***
Create Account
    [Documentation]    Creates accounts in the project space using the provided payload files.
    ...    ACCOUNT_LOCATION_PATH comes from the root ".env" file.
    ...    Each <DB>_ACCOUNT_PAYLOAD_FILE_NAME and <DB>_ACCOUNT_NAME come from the matching
    ...    env_files/database_accounts/.env.<db> file (e.g. .env.sqlserver, .env.oracle, .env.postgres,
    ...    .env.mysql, .env.db2, .env.teradata).
    [Tags]    execute_triggered_task_sample
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${FILEREADER_ACCOUNT_PAYLOAD_FILE_NAME}    filereader_acct2    overwrite_if_exists=${TRUE}

Upload Files
    [Documentation]    Data-driven test case that uploads one or more files to SnapLogic SLDB.
    [Tags]    execute_triggered_task_sample
    [Template]    Upload Files To SnapLogic From Template

    # Columns: source_dir (local)    file_name    destination_path
    ${CURDIR}/../../../../test_data/actual_expected_data/input_data/file_reader    s3_format_data.json    ${ACCOUNT_LOCATION_PATH}

Import Pipeline
    [Documentation]    Imports pipeline
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    execute_triggered_task_sample
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${pipeline_slp_name}

Create Triggered Task For Pipeline
    [Documentation]    Creates a triggered task for the    pipeline
    [Tags]    execute_triggered_task_sample
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}

Execute Triggered Task With Parameters
    [Documentation]    Executes the triggered task for the    pipeline.
    [Tags]    execute_triggered_task_sample
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}

Execute Trigger Task And Save Response To Local Folder
    [Documentation]    Updates task parameters, triggers the task, and saves the HTTP
    ...    response body to a local folder. Uses the template form — each row
    ...    becomes one call to ``Run Triggered Task And Save Response From Template``.
    [Tags]    execute_triggered_task_sample
    [Template]    Run Triggered Task And Save Response From Template

    # Columns: unique_id    project_path    pipeline_name    task_name    output_dir    output_filename    [&{new_parameters} expanded]
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${captured_response_dir}    ${captured_response_filename}

Verify Captured Response File Exists
    [Documentation]    Verifies that the captured trigger response file exists on disk
    ...    and is not empty. Path is derived from suite variables shared with
    ...    the previous test case (no run-time hand-off needed).
    ...
    ...    Depends on "Execute Trigger Task And Save Response To Local Folder":
    ...    if that test fails (or is skipped), this test is SKIPPED rather than
    ...    failing with a misleading "file not found" error.
    [Tags]    execute_triggered_task_sample2

    Depends On Test    Execute Trigger Task And Save Response To Local Folder

    ${file_path}=    Join Path    ${captured_response_dir}    ${captured_response_filename}
    File Should Exist    ${file_path}
    ${content}=    Get File    ${file_path}
    Should Not Be Empty    ${content}


*** Keywords ***
Initialize Variables
    [Documentation]    Generates a unique ID for this test run and sets it as a suite variable.
    ...    The unique_id is used for pipeline naming to avoid conflicts between test runs.
    ...    shared across all test cases via Set Suite Variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes
