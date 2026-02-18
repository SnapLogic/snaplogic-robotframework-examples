*** Settings ***
Documentation       Reusable keywords for JSON field-level validation and comparison.
...                 Provides keywords for:
...                 - File existence and non-empty checks
...                 - Single field value assertion
...                 - Multi-field actual vs expected comparison
...                 - Required fields presence and non-empty validation
...                 - Regex pattern matching on field values

Library             OperatingSystem
Library             JSONLibrary
Library             Collections
Library             String


*** Keywords ***
Validate JSON File Exists And Not Empty
    [Documentation]    Validates that a JSON file exists and has content (size > 0 bytes).
    ...
    ...    Arguments:
    ...    - file_path: Path to the JSON file to validate
    ...
    ...    Example:
    ...    | Validate JSON File Exists And Not Empty | ${CURDIR}/data/approval.json |
    [Arguments]    ${file_path}
    File Should Exist    ${file_path}
    ...    File not found: ${file_path}
    ${size}=    Get File Size    ${file_path}
    Should Be True    ${size} > 0
    ...    File is empty (0 bytes): ${file_path}
    Log    File verified: ${file_path} (${size} bytes)    console=yes

Validate JSON Field Value
    [Documentation]    Extracts a single field from a JSON dictionary and asserts it equals the expected value.
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary (from Load Json From File)
    ...    - field_name: The field/key to extract
    ...    - expected_value: The value the field should have
    ...
    ...    Example:
    ...    | Validate JSON Field Value | ${json} | ut_status | approved |
    [Arguments]    ${json_data}    ${field_name}    ${expected_value}
    ${value_list}=    Get Value From Json    ${json_data}    $.${field_name}
    ${actual_value}=    Get From List    ${value_list}    0
    Should Be Equal As Strings    ${actual_value}    ${expected_value}
    ...    Field '${field_name}': expected '${expected_value}' but got '${actual_value}'
    Log    Field '${field_name}' = '${actual_value}' (matches expected)    console=yes

Validate JSON Fields Match Expected
    [Documentation]    Compares specified fields between actual and expected JSON data.
    ...    Pass the field names you want to match - this keyword loops through all of them.
    ...
    ...    Arguments:
    ...    - actual_json: Parsed actual JSON dictionary
    ...    - expected_json: Parsed expected JSON dictionary
    ...    - @fields_to_match: One or more field names to compare
    ...
    ...    Example:
    ...    | Validate JSON Fields Match Expected | ${actual} | ${expected} |
    ...    | ...    ut_status    approved_by    pipeline_name    jira_ticket |
    [Arguments]    ${actual_json}    ${expected_json}    @{fields_to_match}
    ${total}=    Get Length    ${fields_to_match}
    ${pass_count}=    Set Variable    ${0}
    FOR    ${field}    IN    @{fields_to_match}
        ${actual_list}=    Get Value From Json    ${actual_json}    $.${field}
        ${expected_list}=    Get Value From Json    ${expected_json}    $.${field}
        ${actual_value}=    Get From List    ${actual_list}    0
        ${expected_value}=    Get From List    ${expected_list}    0
        Should Be Equal As Strings    ${actual_value}    ${expected_value}
        ...    Field '${field}' mismatch: actual='${actual_value}' vs expected='${expected_value}'
        ${pass_count}=    Evaluate    ${pass_count} + 1
        Log    MATCH: '${field}' = '${actual_value}'    console=yes
    END
    Log    All ${total} fields matched between actual and expected    console=yes

Validate All Required Fields Present
    [Documentation]    Validates that all specified fields exist as keys in the JSON dictionary
    ...    and have non-empty values.
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary
    ...    - @required_fields: One or more field names that must be present
    ...
    ...    Example:
    ...    | Validate All Required Fields Present | ${json} |
    ...    | ...    ut_status    approved_by    pipeline_name |
    [Arguments]    ${json_data}    @{required_fields}
    ${keys}=    Get Dictionary Keys    ${json_data}
    FOR    ${field}    IN    @{required_fields}
        List Should Contain Value    ${keys}    ${field}
        ...    Required field '${field}' is missing from JSON data
        ${value_list}=    Get Value From Json    ${json_data}    $.${field}
        ${value}=    Get From List    ${value_list}    0
        ${value_str}=    Convert To String    ${value}
        Should Not Be Empty    ${value_str}
        ...    Field '${field}' exists but is empty
        Log    Required field present: '${field}' = '${value}'    console=yes
    END
    ${total}=    Get Length    ${required_fields}
    Log    All ${total} required fields present and non-empty    console=yes

