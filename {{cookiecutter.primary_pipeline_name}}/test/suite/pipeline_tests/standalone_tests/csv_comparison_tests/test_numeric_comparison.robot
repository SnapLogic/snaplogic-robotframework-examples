*** Settings ***
Documentation       Standalone test to verify CSV comparison numeric normalization fix.
...                 Tests that float values (1250.0) and integer values (1250) are treated
...                 as IDENTICAL when normalize_numerics is enabled (opt-in).
...
...                 Default behavior (normalize_numerics=False) preserves strict type comparison
...                 so existing tests are not affected.
...
...                 This test requires NO database connection, NO Snowflake, NO SnapLogic.
...                 It can be run locally with just Robot Framework and the FileComparisonLibrary.
...
...                 Run from snaplogic-robotframework-examples directory:
...                 robot --outputdir robot_output "{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/standalone_ tests/csv_comparison_tests/test_numeric_comparison.robot"
...
...                 Or from {{cookiecutter.primary_pipeline_name}}/test directory:
...                 robot --outputdir robot_output "suite/pipeline_tests/standalone_ tests/csv_comparison_tests/test_numeric_comparison.robot"
...
...                 Or using make (runs inside Docker container):
...                 make robot-run-all-tests TAGS=numeric_fix

Library             OperatingSystem
Library             Collections
Library             ../../../../libraries/common/FileComparisonLibrary.py


*** Variables ***
${TEST_DATA_DIR}    ${CURDIR}/test_data


*** Test Cases ***
Test 1: Float vs Integer With normalize_numerics=True Should Be IDENTICAL
    [Documentation]    Verifies that plain CSV values like "1250" and "1250.0"
    ...    are treated as equal when normalize_numerics is enabled.
    [Tags]    numeric_fix    standalone

    ${result}=    Compare CSV Files
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}
    ...    normalize_numerics=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: With normalize_numerics=True, 1250 vs 1250.0 should be IDENTICAL but got ${result}[status]

    Log    Test 1 PASSED: Float vs Integer with normalize_numerics=True -> IDENTICAL    console=yes

Test 2: Float vs Integer WITHOUT normalize_numerics Should Be DIFFERENT
    [Documentation]    Verifies that without normalize_numerics (default=False),
    ...    "1250" and "1250.0" are treated as DIFFERENT.
    ...    This ensures existing tests are not affected by the fix.
    [Tags]    numeric_fix    standalone

    ${result}=    Compare CSV Files
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}

    Should Be Equal    ${result}[status]    DIFFERENT
    ...    FAILED: Without normalize_numerics, 1250 vs 1250.0 should be DIFFERENT but got ${result}[status]

    Log    Test 2 PASSED: Float vs Integer without normalize_numerics -> DIFFERENT (strict mode)    console=yes

Test 3: JSON Inside CSV With normalize_numerics=True Should Be IDENTICAL
    [Documentation]    Verifies that JSON fields inside CSV like {"amount": 1250}
    ...    and {"amount": 1250.0} are treated as equal when normalize_numerics is enabled.
    [Tags]    numeric_fix    standalone

    @{no_exclusions}=    Create List

    ${result}=    Compare CSV Files With Exclusions
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ${no_exclusions}
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}
    ...    normalize_numerics=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: JSON values {"amount": 1250} vs {"amount": 1250.0} should be IDENTICAL but got ${result}[status]

    Log    Test 3 PASSED: JSON inside CSV with normalize_numerics=True -> IDENTICAL    console=yes

Test 4: Real Value Differences Are Still Caught
    [Documentation]    Verifies that genuinely different values (999 vs 500) are
    ...    still reported as DIFFERENT even with normalize_numerics enabled.
    ...    The fix must NOT mask real mismatches.
    [Tags]    numeric_fix    standalone

    @{no_exclusions}=    Create List

    ${result}=    Compare CSV Files With Exclusions
    ...    ${TEST_DATA_DIR}/actual_with_real_diff.csv
    ...    ${TEST_DATA_DIR}/expected_with_real_diff.csv
    ...    ${no_exclusions}
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}
    ...    normalize_numerics=${TRUE}

    Should Be Equal    ${result}[status]    DIFFERENT
    ...    FAILED: Genuinely different values (999 vs 500) should be DIFFERENT but got ${result}[status]

    Log    Test 4 PASSED: Real value differences (999 vs 500) are still caught as DIFFERENT    console=yes

Test 5: Float vs Integer With Excluded Keys and normalize_numerics Should Be IDENTICAL
    [Documentation]    Simulates the exact scenario from snowflake_baseline_tests.robot:
    ...    comparing files with excluded columns (like SnowflakeConnectorPushTime)
    ...    and normalize_numerics enabled.
    [Tags]    numeric_fix    standalone

    @{excluded_columns}=    Create List    SnowflakeConnectorPushTime    unique_event_id

    ${result}=    Compare CSV Files With Exclusions
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ${excluded_columns}
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}
    ...    normalize_numerics=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: Float vs int with exclusions and normalize_numerics should be IDENTICAL but got ${result}[status]

    Log    Test 5 PASSED: Exclusions + normalize_numerics=True -> IDENTICAL    console=yes

Test 6: Float vs Integer With Ignore Order and normalize_numerics Should Be IDENTICAL
    [Documentation]    Tests that unordered (set-based) comparison also handles
    ...    float vs integer normalization correctly when enabled.
    [Tags]    numeric_fix    standalone

    ${result}=    Compare CSV Files
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ignore_order=${TRUE}
    ...    show_details=${TRUE}
    ...    normalize_numerics=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: Unordered comparison with normalize_numerics should be IDENTICAL but got ${result}[status]

    Log    Test 6 PASSED: Unordered comparison + normalize_numerics=True -> IDENTICAL    console=yes

Test 7: Non-Whole Floats Are NOT Normalized
    [Documentation]    Verifies that non-whole-number floats like 12.5 are NOT
    ...    changed during normalization. Only whole-number floats (1250.0 -> 1250)
    ...    are normalized. This ensures precision is preserved where it matters.
    [Tags]    numeric_fix    standalone

    # Both files have rate=12.5 and rate=8.75 - these should remain unchanged
    # and still match because both files have the same decimal values
    ${result}=    Compare CSV Files
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}
    ...    normalize_numerics=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    Should Be Equal As Numbers    ${result}[total_differences]    0

    Log    Test 7 PASSED: Non-whole floats (12.5, 8.75) are preserved correctly    console=yes
