*** Settings ***
Documentation       CSV-focused resource file for validation, comparison, and data loading.
...                 Contains keywords for:
...                 - CSV file loading and validation
...                 - CSV comparison with exclusions
...                 - CSV row counting
Library             CSVLibrary
Library             DatabaseLibrary
Library             Collections
Library             OperatingSystem
Library             String
Library             ../../libraries/common/FileComparisonLibrary.py

*** Keywords ***
################## FILE ANALYSIS AND COUNTING ##################

Count Data Rows In CSV
    [Documentation]    Counts the number of data rows in a CSV file (excluding header rows).
    ...
    ...    *Arguments:*
    ...    - ``csv_file``: Path to the CSV file to analyze
    ...    - ``header_rows``: Number of header rows to exclude (default: 1)
    ...
    ...    *Returns:*
    ...    - Number of data rows in the CSV file
    ...
    ...    *Examples:*
    ...    | ${count}= | Count Data Rows In CSV | data.csv |
    ...    | ${count}= | Count Data Rows In CSV | raw_data.csv | header_rows=0 |
    [Arguments]    ${csv_file}    ${header_rows}=1

    @{csv_data}=    Read Csv File To List    ${csv_file}
    ${total_rows}=    Get Length    ${csv_data}
    ${data_rows}=    Evaluate    ${total_rows} - ${header_rows}
    Log    CSV file analysis: ${data_rows} data rows (excluding ${header_rows} header rows)
    RETURN    ${data_rows}

################## DATA LOADING TEMPLATES ##################

Load CSV Data Template
    [Documentation]    Enhanced template that auto-calculates expected rows from CSV file.
    ...
    ...    *Arguments:*
    ...    - ``csv_file``: Path to CSV file
    ...    - ``table_name``: Target database table name
    ...    - ``truncate_table``: Whether to truncate table before loading (default: TRUE)
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

################## CSV COMPARISON WITH EXCLUSIONS ##################

Compare CSV Files With Exclusions Template
    [Documentation]    Template keyword for CSV comparison with exclusions and validation.
    ...
    ...    *Arguments:*
    ...    - ``file1_path``: Path to actual output CSV file
    ...    - ``file2_path``: Path to expected output CSV file
    ...    - ``ignore_order``: Whether to ignore row order
    ...    - ``show_details``: Whether to show detailed differences
    ...    - ``expected_status``: Expected comparison result (IDENTICAL or DIFFERENT)
    ...    - ``@exclude_keys``: One or more column keys to exclude from comparison
    ...    - ``&options``: Additional options like ``match_key=headers.profile_id``
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary with ``status`` and ``total_differences``
    ...
    ...    *Examples:*
    ...    | ${result}= | Compare CSV Files With Exclusions Template |
    ...    | ...    ${actual_file}    ${expected_file}    ${TRUE}    ${TRUE}    IDENTICAL |
    ...    | ...    SnowflakeConnectorPushTime    event_timestamp |
    ...    |
    ...    | # With match_key: |
    ...    | ${result}= | Compare CSV Files With Exclusions Template |
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
    ...
    ...    *Arguments:*
    ...    - ``file1_path``: Path to the first CSV file (actual output)
    ...    - ``file2_path``: Path to the second CSV file (expected output)
    ...    - ``ignore_order``: Whether to ignore row order during comparison
    ...    - ``show_details``: Whether to show detailed differences
    ...    - ``expected_status``: Expected comparison result (IDENTICAL or DIFFERENT)
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary with ``status`` and ``total_differences``
    ...
    ...    *Example:*
    ...    | ${result}= | Compare CSV Files Template | ${actual_file} | ${expected_file} | ${TRUE} | ${TRUE} | IDENTICAL |
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

Validate CSV File Template
    [Documentation]    Template keyword for validating CSV file properties.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the CSV file to validate
    ...    - ``expected_rows``: Expected number of data rows
    ...    - ``has_headers``: Whether the CSV has a header row (default: TRUE)
    ...    - ``expected_columns``: Optional expected number of columns (default: None)
    ...
    ...    *Returns:*
    ...    - Dictionary with ``valid`` (boolean), ``actual_rows``, and ``actual_columns``
    ...
    ...    *Examples:*
    ...    | ${result}= | Validate CSV File Template | ${CURDIR}/data/output.csv | 100 |
    ...    | ${result}= | Validate CSV File Template | ${CURDIR}/data/output.csv | 100 | ${TRUE} | 5 |
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