Validate Field Matches Pattern
    [Documentation]    Extracts a field from JSON and validates it against a regex pattern.
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary
    ...    - field_name: The field to extract
    ...    - pattern: Regex pattern the field value must match
    ...
    ...    Example:
    ...    | Validate Field Matches Pattern | ${json} | jira_ticket | ^[A-Z]+-\\d+$ |
    [Arguments]    ${json_data}    ${field_name}    ${pattern}
    ${value_list}=    Get Value From Json    ${json_data}    $.${field_name}
    ${value}=    Get From List    ${value_list}    0
    Should Not Be Empty    ${value}
    ...    Field '${field_name}' is empty - cannot validate pattern
    Should Match Regexp    ${value}    ${pattern}
    ...    Field '${field_name}' value '${value}' does not match pattern '${pattern}'
    Log    Field '${field_name}' = '${value}' matches pattern '${pattern}'    console=yes

Validate File Exists And Not Empty
    [Documentation]    Validates that a file exists and has content (size > 0 bytes).
    ...    Generic version — works for any file type (.expr, .csv, .json, .slp, etc.).
    ...
    ...    Arguments:
    ...    - file_path: Path to the file to validate
    ...
    ...    Example:
    ...    | Validate File Exists And Not Empty | ${CURDIR}/data/oracle_library.expr |
    [Arguments]    ${file_path}
    File Should Exist    ${file_path}
    ...    File not found: ${file_path}
    ${size}=    Get File Size    ${file_path}
    Should Be True    ${size} > 0
    ...    File is empty (0 bytes): ${file_path}
    Log    File verified: ${file_path} (${size} bytes)    console=yes

Validate File Meets Minimum Size
    [Documentation]    Validates that a file size meets or exceeds a minimum threshold.
    ...    Useful for ensuring files are not truncated or incomplete.
    ...
    ...    Arguments:
    ...    - file_path: Path to the file to check
    ...    - min_size: Minimum expected size in bytes
    ...
    ...    Example:
    ...    | Validate File Meets Minimum Size | ${CURDIR}/data/oracle_library.expr | 100 |
    [Arguments]    ${file_path}    ${min_size}
    File Should Exist    ${file_path}
    ...    File not found: ${file_path}
    ${actual_size}=    Get File Size    ${file_path}
    Should Be True    ${actual_size} >= ${min_size}
    ...    File size ${actual_size} bytes is below minimum ${min_size} bytes
    Log    File size: ${actual_size} bytes (minimum: ${min_size})    console=yes

Validate Content Contains All Fields
    [Documentation]    Validates that all specified field names are present in the given text content.
    ...    Uses string matching — works for any text-based file (.expr, .conf, .properties, etc.).
    ...
    ...    Arguments:
    ...    - content: Raw text content of the file
    ...    - @field_names: One or more field names that must be present in the content
    ...
    ...    Example:
    ...    | Validate Content Contains All Fields | ${expr_content} |
    ...    | ...    rejectedState    irsFundAmount    epoch    genzFlag |
    [Arguments]    ${content}    @{field_names}
    ${total}=    Get Length    ${field_names}
    FOR    ${field}    IN    @{field_names}
        Should Contain    ${content}    ${field}
        ...    Required field '${field}' not found in file content
        Log    FOUND: '${field}' present in content    console=yes
    END
    Log    All ${total} required fields found in content    console=yes

