*** Settings ***
Documentation    Pipeline Inspector resource file for peer review automation.
...
...              Provides high-level keywords for validating SnapLogic pipeline (.slp)
...              files against peer review standards. All checks are static
...              (file-based) and require no API calls, Groundplex, or running services.
...
...              == Peer Review Checks ==
...              - Snap naming standards (no defaults, no duplicates)
...              - Pipeline naming conventions (project prefix, z_ for child)
...              - Parameter validation (capture enabled, naming prefix)
...              - Account reference validation (shared folder, not hardcoded)
...              - Pipeline info validation (doc link, notes)
...
...              == Usage ==
...              | Library    | ../libraries/common/PipelineInspectorLibrary.py |
...              | Resource   | pipeline_inspector.resource |
...              | ${pipeline}= | Load Pipeline File | path/to/pipeline.slp |
...              | Run Peer Review On Pipeline File | ${pipeline} | oracle2.slp |

Library     Collections
Library     OperatingSystem
Library     ../libraries/common/PipelineInspectorLibrary.py


*** Keywords ***

# ============================================================
# SETUP KEYWORDS
# ============================================================

Load Pipeline For Review
    [Documentation]    Load a pipeline file for review. Skips the suite if file not found.
    ...
    ...    *Arguments:*
    ...    - ``pipeline_file`` - Path to the .slp pipeline file.
    ...
    ...    *Sets Suite Variables:*
    ...    - ``${pipeline}`` - Parsed pipeline dictionary.
    ...
    ...    *Example:*
    ...    | Load Pipeline For Review | ${CURDIR}/oracle2.slp |
    [Arguments]    ${pipeline_file}
    ${file_exists}=    Run Keyword And Return Status
    ...    File Should Exist    ${pipeline_file}
    IF    not ${file_exists}
        Log    Pipeline file not found: ${pipeline_file}. Tests will be skipped.    WARN
        Skip    Pipeline file not found: ${pipeline_file}
    END
    ${pipeline}=    Load Pipeline File    ${pipeline_file}
    Set Suite Variable    ${pipeline}
    ${name}=    Get Pipeline Name    ${pipeline}
    Log    Loaded pipeline '${name}' for peer review    console=True

# ============================================================
# INDIVIDUAL CHECK KEYWORDS (with logging)
# ============================================================

Verify Snap Naming And Return Result
    [Documentation]    Validate snap naming standards and log violations.
    ...    Returns the result dict. Does NOT assert pass/fail.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``additional_defaults`` - Optional list of extra default names to flag.
    ...
    ...    *Returns:*
    ...    - Dict with 'status', 'violations', 'total_snaps', 'total_violations'.
    ...
    ...    *Example:*
    ...    | ${result}= | Verify Snap Naming And Return Result | ${pipeline} |
    [Arguments]    ${pipeline}    ${additional_defaults}=${NONE}
    ${result}=    Validate Snap Naming Standards    ${pipeline}    additional_defaults=${additional_defaults}
    Log    Total snaps: ${result}[total_snaps], Violations: ${result}[total_violations]
    IF    ${result}[total_violations] > 0
        Log Snap Naming Violations    ${result}[violations]
    END
    RETURN    ${result}

Verify Pipeline Naming And Return Result
    [Documentation]    Validate pipeline naming convention and log violations.
    ...    Returns the result dict. Does NOT assert pass/fail.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``project_name`` - Required pipeline name prefix (optional).
    ...    - ``is_child_pipeline`` - True for child pipelines (default: False).
    ...
    ...    *Returns:*
    ...    - Dict with 'status', 'violations', 'pipeline_name', 'total_violations'.
    ...
    ...    *Example:*
    ...    | ${result}= | Verify Pipeline Naming And Return Result | ${pipeline} |
    [Arguments]    ${pipeline}    ${project_name}=    ${is_child_pipeline}=False
    ${result}=    Validate Pipeline Naming Convention
    ...    ${pipeline}
    ...    project_name=${project_name}
    ...    is_child_pipeline=${is_child_pipeline}
    IF    ${result}[total_violations] > 0
        Log    Pipeline name: ${result}[pipeline_name]    WARN
        FOR    ${violation}    IN    @{result}[violations]
            Log    Violation: ${violation}    WARN
        END
    END
    RETURN    ${result}

