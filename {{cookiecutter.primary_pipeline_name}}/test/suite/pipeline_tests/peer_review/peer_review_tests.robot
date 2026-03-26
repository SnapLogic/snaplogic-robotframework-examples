*** Settings ***
Documentation       Automated peer review tests for SnapLogic pipeline (.slp) files.
...
...                 These tests perform static analysis on pipeline files to validate
...                 compliance with peer review standards. No API calls, Groundplex,
...                 or running services are required — all checks are file-based.
...
...                 == Running These Tests ==
...                 | make robot-run-tests TAGS="peer_review"
...
...                 == Configuring Pipeline Path ==
...                 Set the pipeline_dir variable or override with:
...                 | make robot-run-tests TAGS="peer_review" EXTRA_ARGS="--variable pipeline_dir:/path/to/pipelines"
...
...                 == Peer Review Checks ==
...                 1. Snap naming standards (no defaults like "Mapper", no duplicates)
...                 2. Pipeline naming convention (project prefix, z_ for child pipelines)
...                 3. All parameters have Capture checkbox enabled
...                 4. Parameters follow naming prefix convention (xx by default)
...                 5. Account references are not hardcoded (use expressions)
...                 6. Account references use ../shared/<account> format
...                 7. Pipeline Info has documentation link
...                 8. Pipeline Info has notes for modifications
...                 9. Full peer review report (all checks combined)

Library             Collections
Library             OperatingSystem
Library             ../../../libraries/common/PipelineInspectorLibrary.py
Resource            ../../../resources/common/pipeline_inspector.resource

Suite Setup         Load Pipeline For Review    ${pipeline_file}


*** Variables ***
# Default pipeline file to review — override via command line or .env
${pipeline_file}            ${CURDIR}/../../../../src/pipelines/oracle2.slp
# Directory for batch review — override via command line
${pipeline_dir}             ${CURDIR}/../../../../src/pipelines
# Pipeline naming requirements
${project_name}             ${EMPTY}
${param_prefix}             xx
# Set to True for top-layer pipelines (exempt from param prefix check)
${is_parent_pipeline}       False
# Set to True for child pipelines (must start with z_)
${is_child_pipeline}        False


*** Test Cases ***
# ============================================================
# INDIVIDUAL PEER REVIEW CHECKS
# ============================================================

Verify Snap Naming Standards Are Followed
    [Documentation]    Validates that no snap in the pipeline uses a default or generic name.
    ...    Examples of violations: "Mapper", "Filter", "Router", "Mapper1", "Copy 3".
    ...    Snaps should be named descriptively (e.g., "Extract Customer Fields", "CDC Data Generator").
    [Tags]    peer_review    snap_naming    static_analysis
    ${result}=    Verify Snap Naming And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=${result}[total_violations] snap(s) have default or generic names. See log for details.

Verify No Duplicate Snap Names Exist
    [Documentation]    Validates that all snap names in the pipeline are unique.
    ...    Duplicate names make it difficult to trace errors to specific snaps.
    [Tags]    peer_review    snap_naming    static_analysis
    Pipeline Should Have No Duplicate Snap Names    ${pipeline}

Verify Pipeline Naming Convention
    [Documentation]    Validates pipeline name follows naming standards.
    ...    Pipelines should include project name (e.g., z_greenlight_acquisition).
    [Tags]    peer_review    pipeline_naming    static_analysis
    ${result}=    Verify Pipeline Naming And Return Result
    ...    ${pipeline}
    ...    project_name=${project_name}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Pipeline naming violations: ${result}[violations]

Verify Child Pipeline Naming Convention
    [Documentation]    Validates that child pipelines start with z_ prefix.
    ...    Only runs when is_child_pipeline is set to True.
    ...    Skip this test for parent/top-layer pipelines.
    [Tags]    peer_review    pipeline_naming    child_pipeline    static_analysis
    Skip If    '${is_child_pipeline}' == 'False'    Not a child pipeline — skipping z_ prefix check.
    ${result}=    Verify Child Pipeline Naming And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Child pipeline must start with z_ prefix. Pipeline name: ${result}[pipeline_name]

Verify Pipeline Naming With Auto Detection
    [Documentation]    Auto-detects whether the pipeline is parent or child from the .slp content,
    ...    then validates naming accordingly.
    ...    - All pipelines: name must not be empty, must contain project name (if configured).
    ...    - Child pipelines (auto-detected via input views): name must also start with z_.
    ...    No manual is_child_pipeline flag needed — detection is automatic.
    [Tags]    peer_review    pipeline_naming    auto_detect    static_analysis
    ${result}=    Verify Pipeline Naming With Auto Detection And Return Result
    ...    ${pipeline}
    ...    project_name=${project_name}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Pipeline naming violations (detected as ${result}[pipeline_type]): ${result}[violations]

Verify All Parameters Have Capture Enabled
    [Documentation]    Validates that all pipeline parameters have the "Capture" checkbox checked.
    ...    This ensures variables are being passed through the pipeline correctly.
    [Tags]    peer_review    parameters    static_analysis
    Pipeline Parameters Should Have Capture Enabled    ${pipeline}

Verify Parameters Follow Naming Convention
    [Documentation]    Validates that all parameters are prefixed with '${param_prefix}'.
    ...    Top-layer pipelines are exempt from this requirement.
    ...    See: "Poisoning Pipeline Inputs with xx"
    [Tags]    peer_review    parameters    static_analysis
    Pipeline Parameters Should Have Prefix
    ...    ${pipeline}
    ...    prefix=${param_prefix}
    ...    is_parent_pipeline=${is_parent_pipeline}

Verify Account References Are Not Hardcoded
    [Documentation]    Validates that account references in snaps use expressions
    ...    (pipeline parameters) rather than hardcoded account paths.
    ...    Accounts should never be hard coded per peer review standards.
    [Tags]    peer_review    accounts    static_analysis
    Pipeline Accounts Should Not Be Hardcoded    ${pipeline}

Verify Account References Use Shared Folder Format
    [Documentation]    Validates that account references follow the ../shared/<account> format.
    ...    Accounts must be in the shared folder per peer review standards.
    [Tags]    peer_review    accounts    static_analysis
    Pipeline Account References Should Match Format    ${pipeline}

Verify Pipeline Info Has Documentation Link
    [Documentation]    Validates that the pipeline has a Doc Link in Pipeline Properties > Info.
    ...    New pipelines must have the Original User Story URL linked.
    [Tags]    peer_review    documentation    static_analysis
    ${result}=    Verify Doc Link And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=${result}[message]

Verify Pipeline Info Has Notes
    [Documentation]    Validates that the pipeline Info > Notes section is populated.
    ...    Modified pipelines should have the ticket number in the Notes section.
    [Tags]    peer_review    documentation    static_analysis
    ${result}=    Verify Notes And Return Result    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=${result}[message]

# ============================================================
# BATCH REVIEW (ALL PIPELINES IN DIRECTORY)
# ============================================================

Batch Review All Pipeline Files In Directory
    [Documentation]    Runs peer review on ALL .slp files in the pipeline directory.
    ...    Generates a summary report across all pipeline files.
    ...    Individual pipeline failures are logged but do not fail this test.
    [Tags]    peer_review2    batch_review    static_analysis
    ${reports}=    Run Batch Peer Review
    ...    ${pipeline_dir}
    ...    project_name=${project_name}
    ...    param_prefix=${param_prefix}