Validate JSON Array Contains All Values
    [Documentation]    Validates that a JSON array field contains all expected values.
    ...    Extracts the array from json_data using the given field_name,
    ...    then asserts each expected value is present in the array.
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary
    ...    - field_name: The field containing the array (e.g., output_columns)
    ...    - @expected_values: One or more values that must be in the array
    ...
    ...    Example:
    ...    | Validate JSON Array Contains All Values | ${json} | output_columns |
    ...    | ...    USERID    TIMESTAMP    STATUS |
    [Arguments]    ${json_data}    ${field_name}    @{expected_values}
    ${array_list}=    Get Value From Json    ${json_data}    $.${field_name}
    ${array}=    Get From List    ${array_list}    0
    ${total}=    Get Length    ${expected_values}
    FOR    ${value}    IN    @{expected_values}
        List Should Contain Value    ${array}    ${value}
        ...    Expected value '${value}' not found in '${field_name}' array
        Log    FOUND: '${value}' present in '${field_name}' array    console=yes
    END
    Log    All ${total} expected values found in '${field_name}' array    console=yes

Validate Nested JSON Fields Match Expected
    [Documentation]    Compares fields inside a nested JSON object between actual and expected data.
    ...    Extracts the nested object using parent_key, then compares each specified field.
    ...
    ...    Arguments:
    ...    - actual_json: Parsed actual JSON dictionary
    ...    - expected_json: Parsed expected JSON dictionary
    ...    - parent_key: The parent key containing the nested object (e.g., paths)
    ...    - @fields_to_match: One or more field names within the nested object to compare
    ...
    ...    Example:
    ...    | Validate Nested JSON Fields Match Expected | ${actual} | ${expected} | paths |
    ...    | ...    account_path    upload_source_path    actual_output_path |
    [Arguments]    ${actual_json}    ${expected_json}    ${parent_key}    @{fields_to_match}
    ${total}=    Get Length    ${fields_to_match}
    FOR    ${field}    IN    @{fields_to_match}
        ${actual_list}=    Get Value From Json    ${actual_json}    $.${parent_key}.${field}
        ${expected_list}=    Get Value From Json    ${expected_json}    $.${parent_key}.${field}
        ${actual_value}=    Get From List    ${actual_list}    0
        ${expected_value}=    Get From List    ${expected_list}    0
        Should Be Equal As Strings    ${actual_value}    ${expected_value}
        ...    Path '${parent_key}.${field}' mismatch: actual='${actual_value}' vs expected='${expected_value}'
        Log    MATCH: '${parent_key}.${field}' = '${actual_value}'    console=yes
    END
    Log    All ${total} nested fields in '${parent_key}' matched    console=yes

Validate Nested JSON Fields Present
    [Documentation]    Validates that all specified fields exist within a nested JSON object.
    ...    Extracts the nested object using parent_key, then checks each field is present and non-empty.
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary
    ...    - parent_key: The parent key containing the nested object
    ...    - @required_fields: One or more field names that must exist in the nested object
    ...
    ...    Example:
    ...    | Validate Nested JSON Fields Present | ${json} | paths |
    ...    | ...    account_path    upload_source_path |
    [Arguments]    ${json_data}    ${parent_key}    @{required_fields}
    ${nested_list}=    Get Value From Json    ${json_data}    $.${parent_key}
    ${nested}=    Get From List    ${nested_list}    0
    ${keys}=    Get Dictionary Keys    ${nested}
    FOR    ${field}    IN    @{required_fields}
        List Should Contain Value    ${keys}    ${field}
        ...    Required field '${field}' is missing from '${parent_key}'
        ${value_list}=    Get Value From Json    ${json_data}    $.${parent_key}.${field}
        ${value}=    Get From List    ${value_list}    0
        ${value_str}=    Convert To String    ${value}
        Should Not Be Empty    ${value_str}
        ...    Field '${parent_key}.${field}' exists but is empty
        Log    Required field present: '${parent_key}.${field}' = '${value}'    console=yes
    END
    ${total}=    Get Length    ${required_fields}
    Log    All ${total} required fields present in '${parent_key}'    console=yes

Validate JSON Field Greater Than
    [Documentation]    Extracts a numeric field from JSON and asserts it is greater than a minimum value.
    ...    Useful for count validations where value must exceed a threshold.
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary
    ...    - field_name: The field to extract (must be numeric)
    ...    - min_value: The minimum value (exclusive — actual must be > min_value)
    ...
    ...    Example:
    ...    | Validate JSON Field Greater Than | ${json} | record_count | 0 |
    [Arguments]    ${json_data}    ${field_name}    ${min_value}
    ${value_list}=    Get Value From Json    ${json_data}    $.${field_name}
    ${actual_value}=    Get From List    ${value_list}    0
    Should Be True    ${actual_value} > ${min_value}
    ...    Field '${field_name}' value ${actual_value} is not greater than ${min_value}
    Log    Field '${field_name}' = ${actual_value} (> ${min_value})    console=yes