Verify Child Pipeline Naming And Return Result
    [Documentation]    Validate that a child pipeline name starts with the required prefix.
    ...    Returns the result dict. Does NOT assert pass/fail.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``prefix`` - Required prefix for child pipeline names (default: z_).
    ...
    ...    *Returns:*
    ...    - Dict with 'status', 'pipeline_name', and 'prefix'.
    ...
    ...    *Example:*
    ...    | ${result}= | Verify Child Pipeline Naming And Return Result | ${pipeline} |
    ...    | ${result}= | Verify Child Pipeline Naming And Return Result | ${pipeline} | prefix=child_ |
    [Arguments]    ${pipeline}    ${prefix}=z_
    ${name}=    Get Pipeline Name    ${pipeline}
    ${has_prefix}=    Evaluate    '${name}'.lower().startswith('${prefix}'.lower())
    ${status}=    Set Variable If    ${has_prefix}    PASS    FAIL
    IF    '${status}' == 'FAIL'
        Log    Child pipeline '${name}' does not start with '${prefix}' prefix.    WARN
    END
    ${result}=    Create Dictionary    status=${status}    pipeline_name=${name}    prefix=${prefix}
    RETURN    ${result}

Verify Pipeline Naming With Auto Detection And Return Result
    [Documentation]    Auto-detect parent/child from .slp content and validate naming accordingly.
    ...    - All pipelines: checks name is not empty and contains project name.
    ...    - Child pipelines (auto-detected): additionally checks name starts with z_.
    ...    Returns the result dict. Does NOT assert pass/fail.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``project_name`` - Required project name (optional).
    ...
    ...    *Returns:*
    ...    - Dict with 'status', 'pipeline_name', 'pipeline_type', 'violations', 'total_violations'.
    ...
    ...    *Example:*
    ...    | ${result}= | Verify Pipeline Naming With Auto Detection And Return Result | ${pipeline} |
    [Arguments]    ${pipeline}    ${project_name}=
    ${result}=    Validate Pipeline Naming With Auto Detection
    ...    ${pipeline}
    ...    project_name=${project_name}
    Log    Detected pipeline type: ${result}[pipeline_type]    console=True
    IF    ${result}[total_violations] > 0
        Log    Pipeline name: ${result}[pipeline_name] (type: ${result}[pipeline_type])    WARN
        FOR    ${violation}    IN    @{result}[violations]
            Log    Violation: ${violation}    WARN
        END
    ELSE
        Log    Pipeline '${result}[pipeline_name]' naming is valid (type: ${result}[pipeline_type])    console=True
    END
    RETURN    ${result}

Pipeline Should Pass Naming With Auto Detection
    [Documentation]    Assert pipeline naming is valid with automatic parent/child detection.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``project_name`` - Required project name (optional).
    ...
    ...    *Example:*
    ...    | Pipeline Should Pass Naming With Auto Detection | ${pipeline} | project_name=z_greenlight |
    [Arguments]    ${pipeline}    ${project_name}=
    ${result}=    Validate Pipeline Naming With Auto Detection
    ...    ${pipeline}
    ...    project_name=${project_name}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Pipeline naming violations (detected as ${result}[pipeline_type]): ${result}[violations]

Verify Doc Link And Return Result
    [Documentation]    Validate pipeline has a Doc Link and log result.
    ...    Returns the result dict. Does NOT assert pass/fail.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Returns:*
    ...    - Dict with 'status' and 'message'.
    ...
    ...    *Example:*
    ...    | ${result}= | Verify Doc Link And Return Result | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate Pipeline Info Has Doc Link    ${pipeline}
    IF    '${result}[status]' == 'FAIL'
        Log    ${result}[message]    WARN
    END
    RETURN    ${result}

Verify Notes And Return Result
    [Documentation]    Validate pipeline Info has Notes and log result.
    ...    Returns the result dict. Does NOT assert pass/fail.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Returns:*
    ...    - Dict with 'status' and 'message'.
    ...
    ...    *Example:*
    ...    | ${result}= | Verify Notes And Return Result | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate Pipeline Info Has Notes    ${pipeline}
    IF    '${result}[status]' == 'FAIL'
        Log    ${result}[message]    WARN
    END
    RETURN    ${result}

