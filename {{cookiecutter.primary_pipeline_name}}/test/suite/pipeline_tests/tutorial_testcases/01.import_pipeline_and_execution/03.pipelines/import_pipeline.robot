*** Settings ***
Documentation       Baseline Test Suite — Baseline Data Extract Pipeline

# Standard Libraries
Library             OperatingSystem
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource

Suite Setup         Initialize Variables    # Generates ${unique_id} once for the whole suite


*** Variables ***
${pipeline_name_for_imported_slp_file}      oracle.slp
${pipeline_slp_name}                        oracle


*** Test Cases ***
Import Pipeline
    [Documentation]    Imports both the parent and child pipeline (.slp files) into
    ...    the SnapLogic project space. Uses the unique_id generated in suite
    ...    setup so each test run produces uniquely-named pipelines and avoids
    ...    collisions with previous runs.
    ...
    ...    *Arguments (per template row):*
    ...    - ``unique_id``: Unique suffix appended to the pipeline name to
    ...      avoid naming collisions across test runs (e.g., ``20260513_153022_abc``).
    ...    - ``project_path``: SnapLogic project path where the pipeline will be
    ...      imported (e.g., ``${PIPELINES_LOCATION_PATH}``).
    ...    - ``pipeline_name``: Desired name for the imported pipeline in SnapLogic
    ...      (without the .slp extension). Will become ``<pipeline_name>_<unique_id>``.
    ...    - ``slp_file_name``: Source .slp file located under ``src/pipelines/``
    ...      (e.g., ``oracle.slp``, ``prime_oracle_baseline_tests.slp``).
    [Tags]    import_pipeline_sample
    [Template]    Import Pipelines From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    prime_oracle_baseline_tests3    prime_oracle_baseline_tests.slp
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_slp_name}    ${pipeline_name_for_imported_slp_file}

Import existing child Pipeline Wihout Unique ID
    [Documentation]    Imports pipelines using their original name without appending
    ...    a unique suffix. Use this when the pipeline name must remain exactly as-is
    ...    (e.g., when downstream tasks or expressions reference the pipeline by a
    ...    fixed name).
    ...
    ...    *Arguments (per template row):*
    ...    - ``project_path``: SnapLogic project path where the pipeline will be
    ...      imported (e.g., ``${PIPELINES_LOCATION_PATH}``).
    ...    - ``pipeline_name``: Exact name the imported pipeline should have in
    ...      SnapLogic (no unique suffix appended).
    ...    - ``slp_file_name``: Source .slp file located under ``src/pipelines/``
    ...      (e.g., ``email.slp``).
    ...    - ``duplicate_check`` (optional): If ``true``, fails when a pipeline
    ...      with the same name already exists. Defaults to ``false`` (overwrite
    ...      / skip behavior depends on the underlying keyword).
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
