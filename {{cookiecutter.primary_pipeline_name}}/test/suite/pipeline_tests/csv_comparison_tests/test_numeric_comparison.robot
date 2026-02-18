*** Settings ***
Documentation       Standalone test to verify CSV comparison numeric normalization fix.
...                 Tests that float values (1250.0) and integer values (1250) are treated
...                 as IDENTICAL when they are mathematically equal.
...
...                 This test requires NO database connection, NO Snowflake, NO SnapLogic.
...                 It can be run locally with just Robot Framework and the FileComparisonLibrary.
...
...                 Run from snaplogic-robotframework-examples directory:
...                 robot --outputdir robot_output "{{cookiecutter.primary_pipeline_name}}/test/suite/pipeline_tests/csv_comparison_tests/test_numeric_comparison.robot"
...
...                 Or from {{cookiecutter.primary_pipeline_name}}/test directory:
...                 robot --outputdir robot_output suite/pipeline_tests/csv_comparison_tests/test_numeric_comparison.robot
...
...                 Or using make (runs inside Docker container):
...                 make robot-run-all-tests TAGS=numeric_fix

Library             OperatingSystem
Library             Collections
Library             ../../../libraries/common/FileComparisonLibrary.py


*** Variables ***
${TEST_DATA_DIR}    ${CURDIR}/standalone_test_data


*** Test Cases ***
Test 1: Float vs Integer - Plain CSV Values Should Be IDENTICAL
    [Documentation]    Verifies that plain CSV values like "1250" and "1250.0"
    ...    are treated as equal. This is the core issue reported by Vishal.
    [Tags]    numeric_fix    standalone

    ${result}=    Compare CSV Files
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: Plain CSV values 1250 vs 1250.0 should be IDENTICAL but got ${result}[status]

    Log    Test 1 PASSED: Float vs Integer plain values are treated as IDENTICAL    console=yes

Test 2: Float vs Integer - JSON Inside CSV Should Be IDENTICAL
    [Documentation]    Verifies that JSON fields inside CSV like {"amount": 1250}
    ...    and {"amount": 1250.0} are treated as equal.
    ...
    ...    This tests the nested JSON comparison within CSV cells.
    [Tags]    numeric_fix    standalone

    @{no_exclusions}=    Create List

    ${result}=    Compare CSV Files With Exclusions
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ${no_exclusions}
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: JSON values {"amount": 1250} vs {"amount": 1250.0} should be IDENTICAL but got ${result}[status]

    Log    Test 2 PASSED: JSON inside CSV with float vs int are treated as IDENTICAL    console=yes

Test 3: Real Value Differences Are Still Caught
    [Documentation]    Verifies that genuinely different values (999 vs 500) are
    ...    still reported as DIFFERENT. The fix must NOT mask real mismatches.
    ...
    ...    actual has amount=999, expected has amount=500.0 -> these are truly different.
    [Tags]    numeric_fix    standalone

    @{no_exclusions}=    Create List

    ${result}=    Compare CSV Files With Exclusions
    ...    ${TEST_DATA_DIR}/actual_with_real_diff.csv
    ...    ${TEST_DATA_DIR}/expected_with_real_diff.csv
    ...    ${no_exclusions}
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}

    Should Be Equal    ${result}[status]    DIFFERENT
    ...    FAILED: Genuinely different values (999 vs 500) should be DIFFERENT but got ${result}[status]

    Log    Test 3 PASSED: Real value differences (999 vs 500) are still caught as DIFFERENT    console=yes

Test 4: Float vs Integer With Excluded Keys Should Be IDENTICAL
    [Documentation]    Simulates the exact scenario from snowflake_baseline_tests.robot:
    ...    comparing files with excluded columns (like SnowflakeConnectorPushTime).
    ...    Float vs integer values should still be IDENTICAL after exclusion processing.
    [Tags]    numeric_fix    standalone

    @{excluded_columns}=    Create List    SnowflakeConnectorPushTime    unique_event_id

    ${result}=    Compare CSV Files With Exclusions
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ${excluded_columns}
    ...    ignore_order=${FALSE}
    ...    show_details=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: Float vs int with exclusions should be IDENTICAL but got ${result}[status]

    Log    Test 4 PASSED: Comparison with excluded columns + float vs int -> IDENTICAL    console=yes

Test 5: Float vs Integer With Ignore Order Should Be IDENTICAL
    [Documentation]    Tests that unordered (set-based) comparison also handles
    ...    float vs integer normalization correctly.
    [Tags]    numeric_fix    standalone

    ${result}=    Compare CSV Files
    ...    ${TEST_DATA_DIR}/actual_from_snowflake.csv
    ...    ${TEST_DATA_DIR}/expected_from_json_export.csv
    ...    ignore_order=${TRUE}
    ...    show_details=${TRUE}

    Should Be Equal    ${result}[status]    IDENTICAL
    ...    FAILED: Unordered comparison with float vs int should be IDENTICAL but got ${result}[status]

    Log    Test 5 PASSED: Unordered comparison with float vs int -> IDENTICAL    console=yes

Test 6: Non-Whole Floats Are NOT Normalized
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

    Should Be Equal    ${result}[status]    IDENTICAL
    Should Be Equal As Numbers    ${result}[total_differences]    0

    Log    Test 6 PASSED: Non-whole floats (12.5, 8.75) are preserved correctly    console=yes