Generate Full Peer Review Report
    [Documentation]    Run ALL peer review checks and generate a comprehensive report.
    ...    Returns the report dict. Does NOT assert pass/fail.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``pipeline_file`` - Path to pipeline file (for file_name extraction).
    ...    - ``project_name`` - Required pipeline name prefix (optional).
    ...    - ``is_child_pipeline`` - True for child pipelines (default: False).
    ...    - ``param_prefix`` - Required parameter prefix (default: xx).
    ...    - ``is_parent_pipeline`` - True for top-layer pipelines (default: False).
    ...
    ...    *Returns:*
    ...    - Full inspection report dictionary.
    ...
    ...    *Example:*
    ...    | ${report}= | Generate Full Peer Review Report | ${pipeline} | oracle2.slp |
    [Arguments]    ${pipeline}    ${pipeline_file}
    ...    ${project_name}=    ${is_child_pipeline}=False
    ...    ${param_prefix}=xx    ${is_parent_pipeline}=False
    ${file_name}=    Evaluate    __import__('os').path.basename('${pipeline_file}')
    ${report}=    Get Pipeline Inspection Report
    ...    ${pipeline}
    ...    file_name=${file_name}
    ...    project_name=${project_name}
    ...    is_child_pipeline=${is_child_pipeline}
    ...    param_prefix=${param_prefix}
    ...    is_parent_pipeline=${is_parent_pipeline}
    Log    Overall Status: ${report}[status]
    Log    Summary: ${report}[summary]
    RETURN    ${report}

Run Batch Peer Review
    [Documentation]    Run peer review on ALL .slp files in a directory and log summary.
    ...    Returns list of reports. Does NOT assert pass/fail.
    ...
    ...    Parent/child detection is automatic based on the pipeline name inside each .slp file:
    ...    - Name starts with child_pipeline_prefix → child → enforce prefix + xx parameter prefix
    ...    - Name does NOT start with child_pipeline_prefix → parent → skip checks
    ...
    ...    *Arguments:*
    ...    - ``pipeline_dir`` - Path to directory containing .slp files.
    ...    - ``project_name`` - Required project name that must appear in pipeline name (optional).
    ...    - ``param_prefix`` - Required parameter prefix (default: xx).
    ...    - ``child_pipeline_prefix`` - Required prefix for child pipelines (default: z_).
    ...
    ...    *Returns:*
    ...    - List of inspection report dictionaries, one per pipeline file.
    ...
    ...    *Example:*
    ...    | ${reports}= | Run Batch Peer Review | ${CURDIR}/src/pipelines |
    ...    | ${reports}= | Run Batch Peer Review | ${CURDIR}/src/pipelines | child_pipeline_prefix=child_ |
    [Arguments]    ${pipeline_dir}    ${project_name}=    ${param_prefix}=xx    ${child_pipeline_prefix}=z_
    ${reports}=    Run Peer Review On All Pipeline Files
    ...    ${pipeline_dir}
    ...    project_name=${project_name}
    ...    param_prefix=${param_prefix}
    ...    child_pipeline_prefix=${child_pipeline_prefix}
    ${total}=    Get Length    ${reports}
    ${failed_count}=    Set Variable    ${0}
    FOR    ${report}    IN    @{reports}
        IF    '${report}[status]' == 'FAIL'
            ${failed_count}=    Evaluate    ${failed_count} + 1
        END
    END
    Log    Batch review complete: ${total} pipelines reviewed, ${failed_count} with violations    console=True
    RETURN    ${reports}

# ============================================================
# ASSERTION KEYWORDS (pass/fail)
# ============================================================

Pipeline Should Pass Snap Naming Standards
    [Documentation]    Assert that a pipeline passes snap naming standards.
    ...    Fails if any snap has a default or generic name.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Example:*
    ...    | Pipeline Should Pass Snap Naming Standards | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate Snap Naming Standards    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Snap naming violations found: ${result}[violations]

Pipeline Should Have No Duplicate Snap Names
    [Documentation]    Assert that all snap names in the pipeline are unique.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Example:*
    ...    | Pipeline Should Have No Duplicate Snap Names | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate No Duplicate Snap Names    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Duplicate snap names found: ${result}[duplicates]

Pipeline Parameters Should Have Capture Enabled
    [Documentation]    Assert that all pipeline parameters have the Capture checkbox enabled.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Example:*
    ...    | Pipeline Parameters Should Have Capture Enabled | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate Parameters Have Capture Enabled    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Parameters without Capture enabled: ${result}[violations]

Pipeline Parameters Should Have Prefix
    [Documentation]    Assert that all pipeline parameters start with the required prefix.
    ...    Top-layer pipelines can set is_parent_pipeline=True to skip this check.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``prefix`` - Required prefix (default: xx).
    ...    - ``is_parent_pipeline`` - True to skip check for top-layer pipelines (default: False).
    ...
    ...    *Example:*
    ...    | Pipeline Parameters Should Have Prefix | ${pipeline} | prefix=xx |
    [Arguments]    ${pipeline}    ${prefix}=xx    ${is_parent_pipeline}=False
    ${result}=    Validate Parameters Have Prefix    ${pipeline}    prefix=${prefix}    is_parent_pipeline=${is_parent_pipeline}
    IF    '${result}[status]' != 'SKIP'
        Should Be Equal    ${result}[status]    PASS
        ...    msg=Parameters without '${prefix}' prefix: ${result}[violations]
    END

Pipeline Accounts Should Not Be Hardcoded
    [Documentation]    Assert that no account references are hardcoded in the pipeline.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Example:*
    ...    | Pipeline Accounts Should Not Be Hardcoded | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate Accounts Not Hardcoded    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Hardcoded account references found: ${result}[violations]

Pipeline Account References Should Match Format
    [Documentation]    Assert that account references follow the ../shared/<account> format.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...    - ``expected_pattern`` - Regex pattern (default: '\.\./shared/.+').
    ...
    ...    *Example:*
    ...    | Pipeline Account References Should Match Format | ${pipeline} |
    [Arguments]    ${pipeline}    ${expected_pattern}=\\.\\./shared/.+
    ${result}=    Validate Account References Format    ${pipeline}    expected_pattern=${expected_pattern}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=Account reference format violations: ${result}[violations]

Pipeline Should Have Doc Link
    [Documentation]    Assert that the pipeline has a documentation link in Pipeline Info.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Example:*
    ...    | Pipeline Should Have Doc Link | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate Pipeline Info Has Doc Link    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=${result}[message]

Pipeline Should Have Notes
    [Documentation]    Assert that the pipeline has notes in Pipeline Info.
    ...
    ...    *Arguments:*
    ...    - ``pipeline`` - Parsed pipeline dictionary.
    ...
    ...    *Example:*
    ...    | Pipeline Should Have Notes | ${pipeline} |
    [Arguments]    ${pipeline}
    ${result}=    Validate Pipeline Info Has Notes    ${pipeline}
    Should Be Equal    ${result}[status]    PASS
    ...    msg=${result}[message]

# ============================================================
# LOGGING HELPER KEYWORDS
# ============================================================

Log Snap Naming Violations
    [Documentation]    Log detailed snap naming violations for debugging.
    ...
    ...    *Arguments:*
    ...    - ``violations`` - List of violation dictionaries.
    [Arguments]    ${violations}
    Log    \n--- Snap Naming Violations ---    WARN
    FOR    ${v}    IN    @{violations}
        Log    Snap: ${v}[snap_name] (type: ${v}[snap_type]) - ${v}[reason]    WARN
    END
    Log    --- End Violations ---\n    WARN

# ============================================================
# BATCH REVIEW KEYWORDS
# ============================================================

Run Peer Review On Pipeline File
    [Documentation]    Run all peer review checks on a single pipeline file and return report.
    ...
    ...    *Arguments:*
    ...    - ``file_path`` - Path to the .slp pipeline file.
    ...    - ``project_name`` - Required pipeline name prefix (optional).
    ...    - ``is_child_pipeline`` - Set to True for child pipelines (default: False).
    ...    - ``param_prefix`` - Required parameter prefix (default: xx).
    ...    - ``is_parent_pipeline`` - Set to True for top-layer pipelines to skip prefix check (default: False).
    ...
    ...    *Returns:*
    ...    - Inspection report dictionary.
    ...
    ...    *Example:*
    ...    | ${report}= | Run Peer Review On Pipeline File | ${CURDIR}/oracle2.slp |
    [Arguments]    ${file_path}    ${project_name}=    ${is_child_pipeline}=False
    ...    ${param_prefix}=xx    ${is_parent_pipeline}=False
    ${file_name}=    Evaluate    __import__('os').path.basename('${file_path}')
    ${pipeline}=    Load Pipeline File    ${file_path}
    ${report}=    Get Pipeline Inspection Report
    ...    ${pipeline}
    ...    file_name=${file_name}
    ...    project_name=${project_name}
    ...    is_child_pipeline=${is_child_pipeline}
    ...    param_prefix=${param_prefix}
    ...    is_parent_pipeline=${is_parent_pipeline}
    RETURN    ${report}

Run Peer Review On All Pipeline Files
    [Documentation]    Run peer review on all .slp files in a directory. Collects results for each file.
    ...
    ...    Parent/child detection is automatic based on the pipeline name inside each .slp file:
    ...    - Name starts with child_pipeline_prefix → child → enforce prefix + xx parameter prefix
    ...    - Name does NOT start with child_pipeline_prefix → parent → skip checks
    ...
    ...    *Arguments:*
    ...    - ``directory`` - Path to directory containing .slp files.
    ...    - ``project_name`` - Required project name that must appear in pipeline name (optional).
    ...    - ``param_prefix`` - Required parameter prefix (default: xx).
    ...    - ``child_pipeline_prefix`` - Required prefix for child pipelines (default: z_).
    ...
    ...    *Returns:*
    ...    - List of inspection reports, one per pipeline file.
    ...
    ...    *Example:*
    ...    | ${reports}= | Run Peer Review On All Pipeline Files | ${CURDIR}/src/pipelines |
    ...    | ${reports}= | Run Peer Review On All Pipeline Files | ${CURDIR}/src/pipelines | child_pipeline_prefix=child_ |
    [Arguments]    ${directory}    ${project_name}=    ${param_prefix}=xx    ${child_pipeline_prefix}=z_
    ${pipeline_files}=    Load All Pipeline Files From Directory    ${directory}
    ${reports}=    Create List
    FOR    ${entry}    IN    @{pipeline_files}
        ${pipeline}=    Set Variable    ${entry}[pipeline]
        IF    $pipeline is not None
            ${report}=    Get Pipeline Inspection Report
            ...    ${pipeline}
            ...    file_name=${entry}[file_name]
            ...    project_name=${project_name}
            ...    param_prefix=${param_prefix}
            ...    child_pipeline_prefix=${child_pipeline_prefix}
            Append To List    ${reports}    ${report}
        ELSE
            Log    SKIP: Could not load ${entry}[file_name] - ${entry}[error]    WARN
        END
    END
    Log Peer Review Summary    ${reports}
    RETURN    ${reports}

Log Peer Review Summary
    [Documentation]    Log a summary of peer review results for multiple pipeline files.
    ...
    ...    *Arguments:*
    ...    - ``reports`` - List of inspection report dictionaries.
    [Arguments]    ${reports}
    ${total}=    Get Length    ${reports}
    ${passed}=    Set Variable    ${0}
    ${failed}=    Set Variable    ${0}
    FOR    ${report}    IN    @{reports}
        IF    '${report}[status]' == 'PASS'
            ${passed}=    Evaluate    ${passed} + 1
        ELSE
            ${failed}=    Evaluate    ${failed} + 1
        END
    END
    ${separator}=    Evaluate    '=' * 70
    Log    \n${separator}    console=True
    Log    PEER REVIEW SUMMARY: ${total} pipelines reviewed | ${passed} passed | ${failed} failed    console=True
    Log    ${separator}    console=True
    FOR    ${report}    IN    @{reports}
        ${status_icon}=    Set Variable If    '${report}[status]' == 'PASS'    PASS    FAIL
        ${failed_list}=    Set Variable    ${report}[summary][failed_checks]
        IF    '${report}[status]' == 'PASS'
            Log    [${status_icon}] ${report}[file_name]    console=True
        ELSE
            Log    [${status_icon}] ${report}[file_name] - Failed: ${failed_list}    console=True
        END
    END
    Log    ${separator}\n    console=True
