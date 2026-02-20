*** Settings ***
Documentation       JSON-focused resource file for validation, comparison, and data loading.
...                 Contains keywords for:
...                 - JSON file loading and validation
...                 - JSON schema validation and manipulation
...                 - JSON comparison and row counting
...                 - File existence and non-empty checks
...                 - Single field value assertion
...                 - Multi-field actual vs expected comparison
...                 - Required fields presence and non-empty validation
...                 - Regex pattern matching on field values

Library             JSONLibrary
Library             Collections
Library             OperatingSystem
Library             String
Library             DatabaseLibrary
Library             ../../libraries/common/FileComparisonLibrary.py


*** Keywords ***
################## FILE ANALYSIS AND COUNTING ##################

Count Data Rows In JSON
    [Documentation]    Counts the number of data rows in a JSON file.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the JSON file to analyze
    ...
    ...    *Returns:*
    ...    - Number of items in the JSON array
    ...
    ...    *Example:*
    ...    | ${count}= | Count Data Rows In JSON | data.json |
    [Arguments]    ${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${data_rows}=    Get Length    ${json_data}
    Log    JSON file analysis: ${data_rows} data rows
    RETURN    ${data_rows}

################## DATA LOADING TEMPLATES ##################

Load JSON Data Template
    [Documentation]    Enhanced template that auto-calculates expected rows from JSON file.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the JSON file to load
    ...    - ``table_name``: Target database table name
    ...    - ``truncate_table``: Whether to truncate table before loading (default: TRUE)
    [Arguments]    ${json_file}    ${table_name}    ${truncate_table}=${TRUE}

    Log    Loading JSON file: ${json_file}
    Log    Target table: ${table_name}
    Log    Truncate table: ${truncate_table}

    # Auto-calculate expected rows
    ${expected_rows}=    Count Data Rows In JSON    ${json_file}
    Log    Auto-detected expected rows: ${expected_rows}

    # Load JSON data
    ${json_data}=    Load Json From File    ${json_file}

    # Truncate table if requested
    IF    ${truncate_table}
        Execute SQL String    TRUNCATE TABLE ${table_name}
        Log    Truncated table: ${table_name}
    END

    # Insert data row by row
    ${row_num}=    Set Variable    0
    FOR    ${item}    IN    @{json_data}
        ${row_num}=    Evaluate    ${row_num} + 1
        ${keys}=    Get Dictionary Keys    ${item}
        ${values}=    Get Dictionary Values    ${item}
        ${columns}=    Evaluate    ', '.join($keys)
        # Quote strings, leave numbers unquoted
        ${value_str}=    Evaluate    ', '.join([str(v) if isinstance(v, (int, float)) else f"'{v}'" for v in $values])
        ${sql}=    Set Variable    INSERT INTO ${table_name} (${columns}) VALUES (${value_str})
        Log    Row ${row_num}: Executing SQL: ${sql}
        TRY
            Execute SQL String    ${sql}
            Log    Row ${row_num}: INSERT successful
        EXCEPT    AS    ${error}
            Log    Row ${row_num}: INSERT FAILED - ${error}    level=ERROR
            Fail    JSON row ${row_num} failed to insert. SQL: ${sql} | Error: ${error}
        END
    END

    # Verify row count - use Query to get the actual COUNT value
    ${result}=    Query    SELECT COUNT(*) FROM ${table_name}
    ${actual_count}=    Set Variable    ${result[0][0]}
    Should Be Equal As Numbers
    ...    ${actual_count}
    ...    ${expected_rows}
    ...    JSON Data Load Failed: JSON file '${json_file}' contains ${expected_rows} records, but only ${actual_count} rows were inserted into '${table_name}' table. Possible causes: INSERT statement failed silently, duplicate key constraint, or data type mismatch.

    IF    ${truncate_table}
        Log    Successfully loaded ${expected_rows} rows into ${table_name} table (table was truncated)
    ELSE
        Log    Successfully appended ${expected_rows} rows to ${table_name} table
    END

################## FILE COMPARISON ##################

Compare JSON Files With Exclusions Template
    [Documentation]    Template keyword for JSON comparison with exclusions and validation.
    ...    Compares two JSON files while ignoring specified keys (useful for dynamic fields
    ...    like timestamps, execution IDs, connector push times, etc.).
    ...
    ...    *Arguments:*
    ...    - ``file1_path``: Path to actual output JSON file
    ...    - ``file2_path``: Path to expected output JSON file
    ...    - ``ignore_order``: Whether to ignore array element order
    ...    - ``show_details``: Whether to show detailed differences
    ...    - ``expected_status``: Expected comparison result (IDENTICAL or DIFFERENT)
    ...    - ``@exclude_keys``: One or more JSON keys to exclude from comparison
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary with ``status``, ``total_differences``, and ``excluded_keys``
    ...
    ...    *Examples:*
    ...    | ${result}= | Compare JSON Files With Exclusions Template |
    ...    | ...    ${actual_file}    ${expected_file}    ${TRUE}    ${TRUE}    IDENTICAL |
    ...    | ...    created_at    updated_at    execution_id |
    ...
    ...    *See also:* `Compare JSON Files Template`
    [Arguments]
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${ignore_order}
    ...    ${show_details}
    ...    ${expected_status}
    ...    @{exclude_keys}

    Log    \nComparing JSON files with exclusions template:    console=yes
    Log    File 1 (Actual): ${file1_path}    console=yes
    Log    File 2 (Expected): ${file2_path}    console=yes
    Log    Excluded Keys: ${exclude_keys}    console=yes
    Log    Ignore Order: ${ignore_order}    console=yes
    Log    Expected Status: ${expected_status}    console=yes

    # Call Python library directly
    ${comparison_result}=    FileComparisonLibrary.Compare JSON Files With Exclusions
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${exclude_keys}
    ...    ignore_order=${ignore_order}
    ...    show_details=${show_details}

    Should Be Equal    ${comparison_result}[status]    ${expected_status}
    ...    Expected status '${expected_status}' but got '${comparison_result}[status]'

    Log    \nJSON comparison with exclusions completed - Status: ${comparison_result}[status]    console=yes
    Log    Total differences found: ${comparison_result}[total_differences]    console=yes

    RETURN    ${comparison_result}

Compare JSON Files Template
    [Documentation]    Template keyword for JSON comparison with validation.
    ...
    ...    *Arguments:*
    ...    - ``file1_path``: Path to the first JSON file (actual output)
    ...    - ``file2_path``: Path to the second JSON file (expected output)
    ...    - ``ignore_order``: Whether to ignore element order during comparison
    ...    - ``show_details``: Whether to show detailed differences
    ...    - ``expected_status``: Expected comparison result (IDENTICAL or DIFFERENT)
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary with ``status`` and ``total_differences``
    ...
    ...    *Example:*
    ...    | ${result}= | Compare JSON Files Template | ${actual_file} | ${expected_file} | ${TRUE} | ${TRUE} | IDENTICAL |
    [Arguments]    ${file1_path}    ${file2_path}    ${ignore_order}    ${show_details}    ${expected_status}

    Log    Comparing JSON files with template:
    Log    File 1: ${file1_path}
    Log    File 2: ${file2_path}
    Log    Ignore Order: ${ignore_order}
    Log    Show Details: ${show_details}
    Log    Expected Status: ${expected_status}

    ${comparison_result}=    FileComparisonLibrary.Compare JSON Files
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ignore_order=${ignore_order}
    ...    show_details=${show_details}

    Should Be Equal    ${comparison_result}[status]    ${expected_status}
    ...    Expected status '${expected_status}' but got '${comparison_result}[status]'

    Log    JSON comparison completed successfully - Status: ${comparison_result}[status]
    Log    Total differences found: ${comparison_result}[total_differences]

    RETURN    ${comparison_result}

################## JSON UTILS ##################

Get JSON Value By Path
    [Documentation]    Extracts a specific value from JSON using JSONPath expression.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to JSON file
    ...    - ``json_path``: JSONPath expression (e.g., ``$.config.timeout``)
    ...
    ...    *Returns:*
    ...    - Value at the specified JSONPath
    ...
    ...    *Example:*
    ...    | ${value}= | Get JSON Value By Path | data.json | $.config.timeout |
    [Arguments]    ${json_file}    ${json_path}

    ${json_data}=    Load Json From File    ${json_file}
    ${value}=    Get Value From Json    ${json_data}    ${json_path}
    Log    Extracted value from ${json_path}: ${value}
    RETURN    ${value}

Validate JSON Against Schema File
    [Documentation]    Validates JSON file against a schema file.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to JSON file to validate
    ...    - ``schema_file``: Path to JSON schema file
    ...
    ...    *Example:*
    ...    | Validate JSON Against Schema File | ${CURDIR}/data/output.json | ${CURDIR}/schemas/output_schema.json |
    [Arguments]    ${json_file}    ${schema_file}

    Log    Validating JSON file against schema...
    Log    JSON file: ${json_file}
    Log    Schema file: ${schema_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${schema}=    Load Json From File    ${schema_file}
    Validate Json By Schema    ${json_data}    ${schema}
    Log    JSON validation passed successfully

Check JSON Has Value
    [Documentation]    Checks if JSON contains a value at given JSONPath.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the JSON file
    ...    - ``json_path``: JSONPath expression to check
    ...    - ``expected_value``: Optional expected value to match (default: None)
    ...
    ...    *Example:*
    ...    | Check JSON Has Value | data.json | $.config.timeout |
    ...    | Check JSON Has Value | data.json | $.config.timeout | 30 |
    [Arguments]    ${json_file}    ${json_path}    ${expected_value}=${None}

    ${json_data}=    Load Json From File    ${json_file}
    ${values}=    Get Value From Json    ${json_data}    ${json_path}
    ${length}=    Get Length    ${values}
    Should Be True    ${length} > 0    JSON does not contain path: ${json_path}

    IF    '${expected_value}' != '${None}'
        ${actual_value}=    Get From List    ${values}    0
        Should Be Equal    ${actual_value}    ${expected_value}
        Log    JSON contains expected value '${expected_value}' at path '${json_path}'
    ELSE
        Log    JSON contains a value at path '${json_path}'
    END

Check JSON Does Not Have Value
    [Documentation]    Checks if JSON does NOT contain a value at given JSONPath.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the JSON file
    ...    - ``json_path``: JSONPath expression that should not exist
    ...
    ...    *Example:*
    ...    | Check JSON Does Not Have Value | data.json | $.deprecated_field |
    [Arguments]    ${json_file}    ${json_path}

    ${json_data}=    Load Json From File    ${json_file}
    ${values}=    Get Value From Json    ${json_data}    ${json_path}
    ${length}=    Get Length    ${values}
    Should Be True    ${length} == 0    JSON should not contain path: ${json_path}
    Log    JSON does not contain any value at path '${json_path}'

Modify JSON And Save
    [Documentation]    Modifies JSON file by updating/adding values and saves it.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the source JSON file
    ...    - ``json_path``: JSONPath expression for the value to update
    ...    - ``new_value``: New value to set at the specified path
    ...    - ``output_file``: Path to save modified JSON (default: overwrites source file)
    ...
    ...    *Example:*
    ...    | Modify JSON And Save | config.json | $.timeout | 60 |
    ...    | Modify JSON And Save | config.json | $.timeout | 60 | modified_config.json |
    [Arguments]    ${json_file}    ${json_path}    ${new_value}    ${output_file}=${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${modified_json}=    Update Value To Json    ${json_data}    ${json_path}    ${new_value}
    ${json_string}=    Convert Json To String    ${modified_json}
    Create File    ${output_file}    ${json_string}
    Log    Modified JSON saved to: ${output_file}
    Log    Updated path '${json_path}' with value: ${new_value}

Delete Object From JSON File
    [Documentation]    Deletes an object from JSON file and saves it.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the source JSON file
    ...    - ``json_path``: JSONPath expression for the object to delete
    ...    - ``output_file``: Path to save modified JSON (default: overwrites source file)
    ...
    ...    *Example:*
    ...    | Delete Object From JSON File | config.json | $.deprecated_setting |
    [Arguments]    ${json_file}    ${json_path}    ${output_file}=${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${modified_json}=    Delete Object From Json    ${json_data}    ${json_path}
    ${json_string}=    Convert Json To String    ${modified_json}
    Create File    ${output_file}    ${json_string}
    Log    Deleted object from JSON and saved to: ${output_file}
    Log    Removed object at path: ${json_path}

Convert JSON File To String
    [Documentation]    Converts JSON file content to string format.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the JSON file
    ...
    ...    *Returns:*
    ...    - String representation of the JSON content
    ...
    ...    *Example:*
    ...    | ${json_str}= | Convert JSON File To String | data.json |
    [Arguments]    ${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${json_string}=    Convert Json To String    ${json_data}
    Log    Converted JSON file to string format
    RETURN    ${json_string}

Create JSON From String
    [Documentation]    Creates JSON object from string and optionally saves to file.
    ...
    ...    *Arguments:*
    ...    - ``json_string``: JSON-formatted string to parse
    ...    - ``output_file``: Optional path to save the JSON (default: None)
    ...
    ...    *Returns:*
    ...    - Parsed JSON object
    ...
    ...    *Example:*
    ...    | ${json}= | Create JSON From String | {"key": "value"} |
    ...    | ${json}= | Create JSON From String | {"key": "value"} | output.json |
    [Arguments]    ${json_string}    ${output_file}=${None}

    ${json_data}=    Convert String To Json    ${json_string}

    IF    '${output_file}' != '${None}'
        ${output_string}=    Convert Json To String    ${json_data}
        Create File    ${output_file}    ${output_string}
        Log    Created JSON file from string: ${output_file}
    END

    Log    Converted string to JSON object
    RETURN    ${json_data}

Validate JSON File Template
    [Documentation]    Template keyword for validating JSON file properties.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the JSON file to validate
    ...    - ``expected_rows``: Expected number of rows/items in the JSON array
    ...    - ``schema_file``: Optional path to JSON schema file for validation (default: None)
    ...
    ...    *Returns:*
    ...    - Dictionary with ``valid`` (boolean) and ``actual_rows`` (integer)
    ...
    ...    *Example:*
    ...    | ${result}= | Validate JSON File Template | ${CURDIR}/data/output.json | 100 |
    ...    | ${result}= | Validate JSON File Template | ${CURDIR}/data/output.json | 100 | ${CURDIR}/schemas/schema.json |
    [Arguments]    ${file_path}    ${expected_rows}    ${schema_file}=${None}

    Log    Validating JSON file with template:
    Log    File: ${file_path}
    Log    Expected Rows: ${expected_rows}
    Log    Schema File: ${schema_file}

    File Should Exist    ${file_path}

    ${json_data}=    Load Json From File    ${file_path}
    ${actual_rows}=    Get Length    ${json_data}

    Should Be Equal As Numbers    ${actual_rows}    ${expected_rows}
    ...    Expected ${expected_rows} rows but found ${actual_rows}

    # Validate against schema if provided
    IF    '${schema_file}' != '${None}' and '${schema_file}' != ''
        Validate JSON Against Schema File    ${file_path}    ${schema_file}
    END

    Log    JSON validation completed successfully

    ${result}=    Create Dictionary
    ...    valid=${TRUE}
    ...    actual_rows=${actual_rows}
    RETURN    ${result}

Validate JSON Array Schema
    [Documentation]    Validates JSON array against expected structure.
    ...
    ...    *Arguments:*
    ...    - ``json_file``: Path to the JSON file containing the array
    ...    - ``expected_item_keys``: List of expected keys in each array item
    ...
    ...    *Example:*
    ...    | @{keys}= | Create List | id | name | status |
    ...    | Validate JSON Array Schema | ${CURDIR}/data/users.json | ${keys} |
    [Arguments]    ${json_file}    ${expected_item_keys}

    Log    Validating JSON array schema...

    ${json_data}=    Load Json From File    ${json_file}

    # Check if it's an array
    ${is_array}=    Evaluate    isinstance($json_data, list)
    Should Be True    ${is_array}    JSON file should contain an array

    # Validate each item has expected keys
    ${array_length}=    Get Length    ${json_data}
    IF    ${array_length} > 0
        ${first_item}=    Get From List    ${json_data}    0
        ${actual_keys}=    Get Dictionary Keys    ${first_item}
        ${actual_keys_set}=    Evaluate    set($actual_keys)
        ${expected_keys_set}=    Evaluate    set($expected_item_keys)

        Should Be Equal    ${actual_keys_set}    ${expected_keys_set}
        ...    JSON item keys don't match. Expected: ${expected_item_keys}, Found: ${actual_keys}
    END

    Log    JSON array schema validation passed

Validate JSON File Exists And Not Empty
    [Documentation]    Validates that a JSON file exists and has content (size > 0 bytes).
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the JSON file to validate
    ...
    ...    *Example:*
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
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary (from ``Load Json From File``)
    ...    - ``field_name``: The field/key to extract
    ...    - ``expected_value``: The value the field should have
    ...
    ...    *Example:*
    ...    | Validate JSON Field Value | ${json} | ut_status | approved |
    [Arguments]    ${json_data}    ${field_name}    ${expected_value}
    ${value_list}=    Get Value From Json    ${json_data}    $.${field_name}
    ${actual_value}=    Get From List    ${value_list}    0
    Should Be Equal As Strings    ${actual_value}    ${expected_value}
    ...    Field '${field_name}': expected '${expected_value}' but got '${actual_value}'
    Log    Field '${field_name}' = '${actual_value}' (matches expected)    console=yes

Validate JSON Fields Match Expected
    [Documentation]    Compares specified fields between actual and expected JSON data.
    ...    Pass the field names you want to match — this keyword loops through all of them.
    ...
    ...    *Arguments:*
    ...    - ``actual_json``: Parsed actual JSON dictionary
    ...    - ``expected_json``: Parsed expected JSON dictionary
    ...    - ``@fields_to_match``: One or more field names to compare
    ...
    ...    *Example:*
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
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary
    ...    - ``@required_fields``: One or more field names that must be present
    ...
    ...    *Example:*
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
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary
    ...    - ``field_name``: The field to extract
    ...    - ``pattern``: Regex pattern the field value must match
    ...
    ...    *Example:*
    ...    | Validate Field Matches Pattern | ${json} | jira_ticket | ^[A-Z]+-\\d+$ |
    [Arguments]    ${json_data}    ${field_name}    ${pattern}
    ${value_list}=    Get Value From Json    ${json_data}    $.${field_name}
    ${value}=    Get From List    ${value_list}    0
    Should Not Be Empty    ${value}
    ...    Field '${field_name}' is empty - cannot validate pattern
    Should Match Regexp    ${value}    ${pattern}
    ...    Field '${field_name}' value '${value}' does not match pattern '${pattern}'
    Log    Field '${field_name}' = '${value}' matches pattern '${pattern}'    console=yes

Validate JSON Array Contains All Values
    [Documentation]    Validates that a JSON array field contains all expected values.
    ...    Extracts the array from ``json_data`` using the given ``field_name``,
    ...    then asserts each expected value is present in the array.
    ...
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary
    ...    - ``field_name``: The field containing the array (e.g., ``output_columns``)
    ...    - ``@expected_values``: One or more values that must be in the array
    ...
    ...    *Example:*
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
    ...    Extracts the nested object using ``parent_key``, then compares each specified field.
    ...
    ...    *Arguments:*
    ...    - ``actual_json``: Parsed actual JSON dictionary
    ...    - ``expected_json``: Parsed expected JSON dictionary
    ...    - ``parent_key``: The parent key containing the nested object (e.g., ``paths``)
    ...    - ``@fields_to_match``: One or more field names within the nested object to compare
    ...
    ...    *Example:*
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
    ...    Extracts the nested object using ``parent_key``, then checks each field is present and non-empty.
    ...
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary
    ...    - ``parent_key``: The parent key containing the nested object
    ...    - ``@required_fields``: One or more field names that must exist in the nested object
    ...
    ...    *Example:*
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
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary
    ...    - ``field_name``: The field to extract (must be numeric)
    ...    - ``min_value``: The minimum value (exclusive — actual must be > ``min_value``)
    ...
    ...    *Example:*
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
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary
    ...    - ``expected_total``: The expected sum value
    ...    - ``@field_names``: One or more numeric field names to sum
    ...
    ...    *Example:*
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
    ...    Asserts ``actual_field_value`` <= ``threshold_field_value``.
    ...    Useful for duration/timeout checks where a value must not exceed a limit.
    ...
    ...    *Arguments:*
    ...    - ``actual_json``: Parsed actual JSON dictionary
    ...    - ``actual_field``: The field name to check (e.g., ``execution_duration_seconds``)
    ...    - ``expected_json``: Parsed expected JSON dictionary
    ...    - ``threshold_field``: The field containing the max allowed value (e.g., ``max_duration_threshold``)
    ...
    ...    *Example:*
    ...    | Validate JSON Field Less Than Or Equal | ${actual} | execution_duration_seconds | ${expected} | max_duration_threshold |
    [Arguments]    ${actual_json}    ${actual_field}    ${expected_json}    ${threshold_field}
    ${actual_list}=    Get Value From Json    ${actual_json}    $.${actual_field}
    ${actual_value}=    Get From List    ${actual_list}    0
    ${threshold_list}=    Get Value From Json    ${expected_json}    $.${threshold_field}
    ${threshold_value}=    Get From List    ${threshold_list}    0
    Should Be True
    ...    ${actual_value} <= ${threshold_value}
    ...    Field '${actual_field}' value ${actual_value} exceeds threshold '${threshold_field}' value ${threshold_value}
    Log    Field '${actual_field}' = ${actual_value} (<= ${threshold_field} = ${threshold_value})    console=yes

Validate JSON Two Fields Are Equal
    [Documentation]    Asserts that two fields from the same JSON dictionary have equal values.
    ...    Useful for data integrity checks where two counts must match (e.g., source sum = target count).
    ...
    ...    *Arguments:*
    ...    - ``json_data``: Parsed JSON dictionary
    ...    - ``field_1``: First field name
    ...    - ``field_2``: Second field name (must equal ``field_1``)
    ...
    ...    *Example:*
    ...    | Validate JSON Two Fields Are Equal | ${json} | source_total_sum | target_table_count |
    [Arguments]    ${json_data}    ${field_1}    ${field_2}
    ${value_1_list}=    Get Value From Json    ${json_data}    $.${field_1}
    ${value_2_list}=    Get Value From Json    ${json_data}    $.${field_2}
    ${value_1}=    Get From List    ${value_1_list}    0
    ${value_2}=    Get From List    ${value_2_list}    0
    Should Be Equal As Strings    ${value_1}    ${value_2}
    ...    Field '${field_1}' (${value_1}) does not equal field '${field_2}' (${value_2})
    Log    Fields match: '${field_1}' = '${field_2}' = ${value_1}    console=yes
