*** Settings ***
Documentation       Optimized resource file for CSV/JSON file operations and comparisons.
...                 This resource file uses standard Robot Framework libraries
...                 with a custom file_comparison_library for comparison with exclusions.
...
...                 Contains keywords for:
...                 - CSV/JSON file loading and validation
...                 - File content analysis and row counting
...                 - Database loading operations
...                 - File comparison with exclusions
...                 - JSON schema validation and manipulation
...                 - Key-based row matching for CSV comparison

# Custom Library for comparison operations (not available in standard libraries)
Library             ../../libraries/common/FileComparisonLibrary.py
# Standard Libraries
Library             OperatingSystem
Library             Collections
Library             String
Library             JSONLibrary
Library             CSVLibrary
Library             DatabaseLibrary
# Other Resource Files
Resource            general.resource
Resource            sql_table_operations.resource
Resource            database.resource
# SnapLogic API keywords for file upload operations
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource


*** Keywords ***
################## FILE ANALYSIS AND COUNTING ##################

Count Data Rows In CSV
    [Documentation]    Counts the number of data rows in a CSV file (excluding header rows).
    ...
    ...    Arguments:
    ...    - csv_file: Path to the CSV file to analyze
    ...    - header_rows: Number of header rows to exclude (default: 1)
    ...
    ...    Returns: Number of data rows in the CSV file
    ...
    ...    Example:
    ...    | ${count}= | Count Data Rows In CSV | data.csv |
    ...    | ${count}= | Count Data Rows In CSV | raw_data.csv | header_rows=0 |
    [Arguments]    ${csv_file}    ${header_rows}=1

    @{csv_data}=    Read Csv File To List    ${csv_file}
    ${total_rows}=    Get Length    ${csv_data}
    ${data_rows}=    Evaluate    ${total_rows} - ${header_rows}
    Log    CSV file analysis: ${data_rows} data rows (excluding ${header_rows} header rows)
    RETURN    ${data_rows}

Count Data Rows In JSON
    [Documentation]    Counts the number of data rows in a JSON file.
    ...
    ...    Arguments:
    ...    - json_file: Path to the JSON file to analyze
    ...
    ...    Returns: Number of items in the JSON array
    ...
    ...    Example:
    ...    | ${count}= | Count Data Rows In JSON | data.json |
    [Arguments]    ${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${data_rows}=    Get Length    ${json_data}
    Log    JSON file analysis: ${data_rows} data rows
    RETURN    ${data_rows}

Get File Extension
    [Documentation]    Extracts file extension from file path (returns lowercase with dot).
    [Arguments]    ${file_path}

    ${path}    ${ext}=    Split Extension    ${file_path}
    ${extension}=    Convert To Lower Case    ${ext}
    RETURN    ${extension}

Get Directory From Path
    [Documentation]    Extracts directory path from a full file path.
    [Arguments]    ${file_path}

    ${dir_path}    ${file_name}=    Split Path    ${file_path}
    RETURN    ${dir_path}

Get File Content Safely
    [Documentation]    Gets file content from a text file.
    [Arguments]    ${file_path}

    ${content}=    Get File    ${file_path}
    RETURN    ${content}

################## DATA LOADING TEMPLATES ##################

Load CSV Data Template
    [Documentation]    Enhanced template that auto-calculates expected rows from CSV file.
    ...
    ...    Arguments:
    ...    - csv_file: Path to CSV file
    ...    - table_name: Target database table name
    ...    - truncate_table: Whether to truncate table before loading (default: TRUE)
    [Arguments]    ${csv_file}    ${table_name}    ${truncate_table}=${TRUE}

    Log    Loading CSV file: ${csv_file}
    Log    Target table: ${table_name}
    Log    Truncate table: ${truncate_table}

    # Auto-calculate expected rows from CSV file
    ${expected_rows}=    Count Data Rows In CSV    ${csv_file}
    Log    Auto-detected expected rows: ${expected_rows}

    # Read CSV data - first row is header with column names
    @{all_rows}=    Read Csv File To List    ${csv_file}
    ${header_row}=    Evaluate    $all_rows[0]    # Get column names from header
    @{csv_data}=    Evaluate    $all_rows[1:]    # Skip header row for data

    # Build column names string from CSV header
    ${columns}=    Evaluate    ', '.join($header_row)

    # Truncate table if requested
    IF    ${truncate_table}
        Execute SQL String    TRUNCATE TABLE ${table_name}
        Log    Truncated table: ${table_name}
    END

    # Log total rows to insert for debugging
    ${total_rows}=    Get Length    ${csv_data}
    Log    Total data rows to insert: ${total_rows}

    # Insert data row by row with explicit column names
    ${row_num}=    Set Variable    0
    FOR    ${row}    IN    @{csv_data}
        ${row_num}=    Evaluate    ${row_num} + 1
        Log    Processing row ${row_num}: ${row}
        # Build INSERT statement - quote strings, leave numbers unquoted
        ${values}=    Evaluate
        ...    ', '.join([v if v.isdigit() or (v.replace('.','',1).replace('-','',1).isdigit()) else f"'{v}'" for v in $row])
        ${sql}=    Set Variable    INSERT INTO ${table_name} (${columns}) VALUES (${values})
        Log    Row ${row_num}: Executing SQL: ${sql}
        Execute SQL String    ${sql}
        # Verify the insert worked by checking count after each insert
        ${count_after}=    Row Count    SELECT COUNT(*) FROM ${table_name}
        Log    Row ${row_num}: After insert, table has ${count_after} rows
    END

    # Verify row count - use Query to get the actual COUNT value
    ${result}=    Query    SELECT COUNT(*) FROM ${table_name}
    ${actual_count}=    Set Variable    ${result[0][0]}
    Should Be Equal As Numbers
    ...    ${actual_count}
    ...    ${expected_rows}
    ...    CSV Data Load Failed: CSV file '${csv_file}' contains ${expected_rows} data rows (excluding header), but only ${actual_count} rows were inserted into '${table_name}' table. Possible causes: INSERT statement failed silently, duplicate key constraint, or data type mismatch.

    IF    ${truncate_table}
        Log    Successfully loaded ${expected_rows} rows into ${table_name} table (table was truncated)
    ELSE
        Log    Successfully appended ${expected_rows} rows to ${table_name} table
    END

Load JSON Data Template
    [Documentation]    Enhanced template that auto-calculates expected rows from JSON file.
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

Load Data File Auto
    [Documentation]    Universal data loader that detects file type and loads automatically.
    [Arguments]    ${data_file}    ${table_name}    ${truncate}=${TRUE}

    Log    Auto-loading data file: ${data_file}

    ${file_extension}=    Get File Extension    ${data_file}

    IF    '${file_extension}' == '.csv'
        Load CSV Data Template    ${data_file}    ${table_name}    ${truncate}
    ELSE IF    '${file_extension}' == '.json'
        Load JSON Data Template    ${data_file}    ${table_name}    ${truncate}
    ELSE
        Fail    Unsupported file type: ${file_extension}
    END

################## CSV COMPARISON WITH EXCLUSIONS ##################

Compare CSV Files With Exclusions Template
    [Documentation]    Template keyword for CSV comparison with exclusions and validation.
    ...
    ...    Arguments:
    ...    - file1_path: Path to actual output CSV file
    ...    - file2_path: Path to expected output CSV file
    ...    - ignore_order: Whether to ignore row order
    ...    - show_details: Whether to show detailed differences
    ...    - expected_status: Expected comparison result (IDENTICAL or DIFFERENT)
    ...    - @exclude_keys: One or more JSON keys to exclude from comparison
    ...    - &options: Additional options like match_key=headers.profile_id
    ...
    ...    Example:
    ...    | Compare CSV Files With Exclusions Template |
    ...    | ...    ${actual_file}    ${expected_file}    ${TRUE}    ${TRUE}    IDENTICAL |
    ...    | ...    SnowflakeConnectorPushTime    event_timestamp |
    ...
    ...    Example with match_key:
    ...    | Compare CSV Files With Exclusions Template |
    ...    | ...    ${actual_file}    ${expected_file}    ${TRUE}    ${TRUE}    IDENTICAL |
    ...    | ...    SnowflakeConnectorPushTime    match_key=headers.profile_id |
    [Arguments]
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${ignore_order}
    ...    ${show_details}
    ...    ${expected_status}
    ...    @{exclude_keys}
    ...    &{options}

    # Extract match_key from options if provided
    ${match_key}=    Evaluate    $options.get('match_key', None)
    ${is_match_key_set}=    Evaluate    $match_key is not None and str($match_key) != 'None'

    Log    \nComparing CSV files with exclusions template:    console=yes
    Log    File 1 (Actual): ${file1_path}    console=yes
    Log    File 2 (Expected): ${file2_path}    console=yes
    Log    Excluded Keys: ${exclude_keys}    console=yes
    Log    Ignore Order: ${ignore_order}    console=yes
    Log    Expected Status: ${expected_status}    console=yes
    IF    ${is_match_key_set}    Log    Match Key: ${match_key}    console=yes

    # Call Python library directly - all logging is handled by _log_comparison_result
    ${comparison_result}=    FileComparisonLibrary.Compare CSV Files With Exclusions
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${exclude_keys}
    ...    match_key=${match_key}
    ...    ignore_order=${ignore_order}
    ...    show_details=${show_details}

    Should Be Equal    ${comparison_result}[status]    ${expected_status}
    ...    Expected status '${expected_status}' but got '${comparison_result}[status]'

    Log    \nCSV comparison with exclusions completed - Status: ${comparison_result}[status]    console=yes
    Log    Total differences found: ${comparison_result}[total_differences]    console=yes

    RETURN    ${comparison_result}

Compare CSV Files Template
    [Documentation]    Template keyword for CSV comparison with validation.
    [Arguments]    ${file1_path}    ${file2_path}    ${ignore_order}    ${show_details}    ${expected_status}

    Log    Comparing CSV files with template:
    Log    File 1: ${file1_path}
    Log    File 2: ${file2_path}
    Log    Ignore Order: ${ignore_order}
    Log    Show Details: ${show_details}
    Log    Expected Status: ${expected_status}

    ${comparison_result}=    FileComparisonLibrary.Compare CSV Files
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ignore_order=${ignore_order}
    ...    show_details=${show_details}

    Should Be Equal    ${comparison_result}[status]    ${expected_status}
    ...    Expected status '${expected_status}' but got '${comparison_result}[status]'

    Log    CSV comparison completed successfully - Status: ${comparison_result}[status]
    Log    Total differences found: ${comparison_result}[total_differences]

    RETURN    ${comparison_result}

Compare JSON Files Template
    [Documentation]    Template keyword for JSON comparison with validation.
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

################## FILE PROTOCOL TEMPLATES ##################

Upload File Using File Protocol Template
    [Documentation]    Template keyword to upload files to SnapLogic using file:/// protocol URLs.
    ...    Reads the source file from local filesystem and uploads it to SnapLogic.
    ...    Supports both file:// prefixed URLs and regular file paths.
    ...
    ...    Arguments:
    ...    - file_url: Local file path (with or without file:// prefix)
    ...    - destination_path: SnapLogic destination path (e.g., project_space/project_name)
    ...
    ...    Example:
    ...    | Upload File Using File Protocol Template | ${CURDIR}/data/test.json | ${PIPELINES_LOCATION_PATH} |
    ...    | Upload File Using File Protocol Template | file://${CURDIR}/data/test.json | ${PIPELINES_LOCATION_PATH} |
    [Arguments]    ${file_url}    ${destination_path}

    # Extract path from file:// URL (handles both with and without prefix)
    ${source_path}=    Evaluate    '${file_url}'.replace('file://', '')
    ${path}    ${filename}=    Split Path    ${source_path}

    Log    Uploading from file URL: ${file_url}    console=yes
    Log    Source path: ${source_path}    console=yes
    Log    File name: ${filename}    console=yes
    Log    Destination in SnapLogic: ${destination_path}    console=yes

    # Verify source file exists
    File Should Exist    ${source_path}    Source file not found: ${source_path}

    # Upload file to SnapLogic using the snaplogic_common_robot keyword
    Upload Files To SnapLogic From Template    ${path}    ${filename}    ${destination_path}

    Log    ✅ File uploaded successfully to SnapLogic: ${destination_path}/${filename}    console=yes

List Files Using File Protocol Template
    [Documentation]    Template keyword to list files in directory using file:/// protocol URL.
    [Arguments]    ${dir_url}    ${pattern}=*

    ${dir_path}=    Evaluate    '${dir_url}'.replace('file://', '')
    @{files}=    List Files In Directory    ${dir_path}    pattern=${pattern}

    @{file_urls}=    Create List
    FOR    ${file}    IN    @{files}
        ${file_url}=    Set Variable    file://${dir_path}/${file}
        Append To List    ${file_urls}    ${file_url}
        Log    Found: ${file_url}
    END

    RETURN    ${file_urls}

Copy File Using File Protocol Template
    [Documentation]    Template keyword to copy files between file:/// protocol URLs.
    [Arguments]    ${source_file_url}    ${dest_file_url}

    ${source_path}=    Evaluate    '${source_file_url}'.replace('file://', '')
    ${dest_path}=    Evaluate    '${dest_file_url}'.replace('file://', '')

    Log    Copying from: ${source_file_url}
    Log    Copying to: ${dest_file_url}

    Copy File    ${source_path}    ${dest_path}
    Log    File copied successfully

##################################################################################
#    UNUSED KEYWORDS    #
# The following keywords are not currently used in any test cases or resources.    #
# They are kept here for potential future use or reference.    #
##################################################################################

Count Rows In File
    [Documentation]    Universal row counter that detects file type and counts appropriately.
    ...
    ...    Arguments:
    ...    - file_path: Path to the file to analyze
    ...    - header_rows: Number of header rows (only applies to CSV, default: 1)
    ...
    ...    Returns: Number of data rows
    [Arguments]    ${file_path}    ${header_rows}=1

    ${extension}=    Get File Extension    ${file_path}

    IF    '${extension}' == '.csv'
        ${row_count}=    Count Data Rows In CSV    ${file_path}    ${header_rows}
    ELSE IF    '${extension}' == '.json'
        ${row_count}=    Count Data Rows In JSON    ${file_path}
    ELSE
        Fail    Unsupported file type: ${extension}
    END
    RETURN    ${row_count}

Remove Directory Safely
    [Documentation]    Removes directory if it exists, otherwise does nothing.
    [Arguments]    ${directory_path}

    ${exists}=    Run Keyword And Return Status    Directory Should Exist    ${directory_path}
    IF    ${exists}
        Remove Directory    ${directory_path}    recursive=True
        Log    Removed existing directory: ${directory_path}
    ELSE
        Log    Directory does not exist (no need to remove): ${directory_path}
    END

Get JSON Value By Path
    [Documentation]    Extracts a specific value from JSON using JSONPath expression.
    ...
    ...    Arguments:
    ...    - json_file: Path to JSON file
    ...    - json_path: JSONPath expression (e.g., '$.config.timeout')
    ...
    ...    Example:
    ...    | ${value}= | Get JSON Value By Path | data.json | $.config.timeout |
    [Arguments]    ${json_file}    ${json_path}

    ${json_data}=    Load Json From File    ${json_file}
    ${value}=    Get Value From Json    ${json_data}    ${json_path}
    Log    Extracted value from ${json_path}: ${value}
    RETURN    ${value}

Validate JSON Against Schema File
    [Documentation]    Validates JSON file against a schema file.
    ...
    ...    Arguments:
    ...    - json_file: Path to JSON file to validate
    ...    - schema_file: Path to JSON schema file
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
    [Arguments]    ${json_file}    ${json_path}

    ${json_data}=    Load Json From File    ${json_file}
    ${values}=    Get Value From Json    ${json_data}    ${json_path}
    ${length}=    Get Length    ${values}
    Should Be True    ${length} == 0    JSON should not contain path: ${json_path}
    Log    JSON does not contain any value at path '${json_path}'

Modify JSON And Save
    [Documentation]    Modifies JSON file by updating/adding values and saves it.
    [Arguments]    ${json_file}    ${json_path}    ${new_value}    ${output_file}=${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${modified_json}=    Update Value To Json    ${json_data}    ${json_path}    ${new_value}
    ${json_string}=    Convert Json To String    ${modified_json}
    Create File    ${output_file}    ${json_string}
    Log    Modified JSON saved to: ${output_file}
    Log    Updated path '${json_path}' with value: ${new_value}

Delete Object From JSON File
    [Documentation]    Deletes an object from JSON file and saves it.
    [Arguments]    ${json_file}    ${json_path}    ${output_file}=${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${modified_json}=    Delete Object From Json    ${json_data}    ${json_path}
    ${json_string}=    Convert Json To String    ${modified_json}
    Create File    ${output_file}    ${json_string}
    Log    Deleted object from JSON and saved to: ${output_file}
    Log    Removed object at path: ${json_path}

Convert JSON File To String
    [Documentation]    Converts JSON file content to string format.
    [Arguments]    ${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    ${json_string}=    Convert Json To String    ${json_data}
    Log    Converted JSON file to string format
    RETURN    ${json_string}

Create JSON From String
    [Documentation]    Creates JSON object from string and optionally saves to file.
    [Arguments]    ${json_string}    ${output_file}=${None}

    ${json_data}=    Convert String To Json    ${json_string}

    IF    '${output_file}' != '${None}'
        ${output_string}=    Convert Json To String    ${json_data}
        Create File    ${output_file}    ${output_string}
        Log    Created JSON file from string: ${output_file}
    END

    Log    Converted string to JSON object
    RETURN    ${json_data}

Validate CSV File Template
    [Documentation]    Template keyword for validating CSV file properties.
    [Arguments]    ${file_path}    ${expected_rows}    ${has_headers}=${TRUE}    ${expected_columns}=${None}

    Log    Validating CSV file with template:
    Log    File: ${file_path}
    Log    Expected Rows: ${expected_rows}
    Log    Has Headers: ${has_headers}
    Log    Expected Columns: ${expected_columns}

    File Should Exist    ${file_path}

    @{csv_data}=    Read Csv File To List    ${file_path}
    ${total_rows}=    Get Length    ${csv_data}

    IF    ${has_headers}
        ${actual_rows}=    Evaluate    ${total_rows} - 1
        ${headers}=    Get From List    ${csv_data}    0
        ${actual_columns}=    Get Length    ${headers}
    ELSE
        ${actual_rows}=    Set Variable    ${total_rows}
        ${first_row}=    Get From List    ${csv_data}    0
        ${actual_columns}=    Get Length    ${first_row}
    END

    Should Be Equal As Numbers    ${actual_rows}    ${expected_rows}
    ...    Expected ${expected_rows} rows but found ${actual_rows}

    IF    '${expected_columns}' != '${None}'
        Should Be Equal As Numbers    ${actual_columns}    ${expected_columns}
        ...    Expected ${expected_columns} columns but found ${actual_columns}
    END

    Log    CSV validation completed successfully
    Log    Actual rows: ${actual_rows}, Actual columns: ${actual_columns}

    ${result}=    Create Dictionary
    ...    valid=${TRUE}
    ...    actual_rows=${actual_rows}
    ...    actual_columns=${actual_columns}
    RETURN    ${result}

Validate JSON File Template
    [Documentation]    Template keyword for validating JSON file properties.
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

Get File Info
    [Documentation]    Get comprehensive information about a file.
    [Arguments]    ${file_path}

    File Should Exist    ${file_path}

    ${dir_path}    ${file_name}=    Split Path    ${file_path}
    ${extension}=    Get File Extension    ${file_path}
    ${size}=    Get File Size    ${file_path}

    ${info}=    Create Dictionary
    ...    path=${file_path}
    ...    name=${file_name}
    ...    extension=${extension}
    ...    size=${size}
    ...    directory=${dir_path}

    Log    File Info: ${info}
    RETURN    ${info}

Ensure Directory Exists
    [Documentation]    Creates directory if it doesn't exist.
    [Arguments]    ${directory_path}

    ${exists}=    Run Keyword And Return Status    Directory Should Exist    ${directory_path}
    IF    not ${exists}
        Create Directory    ${directory_path}
        Log    Created directory: ${directory_path}
    ELSE
        Log    Directory already exists: ${directory_path}
    END

Clean Up Test Files
    [Documentation]    Cleans up test files and directories.
    [Arguments]    @{paths}

    FOR    ${path}    IN    @{paths}
        ${is_dir}=    Run Keyword And Return Status    Directory Should Exist    ${path}
        IF    ${is_dir}
            Remove Directory    ${path}    recursive=True
            Log    Removed directory: ${path}
        ELSE
            ${is_file}=    Run Keyword And Return Status    File Should Exist    ${path}
            IF    ${is_file}
                Remove File    ${path}
                Log    Deleted file: ${path}
            END
        END
    END
    Log    Cleanup completed