Validate JSON Fields Sum Equals Expected
    [Documentation]    Sums multiple numeric fields from a JSON dictionary and asserts the total
    ...    equals the expected value. Useful for verifying source table counts add up.
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary
    ...    - expected_total: The expected sum value
    ...    - @field_names: One or more numeric field names to sum
    ...
    ...    Example:
    ...    | Validate JSON Fields Sum Equals Expected | ${json} | 450 |
    ...    | ...    source_table_1_count    source_table_2_count    source_table_3_count |
    [Arguments]    ${json_data}    ${expected_total}    @{field_names}
    ${sum}=    Set Variable    ${0}
    FOR    ${field}    IN    @{field_names}
        ${value_list}=    Get Value From Json    ${json_data}    $.${field}
        ${value}=    Get From List    ${value_list}    0
        ${sum}=    Evaluate    ${sum} + ${value}
        Log    Field '${field}' = ${value}    console=yes
    END
    Should Be Equal As Integers    ${sum}    ${expected_total}
    ...    Sum of fields (${sum}) does not match expected total (${expected_total})
    Log    Sum of ${field_names.__len__()} fields = ${sum} (matches expected ${expected_total})    console=yes

Validate JSON Field Less Than Or Equal
    [Documentation]    Compares a numeric field from actual JSON against a threshold field from expected JSON.
    ...    Asserts actual_field_value <= threshold_field_value.
    ...    Useful for duration/timeout checks where a value must not exceed a limit.
    ...
    ...    Arguments:
    ...    - actual_json: Parsed actual JSON dictionary
    ...    - actual_field: The field name to check (e.g., execution_duration_seconds)
    ...    - expected_json: Parsed expected JSON dictionary
    ...    - threshold_field: The field containing the max allowed value (e.g., max_duration_threshold)
    ...
    ...    Example:
    ...    | Validate JSON Field Less Than Or Equal | ${actual} | execution_duration_seconds | ${expected} | max_duration_threshold |
    [Arguments]    ${actual_json}    ${actual_field}    ${expected_json}    ${threshold_field}
    ${actual_list}=    Get Value From Json    ${actual_json}    $.${actual_field}
    ${actual_value}=    Get From List    ${actual_list}    0
    ${threshold_list}=    Get Value From Json    ${expected_json}    $.${threshold_field}
    ${threshold_value}=    Get From List    ${threshold_list}    0
    Should Be True    ${actual_value} <= ${threshold_value}
    ...    Field '${actual_field}' value ${actual_value} exceeds threshold '${threshold_field}' value ${threshold_value}
    Log    Field '${actual_field}' = ${actual_value} (<= ${threshold_field} = ${threshold_value})    console=yes

Validate JSON Two Fields Are Equal
    [Documentation]    Asserts that two fields from the same JSON dictionary have equal values.
    ...    Useful for data integrity checks where two counts must match (e.g., source sum = target count).
    ...
    ...    Arguments:
    ...    - json_data: Parsed JSON dictionary
    ...    - field_1: First field name
    ...    - field_2: Second field name (must equal field_1)
    ...
    ...    Example:
    ...    | Validate JSON Two Fields Are Equal | ${json} | source_total_sum | target_table_count |
    [Arguments]    ${json_data}    ${field_1}    ${field_2}
    ${value_1_list}=    Get Value From Json    ${json_data}    $.${field_1}
    ${value_2_list}=    Get Value From Json    ${json_data}    $.${field_2}
    ${value_1}=    Get From List    ${value_1_list}    0
    ${value_2}=    Get From List    ${value_2_list}    0
    Should Be Equal As Strings    ${value_1}    ${value_2}
    ...    Field '${field_1}' (${value_1}) does not equal field '${field_2}' (${value_2})
    Log    Fields match: '${field_1}' = '${field_2}' = ${value_1}    console=yes
