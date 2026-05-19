*** Settings ***
Documentation       Baseline Test Suite — Baseline Data Extract Pipeline

# Standard Libraries
Library             OperatingSystem
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource

Suite Setup         Initialize Variables    # Generates ${unique_id} once for the whole suite


*** Variables ***
${pipeline_name_for_imported_slp_file}      oracle
${pipeline_slp_name}                        oracle.slp

# Used by the triggered-task examples below
${pipeline_name}                            prime_oracle_baseline_tests3
${task1}                                    My_Task

# Optional pipeline parameters — passed as a dictionary
&{task_params_set}                          oracle_acct=../shared/oracle_acct

# Optional notifications — fires emails on Completed / Failed states
@{notification_states}                      Completed    Failed
&{task_notifications}                       recipients=demo@example.com    states=${notification_states}

${task_timeout}                             300    # seconds


*** Test Cases ***
Import Pipeline
    [Documentation]    Imports both the parent and child pipeline (.slp files) into
    ...
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    create_triggeredtask_sample
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_2    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_3    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_4    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_5    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_6    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_7    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_8    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_9    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_10    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}_11    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp

Import existing child Pipeline Wihout Unique ID
    [Documentation]    Imports pipelines using their original name without appending
    ...    a unique suffix. Use this when the pipeline name must remain exactly as-is
    ...    (e.g., when downstream tasks or expressions reference the pipeline by a fixed name).
    [Tags]    create_triggeredtask_sample
    [Template]    Import Pipeline With Original Name
    ${PIPELINES_LOCATION_PATH}    prime_oracle_child_pipeline    prime_oracle_child_pipeline.slp

Create Triggered Task For Pipeline
    [Documentation]    Creates a triggered task for the parent pipeline and returns
    ...    the task name and task snode id used to execute it.
    ...    Prerequisites:
    ...    - Import Pipeline must have completed (pipeline exists in project)
    ...    - Groundplex must be running and registered
    ...
    ...    Each row below shows ONE valid way to call `Create Triggered Task From Template`.
    ...    All 4 required arguments must always be present; the 4 optional ones can be
    ...    supplied positionally, named (`name=value`), or omitted entirely.
    [Tags]    create_triggeredtask_sample
    [Template]    Create Triggered Task From Template

    # ── Case 1: BARE MINIMUM — only the 4 required args ────────────────────────────────────────────
    # plex_name defaults to ${groundplex_name}, params/notification/timeout default to None.
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}

    # ── Case 2: ALL POSITIONAL (full 8 args) ───────────────────────────────────────────────────────
    ${unique_id}_2    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}    ${task_timeout}

    # ── Case 3: 7 POSITIONAL — drop the trailing timeout ───────────────────────────────────────────
    ${unique_id}_3    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}

    # ── Case 4: PLEX OVERRIDE ONLY (5 positional) ──────────────────────────────────────────────────
    ${unique_id}_4    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}

    # ── Case 5: PIPELINE PARAMS ONLY — skip plex (named arg) ───────────────────────────────────────
    ${unique_id}_5    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    pipeline_params=${task_params_set}

    # ── Case 6: NOTIFICATIONS ONLY — skip plex AND params (named arg) ──────────────────────────────
    ${unique_id}_6    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    notification=${task_notifications}

    # ── Case 7: TIMEOUT ONLY — skip plex, params, notification (named arg) ─────────────────────────
    # plex_name falls back to its default value: ${groundplex_name} — the global suite variable Robot reads from your loaded .env files.
    ${unique_id}_7    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    execution_timeout=${task_timeout}

    # ── Case 8: PLEX (positional) + NOTIFICATIONS (named) — skip params ────────────────────────────
    ${unique_id}_8    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    notification=${task_notifications}

    # ── Case 9: NAMED-ONLY for all optional args (skip in any order) ───────────────────────────────
    ${unique_id}_9    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    notification=${task_notifications}    execution_timeout=${task_timeout}

    # ── Case 10: ALL NAMED — every argument passed by name=value (verbose but explicit) ────────────
    # Even required args can be named. Order doesn't matter when everything is named.
    unique_id=${unique_id}_10    project_path=${PIPELINES_LOCATION_PATH}    pipeline_name=${pipeline_name}    task_name=${task1}    plex_name=${GROUNDPLEX_NAME}    pipeline_params=${task_params_set}    notification=${task_notifications}    execution_timeout=${task_timeout}

    # ── Case 11: ALL NAMED in SCRAMBLED order — same result as Case 10 ─────────────────────────────
    # Demonstrates that with named args, position is irrelevant.
    plex_name=${GROUNDPLEX_NAME}    task_name=${task1}    unique_id=${unique_id}    pipeline_name=${pipeline_name}    project_path=${PIPELINES_LOCATION_PATH}    notification=${task_notifications}

Create Triggered Task For Pipelines which dont have unique suffix in their name
    [Documentation]    Creates a triggered task for the parent pipeline that was imported
    ...    without a unique suffix (via Import Pipeline With Original Name).
    ...    The task name still includes unique_id to avoid collisions across runs,
    ...    but the pipeline snode lookup uses the original pipeline name (no suffix).
    ...    Prerequisites:
    ...    - Import existing    Pipeline must have completed
    ...    - Groundplex must be running and registered
    [Tags]    create_triggeredtask_sample
    [Template]    Create Triggered Task For Original Pipeline Name
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task1}    ${GROUNDPLEX_NAME}    ${task_params_set}    ${task_notifications}


*** Keywords ***
Initialize Variables
    [Documentation]    Generates a unique ID for this test run and sets it as a suite variable.
    ...    The unique_id is used for pipeline naming to avoid conflicts between test runs.
    ...    shared across all test cases via Set Suite Variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes
