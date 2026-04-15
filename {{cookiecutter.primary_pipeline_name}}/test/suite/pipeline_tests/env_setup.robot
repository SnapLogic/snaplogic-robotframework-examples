*** Settings ***
Documentation       Test Suite for Snaplex Creation and Configuration
...                 This suite validates Snaplex deployment functionality by:

Library             Collections
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords


*** Test Cases ***
Create Snaplex In Project Space
    [Tags]    createplex    project_space    create_project
    [Template]    Create Snaplex
    ${env_file_path}    ${GROUNDPLEX_NAME}    ${GROUNDPLEX_ENV}    ${ORG_NAME}    ${RELEASE_BUILD_VERSION}    ${GROUNDPLEX_LOCATION_PATH}

Download And Save slpropz File
    [Tags]    createplex    project_space    create_project
    [Template]    Download And Save Config File
    ./.config    ${GROUNDPLEX_LOCATION_PATH}    ${GROUNDPLEX_NAME}.slpropz

Check if Project Space Exists
    [Tags]    verify_project_space_exists
    [Template]    Check Project Space Setup Requirement
    ${ORG_NAME}    ${PROJECT_SPACE}

Cleanup Stale Timestamped Projects
    [Documentation]    Deletes timestamped test projects older than RETENTION_DAYS (default 7).
    ...    Only projects matching `${PROJECT_NAME}_YYYYMMDD_HHMMSS` are considered.
    [Tags]    cleanup_stale_projects
    ${retention}    Get Variable Value    ${RETENTION_DAYS}    7
    ${dry}    Get Variable Value    ${DRY_RUN}    False
    ${dry_bool}    Evaluate    '${dry}'.lower() == 'true'
    @{deleted}    Cleanup Old Timestamped Projects
    ...    ${ORG_NAME}    ${PROJECT_SPACE}    ${PROJECT_NAME}
    ...    retention_days=${retention}    dry_run=${dry_bool}
    ${count}    Get Length    ${deleted}
    Log    Removed ${count} stale project(s).    console=yes


*** Keywords ***
Validate Project Space Exists
    [Documentation]    Validates that the required project space exists when PROJECT_SPACE_SETUP is False.
    ...    If the project space doesn't exist, fails the test with a helpful message.
    ...
    ...    *Arguments:*
    ...    - ``org_name``: Name of the organization
    ...    - ``expected_project_space``: Name of the project space that should exist
    ...
    ...    *Usage:*
    ...    This keyword should be called at the beginning of test cases when PROJECT_SPACE_SETUP=False
    ...    to ensure the required project space exists before proceeding with tests.
    [Arguments]    ${org_name}    ${expected_project_space}

    Log    Checking if project space '${expected_project_space}' exists...    level=CONSOLE

    TRY
        ${projects}    Get Project List    ${org_name}    ${expected_project_space}
        ${project_count}    Get Length    ${projects}
        Log    Project space '${expected_project_space}' Exists with ${project_count} projects    level=CONSOLE
    EXCEPT    AS    ${error}
        Log    Error accessing project space '${expected_project_space}': ${error}    level=ERROR
        ${guidance}=    Catenate    SEPARATOR=\n
        ...    ${\n}============================================================
        ...    ❌ Project space '${expected_project_space}' is not created in org '${org_name}'.
        ...    ============================================================
        ...    ${EMPTY}
        ...    💡 To create the project space and project, run ONE of these:
        ...    ${EMPTY}
        ...    \ \ 1) Full setup (creates project space + project + Snaplex, launches Groundplex):
        ...    \ \ \ \ \ \ make robot-run-all-tests TAGS="<your-tags>"
        ...    \ \ \ \ \ \ Example: make robot-run-all-tests TAGS="oracle"
        ...    ${EMPTY}
        ...    \ \ 2) Without Groundplex (use when a Groundplex is already running externally):
        ...    \ \ \ \ \ \ make robot-run-tests-no-gp TAGS="<your-tags>"
        ...    \ \ \ \ \ \ Example: make robot-run-tests-no-gp TAGS="oracle"
        ...    ${EMPTY}
        ...    ℹ️ PROJECT_SPACE_SETUP defaults to True (safe, idempotent — creates only what's missing).
        ...    \ \ \ You explicitly passed PROJECT_SPACE_SETUP=False, which only VERIFIES the space exists.
        ...    \ \ \ Drop the flag (or omit it) to let the framework create the project space for you.
        ...    ============================================================${\n}
        Log To Console    ${guidance}
        Fail    Project space '${expected_project_space}' is not created in org '${org_name}'. See console output above for the make command to create it.
    END

Check Project Space Setup Requirement
    [Documentation]    Checks PROJECT_SPACE_SETUP variable and validates project space exists if needed.
    ...
    ...    *Arguments:*
    ...    - ``org_name``: Name of the organization
    ...    - ``project_space``: Name of the project space to validate
    ...
    ...    *Logic:*
    ...    - If PROJECT_SPACE_SETUP is True: Skip validation (setup will create it)
    ...    - If PROJECT_SPACE_SETUP is False: Validate that project space exists
    [Arguments]    ${org_name}    ${project_space}

    ${setup_mode}    Get Variable Value    ${PROJECT_SPACE_SETUP}    False
    Log    PROJECT_SPACE_SETUP mode: ${setup_mode}    level=CONSOLE

    IF    '${setup_mode}' == 'False'
        Log    As PROJECT_SPACE_SETUP is False - validating If project space exists    level=CONSOLE
        Validate Project Space Exists    ${org_name}    ${project_space}
    ELSE
        Log    PROJECT_SPACE_SETUP is True - skipping project space validation    level=CONSOLE
    END
