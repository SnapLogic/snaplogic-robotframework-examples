*** Settings ***
Documentation       Baseline Test Suite — Baseline Data Extract Pipeline

# Standard Libraries
Library             OperatingSystem
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../resources/common/general.resource

Suite Setup         Initialize Variables    # Generates ${unique_id} once for the whole suite


*** Variables ***
${pipeline_name_for_imported_slp_file}      oracle
${pipeline_slp_name}                        oracle.slp


*** Test Cases ***
Import Pipeline
    [Documentation]    Imports both the parent and child pipeline (.slp files) into
    ...
    ...    Uses unique_id generated in suite setup for unique pipeline naming.
    [Tags]    import_pipeline_sample
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name_for_imported_slp_file}    ${pipeline_slp_name}

Import existing child Pipeline Wihout Unique ID
    [Documentation]    Imports pipelines using their original name without appending
    ...    a unique suffix. Use this when the pipeline name must remain exactly as-is
    ...    (e.g., when downstream tasks or expressions reference the pipeline by a fixed name).
    [Tags]    import_pipeline_sample
    [Template]    Import Pipeline With Original Name
    ${PIPELINES_LOCATION_PATH}    email    email.slp
    # ${PIPELINES_LOCATION_PATH}    email    email.slp    duplicate_check=true


*** Keywords ***
Initialize Variables
    [Documentation]    Generates a unique ID for this test run and sets it as a suite variable.
    ...    The unique_id is used for pipeline naming to avoid conflicts between test runs.
    ...    shared across all test cases via Set Suite Variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes
