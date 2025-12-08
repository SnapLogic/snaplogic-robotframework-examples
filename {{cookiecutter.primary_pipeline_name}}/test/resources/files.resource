*** Settings ***
Documentation       Resource file for CSV/JSON file operations and comparisons
...                 Contains all keywords related to:
...                 • CSV/JSON file loading and validation with enhanced JSONLibrary usage
...                 • File content analysis and row counting
...                 • Database loading operations
...                 • File comparison and validation
...                 • Enhanced templates with auto-detection
...                 • JSON schema validation and manipulation
...                 • Key-based row matching for CSV comparison

# Standard Libraries for file operations
Library             OperatingSystem    # File system operations
Library             CSVLibrary    # CSV file operations
Library             JSONLibrary    # JSON file operations - NOW PROPERLY UTILIZED
Library             DatabaseLibrary    # Database operations for file loading
Library             String
Library             Collections
Resource            general.resource
Resource            database.resource    # Database operations for file loading
Resource            minio.resource    # MinIO file operations (if needed)
Resource            sql_table_operations.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords from installed package


*** Keywords ***
################## FILE ANALYSIS AND COUNTING ##################

Count Data Rows In CSV
    [Documentation]    Counts the number of data rows in a CSV file (excluding header rows)
    ...
    ...    This keyword reads a CSV file and returns the count of data rows,
    ...    excluding any header rows. The number of header rows can be customized
    ...    to accommodate different CSV file formats.
    ...
    ...    Arguments:
    ...    ${csv_file}    - Path to the CSV file to analyze
    ...    ${header_rows}    - Number of header rows to exclude (default: 1)
    ...    Set to 0 for headerless CSV files
    ...    Set to 2+ for multi-line headers
    ...
    ...    Returns:
    ...    Number of data rows in the CSV file (always >= 0)
    ...
    ...    Examples:
    ...    # Standard CSV with single header row (default)
    ...    ${count}=    Count Data Rows In CSV    data.csv
    ...
    ...    # CSV without headers
    ...    ${count}=    Count Data Rows In CSV    raw_data.csv    header_rows=0
    ...
    ...    # CSV with complex 3-row header
    ...    ${count}=    Count Data Rows In CSV    complex_report.csv    header_rows=3
    ...
    ...    # Using with variable
    ...    ${headers}=    Set Variable    2
    ...    ${count}=    Count Data Rows In CSV    report.csv    header_rows=${headers}
    ...
    [Arguments]    ${csv_file}    ${header_rows}=1

    File Should Exist    ${csv_file}

    # Read CSV file as list
    ${csv_content}=    Read Csv File To List    ${csv_file}
    ${total_rows}=    Get Length    ${csv_content}

    # Subtract header rows from total
    ${data_rows}=    Evaluate    ${total_rows} - ${header_rows}

    # Ensure we don't return negative numbers
    ${data_rows}=    Evaluate    max(0, ${data_rows})

    Log    📊 CSV file analysis: ${total_rows} total rows, ${header_rows} header rows, ${data_rows} data rows

    RETURN    ${data_rows}

Count Data Rows In JSON
    [Documentation]    Counts the number of data rows in a JSON file using JSONLibrary
    [Arguments]    ${json_file}

    File Should Exist    ${json_file}

    # Use JSONLibrary to load and parse JSON file - REFACTORED
    ${json_data}=    Load Json From File    ${json_file}

    # Count array elements (assuming JSON is an array of objects)
    ${data_rows}=    Get Length    ${json_data}

    Log    📊 JSON file analysis: ${data_rows} data rows

    RETURN    ${data_rows}

Count Rows In File
    [Documentation]    Universal row counter that detects file type and counts appropriately
    ...
    ...    Arguments:
    ...    ${file_path}    - Path to the file to analyze
    ...    ${header_rows}    - Number of header rows (only applies to CSV files, default: 1)
    ...
    [Arguments]    ${file_path}    ${header_rows}=1

    # Detect file type by extension
    ${file_extension}=    Get File Extension From Path    ${file_path}

    IF    '${file_extension}' == '.csv'
        ${row_count}=    Count Data Rows In CSV    ${file_path}    header_rows=${header_rows}
    ELSE IF    '${file_extension}' == '.json'
        ${row_count}=    Count Data Rows In JSON    ${file_path}
    ELSE
        # For other file types, could implement additional logic
        Log    ⚠️ Unknown file type: ${file_extension}. Returning 0.
        ${row_count}=    Set Variable    0
    END

    RETURN    ${row_count}

Get File Extension From Path
    [Documentation]    Extracts file extension from file path (returns lowercase with dot)
    [Arguments]    ${file_path}

    # Split by forward slash to get filename
    ${path_parts}=    Split String    ${file_path}    /
    ${filename}=    Get From List    ${path_parts}    -1

    # Split filename by dot to get extension
    ${name_parts}=    Split String    ${filename}    .
    ${parts_count}=    Get Length    ${name_parts}

    IF    ${parts_count} > 1
        ${extension}=    Get From List    ${name_parts}    -1
        ${extension_lower}=    Convert To Lower Case    .${extension}
        RETURN    ${extension_lower}
    ELSE
        RETURN    ${EMPTY}
    END

Get Directory From Path
    [Documentation]    Extracts directory path from a full file path
    [Arguments]    ${file_path}

    ${path_parts}=    Split String    ${file_path}    /
    ${path_parts_length}=    Get Length    ${path_parts}

    IF    ${path_parts_length} > 1
        ${dir_parts}=    Get Slice From List    ${path_parts}    0    -1
        ${dir_path}=    Catenate    SEPARATOR=/    @{dir_parts}
    ELSE
        ${dir_path}=    Set Variable    ${CURDIR}
    END

    RETURN    ${dir_path}

Get File Content Safely
    [Documentation]    Gets file content, handling both text and binary files
    [Arguments]    ${file_path}

    # Extract filename from path
    ${path_parts}=    Split String    ${file_path}    /
    ${filename}=    Get From List    ${path_parts}    -1
    ${is_binary}=    Is Binary File    ${filename}

    IF    ${is_binary}
        ${file_size}=    Get File Size    ${file_path}
        ${content}=    Set Variable    <Binary file: ${filename} (${file_size} bytes)>
        Log    Handled binary file: ${filename}
    ELSE
        TRY
            ${content}=    Get File    ${file_path}
            Log    Read text file: ${filename}
        EXCEPT    UnicodeDecodeError
            ${file_size}=    Get File Size    ${file_path}
            ${content}=    Set Variable    <Binary content detected: ${filename} (${file_size} bytes)>
            Log    Binary content detected in: ${filename}
        END
    END

    RETURN    ${content}

Is Binary File
    [Documentation]    Checks if a file is binary based on its extension
    [Arguments]    ${filename}

    # Common binary file extensions
    @{binary_extensions}=    Create List
    ...    .slpropz
    ...    .zip
    ...    .jar
    ...    .exe
    ...    .bin
    ...    .pdf
    ...    .jpg
    ...    .png
    ...    .gif
    ...    .mp3
    ...    .mp4
    ...    .avi

    ${lower_filename}=    Convert To Lower Case    ${filename}

    FOR    ${ext}    IN    @{binary_extensions}
        ${is_binary}=    Run Keyword And Return Status    Should End With    ${lower_filename}    ${ext}
        IF    ${is_binary}    RETURN    ${True}
    END

    RETURN    ${False}

Remove Directory If Exists
    [Documentation]    Removes directory if it exists, otherwise does nothing
    [Arguments]    ${directory_path}

    ${dir_exists}=    Run Keyword And Return Status    Directory Should Exist    ${directory_path}
    IF    ${dir_exists}
        Remove Directory    ${directory_path}    recursive=True
        Log    🗑️ Removed existing directory: ${directory_path}
    ELSE
        Log    📁 Directory does not exist (no need to remove): ${directory_path}
    END

Remove ID Column From Row
    [Documentation]    Removes the first column (ID) from a CSV row if it exists
    [Arguments]    ${row}

    ${row_length}=    Get Length    ${row}
    IF    ${row_length} > 3
        # If row has more than 3 columns, assume first is ID and remove it
        ${without_id}=    Get Slice From List    ${row}    1
        RETURN    ${without_id}
    ELSE
        # If row has 3 or fewer columns, return as-is
        RETURN    ${row}
    END

################## NEW JSON UTILITY KEYWORDS ##################

Get JSON Value By Path
    [Documentation]    Extracts a specific value from JSON file using JSONPath
    [Arguments]    ${json_file}    ${json_path}

    File Should Exist    ${json_file}
    ${json_data}=    Load Json From File    ${json_file}
    ${value}=    Get Value From Json    ${json_data}    ${json_path}

    Log    🔍 Extracted value from ${json_path}: ${value}
    RETURN    ${value}

Validate JSON Against Schema File
    [Documentation]    Validates JSON file against a schema file
    [Arguments]    ${json_file}    ${schema_file}

    File Should Exist    ${json_file}
    File Should Exist    ${schema_file}

    Log    ✅ Validating JSON file against schema...
    Log    📄 JSON file: ${json_file}
    Log    📋 Schema file: ${schema_file}

    Validate Json By Schema File    ${json_file}    ${schema_file}
    Log    ✅ JSON validation passed successfully

Validate JSON Against Schema String
    [Documentation]    Validates JSON file against a schema provided as string
    [Arguments]    ${json_file}    ${schema_string}

    File Should Exist    ${json_file}

    Log    ✅ Validating JSON file against provided schema...
    Log    📄 JSON file: ${json_file}

    ${json_data}=    Load Json From File    ${json_file}
    Validate Json By Schema    ${json_data}    ${schema_string}
    Log    ✅ JSON validation passed successfully

Check JSON Has Value
    [Documentation]    Checks if JSON contains a specific value at given path
    [Arguments]    ${json_file}    ${json_path}    ${expected_value}=${None}

    File Should Exist    ${json_file}
    ${json_data}=    Load Json From File    ${json_file}

    IF    '${expected_value}' != '${None}'
        Should Have Value In Json    ${json_data}    ${json_path}    ${expected_value}
        Log    ✅ JSON contains expected value '${expected_value}' at path '${json_path}'
    ELSE
        Should Have Value In Json    ${json_data}    ${json_path}
        Log    ✅ JSON contains a value at path '${json_path}'
    END

Check JSON Does Not Have Value
    [Documentation]    Checks if JSON does NOT contain a value at given path
    [Arguments]    ${json_file}    ${json_path}    ${unexpected_value}=${None}

    File Should Exist    ${json_file}
    ${json_data}=    Load Json From File    ${json_file}

    IF    '${unexpected_value}' != '${None}'
        Should Not Have Value In Json    ${json_data}    ${json_path}    ${unexpected_value}
        Log    ✅ JSON does not contain unexpected value '${unexpected_value}' at path '${json_path}'
    ELSE
        Should Not Have Value In Json    ${json_data}    ${json_path}
        Log    ✅ JSON does not contain any value at path '${json_path}'
    END

Modify JSON And Save
    [Documentation]    Modifies JSON file by updating/adding values and saves it
    [Arguments]    ${json_file}    ${json_path}    ${new_value}    ${output_file}=${json_file}

    File Should Exist    ${json_file}

    # Load JSON
    ${json_data}=    Load Json From File    ${json_file}

    # Update value
    ${modified_json}=    Update Value To Json    ${json_data}    ${json_path}    ${new_value}

    # Save modified JSON
    Dump Json To File    ${modified_json}    ${output_file}

    Log    ✅ Modified JSON saved to: ${output_file}
    Log    🔧 Updated path '${json_path}' with value: ${new_value}

Add Object To JSON File
    [Documentation]    Adds a new object to JSON file and saves it
    [Arguments]    ${json_file}    ${json_path}    ${new_object}    ${output_file}=${json_file}

    File Should Exist    ${json_file}

    # Load JSON
    ${json_data}=    Load Json From File    ${json_file}

    # Add object
    ${modified_json}=    Add Object To Json    ${json_data}    ${json_path}    ${new_object}

    # Save modified JSON
    Dump Json To File    ${modified_json}    ${output_file}

    Log    ✅ Added object to JSON and saved to: ${output_file}
    Log    ➕ Added object at path '${json_path}': ${new_object}

Delete Object From JSON File
    [Documentation]    Deletes an object from JSON file and saves it
    [Arguments]    ${json_file}    ${json_path}    ${output_file}=${json_file}

    File Should Exist    ${json_file}

    # Load JSON
    ${json_data}=    Load Json From File    ${json_file}

    # Delete object
    ${modified_json}=    Delete Object From Json    ${json_data}    ${json_path}

    # Save modified JSON
    Dump Json To File    ${modified_json}    ${output_file}

    Log    ✅ Deleted object from JSON and saved to: ${output_file}
    Log    ❌ Removed object at path: ${json_path}

Convert JSON File To String
    [Documentation]    Converts JSON file content to string format
    [Arguments]    ${json_file}

    File Should Exist    ${json_file}
    ${json_data}=    Load Json From File    ${json_file}
    ${json_string}=    Convert Json To String    ${json_data}

    Log    🔄 Converted JSON file to string format
    RETURN    ${json_string}

Create JSON From String
    [Documentation]    Creates JSON object from string and optionally saves to file
    [Arguments]    ${json_string}    ${output_file}=${None}

    ${json_data}=    Convert String To Json    ${json_string}

    IF    '${output_file}' != '${None}'
        Dump Json To File    ${json_data}    ${output_file}
        Log    ✅ Created JSON file from string: ${output_file}
    END

    Log    🔄 Converted string to JSON object
    RETURN    ${json_data}

################## ENHANCED DATA LOADING TEMPLATES ##################

Load CSV Data Template
    [Documentation]    Enhanced template that auto-calculates expected rows from CSV file
    [Arguments]    ${csv_file}    ${table_name}    ${truncate_table}=${TRUE}

    Log    📂 Loading CSV file: ${csv_file}
    Log    🗄️ Target table: ${table_name}
    Log    🗑️ Truncate table: ${truncate_table}

    # Auto-calculate expected rows from CSV file
    ${expected_rows}=    Count Data Rows In CSV    ${csv_file}
    Log    📊 Auto-detected expected rows: ${expected_rows}

    # Load CSV data into database table
    ${result}=    Load CSV To Database Table
    ...    csv_file=${csv_file}
    ...    table_name=${table_name}
    ...    truncate_table=${truncate_table}

    # Verify the test passed using auto-calculated expected rows
    Should Be True    ${result}[success]    CSV loading failed: ${result}[error]
    Should Be True    ${result}[rows_inserted] > 0    No rows were inserted
    Should Be Equal As Numbers
    ...    ${result}[rows_inserted]
    ...    ${expected_rows}
    ...    Expected ${expected_rows} rows but inserted ${result}[rows_inserted]

    IF    ${truncate_table}
        Log    ✅ Successfully loaded ${result}[rows_inserted] rows into ${table_name} table (table was truncated)
    ELSE
        Log    ✅ Successfully appended ${result}[rows_inserted] rows to ${table_name} table (table was not truncated)
    END

Load JSON Data Template
    [Documentation]    Enhanced template that auto-calculates expected rows from JSON file using JSONLibrary
    [Arguments]    ${json_file}    ${table_name}    ${truncate_table}=${TRUE}

    Log    📄 Loading JSON file: ${json_file}
    Log    🗄️ Target table: ${table_name}
    Log    🗑️ Truncate table: ${truncate_table}

    # Auto-calculate expected rows from JSON file - REFACTORED
    ${expected_rows}=    Count Data Rows In JSON    ${json_file}
    Log    📊 Auto-detected expected rows: ${expected_rows}

    # Load JSON data into database table
    ${result}=    Load JSON To Database Table
    ...    json_file=${json_file}
    ...    table_name=${table_name}
    ...    truncate_table=${truncate_table}

    # Verify the test passed using auto-calculated expected rows
    Should Be True    ${result}[success]    JSON loading failed: ${result}[error]
    Should Be True    ${result}[rows_inserted] > 0    No rows were inserted
    Should Be Equal As Numbers
    ...    ${result}[rows_inserted]
    ...    ${expected_rows}
    ...    Expected ${expected_rows} rows but inserted ${result}[rows_inserted]

    IF    ${truncate_table}
        Log    ✅ Successfully loaded ${result}[rows_inserted] rows into ${table_name} table (table was truncated)
    ELSE
        Log    ✅ Successfully appended ${result}[rows_inserted] rows to ${table_name} table (table was not truncated)
    END

################## DATABASE LOADING OPERATIONS ##################

Load CSV To Database Table
    [Documentation]    Loads CSV data into existing database table using associative CSV reading
    [Arguments]    ${csv_file}    ${table_name}    ${truncate_table}=${TRUE}

    # Initialize result
    ${result}=    Create Dictionary    success=${FALSE}    rows_inserted=0    error=${EMPTY}

    TRY
        # Truncate table if requested
        IF    ${truncate_table}
            # Try different TRUNCATE syntaxes based on database type
            ${truncate_success}=    Set Variable    ${FALSE}

            # Try standard TRUNCATE first (works for most databases including Snowflake)
            TRY
                Execute SQL String    TRUNCATE TABLE ${table_name}
                Log    🗑️ Truncated table: ${table_name} (standard syntax)
                ${truncate_success}=    Set Variable    ${TRUE}
            EXCEPT
                # If standard fails, try DB2 syntax with IMMEDIATE
                TRY
                    Execute SQL String    TRUNCATE TABLE ${table_name} IMMEDIATE
                    Log    🗑️ Truncated table: ${table_name} (DB2 syntax with IMMEDIATE)
                    ${truncate_success}=    Set Variable    ${TRUE}
                EXCEPT
                    # If both TRUNCATE attempts fail, fall back to DELETE
                    Log    TRUNCATE failed, falling back to DELETE    level=WARN
                    Execute SQL String    DELETE FROM ${table_name}
                    Log    🗑️ Cleared table using DELETE: ${table_name}
                END
            END
        END

        # Read CSV file as associative data (dictionary format)
        ${csv_data}=    Read Csv File To Associative    ${csv_file}
        Log    📊 Read ${csv_data.__len__()} rows from CSV file

        # Get table columns for validation (use 'public' schema for PostgreSQL)
        ${table_columns}=    Get Table Columns    ${table_name}    schema=public
        Log    🗄️ Table columns: ${table_columns}

        # Insert each row using associative data
        ${inserted_count}=    Set Variable    0
        FOR    ${row_dict}    IN    @{csv_data}
            ${sql}=    Build Insert SQL From Dict    ${table_name}    ${row_dict}    ${table_columns}
            Execute SQL String    ${sql}
            ${inserted_count}=    Evaluate    ${inserted_count} + 1
        END

        # Update result with success
        Set To Dictionary    ${result}    success=${TRUE}    rows_inserted=${inserted_count}
    EXCEPT    AS    ${error}
        Set To Dictionary    ${result}    error=${error}
    END

    RETURN    ${result}

Load JSON To Database Table
    [Documentation]    Loads JSON data into existing database table using JSONLibrary - REFACTORED
    [Arguments]    ${json_file}    ${table_name}    ${truncate_table}=${TRUE}

    # Initialize result
    ${result}=    Create Dictionary    success=${FALSE}    rows_inserted=0    error=${EMPTY}

    TRY
        # Truncate table if requested
        IF    ${truncate_table}
            # Try different TRUNCATE syntaxes based on database type
            ${truncate_success}=    Set Variable    ${FALSE}

            # Try standard TRUNCATE first (works for most databases including Snowflake)
            TRY
                Execute SQL String    TRUNCATE TABLE ${table_name}
                Log    🗑️ Truncated table: ${table_name} (standard syntax)
                ${truncate_success}=    Set Variable    ${TRUE}
            EXCEPT
                # If standard fails, try DB2 syntax with IMMEDIATE
                TRY
                    Execute SQL String    TRUNCATE TABLE ${table_name} IMMEDIATE
                    Log    🗑️ Truncated table: ${table_name} (DB2 syntax with IMMEDIATE)
                    ${truncate_success}=    Set Variable    ${TRUE}
                EXCEPT
                    # If both TRUNCATE attempts fail, fall back to DELETE
                    Log    TRUNCATE failed, falling back to DELETE    level=WARN
                    Execute SQL String    DELETE FROM ${table_name}
                    Log    🗑️ Cleared table using DELETE: ${table_name}
                END
            END
        END

        # Use JSONLibrary to load JSON file - REFACTORED
        ${json_data}=    Load Json From File    ${json_file}
        Log    📊 Read ${json_data.__len__()} rows from JSON file

        # Get table columns for validation (use 'public' schema for PostgreSQL)
        ${table_columns}=    Get Table Columns    ${table_name}    schema=public
        Log    🗄️ Table columns: ${table_columns}

        # Insert each row using JSON data
        ${inserted_count}=    Set Variable    0
        FOR    ${row_dict}    IN    @{json_data}
            ${sql}=    Build Insert SQL From Dict    ${table_name}    ${row_dict}    ${table_columns}
            Execute SQL String    ${sql}
            ${inserted_count}=    Evaluate    ${inserted_count} + 1
        END

        # Update result with success
        Set To Dictionary    ${result}    success=${TRUE}    rows_inserted=${inserted_count}
    EXCEPT    AS    ${error}
        Set To Dictionary    ${result}    error=${error}
    END

    RETURN    ${result}

################## SIMPLIFIED AUTO-LOADING KEYWORDS ##################

Load CSV To Database Auto
    [Documentation]    Simplified CSV loading with automatic row count detection
    [Arguments]    ${csv_file}    ${table_name}    ${truncate}=${TRUE}

    Log    🚀 Auto-loading CSV: ${csv_file} → ${table_name}

    # Get expected count automatically
    ${expected_count}=    Count Data Rows In CSV    ${csv_file}

    # Load using existing keyword
    ${result}=    Load CSV To Database Table
    ...    csv_file=${csv_file}
    ...    table_name=${table_name}
    ...    truncate_table=${truncate}

    # Validate automatically
    Should Be True    ${result}[success]    CSV loading failed: ${result}[error]
    Should Be Equal As Numbers    ${result}[rows_inserted]    ${expected_count}
    ...    Expected ${expected_count} rows but got ${result}[rows_inserted]

    Log    ✅ Successfully loaded ${result}[rows_inserted]/${expected_count} rows

    RETURN    ${result}

Load JSON To Database Auto
    [Documentation]    Simplified JSON loading with automatic row count detection - REFACTORED
    [Arguments]    ${json_file}    ${table_name}    ${truncate}=${TRUE}

    Log    🚀 Auto-loading JSON: ${json_file} → ${table_name}

    # Get expected count automatically using JSONLibrary - REFACTORED
    ${expected_count}=    Count Data Rows In JSON    ${json_file}

    # Load using existing keyword
    ${result}=    Load JSON To Database Table
    ...    json_file=${json_file}
    ...    table_name=${table_name}
    ...    truncate_table=${truncate}

    # Validate automatically
    Should Be True    ${result}[success]    JSON loading failed: ${result}[error]
    Should Be Equal As Numbers    ${result}[rows_inserted]    ${expected_count}
    ...    Expected ${expected_count} rows but got ${result}[rows_inserted]

    Log    ✅ Successfully loaded ${result}[rows_inserted]/${expected_count} rows

    RETURN    ${result}

Load Data File Auto
    [Documentation]    Universal data loader that detects file type and loads automatically
    [Arguments]    ${data_file}    ${table_name}    ${truncate}=${TRUE}

    Log    🎯 Auto-loading data file: ${data_file}

    # Detect file type
    ${file_extension}=    Get File Extension From Path    ${data_file}

    IF    '${file_extension}' == '.csv'
        ${result}=    Load CSV To Database Auto    ${data_file}    ${table_name}    ${truncate}
    ELSE IF    '${file_extension}' == '.json'
        ${result}=    Load JSON To Database Auto    ${data_file}    ${table_name}    ${truncate}
    ELSE
        Fail    Unsupported file type: ${file_extension}
    END

    RETURN    ${result}

################## FILE COMPARISON OPERATIONS ##################

Compare CSV Files Template
    [Documentation]    Template keyword for CSV comparison with validation
    [Arguments]    ${file1_path}    ${file2_path}    ${ignore_order}    ${show_details}    ${expected_status}

    Log    📋 Comparing CSV files with template:
    Log    📁 File 1: ${file1_path}
    Log    📁 File 2: ${file2_path}
    Log    🔄 Ignore Order: ${ignore_order}
    Log    📝 Show Details: ${show_details}
    Log    ✅ Expected Status: ${expected_status}

    # Perform the comparison
    ${comparison_result}=    Compare CSV Files
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ignore_order=${ignore_order}
    ...    show_details=${show_details}

    # Validate the expected status
    Should Be Equal    ${comparison_result}[status]    ${expected_status}
    ...    Expected status '${expected_status}' but got '${comparison_result}[status]'

    # Log success
    Log    ✅ CSV comparison completed successfully - Status: ${comparison_result}[status]
    Log    📈 Total differences found: ${comparison_result}[total_differences]

    RETURN    ${comparison_result}

Compare JSON Files Template
    [Documentation]    Template keyword for JSON comparison with validation
    [Arguments]    ${file1_path}    ${file2_path}    ${ignore_order}    ${show_details}    ${expected_status}

    Log    📄 Comparing JSON files with template:
    Log    📁 File 1: ${file1_path}
    Log    📁 File 2: ${file2_path}
    Log    🔄 Ignore Order: ${ignore_order}
    Log    📝 Show Details: ${show_details}
    Log    ✅ Expected Status: ${expected_status}

    # Perform the comparison
    ${comparison_result}=    Compare JSON Files
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ignore_order=${ignore_order}
    ...    show_details=${show_details}

    # Validate the expected status
    Should Be Equal    ${comparison_result}[status]    ${expected_status}
    ...    Expected status '${expected_status}' but got '${comparison_result}[status]'

    # Log success
    Log    ✅ JSON comparison completed successfully - Status: ${comparison_result}[status]
    Log    📈 Total differences found: ${comparison_result}[total_differences]

    RETURN    ${comparison_result}

Compare CSV Files
    [Documentation]    Compares two CSV files and returns detailed comparison results
    [Arguments]    ${file1_path}    ${file2_path}    ${ignore_order}=${TRUE}    ${show_details}=${TRUE}

    # Read both CSV files
    ${csv1_content}=    Read Csv File To List    ${file1_path}
    ${csv2_content}=    Read Csv File To List    ${file2_path}

    Log    Comparing CSV files:
    Log    File 1: ${file1_path}
    Log    File 2: ${file2_path}

    # Initialize comparison result
    ${comparison_result}=    Create Dictionary
    ...    status=UNKNOWN
    ...    file1_path=${file1_path}
    ...    file2_path=${file2_path}
    ...    file1_rows=${csv1_content.__len__()}
    ...    file2_rows=${csv2_content.__len__()}
    ...    total_differences=0
    ...    headers_match=${FALSE}
    ...    row_count_match=${FALSE}

    # Create empty list for differences
    ${differences_list}=    Create List
    Set To Dictionary    ${comparison_result}    differences    ${differences_list}

    # Compare basic structure
    ${file1_row_count}=    Get Length    ${csv1_content}
    ${file2_row_count}=    Get Length    ${csv2_content}

    IF    ${file1_row_count} == ${file2_row_count}
        Set To Dictionary    ${comparison_result}    row_count_match=${TRUE}
    ELSE
        Set To Dictionary    ${comparison_result}    row_count_match=${FALSE}
        ${diff}=    Create Dictionary
        ...    type=ROW_COUNT_MISMATCH
        ...    file1_count=${file1_row_count}
        ...    file2_count=${file2_row_count}
        Append To List    ${comparison_result}[differences]    ${diff}
    END

    # Compare headers (first row)
    IF    ${file1_row_count} > 0 and ${file2_row_count} > 0
        ${header1}=    Get From List    ${csv1_content}    0
        ${header2}=    Get From List    ${csv2_content}    0
        ${headers_equal}=    Evaluate    $header1 == $header2

        Set To Dictionary    ${comparison_result}    headers_match=${headers_equal}

        IF    not ${headers_equal}
            ${diff}=    Create Dictionary
            ...    type=HEADER_MISMATCH
            ...    file1_header=${header1}
            ...    file2_header=${header2}
            Append To List    ${comparison_result}[differences]    ${diff}
        END
    END

    # Compare data rows
    ${max_rows}=    Evaluate    max(${file1_row_count}, ${file2_row_count})

    FOR    ${row_index}    IN RANGE    1    ${max_rows}    # Skip header row
        ${has_row1}=    Evaluate    ${row_index} < ${file1_row_count}
        ${has_row2}=    Evaluate    ${row_index} < ${file2_row_count}

        IF    ${has_row1} and ${has_row2}
            ${row1}=    Get From List    ${csv1_content}    ${row_index}
            ${row2}=    Get From List    ${csv2_content}    ${row_index}

            ${rows_equal}=    Evaluate    $row1 == $row2

            IF    not ${rows_equal}
                ${diff}=    Create Dictionary
                ...    type=ROW_CONTENT_MISMATCH
                ...    row_index=${row_index}
                ...    file1_row=${row1}
                ...    file2_row=${row2}
                Append To List    ${comparison_result}[differences]    ${diff}

                # Compare individual fields
                ${field_differences}=    Compare Row Fields    ${row1}    ${row2}    ${row_index}
                FOR    ${field_diff}    IN    @{field_differences}
                    Append To List    ${comparison_result}[differences]    ${field_diff}
                END
            END
        ELSE IF    ${has_row1} and not ${has_row2}
            ${row1}=    Get From List    ${csv1_content}    ${row_index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_ROW_IN_FILE1
            ...    row_index=${row_index}
            ...    row_content=${row1}
            Append To List    ${comparison_result}[differences]    ${diff}
        ELSE IF    not ${has_row1} and ${has_row2}
            ${row2}=    Get From List    ${csv2_content}    ${row_index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_ROW_IN_FILE2
            ...    row_index=${row_index}
            ...    row_content=${row2}
            Append To List    ${comparison_result}[differences]    ${diff}
        END
    END

    # If ignore_order is True, also check if rows exist in different order
    IF    ${ignore_order}
        ${unordered_comparison}=    Compare CSV Files Ignore Order    ${csv1_content}    ${csv2_content}
        Set To Dictionary    ${comparison_result}    unordered_match=${unordered_comparison}
    END

    # Set final status
    ${total_diff}=    Get Length    ${comparison_result}[differences]
    Set To Dictionary    ${comparison_result}    total_differences=${total_diff}

    IF    ${total_diff} == 0
        Set To Dictionary    ${comparison_result}    status=IDENTICAL
    ELSE
        Set To Dictionary    ${comparison_result}    status=DIFFERENT
    END

    # Log details if requested
    IF    ${show_details}    Log CSV Comparison Details    ${comparison_result}

    RETURN    ${comparison_result}

Compare JSON Files
    [Documentation]    Compares two JSON files using JSONLibrary - REFACTORED
    [Arguments]    ${file1_path}    ${file2_path}    ${ignore_order}=${TRUE}    ${show_details}=${TRUE}

    # Check if both files exist
    File Should Exist    ${file1_path}
    File Should Exist    ${file2_path}

    Log    Comparing JSON files:
    Log    File 1: ${file1_path}
    Log    File 2: ${file2_path}

    # Initialize comparison result
    ${comparison_result}=    Create Dictionary
    ...    status=UNKNOWN
    ...    file1_path=${file1_path}
    ...    file2_path=${file2_path}
    ...    total_differences=0
    ...    files_match=${FALSE}

    # Create empty list for differences
    ${differences_list}=    Create List
    Set To Dictionary    ${comparison_result}    differences    ${differences_list}

    TRY
        # Use JSONLibrary to load JSON files - REFACTORED
        ${json1_data}=    Load Json From File    ${file1_path}
        ${json2_data}=    Load Json From File    ${file2_path}

        # Compare JSON structures
        ${files_equal}=    Evaluate    $json1_data == $json2_data

        IF    ${files_equal}
            Set To Dictionary    ${comparison_result}    status=IDENTICAL    files_match=${TRUE}
        ELSE
            Set To Dictionary    ${comparison_result}    status=DIFFERENT    files_match=${FALSE}

            # Get detailed differences for arrays
            ${is_array1}=    Evaluate    isinstance($json1_data, list)
            ${is_array2}=    Evaluate    isinstance($json2_data, list)

            IF    ${is_array1} and ${is_array2}
                ${array_differences}=    Compare JSON Arrays    ${json1_data}    ${json2_data}    ${ignore_order}
                FOR    ${diff}    IN    @{array_differences}
                    Append To List    ${comparison_result}[differences]    ${diff}
                END
            ELSE
                # For non-array JSON, create a simple difference entry
                ${diff}=    Create Dictionary
                ...    type=STRUCTURE_MISMATCH
                ...    file1_type=${json1_data.__class__.__name__}
                ...    file2_type=${json2_data.__class__.__name__}
                Append To List    ${comparison_result}[differences]    ${diff}
            END
        END
    EXCEPT    AS    ${error}
        Set To Dictionary    ${comparison_result}    status=ERROR
        ${diff}=    Create Dictionary
        ...    type=PARSE_ERROR
        ...    error=${error}
        Append To List    ${comparison_result}[differences]    ${diff}
    END

    # Set final difference count
    ${total_diff}=    Get Length    ${comparison_result}[differences]
    Set To Dictionary    ${comparison_result}    total_differences=${total_diff}

    # Log details if requested
    IF    ${show_details}    Log JSON Comparison Details    ${comparison_result}

    RETURN    ${comparison_result}

################## CSV COMPARISON WITH EXCLUSIONS ##################

Compare CSV Files With Exclusions
    [Documentation]    Compares two CSV files while excluding specified JSON keys from comparison.
    ...    This is useful when CSV files contain JSON data with dynamic fields like timestamps
    ...    that change between runs (e.g., SnowflakeConnectorPushTime, created_at, updated_at).
    ...
    ...    Arguments:
    ...    ${file1_path}    - Path to the first CSV file (actual output)
    ...    ${file2_path}    - Path to the second CSV file (expected output)
    ...    ${exclude_keys}    - List of JSON keys to exclude from comparison
    ...    Example: @{exclude}=    SnowflakeConnectorPushTime    created_at
    ...    ${ignore_order}    - Whether to ignore row order (default: TRUE)
    ...    ${show_details}    - Whether to show detailed comparison results (default: TRUE)
    ...    ${match_key}    - (Optional) JSON path to use for matching rows between files
    ...    Example: headers.profile_id or entityId
    ...    When provided, rows are matched by this key instead of position/set comparison
    ...
    ...    Returns:
    ...    Dictionary with comparison results including status (IDENTICAL/DIFFERENT)
    ...
    ...    Example Usage (without match_key - uses set-based comparison):
    ...    @{exclude_keys}=    Create List    SnowflakeConnectorPushTime    timestamp
    ...    ${result}=    Compare CSV Files With Exclusions
    ...    ...    ${actual_file}
    ...    ...    ${expected_file}
    ...    ...    ${exclude_keys}
    ...    Should Be Equal    ${result}[status]    IDENTICAL
    ...
    ...    Example Usage (with match_key - matches rows by specific field):
    ...    ${result}=    Compare CSV Files With Exclusions
    ...    ...    ${actual_file}
    ...    ...    ${expected_file}
    ...    ...    ${exclude_keys}
    ...    ...    match_key=headers.profile_id
    ...
    [Arguments]
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${exclude_keys}
    ...    ${ignore_order}=${TRUE}
    ...    ${show_details}=${TRUE}
    ...    ${match_key}=${None}

    # Check if match_key is actually set (not None or string 'None')
    ${is_match_key_set}=    Evaluate    $match_key is not None and str($match_key) != 'None'

    Log    \n🔍 Comparing CSV files with exclusions:    console=yes
    Log    📁 File 1: ${file1_path}    console=yes
    Log    📁 File 2: ${file2_path}    console=yes
    Log    🚫 Excluded keys: ${exclude_keys}    console=yes
    IF    ${is_match_key_set}    Log    🔑 Match Key: ${match_key}    console=yes

    # Read both CSV files
    ${csv1_content}=    Read Csv File To List    ${file1_path}
    ${csv2_content}=    Read Csv File To List    ${file2_path}

    # Normalize both CSV contents by removing excluded keys from JSON fields
    ${normalized_csv1}=    Normalize CSV Content With Exclusions    ${csv1_content}    ${exclude_keys}
    ${normalized_csv2}=    Normalize CSV Content With Exclusions    ${csv2_content}    ${exclude_keys}

    # Initialize comparison result
    ${comparison_result}=    Create Dictionary
    ...    status=UNKNOWN
    ...    file1_path=${file1_path}
    ...    file2_path=${file2_path}
    ...    file1_rows=${csv1_content.__len__()}
    ...    file2_rows=${csv2_content.__len__()}
    ...    excluded_keys=${exclude_keys}
    ...    match_key=${match_key}
    ...    total_differences=0
    ...    headers_match=${FALSE}
    ...    row_count_match=${FALSE}

    # Create empty list for differences
    ${differences_list}=    Create List
    Set To Dictionary    ${comparison_result}    differences    ${differences_list}

    # Compare row counts
    ${file1_row_count}=    Get Length    ${normalized_csv1}
    ${file2_row_count}=    Get Length    ${normalized_csv2}

    IF    ${file1_row_count} == ${file2_row_count}
        Set To Dictionary    ${comparison_result}    row_count_match=${TRUE}
    ELSE
        Set To Dictionary    ${comparison_result}    row_count_match=${FALSE}
        ${diff}=    Create Dictionary
        ...    type=ROW_COUNT_MISMATCH
        ...    file1_count=${file1_row_count}
        ...    file2_count=${file2_row_count}
        Append To List    ${comparison_result}[differences]    ${diff}
    END

    # Compare headers (first row)
    IF    ${file1_row_count} > 0 and ${file2_row_count} > 0
        ${header1}=    Get From List    ${normalized_csv1}    0
        ${header2}=    Get From List    ${normalized_csv2}    0
        ${headers_equal}=    Evaluate    $header1 == $header2

        Set To Dictionary    ${comparison_result}    headers_match=${headers_equal}

        IF    not ${headers_equal}
            ${diff}=    Create Dictionary
            ...    type=HEADER_MISMATCH
            ...    file1_header=${header1}
            ...    file2_header=${header2}
            Append To List    ${comparison_result}[differences]    ${diff}
        END
    END

    # Choose comparison method based on match_key
    IF    ${is_match_key_set}
        # Key-based matching
        Log    🔑 Using key-based matching with key: ${match_key}    console=yes
        IF    not ${ignore_order}
            Log    📍 Row order will also be verified (ignore_order=${FALSE})    console=yes
        END
        ${key_based_differences}=    Compare CSV With Key Matching
        ...    ${normalized_csv1}
        ...    ${normalized_csv2}
        ...    ${match_key}
        ...    ${ignore_order}
        FOR    ${diff}    IN    @{key_based_differences}
            Append To List    ${comparison_result}[differences]    ${diff}
        END
    ELSE
        # Original positional comparison
        ${max_rows}=    Evaluate    max(${file1_row_count}, ${file2_row_count})

        FOR    ${row_index}    IN RANGE    1    ${max_rows}
            ${has_row1}=    Evaluate    ${row_index} < ${file1_row_count}
            ${has_row2}=    Evaluate    ${row_index} < ${file2_row_count}

            IF    ${has_row1} and ${has_row2}
                ${row1}=    Get From List    ${normalized_csv1}    ${row_index}
                ${row2}=    Get From List    ${normalized_csv2}    ${row_index}

                ${rows_equal}=    Evaluate    $row1 == $row2

                IF    not ${rows_equal}
                    ${diff}=    Create Dictionary
                    ...    type=ROW_CONTENT_MISMATCH
                    ...    row_index=${row_index}
                    ...    file1_row=${row1}
                    ...    file2_row=${row2}
                    Append To List    ${comparison_result}[differences]    ${diff}

                    # Compare individual fields for more detail
                    ${field_differences}=    Compare Row Fields With Details    ${row1}    ${row2}    ${row_index}
                    FOR    ${field_diff}    IN    @{field_differences}
                        Append To List    ${comparison_result}[differences]    ${field_diff}
                    END
                END
            ELSE IF    ${has_row1} and not ${has_row2}
                ${row1}=    Get From List    ${normalized_csv1}    ${row_index}
                ${diff}=    Create Dictionary
                ...    type=EXTRA_ROW_IN_FILE1
                ...    row_index=${row_index}
                ...    row_content=${row1}
                Append To List    ${comparison_result}[differences]    ${diff}
            ELSE IF    not ${has_row1} and ${has_row2}
                ${row2}=    Get From List    ${normalized_csv2}    ${row_index}
                ${diff}=    Create Dictionary
                ...    type=EXTRA_ROW_IN_FILE2
                ...    row_index=${row_index}
                ...    row_content=${row2}
                Append To List    ${comparison_result}[differences]    ${diff}
            END
        END

        # If ignore_order is True and no match_key, check unordered comparison
        IF    ${ignore_order}
            ${unordered_match}=    Compare Normalized CSV Ignore Order    ${normalized_csv1}    ${normalized_csv2}
            Set To Dictionary    ${comparison_result}    unordered_match=${unordered_match}

            # If unordered match is True, clear row content differences since order doesn't matter
            IF    ${unordered_match}
                @{structural_differences}=    Create List
                FOR    ${diff}    IN    @{comparison_result}[differences]
                    IF    '${diff}[type]' == 'ROW_COUNT_MISMATCH' or '${diff}[type]' == 'HEADER_MISMATCH'
                        Append To List    ${structural_differences}    ${diff}
                    END
                END
                Set To Dictionary    ${comparison_result}    differences=${structural_differences}
                Log    ℹ️ Rows match when ignoring order - cleared positional differences    console=yes
            END
        END
    END

    # Set final status
    ${total_diff}=    Get Length    ${comparison_result}[differences]
    Set To Dictionary    ${comparison_result}    total_differences=${total_diff}

    IF    ${total_diff} == 0
        Set To Dictionary    ${comparison_result}    status=IDENTICAL
        Log    ✅ Files are IDENTICAL (after excluding: ${exclude_keys})    console=yes
    ELSE
        Set To Dictionary    ${comparison_result}    status=DIFFERENT
        Log    ❌ Files are DIFFERENT - Found ${total_diff} differences    console=yes
    END

    # Log details if requested
    IF    ${show_details}
        Log Comparison With Exclusions Details    ${comparison_result}
    END

    RETURN    ${comparison_result}

Compare CSV Files With Exclusions Template
    [Documentation]    Template keyword for CSV comparison with exclusions and validation
    ...
    ...    Arguments:
    ...    ${file1_path}    - Path to actual output CSV file
    ...    ${file2_path}    - Path to expected output CSV file
    ...    ${ignore_order}    - Whether to ignore row order
    ...    ${show_details}    - Whether to show detailed differences
    ...    ${expected_status} - Expected comparison result (IDENTICAL or DIFFERENT)
    ...    @{exclude_keys}    - (Optional) One or more JSON keys to exclude
    ...    &{options}    - (Optional) Additional options like match_key=headers.profile_id
    ...
    ...    Example Usage - Without match_key (set-based):
    ...    Compare CSV Files With Exclusions Template
    ...    ...    ${actual_file}    ${expected_file}    ${TRUE}    ${TRUE}    IDENTICAL
    ...    ...    SnowflakeConnectorPushTime    event_timestamp
    ...
    ...    Example Usage - With match_key at the end:
    ...    Compare CSV Files With Exclusions Template
    ...    ...    ${actual_file}    ${expected_file}    ${TRUE}    ${TRUE}    IDENTICAL
    ...    ...    SnowflakeConnectorPushTime    event_timestamp    match_key=headers.profile_id
    ...
    [Arguments]
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${ignore_order}
    ...    ${show_details}
    ...    ${expected_status}
    ...    @{exclude_keys}
    ...    &{options}

    # Extract match_key from options (if provided)
    ${match_key}=    Evaluate    $options.get('match_key', None)

    # Check if match_key is actually set (not None or string 'None')
    ${is_match_key_set}=    Evaluate    $match_key is not None and str($match_key) != 'None'

    Log    📋 Comparing CSV files with exclusions template:    console=yes
    Log    📁 File 1 (Actual): ${file1_path}    console=yes
    Log    📁 File 2 (Expected): ${file2_path}    console=yes
    Log    🚫 Excluded Keys: ${exclude_keys}    console=yes
    Log    🔄 Ignore Order: ${ignore_order}    console=yes
    Log    📝 Show Details: ${show_details}    console=yes
    Log    ✅ Expected Status: ${expected_status}    console=yes
    IF    ${is_match_key_set}    Log    🔑 Match Key: ${match_key}    console=yes

    # Perform the comparison with exclusions
    ${comparison_result}=    Compare CSV Files With Exclusions
    ...    ${file1_path}
    ...    ${file2_path}
    ...    ${exclude_keys}
    ...    ignore_order=${ignore_order}
    ...    show_details=${show_details}
    ...    match_key=${match_key}

    # Validate the expected status
    Should Be Equal
    ...    ${comparison_result}[status]
    ...    ${expected_status}
    ...    Expected status '${expected_status}' but got '${comparison_result}[status]'

    Log    ✅ CSV comparison with exclusions completed - Status: ${comparison_result}[status]    console=yes
    Log    📈 Total differences found: ${comparison_result}[total_differences]    console=yes

    RETURN    ${comparison_result}

Normalize CSV Content With Exclusions
    [Documentation]    Normalizes CSV content by removing specified keys from JSON fields.
    ...    Parses each field that looks like JSON and removes the excluded keys.
    [Arguments]    ${csv_content}    ${exclude_keys}

    @{normalized_content}=    Create List

    FOR    ${row}    IN    @{csv_content}
        @{normalized_row}=    Create List
        FOR    ${field}    IN    @{row}
            ${normalized_field}=    Normalize Field With Exclusions    ${field}    ${exclude_keys}
            Append To List    ${normalized_row}    ${normalized_field}
        END
        Append To List    ${normalized_content}    ${normalized_row}
    END

    RETURN    ${normalized_content}

Normalize Field With Exclusions
    [Documentation]    Normalizes a single field by removing excluded keys if it's JSON.
    ...    Returns the original field if it's not valid JSON.
    ...    Uses pure Python for reliable JSON handling.
    ...    Handles CSV-style escaped quotes ("") by converting to standard JSON escaping.
    [Arguments]    ${field}    ${exclude_keys}

    # Check if field looks like JSON
    ${trimmed}=    Strip String    ${field}

    # Handle CSV-style quoted JSON: remove outer quotes if present
    ${clean}=    Remove CSV Outer Quotes    ${trimmed}

    ${starts_with_brace}=    Evaluate    '''${clean}'''.startswith('{')
    ${ends_with_brace}=    Evaluate    '''${clean}'''.endswith('}')
    ${starts_with_bracket}=    Evaluate    '''${clean}'''.startswith('[')
    ${ends_with_bracket}=    Evaluate    '''${clean}'''.endswith(']')

    ${is_json_object}=    Evaluate    ${starts_with_brace} and ${ends_with_brace}
    ${is_json_array}=    Evaluate    ${starts_with_bracket} and ${ends_with_bracket}

    IF    not (${is_json_object} or ${is_json_array})    RETURN    ${field}

    # Parse JSON, remove keys, and serialize back
    TRY
        # Convert CSV-style escaped quotes ("") to standard JSON escaping (\")
        ${json_str}=    Replace String    ${clean}    ""    \\"
        ${json_data}=    Evaluate    json.loads(r'''${json_str}''')    modules=json
        ${cleaned_data}=    Remove Keys From Dict Recursive    ${json_data}    ${exclude_keys}
        ${result}=    Evaluate    json.dumps($cleaned_data, sort_keys=True)    modules=json
        RETURN    ${result}
    EXCEPT    AS    ${error}
        Log    JSON normalization failed for field: ${error}    level=WARN
        RETURN    ${field}
    END

Remove CSV Outer Quotes
    [Documentation]    Removes outer quotes from CSV-style quoted JSON fields.
    ...    CSV files often wrap JSON in quotes: "{""key"":""value""}"
    ...    This keyword strips those outer quotes to get: {""key"":""value""}
    [Arguments]    ${field}

    ${length}=    Get Length    ${field}

    # Check if field starts and ends with a quote
    IF    ${length} < 2    RETURN    ${field}

    ${first_char}=    Evaluate    '''${field}'''[0]
    ${last_char}=    Evaluate    '''${field}'''[-1]

    IF    '${first_char}' == '"' and '${last_char}' == '"'
        # Remove outer quotes
        ${stripped}=    Evaluate    '''${field}'''[1:-1]
        RETURN    ${stripped}
    END

    RETURN    ${field}

Remove Keys From Dict Recursive
    [Documentation]    Recursively removes specified keys from a dictionary or list.
    ...    Handles nested structures.
    [Arguments]    ${data}    ${exclude_keys}

    # Build lowercase exclude set
    @{exclude_lower}=    Create List
    FOR    ${key}    IN    @{exclude_keys}
        ${lower}=    Convert To Lower Case    ${key}
        Append To List    ${exclude_lower}    ${lower}
    END

    ${result}=    Process Data Structure    ${data}    ${exclude_lower}
    RETURN    ${result}

Process Data Structure
    [Documentation]    Processes a data structure recursively to remove excluded keys
    [Arguments]    ${data}    ${exclude_keys_lower}

    ${is_dict}=    Evaluate    isinstance($data, dict)
    ${is_list}=    Evaluate    isinstance($data, list)

    IF    ${is_dict}
        &{new_dict}=    Create Dictionary
        FOR    ${key}    IN    @{data.keys()}
            ${key_lower}=    Convert To Lower Case    ${key}
            ${should_exclude}=    Evaluate    '''${key_lower}''' in $exclude_keys_lower
            IF    not ${should_exclude}
                ${value}=    Set Variable    ${data}[${key}]
                ${processed_value}=    Process Data Structure    ${value}    ${exclude_keys_lower}
                Set To Dictionary    ${new_dict}    ${key}=${processed_value}
            END
        END
        RETURN    ${new_dict}
    ELSE IF    ${is_list}
        @{new_list}=    Create List
        FOR    ${item}    IN    @{data}
            ${processed_item}=    Process Data Structure    ${item}    ${exclude_keys_lower}
            Append To List    ${new_list}    ${processed_item}
        END
        RETURN    ${new_list}
    ELSE
        RETURN    ${data}
    END

Remove Keys From JSON Recursive
    [Documentation]    DEPRECATED - Use Remove Keys From Dict Recursive instead.
    ...    Kept for backward compatibility.
    [Arguments]    ${json_data}    ${exclude_keys}

    ${result}=    Remove Keys From Dict Recursive    ${json_data}    ${exclude_keys}
    RETURN    ${result}

Compare Normalized CSV Ignore Order
    [Documentation]    Compares normalized CSV content ignoring row order
    [Arguments]    ${csv1_content}    ${csv2_content}

    # Skip headers and compare data rows only
    ${data1}=    Get Slice From List    ${csv1_content}    1
    ${data2}=    Get Slice From List    ${csv2_content}    1

    # Convert to sets for comparison
    ${data1_str}=    Evaluate    [str(row) for row in $data1]
    ${data2_str}=    Evaluate    [str(row) for row in $data2]

    ${set1}=    Evaluate    set($data1_str)
    ${set2}=    Evaluate    set($data2_str)

    ${sets_equal}=    Evaluate    $set1 == $set2

    RETURN    ${sets_equal}

################## KEY-BASED ROW MATCHING ##################

Compare CSV With Key Matching
    [Documentation]    Compares CSV rows by matching them using a specific key field.
    ...    Instead of comparing by position, rows are matched by the value of the match_key.
    ...    This allows comparing files where rows may be in different order but should match by ID.
    ...    When ignore_order=${FALSE}, also verifies that matched rows are at the same position.
    [Arguments]    ${csv1_content}    ${csv2_content}    ${match_key}    ${ignore_order}=${TRUE}

    ${differences}=    Create List

    # Skip headers - get data rows only
    ${data1}=    Get Slice From List    ${csv1_content}    1
    ${data2}=    Get Slice From List    ${csv2_content}    1

    # Build lookup dictionaries by match_key (now includes row index)
    ${file1_by_key}=    Build Row Lookup By Key    ${data1}    ${match_key}
    ${file2_by_key}=    Build Row Lookup By Key    ${data2}    ${match_key}

    # Get all unique keys from both files
    ${all_keys}=    Evaluate    set($file1_by_key.keys()) | set($file2_by_key.keys())

    # Compare rows by key
    FOR    ${key_value}    IN    @{all_keys}
        ${in_file1}=    Evaluate    '''${key_value}''' in $file1_by_key
        ${in_file2}=    Evaluate    '''${key_value}''' in $file2_by_key

        IF    ${in_file1} and ${in_file2}
            # Both files have this key - get row info (includes index)
            ${row_info1}=    Get From Dictionary    ${file1_by_key}    ${key_value}
            ${row_info2}=    Get From Dictionary    ${file2_by_key}    ${key_value}

            ${row1}=    Get From Dictionary    ${row_info1}    row
            ${row2}=    Get From Dictionary    ${row_info2}    row
            ${index1}=    Get From Dictionary    ${row_info1}    index
            ${index2}=    Get From Dictionary    ${row_info2}    index

            # Check row order if ignore_order is FALSE
            IF    not ${ignore_order}
                IF    ${index1} != ${index2}
                    ${diff}=    Create Dictionary
                    ...    type=ROW_ORDER_MISMATCH
                    ...    match_key=${match_key}
                    ...    key_value=${key_value}
                    ...    file1_position=${index1}
                    ...    file2_position=${index2}
                    Append To List    ${differences}    ${diff}
                END
            END

            # Compare row content
            ${rows_equal}=    Evaluate    $row1 == $row2

            IF    not ${rows_equal}
                # Get detailed field differences
                ${field_diffs}=    Compare Matched Rows    ${row1}    ${row2}    ${match_key}    ${key_value}
                FOR    ${diff}    IN    @{field_diffs}
                    Append To List    ${differences}    ${diff}
                END
            END
        ELSE IF    ${in_file1} and not ${in_file2}
            # Row only in file1 (actual)
            ${row_info1}=    Get From Dictionary    ${file1_by_key}    ${key_value}
            ${row1}=    Get From Dictionary    ${row_info1}    row
            ${diff}=    Create Dictionary
            ...    type=UNMATCHED_ROW_IN_FILE1
            ...    match_key=${match_key}
            ...    key_value=${key_value}
            ...    row_content=${row1}
            Append To List    ${differences}    ${diff}
        ELSE IF    not ${in_file1} and ${in_file2}
            # Row only in file2 (expected)
            ${row_info2}=    Get From Dictionary    ${file2_by_key}    ${key_value}
            ${row2}=    Get From Dictionary    ${row_info2}    row
            ${diff}=    Create Dictionary
            ...    type=UNMATCHED_ROW_IN_FILE2
            ...    match_key=${match_key}
            ...    key_value=${key_value}
            ...    row_content=${row2}
            Append To List    ${differences}    ${diff}
        END
    END

    RETURN    ${differences}

Build Row Lookup By Key
    [Documentation]    Builds a dictionary mapping match_key values to their rows and positions.
    ...    Searches all columns (which may contain JSON) for the match_key.
    ...    Fails with clear error if match_key is not found in all rows.
    ...    Returns: {key_value: {"row": row_data, "index": row_index}}
    [Arguments]    ${rows}    ${match_key}

    &{lookup}=    Create Dictionary
    ${keys_found}=    Set Variable    ${0}
    ${total_rows}=    Get Length    ${rows}
    ${row_index}=    Set Variable    ${0}

    FOR    ${row}    IN    @{rows}
        ${key_value}=    Extract Key Value From Row    ${row}    ${match_key}
        IF    '${key_value}' != '${None}'
            # Store both row data and its index
            &{row_info}=    Create Dictionary    row=${row}    index=${row_index}
            Set To Dictionary    ${lookup}    ${key_value}=${row_info}
            ${keys_found}=    Evaluate    ${keys_found} + 1
        END
        ${row_index}=    Evaluate    ${row_index} + 1
    END

    # Fail if no keys found in any row
    IF    ${keys_found} == 0
        Fail
        ...    ❌ match_key '${match_key}' not found in any row. Please check:\n
        ...    1. Is the field name correct?\n
        ...    2. Is it nested? Use dot notation: headers.profile_id\n
        ...    3. Does the field exist in your CSV data?
    END

    # Fail if match_key not found in all rows (partial match = incomplete comparison)
    IF    ${keys_found} < ${total_rows}
        ${missing_count}=    Evaluate    ${total_rows} - ${keys_found}
        Fail
        ...    ❌ match_key '${match_key}' not found in ${missing_count} of ${total_rows} rows.\n
        ...    All rows must contain the match_key for accurate comparison.\n
        ...    Rows without match_key will not be compared, leading to incorrect results.
    END

    RETURN    ${lookup}

Extract Key Value From Row
    [Documentation]    Extracts the value of a key from a CSV row.
    ...    The key can be a simple key or a nested path like "headers.profile_id".
    ...    Searches through all columns (which may contain JSON).
    [Arguments]    ${row}    ${match_key}

    # Split the match_key into parts (e.g., "headers.profile_id" -> ["headers", "profile_id"])
    ${key_parts}=    Split String    ${match_key}    .

    # Search each field in the row
    FOR    ${field}    IN    @{row}
        ${value}=    Extract Value From Field    ${field}    ${key_parts}
        IF    '${value}' != '${None}'    RETURN    ${value}
    END

    RETURN    ${None}

Extract Value From Field
    [Documentation]    Extracts a value from a field using the key path.
    ...    Handles JSON fields and nested paths.
    [Arguments]    ${field}    ${key_parts}

    ${trimmed}=    Strip String    ${field}
    ${clean}=    Remove CSV Outer Quotes    ${trimmed}

    # Check if field looks like JSON
    ${is_json}=    Evaluate    '''${clean}'''.startswith('{') and '''${clean}'''.endswith('}')

    IF    not ${is_json}    RETURN    ${None}

    TRY
        # Parse JSON
        ${json_str}=    Replace String    ${clean}    ""    \\"
        ${data}=    Evaluate    json.loads(r'''${json_str}''')    modules=json

        # Navigate to the value using key_parts
        ${current}=    Set Variable    ${data}
        FOR    ${key}    IN    @{key_parts}
            ${is_dict}=    Evaluate    isinstance($current, dict)
            IF    not ${is_dict}    RETURN    ${None}

            ${has_key}=    Evaluate    '''${key}''' in $current
            IF    not ${has_key}    RETURN    ${None}

            ${current}=    Evaluate    $current.get('''${key}''')
        END

        # Convert to string for consistent comparison
        ${result}=    Convert To String    ${current}
        RETURN    ${result}
    EXCEPT
        RETURN    ${None}
    END

Compare Matched Rows
    [Documentation]    Compares two rows that were matched by key and returns field differences.
    [Arguments]    ${row1}    ${row2}    ${match_key}    ${key_value}

    ${differences}=    Create List
    ${max_fields}=    Evaluate    max(len($row1), len($row2))

    FOR    ${field_index}    IN RANGE    ${max_fields}
        ${has_field1}=    Evaluate    ${field_index} < len($row1)
        ${has_field2}=    Evaluate    ${field_index} < len($row2)

        IF    ${has_field1} and ${has_field2}
            ${field1}=    Get From List    ${row1}    ${field_index}
            ${field2}=    Get From List    ${row2}    ${field_index}

            IF    '${field1}' != '${field2}'
                # Get JSON field differences for detailed reporting
                ${json_diffs}=    Get JSON Field Differences    ${field1}    ${field2}

                ${diff}=    Create Dictionary
                ...    type=FIELD_VALUE_MISMATCH
                ...    match_key=${match_key}
                ...    key_value=${key_value}
                ...    field_index=${field_index}
                ...    file1_value=${field1}
                ...    file2_value=${field2}
                ...    json_key_differences=${json_diffs}

                Append To List    ${differences}    ${diff}
            END
        END
    END

    RETURN    ${differences}

Compare Row Fields With Details
    [Documentation]    Compares individual fields between two rows and returns detailed differences.
    ...    For JSON fields, it shows the specific keys that differ.
    [Arguments]    ${row1}    ${row2}    ${row_index}

    ${field_differences}=    Create List
    ${max_fields}=    Evaluate    max(len($row1), len($row2))

    FOR    ${field_index}    IN RANGE    ${max_fields}
        ${has_field1}=    Evaluate    ${field_index} < len($row1)
        ${has_field2}=    Evaluate    ${field_index} < len($row2)

        IF    ${has_field1} and ${has_field2}
            ${field1}=    Get From List    ${row1}    ${field_index}
            ${field2}=    Get From List    ${row2}    ${field_index}

            IF    '${field1}' != '${field2}'
                ${diff}=    Create Dictionary
                ...    type=FIELD_VALUE_MISMATCH
                ...    row_index=${row_index}
                ...    field_index=${field_index}
                ...    file1_value=${field1}
                ...    file2_value=${field2}

                # Check if both fields are JSON and get specific key differences
                ${json_diff}=    Get JSON Field Differences    ${field1}    ${field2}
                Set To Dictionary    ${diff}    json_key_differences=${json_diff}

                Append To List    ${field_differences}    ${diff}
            END
        ELSE IF    ${has_field1} and not ${has_field2}
            ${field1}=    Get From List    ${row1}    ${field_index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_FIELD_IN_FILE1
            ...    row_index=${row_index}
            ...    field_index=${field_index}
            ...    field_value=${field1}
            Append To List    ${field_differences}    ${diff}
        ELSE IF    not ${has_field1} and ${has_field2}
            ${field2}=    Get From List    ${row2}    ${field_index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_FIELD_IN_FILE2
            ...    row_index=${row_index}
            ...    field_index=${field_index}
            ...    field_value=${field2}
            Append To List    ${field_differences}    ${diff}
        END
    END

    RETURN    ${field_differences}

Get JSON Field Differences
    [Documentation]    Compares two JSON/dict strings and returns the specific keys that differ.
    ...    Recursively compares nested objects to find leaf-level differences.
    [Arguments]    ${field1}    ${field2}

    ${differences}=    Create List

    ${trimmed1}=    Strip String    ${field1}
    ${trimmed2}=    Strip String    ${field2}

    ${clean1}=    Remove CSV Outer Quotes    ${trimmed1}
    ${clean2}=    Remove CSV Outer Quotes    ${trimmed2}

    ${is_dict1}=    Evaluate    '''${clean1}'''.startswith('{') and '''${clean1}'''.endswith('}')
    ${is_dict2}=    Evaluate    '''${clean2}'''.startswith('{') and '''${clean2}'''.endswith('}')

    IF    not (${is_dict1} and ${is_dict2})    RETURN    ${differences}

    TRY
        # Try ast.literal_eval first (handles Python dict format with single quotes)
        ${dict1}=    Evaluate    ast.literal_eval(r'''${clean1}''')    modules=ast
        ${dict2}=    Evaluate    ast.literal_eval(r'''${clean2}''')    modules=ast
        ${differences}=    Find Nested Differences    ${dict1}    ${dict2}    ${EMPTY}
    EXCEPT
        TRY
            # Fall back to JSON parsing
            ${json_str1}=    Replace String    ${clean1}    ""    \\"
            ${json_str2}=    Replace String    ${clean2}    ""    \\"
            ${dict1}=    Evaluate    json.loads(r'''${json_str1}''')    modules=json
            ${dict2}=    Evaluate    json.loads(r'''${json_str2}''')    modules=json
            ${differences}=    Find Nested Differences    ${dict1}    ${dict2}    ${EMPTY}
        EXCEPT    AS    ${error}
            Log    Could not parse for detailed comparison: ${error}    level=WARN
        END
    END

    RETURN    ${differences}

Find Nested Differences
    [Documentation]    Recursively compares two dictionaries and returns leaf-level differences.
    [Arguments]    ${dict1}    ${dict2}    ${parent_key}

    ${differences}=    Create List

    # Get all keys from both dicts
    ${all_keys}=    Evaluate
    ...    set($dict1.keys() if isinstance($dict1, dict) else []) | set($dict2.keys() if isinstance($dict2, dict) else [])

    FOR    ${key}    IN    @{all_keys}
        # Build the full key path
        IF    '${parent_key}' == ''
            ${full_key}=    Set Variable    ${key}
        ELSE
            ${full_key}=    Set Variable    ${parent_key}.${key}
        END

        ${has_key1}=    Evaluate    '''${key}''' in $dict1 if isinstance($dict1, dict) else False
        ${has_key2}=    Evaluate    '''${key}''' in $dict2 if isinstance($dict2, dict) else False

        IF    ${has_key1} and ${has_key2}
            ${val1}=    Evaluate    $dict1.get('''${key}''')
            ${val2}=    Evaluate    $dict2.get('''${key}''')

            # Check if both values are dicts - recurse if so
            ${is_dict1}=    Evaluate    isinstance($val1, dict)
            ${is_dict2}=    Evaluate    isinstance($val2, dict)

            IF    ${is_dict1} and ${is_dict2}
                # Recursively compare nested dicts
                ${nested_diffs}=    Find Nested Differences    ${val1}    ${val2}    ${full_key}
                FOR    ${nested_diff}    IN    @{nested_diffs}
                    Append To List    ${differences}    ${nested_diff}
                END
            ELSE
                # Compare leaf values
                ${values_equal}=    Evaluate    $val1 == $val2
                IF    not ${values_equal}
                    ${diff_entry}=    Create Dictionary
                    ...    key=${full_key}
                    ...    file1_value=${val1}
                    ...    file2_value=${val2}
                    Append To List    ${differences}    ${diff_entry}
                END
            END
        ELSE IF    ${has_key1} and not ${has_key2}
            ${val1}=    Evaluate    $dict1.get('''${key}''')
            ${diff_entry}=    Create Dictionary
            ...    key=${full_key}
            ...    status=ONLY_IN_FILE1
            ...    file1_value=${val1}
            Append To List    ${differences}    ${diff_entry}
        ELSE IF    not ${has_key1} and ${has_key2}
            ${val2}=    Evaluate    $dict2.get('''${key}''')
            ${diff_entry}=    Create Dictionary
            ...    key=${full_key}
            ...    status=ONLY_IN_FILE2
            ...    file2_value=${val2}
            Append To List    ${differences}    ${diff_entry}
        END
    END

    RETURN    ${differences}

Log Comparison With Exclusions Details
    [Documentation]    Logs detailed comparison results for CSV comparison with exclusions.
    ...    Handles JSON fields, simple fields, key-based matching, and structural differences.
    ...    Updates status to IDENTICAL if no unique differences found.
    [Arguments]    ${comparison_result}

    # Check if match_key was used
    ${has_match_key}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key    ${comparison_result}    match_key
    ${match_key}=    Set Variable    ${None}
    IF    ${has_match_key}
        ${match_key}=    Get From Dictionary    ${comparison_result}    match_key
    END

    # Count unique field differences first
    @{unique_keys}=    Create List
    FOR    ${diff}    IN    @{comparison_result}[differences]
        IF    '${diff}[type]' == 'FIELD_VALUE_MISMATCH'
            ${has_json_diff}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key    ${diff}    json_key_differences
            IF    ${has_json_diff}
                ${json_diffs}=    Get From Dictionary    ${diff}    json_key_differences
                ${json_diff_count}=    Get Length    ${json_diffs}
                IF    ${json_diff_count} > 0
                    FOR    ${json_diff}    IN    @{json_diffs}
                        ${key}=    Get From Dictionary    ${json_diff}    key
                        ${exists}=    Evaluate    '''${key}''' in $unique_keys
                        IF    not ${exists}
                            Append To List    ${unique_keys}    ${key}
                        END
                    END
                ELSE
                    # Simple field (non-JSON) - count by row_index.field_index or key_value.field_index
                    ${has_key_value}=    Run Keyword And Return Status
                    ...    Dictionary Should Contain Key    ${diff}    key_value
                    IF    ${has_key_value}
                        ${field_key}=    Set Variable    ${diff}[key_value]_Field${diff}[field_index]
                    ELSE
                        ${field_key}=    Set Variable    Row${diff}[row_index]_Field${diff}[field_index]
                    END
                    ${exists}=    Evaluate    '''${field_key}''' in $unique_keys
                    IF    not ${exists}
                        Append To List    ${unique_keys}    ${field_key}
                    END
                END
            ELSE
                # No json_key_differences key - simple field
                ${has_key_value}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${diff}    key_value
                IF    ${has_key_value}
                    ${field_key}=    Set Variable    ${diff}[key_value]_Field${diff}[field_index]
                ELSE
                    ${field_key}=    Set Variable    Row${diff}[row_index]_Field${diff}[field_index]
                END
                ${exists}=    Evaluate    '''${field_key}''' in $unique_keys
                IF    not ${exists}
                    Append To List    ${unique_keys}    ${field_key}
                END
            END
        ELSE IF    '${diff}[type]' == 'ROW_COUNT_MISMATCH'
            ${exists}=    Evaluate    'ROW_COUNT' in $unique_keys
            IF    not ${exists}    Append To List    ${unique_keys}    ROW_COUNT
        ELSE IF    '${diff}[type]' == 'HEADER_MISMATCH'
            ${exists}=    Evaluate    'HEADERS' in $unique_keys
            IF    not ${exists}    Append To List    ${unique_keys}    HEADERS
        ELSE IF    '${diff}[type]' == 'EXTRA_ROW_IN_FILE1'
            ${row_key}=    Set Variable    EXTRA_ROW_ACTUAL_${diff}[row_index]
            ${exists}=    Evaluate    '''${row_key}''' in $unique_keys
            IF    not ${exists}
                Append To List    ${unique_keys}    ${row_key}
            END
        ELSE IF    '${diff}[type]' == 'EXTRA_ROW_IN_FILE2'
            ${row_key}=    Set Variable    EXTRA_ROW_EXPECTED_${diff}[row_index]
            ${exists}=    Evaluate    '''${row_key}''' in $unique_keys
            IF    not ${exists}
                Append To List    ${unique_keys}    ${row_key}
            END
        ELSE IF    '${diff}[type]' == 'EXTRA_FIELD_IN_FILE1'
            ${field_key}=    Set Variable    EXTRA_FIELD_ACTUAL_Row${diff}[row_index]_Field${diff}[field_index]
            ${exists}=    Evaluate    '''${field_key}''' in $unique_keys
            IF    not ${exists}
                Append To List    ${unique_keys}    ${field_key}
            END
        ELSE IF    '${diff}[type]' == 'EXTRA_FIELD_IN_FILE2'
            ${field_key}=    Set Variable    EXTRA_FIELD_EXPECTED_Row${diff}[row_index]_Field${diff}[field_index]
            ${exists}=    Evaluate    '''${field_key}''' in $unique_keys
            IF    not ${exists}
                Append To List    ${unique_keys}    ${field_key}
            END
        ELSE IF    '${diff}[type]' == 'UNMATCHED_ROW_IN_FILE1'
            ${row_key}=    Set Variable    UNMATCHED_ACTUAL_${diff}[key_value]
            ${exists}=    Evaluate    '''${row_key}''' in $unique_keys
            IF    not ${exists}
                Append To List    ${unique_keys}    ${row_key}
            END
        ELSE IF    '${diff}[type]' == 'UNMATCHED_ROW_IN_FILE2'
            ${row_key}=    Set Variable    UNMATCHED_EXPECTED_${diff}[key_value]
            ${exists}=    Evaluate    '''${row_key}''' in $unique_keys
            IF    not ${exists}
                Append To List    ${unique_keys}    ${row_key}
            END
        ELSE IF    '${diff}[type]' == 'ROW_ORDER_MISMATCH'
            ${order_key}=    Set Variable    ORDER_MISMATCH_${diff}[key_value]
            ${exists}=    Evaluate    '''${order_key}''' in $unique_keys
            IF    not ${exists}
                Append To List    ${unique_keys}    ${order_key}
            END
        END
        # Skip ROW_CONTENT_MISMATCH - it's a parent-level diff, details are in FIELD_VALUE_MISMATCH
    END
    ${unique_count}=    Get Length    ${unique_keys}

    # Update status based on unique differences count
    IF    ${unique_count} == 0
        Set To Dictionary    ${comparison_result}    status=IDENTICAL
        Set To Dictionary    ${comparison_result}    total_differences=0
    ELSE
        Set To Dictionary    ${comparison_result}    total_differences=${unique_count}
    END

    Log    \n========== CSV COMPARISON SUMMARY ==========    console=yes
    Log    Status: ${comparison_result}[status]    console=yes
    # Check if match_key is actually set (not None or string 'None')
    ${is_match_key_set}=    Evaluate    $match_key is not None and str($match_key) != 'None'
    IF    ${is_match_key_set}    Log    Match Key: ${match_key}    console=yes
    Log    Excluded Keys: ${comparison_result}[excluded_keys]    console=yes
    Log    Unique Field Differences: ${unique_count}    console=yes

    IF    ${unique_count} > 0
        Log    \nFIELD DIFFERENCES:    console=yes

        @{logged_keys}=    Create List

        FOR    ${diff}    IN    @{comparison_result}[differences]
            IF    '${diff}[type]' == 'FIELD_VALUE_MISMATCH'
                ${has_json_diff}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${diff}    json_key_differences

                ${json_diff_count}=    Set Variable    0
                IF    ${has_json_diff}
                    ${json_diffs}=    Get From Dictionary    ${diff}    json_key_differences
                    ${json_diff_count}=    Get Length    ${json_diffs}
                END

                # Check if this is from key-based matching
                ${has_key_value}=    Run Keyword And Return Status
                ...    Dictionary Should Contain Key    ${diff}    key_value

                IF    ${json_diff_count} > 0
                    # JSON field - show nested key differences
                    FOR    ${json_diff}    IN    @{json_diffs}
                        ${key}=    Get From Dictionary    ${json_diff}    key

                        ${already_logged}=    Evaluate    '''${key}''' in $logged_keys
                        IF    ${already_logged}    CONTINUE

                        Append To List    ${logged_keys}    ${key}

                        ${has_status}=    Run Keyword And Return Status
                        ...    Dictionary Should Contain Key    ${json_diff}    status

                        # Log context for key-based matching
                        IF    ${has_key_value}
                            Log    \nMatched Row (${diff}[match_key] = ${diff}[key_value]):    console=yes
                        END

                        IF    ${has_status}
                            ${status}=    Get From Dictionary    ${json_diff}    status
                            IF    '${status}' == 'ONLY_IN_FILE1'
                                ${val1}=    Get From Dictionary    ${json_diff}    file1_value
                                Log    Field: ${key}    console=yes
                                Log    Actual: ${val1}    console=yes
                                Log    Expected: (not present)    console=yes
                            ELSE IF    '${status}' == 'ONLY_IN_FILE2'
                                ${val2}=    Get From Dictionary    ${json_diff}    file2_value
                                Log    Field: ${key}    console=yes
                                Log    Actual: (not present)    console=yes
                                Log    Expected: ${val2}    console=yes
                            END
                        ELSE
                            ${val1}=    Get From Dictionary    ${json_diff}    file1_value
                            ${val2}=    Get From Dictionary    ${json_diff}    file2_value
                            Log    Field: ${key}    console=yes
                            Log    Actual: ${val1}    console=yes
                            Log    Expected: ${val2}    console=yes
                        END
                    END
                ELSE
                    # Simple field - show row/field difference
                    IF    ${has_key_value}
                        ${field_key}=    Set Variable    ${diff}[key_value]_Field${diff}[field_index]
                    ELSE
                        ${field_key}=    Set Variable    Row${diff}[row_index]_Field${diff}[field_index]
                    END
                    ${already_logged}=    Evaluate    '''${field_key}''' in $logged_keys
                    IF    not ${already_logged}
                        Append To List    ${logged_keys}    ${field_key}
                        IF    ${has_key_value}
                            Log
                            ...    \nMatched Row (${diff}[match_key] = ${diff}[key_value]), Field: ${diff}[field_index]
                            ...    console=yes
                        ELSE
                            Log    \nRow: ${diff}[row_index], Field: ${diff}[field_index]    console=yes
                        END
                        Log    Actual: ${diff}[file1_value]    console=yes
                        Log    Expected: ${diff}[file2_value]    console=yes
                    END
                END
            ELSE IF    '${diff}[type]' == 'ROW_COUNT_MISMATCH'
                ${already_logged}=    Evaluate    'ROW_COUNT' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ROW_COUNT
                    Log    \nRow Count Mismatch    console=yes
                    Log    Actual: ${diff}[file1_count] rows    console=yes
                    Log    Expected: ${diff}[file2_count] rows    console=yes
                END
            ELSE IF    '${diff}[type]' == 'HEADER_MISMATCH'
                ${already_logged}=    Evaluate    'HEADERS' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    HEADERS
                    Log    \nHeader Mismatch    console=yes
                    Log    Actual: ${diff}[file1_header]    console=yes
                    Log    Expected: ${diff}[file2_header]    console=yes
                END
            ELSE IF    '${diff}[type]' == 'EXTRA_ROW_IN_FILE1'
                ${row_key}=    Set Variable    EXTRA_ROW_ACTUAL_${diff}[row_index]
                ${already_logged}=    Evaluate    '''${row_key}''' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ${row_key}
                    Log    \nExtra Row in Actual (Row ${diff}[row_index])    console=yes
                    Log    Content: ${diff}[row_content]    console=yes
                END
            ELSE IF    '${diff}[type]' == 'EXTRA_ROW_IN_FILE2'
                ${row_key}=    Set Variable    EXTRA_ROW_EXPECTED_${diff}[row_index]
                ${already_logged}=    Evaluate    '''${row_key}''' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ${row_key}
                    Log    \nMissing Row (Expected Row ${diff}[row_index])    console=yes
                    Log    Content: ${diff}[row_content]    console=yes
                END
            ELSE IF    '${diff}[type]' == 'EXTRA_FIELD_IN_FILE1'
                ${field_key}=    Set Variable    EXTRA_FIELD_ACTUAL_Row${diff}[row_index]_Field${diff}[field_index]
                ${already_logged}=    Evaluate    '''${field_key}''' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ${field_key}
                    Log    \nExtra Field in Actual (Row ${diff}[row_index], Field ${diff}[field_index])    console=yes
                    Log    Value: ${diff}[field_value]    console=yes
                END
            ELSE IF    '${diff}[type]' == 'EXTRA_FIELD_IN_FILE2'
                ${field_key}=    Set Variable    EXTRA_FIELD_EXPECTED_Row${diff}[row_index]_Field${diff}[field_index]
                ${already_logged}=    Evaluate    '''${field_key}''' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ${field_key}
                    Log    \nMissing Field (Expected Row ${diff}[row_index], Field ${diff}[field_index])    console=yes
                    Log    Value: ${diff}[field_value]    console=yes
                END
            ELSE IF    '${diff}[type]' == 'UNMATCHED_ROW_IN_FILE1'
                ${row_key}=    Set Variable    UNMATCHED_ACTUAL_${diff}[key_value]
                ${already_logged}=    Evaluate    '''${row_key}''' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ${row_key}
                    Log    \nUnmatched Row in Actual (${diff}[match_key] = ${diff}[key_value])    console=yes
                    Log    This row exists in actual but not in expected    console=yes
                END
            ELSE IF    '${diff}[type]' == 'UNMATCHED_ROW_IN_FILE2'
                ${row_key}=    Set Variable    UNMATCHED_EXPECTED_${diff}[key_value]
                ${already_logged}=    Evaluate    '''${row_key}''' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ${row_key}
                    Log    \nMissing Row in Actual (${diff}[match_key] = ${diff}[key_value])    console=yes
                    Log    This row exists in expected but not in actual    console=yes
                END
            ELSE IF    '${diff}[type]' == 'ROW_ORDER_MISMATCH'
                ${order_key}=    Set Variable    ORDER_MISMATCH_${diff}[key_value]
                ${already_logged}=    Evaluate    '''${order_key}''' in $logged_keys
                IF    not ${already_logged}
                    Append To List    ${logged_keys}    ${order_key}
                    Log    \n📍 Row Order Mismatch (${diff}[match_key] = ${diff}[key_value])    console=yes
                    Log    Position in Actual: Row ${diff}[file1_position]    console=yes
                    Log    Position in Expected: Row ${diff}[file2_position]    console=yes
                END
            END
        END
    ELSE
        Log    \nFILES ARE IDENTICAL (after excluding dynamic fields)    console=yes
    END

    Log    \n============================================    console=yes

################## HELPER KEYWORDS FOR FILE COMPARISON ##################

Compare Row Fields
    [Documentation]    Compares individual fields between two CSV rows
    [Arguments]    ${row1}    ${row2}    ${row_index}

    ${field_differences}=    Create List
    ${max_fields}=    Evaluate    max(len($row1), len($row2))

    FOR    ${field_index}    IN RANGE    ${max_fields}
        ${has_field1}=    Evaluate    ${field_index} < len($row1)
        ${has_field2}=    Evaluate    ${field_index} < len($row2)

        IF    ${has_field1} and ${has_field2}
            ${field1}=    Get From List    ${row1}    ${field_index}
            ${field2}=    Get From List    ${row2}    ${field_index}

            IF    '${field1}' != '${field2}'
                ${diff}=    Create Dictionary
                ...    type=FIELD_VALUE_MISMATCH
                ...    row_index=${row_index}
                ...    field_index=${field_index}
                ...    file1_value=${field1}
                ...    file2_value=${field2}
                Append To List    ${field_differences}    ${diff}
            END
        ELSE IF    ${has_field1} and not ${has_field2}
            ${field1}=    Get From List    ${row1}    ${field_index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_FIELD_IN_FILE1
            ...    row_index=${row_index}
            ...    field_index=${field_index}
            ...    field_value=${field1}
            Append To List    ${field_differences}    ${diff}
        ELSE IF    not ${has_field1} and ${has_field2}
            ${field2}=    Get From List    ${row2}    ${field_index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_FIELD_IN_FILE2
            ...    row_index=${row_index}
            ...    field_index=${field_index}
            ...    field_value=${field2}
            Append To List    ${field_differences}    ${diff}
        END
    END

    RETURN    ${field_differences}

Compare CSV Files Ignore Order
    [Documentation]    Compares CSV content ignoring row order
    [Arguments]    ${csv1_content}    ${csv2_content}

    # Skip headers and compare data rows only
    ${data1}=    Get Slice From List    ${csv1_content}    1
    ${data2}=    Get Slice From List    ${csv2_content}    1

    # Convert to sets for comparison (if rows are hashable)
    ${data1_str}=    Evaluate    [str(row) for row in $data1]
    ${data2_str}=    Evaluate    [str(row) for row in $data2]

    ${set1}=    Evaluate    set($data1_str)
    ${set2}=    Evaluate    set($data2_str)

    ${sets_equal}=    Evaluate    $set1 == $set2

    RETURN    ${sets_equal}

Compare JSON Arrays
    [Documentation]    Compares two JSON arrays and returns differences
    [Arguments]    ${array1}    ${array2}    ${ignore_order}=${TRUE}

    ${differences}=    Create List
    ${len1}=    Get Length    ${array1}
    ${len2}=    Get Length    ${array2}

    # Check array length differences
    IF    ${len1} != ${len2}
        ${diff}=    Create Dictionary
        ...    type=ARRAY_LENGTH_MISMATCH
        ...    array1_length=${len1}
        ...    array2_length=${len2}
        Append To List    ${differences}    ${diff}
    END

    # Compare individual elements
    ${max_len}=    Evaluate    max(${len1}, ${len2})

    FOR    ${index}    IN RANGE    ${max_len}
        ${has_item1}=    Evaluate    ${index} < ${len1}
        ${has_item2}=    Evaluate    ${index} < ${len2}

        IF    ${has_item1} and ${has_item2}
            ${item1}=    Get From List    ${array1}    ${index}
            ${item2}=    Get From List    ${array2}    ${index}
            ${items_equal}=    Evaluate    $item1 == $item2

            IF    not ${items_equal}
                ${diff}=    Create Dictionary
                ...    type=ITEM_MISMATCH
                ...    index=${index}
                ...    item1=${item1}
                ...    item2=${item2}
                Append To List    ${differences}    ${diff}
            END
        ELSE IF    ${has_item1} and not ${has_item2}
            ${item1}=    Get From List    ${array1}    ${index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_ITEM_IN_ARRAY1
            ...    index=${index}
            ...    item=${item1}
            Append To List    ${differences}    ${diff}
        ELSE IF    not ${has_item1} and ${has_item2}
            ${item2}=    Get From List    ${array2}    ${index}
            ${diff}=    Create Dictionary
            ...    type=EXTRA_ITEM_IN_ARRAY2
            ...    index=${index}
            ...    item=${item2}
            Append To List    ${differences}    ${diff}
        END
    END

    RETURN    ${differences}

################## LOGGING AND DETAILS ##################

Log CSV Comparison Details
    [Documentation]    Logs detailed comparison results
    [Arguments]    ${comparison_result}

    Log    \n=== CSV COMPARISON DETAILS ===
    Log    Status: ${comparison_result}[status]
    Log    File 1: ${comparison_result}[file1_path] (${comparison_result}[file1_rows] rows)
    Log    File 2: ${comparison_result}[file2_path] (${comparison_result}[file2_rows] rows)
    Log    Headers Match: ${comparison_result}[headers_match]
    Log    Row Count Match: ${comparison_result}[row_count_match]
    Log    Total Differences: ${comparison_result}[total_differences]

    IF    ${comparison_result}[total_differences] > 0
        Log    \n--- DIFFERENCES FOUND ---
        FOR    ${index}    ${diff}    IN ENUMERATE    @{comparison_result}[differences]
            Log    Difference ${index + 1}: ${diff}[type]

            IF    '${diff}[type]' == 'HEADER_MISMATCH'
                Log    \tFile1 Header: ${diff}[file1_header]
                Log    \tFile2 Header: ${diff}[file2_header]
            ELSE IF    '${diff}[type]' == 'ROW_CONTENT_MISMATCH'
                Log    \tRow ${diff}[row_index]:
                Log    \t\tFile1: ${diff}[file1_row]
                Log    \t\tFile2: ${diff}[file2_row]
            ELSE IF    '${diff}[type]' == 'FIELD_VALUE_MISMATCH'
                Log    \tRow ${diff}[row_index], Field ${diff}[field_index]:
                Log    \t\tFile1: '${diff}[file1_value]'
                Log    \t\tFile2: '${diff}[file2_value]'
            ELSE IF    '${diff}[type]' == 'ROW_COUNT_MISMATCH'
                Log    \tFile1 has ${diff}[file1_count] rows, File2 has ${diff}[file2_count] rows
            ELSE
                Log    \t${diff}
            END
        END
    ELSE
        Log    \n✅ FILES ARE IDENTICAL
    END

    Log    \n=== END COMPARISON DETAILS ===

Log JSON Comparison Details
    [Documentation]    Logs detailed JSON comparison results
    [Arguments]    ${comparison_result}

    Log    \n=== JSON COMPARISON DETAILS ===
    Log    Status: ${comparison_result}[status]
    Log    File 1: ${comparison_result}[file1_path]
    Log    File 2: ${comparison_result}[file2_path]
    Log    Files Match: ${comparison_result}[files_match]
    Log    Total Differences: ${comparison_result}[total_differences]

    IF    ${comparison_result}[total_differences] > 0
        Log    \n--- DIFFERENCES FOUND ---
        FOR    ${index}    ${diff}    IN ENUMERATE    @{comparison_result}[differences]
            Log    Difference ${index + 1}: ${diff}[type]

            IF    '${diff}[type]' == 'ARRAY_LENGTH_MISMATCH'
                Log    \tArray1 length: ${diff}[array1_length], Array2 length: ${diff}[array2_length]
            ELSE IF    '${diff}[type]' == 'ITEM_MISMATCH'
                Log    \tIndex ${diff}[index]:
                Log    \t\tArray1: ${diff}[item1]
                Log    \t\tArray2: ${diff}[item2]
            ELSE IF    '${diff}[type]' == 'EXTRA_ITEM_IN_ARRAY1'
                Log    \tExtra item in Array1 at index ${diff}[index]: ${diff}[item]
            ELSE IF    '${diff}[type]' == 'EXTRA_ITEM_IN_ARRAY2'
                Log    \tExtra item in Array2 at index ${diff}[index]: ${diff}[item]
            ELSE IF    '${diff}[type]' == 'STRUCTURE_MISMATCH'
                Log    \tFile1 type: ${diff}[file1_type], File2 type: ${diff}[file2_type]
            ELSE IF    '${diff}[type]' == 'PARSE_ERROR'
                Log    \tParse error: ${diff}[error]
            ELSE
                Log    \t${diff}
            END
        END
    ELSE
        Log    \n✅ JSON FILES ARE IDENTICAL
    END

    Log    \n=== END JSON COMPARISON DETAILS ===

################## FILE VALIDATION TEMPLATES ##################

Validate CSV File Template
    [Documentation]    Template keyword for validating CSV file properties using associative reading
    [Arguments]    ${file_path}    ${expected_rows}    ${has_headers}    ${expected_columns}

    Log    📋 Validating CSV file with template:
    Log    📁 File: ${file_path}
    Log    📈 Expected Rows: ${expected_rows}
    Log    📝 Has Headers: ${has_headers}
    Log    📈 Expected Columns: ${expected_columns}

    # Check file exists
    File Should Exist    ${file_path}

    IF    ${has_headers}
        # Use associative reading for files with headers - more efficient
        ${csv_data}=    Read Csv File To Associative    ${file_path}
        ${actual_rows}=    Get Length    ${csv_data}

        Should Be Equal As Numbers    ${actual_rows}    ${expected_rows}
        ...    Expected ${expected_rows} data rows but found ${actual_rows}

        # Get column count from first row's keys
        IF    ${actual_rows} > 0
            ${first_row}=    Get From List    ${csv_data}    0
            ${column_names}=    Get Dictionary Keys    ${first_row}
            ${actual_columns}=    Get Length    ${column_names}
            Should Be Equal As Numbers    ${actual_columns}    ${expected_columns}
            ...    Expected ${expected_columns} columns but found ${actual_columns}
            Log    ✅ Columns found: ${column_names}
        END
    ELSE
        # Use list reading for files without headers
        ${csv_content}=    Read Csv File To List    ${file_path}
        ${total_rows}=    Get Length    ${csv_content}

        Should Be Equal As Numbers    ${total_rows}    ${expected_rows}
        ...    Expected ${expected_rows} rows but found ${total_rows}

        # Validate column count from first data row
        ${first_row}=    Get From List    ${csv_content}    0
        ${actual_columns}=    Get Length    ${first_row}
        Should Be Equal As Numbers    ${actual_columns}    ${expected_columns}
        ...    Expected ${expected_columns} columns but found ${actual_columns}
    END

    Log    ✅ CSV validation completed successfully

Validate JSON File Template
    [Documentation]    NEW: Template keyword for validating JSON file properties using JSONLibrary
    [Arguments]    ${file_path}    ${expected_rows}    ${schema_file}=${None}

    Log    📄 Validating JSON file with template:
    Log    📁 File: ${file_path}
    Log    📈 Expected Rows: ${expected_rows}
    Log    📋 Schema File: ${schema_file}

    # Check file exists
    File Should Exist    ${file_path}

    # Load JSON using JSONLibrary
    ${json_data}=    Load Json From File    ${file_path}

    # Validate row count (assuming JSON array)
    ${actual_rows}=    Get Length    ${json_data}
    Should Be Equal As Numbers    ${actual_rows}    ${expected_rows}
    ...    Expected ${expected_rows} rows but found ${actual_rows}

    # Validate against schema if provided
    IF    '${schema_file}' != '${None}' and '${schema_file}' != ''
        Validate JSON Against Schema File    ${file_path}    ${schema_file}
    END

    Log    ✅ JSON validation completed successfully

################## NEW JSON SCHEMA VALIDATION TEMPLATES ##################

Validate JSON Array Schema
    [Documentation]    Validates JSON array against expected structure
    [Arguments]    ${json_file}    ${expected_item_keys}

    Log    🔍 Validating JSON array schema...

    ${json_data}=    Load Json From File    ${json_file}

    # Check if it's an array
    ${is_array}=    Evaluate    isinstance($json_data, list)
    Should Be True    ${is_array}    JSON file should contain an array

    # Validate each item has expected keys
    IF    ${json_data.__len__()} > 0
        ${first_item}=    Get From List    ${json_data}    0
        ${actual_keys}=    Get Dictionary Keys    ${first_item}
        ${actual_keys_set}=    Evaluate    set($actual_keys)
        ${expected_keys_set}=    Evaluate    set($expected_item_keys)

        Should Be Equal    ${actual_keys_set}    ${expected_keys_set}
        ...    JSON item keys don't match expected structure. Expected: ${expected_item_keys}, Found: ${actual_keys}
    END

    Log    ✅ JSON array schema validation passed

Validate JSON File Structure
    [Documentation]    Comprehensive JSON file structure validation
    [Arguments]    ${json_file}    ${expected_type}=list    ${min_items}=0    ${max_items}=${None}

    Log    🔍 Validating JSON file structure...
    Log    📄 File: ${json_file}
    Log    📊 Expected Type: ${expected_type}
    Log    📉 Min Items: ${min_items}
    Log    📈 Max Items: ${max_items}

    ${json_data}=    Load Json From File    ${json_file}

    # Validate type
    IF    '${expected_type}' == 'list'
        ${is_correct_type}=    Evaluate    isinstance($json_data, list)
        Should Be True    ${is_correct_type}    JSON should be an array/list
        ${item_count}=    Get Length    ${json_data}
    ELSE IF    '${expected_type}' == 'dict'
        ${is_correct_type}=    Evaluate    isinstance($json_data, dict)
        Should Be True    ${is_correct_type}    JSON should be an object/dictionary
        ${item_count}=    Get Length    ${json_data}
    ELSE
        Fail    Unsupported expected_type: ${expected_type}
    END

    # Validate item count constraints
    Should Be True    ${item_count} >= ${min_items}
    ...    JSON has ${item_count} items, but minimum required is ${min_items}

    IF    '${max_items}' != '${None}' and '${max_items}' != ''
        Should Be True    ${item_count} <= ${max_items}
        ...    JSON has ${item_count} items, but maximum allowed is ${max_items}
    END

    Log    ✅ JSON structure validation passed: ${item_count} items of type ${expected_type}

################## FILE UPLOAD AND LISTING TEMPLATES ##################

Upload File Using File Protocol Template
    [Documentation]    Template keyword to upload files using file:/// protocol URLs
    ...    Converts file:/// URLs to paths and uploads to SnapLogic
    [Arguments]    ${file_url}    ${destination_path}

    # Convert file:/// URL to actual path
    ${source_path}=    Replace String    ${file_url}    file://    ${EMPTY}

    # Extract filename from URL
    ${parts}=    Split String    ${source_path}    /
    ${filename}=    Get From List    ${parts}    -1

    # Extract directory path
    ${dir_parts}=    Get Slice From List    ${parts}    0    -1
    ${source_dir}=    Catenate    SEPARATOR=/    @{dir_parts}

    Log    Uploading from file URL: ${file_url}
    Log    Source directory: ${source_dir}
    Log    File name: ${filename}
    Log    Destination: ${destination_path}

    # Call the actual upload keyword
    Upload Files To SnapLogic From Template    ${source_dir}    ${filename}    ${destination_path}

List Files Using File Protocol Template
    [Documentation]    Template keyword to list files in directory using file:/// protocol URL
    [Arguments]    ${dir_url}    ${pattern}=*

    # Convert URL to path
    ${dir_path}=    Replace String    ${dir_url}    file://    ${EMPTY}

    # List files
    @{files}=    List Files In Directory    ${dir_path}    pattern=${pattern}

    # Create file URLs for each file
    @{file_urls}=    Create List
    FOR    ${file}    IN    @{files}
        ${file_url}=    Set Variable    ${dir_url}/${file}
        Append To List    ${file_urls}    ${file_url}
        Log    Found: ${file_url}
    END

    RETURN    ${file_urls}

Copy File Using File Protocol Template
    [Documentation]    Template keyword to copy files between file:/// protocol URLs
    [Arguments]    ${source_file_url}    ${dest_file_url}

    # Convert URLs to paths
    ${source_path}=    Replace String    ${source_file_url}    file://    ${EMPTY}
    ${dest_path}=    Replace String    ${dest_file_url}    file://    ${EMPTY}

    Log    Copying from: ${source_file_url}
    Log    Copying to: ${dest_file_url}

    Copy File    ${source_path}    ${dest_path}
    Log    File copied successfully
