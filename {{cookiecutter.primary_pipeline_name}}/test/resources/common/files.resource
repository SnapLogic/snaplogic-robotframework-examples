*** Settings ***
Documentation       Optimized resource file for CSV/JSON/XML file operations and comparisons.
...                 This resource file uses standard Robot Framework libraries
...                 with a custom file_comparison_library for comparison with exclusions.
...
...                 Contains keywords for:
...                 - CSV/JSON/XML file loading and validation
...                 - File content analysis and row counting
...                 - Database loading operations
...                 - File comparison with exclusions
...                 - JSON schema validation and manipulation
...                 - XML element validation and XPath queries
...                 - Key-based row matching for CSV comparison

# Custom Library for comparison operations (not available in standard libraries)
Library             ../../libraries/common/FileComparisonLibrary.py
# Standard Libraries
Library             OperatingSystem
Library             Collections
Library             String
# Other Resource Files
Resource            general.resource
Resource            sql_table_operations.resource
Resource            database.resource
Resource            json_validation.resource
Resource            csv_validations.resource
Resource            xml_validations.resource
# SnapLogic API keywords for file upload operations
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource


*** Keywords ***
################## FILE ANALYSIS AND COUNTING ##################

Get File Extension
    [Documentation]    Extracts file extension from file path (returns lowercase with dot).
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Full path to the file
    ...
    ...    *Returns:*
    ...    - Lowercase file extension with dot (e.g., ``.csv``, ``.json``)
    ...
    ...    *Example:*
    ...    | ${ext}= | Get File Extension | /data/report.CSV |
    [Arguments]    ${file_path}

    ${path}    ${ext}=    Split Extension    ${file_path}
    ${extension}=    Convert To Lower Case    ${ext}
    RETURN    ${extension}

Get Directory From Path
    [Documentation]    Extracts directory path from a full file path.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Full path to the file
    ...
    ...    *Returns:*
    ...    - Directory portion of the path
    ...
    ...    *Example:*
    ...    | ${dir}= | Get Directory From Path | /data/files/report.csv |
    [Arguments]    ${file_path}

    ${dir_path}    ${file_name}=    Split Path    ${file_path}
    RETURN    ${dir_path}

Get File Content Safely
    [Documentation]    Gets file content from a text file.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the text file to read
    ...
    ...    *Returns:*
    ...    - String content of the file
    ...
    ...    *Example:*
    ...    | ${content}= | Get File Content Safely | ${CURDIR}/data/config.properties |
    [Arguments]    ${file_path}

    ${content}=    Get File    ${file_path}
    RETURN    ${content}

Validate File Exists And Not Empty
    [Documentation]    Validates that a file exists and has content (size > 0 bytes).
    ...    Generic version — works for any file type (.expr, .csv, .json, .slp, etc.).
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the file to validate
    ...
    ...    *Example:*
    ...    | Validate File Exists And Not Empty | ${CURDIR}/data/oracle_library.expr |
    [Arguments]    ${file_path}
    File Should Exist    ${file_path}
    ...    File not found: ${file_path}
    ${size}=    Get File Size    ${file_path}
    Should Be True    ${size} > 0
    ...    File is empty (0 bytes): ${file_path}
    Log    File verified: ${file_path} (${size} bytes)    console=yes

################## DATA LOADING TEMPLATES ##################

Load Data File Auto
    [Documentation]    Universal data loader that detects file type and loads automatically.
    ...
    ...    *Arguments:*
    ...    - ``data_file``: Path to the data file (.csv or .json)
    ...    - ``table_name``: Target database table name
    ...    - ``truncate``: Whether to truncate table before loading (default: TRUE)
    ...
    ...    *Example:*
    ...    | Load Data File Auto | ${CURDIR}/data/users.csv | USERS_TABLE |
    ...    | Load Data File Auto | ${CURDIR}/data/orders.json | ORDERS_TABLE | ${FALSE} |
    ...
    ...    *See also:* `Load CSV Data Template`, `Load JSON Data Template`
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

################## FILE PROTOCOL TEMPLATES ##################

Upload File Using File Protocol Template
    [Documentation]    Template keyword to upload files to SnapLogic using file:/// protocol URLs.
    ...    Reads the source file from local filesystem and uploads it to SnapLogic.
    ...    Supports both file:// prefixed URLs and regular file paths.
    ...
    ...    *Arguments:*
    ...    - ``file_url``: Local file path (with or without file:// prefix)
    ...    - ``destination_path``: SnapLogic destination path (e.g., project_space/project_name)
    ...
    ...    *Examples:*
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

    Log    File uploaded successfully to SnapLogic: ${destination_path}/${filename}    console=yes

List Files Using File Protocol Template
    [Documentation]    Template keyword to list files in directory using file:/// protocol URL.
    ...
    ...    *Arguments:*
    ...    - ``dir_url``: Directory path (with or without file:// prefix)
    ...    - ``pattern``: Glob pattern to filter files (default: *)
    ...
    ...    *Returns:*
    ...    - List of file:// URLs for matching files
    ...
    ...    *Example:*
    ...    | @{files}= | List Files Using File Protocol Template | file://${CURDIR}/data | *.csv |
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
    ...
    ...    *Arguments:*
    ...    - ``source_file_url``: Source file path (with or without file:// prefix)
    ...    - ``dest_file_url``: Destination file path (with or without file:// prefix)
    ...
    ...    *Example:*
    ...    | Copy File Using File Protocol Template | file://${CURDIR}/data/input.csv | file://${CURDIR}/output/input.csv |
    [Arguments]    ${source_file_url}    ${dest_file_url}

    ${source_path}=    Evaluate    '${source_file_url}'.replace('file://', '')
    ${dest_path}=    Evaluate    '${dest_file_url}'.replace('file://', '')

    Log    Copying from: ${source_file_url}
    Log    Copying to: ${dest_file_url}

    Copy File    ${source_path}    ${dest_path}
    Log    File copied successfully

################## FILE VALIDATION ##################

Validate File Meets Minimum Size
    [Documentation]    Validates that a file size meets or exceeds a minimum threshold.
    ...    Useful for ensuring files are not truncated or incomplete.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the file to check
    ...    - ``min_size``: Minimum expected size in bytes
    ...
    ...    *Example:*
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
    ...    *Arguments:*
    ...    - ``content``: Raw text content of the file
    ...    - ``@field_names``: One or more field names that must be present in the content
    ...
    ...    *Example:*
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

##################################################################################
#    UNUSED KEYWORDS    #
# The following keywords are not currently used in any test cases or resources.    #
# They are kept here for potential future use or reference.    #
##################################################################################

Count Rows In File
    [Documentation]    Universal row counter that detects file type and counts appropriately.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the file to analyze
    ...    - ``header_rows``: Number of header rows (only applies to CSV, default: 1)
    ...
    ...    *Returns:*
    ...    - Number of data rows
    ...
    ...    *See also:* `Count Data Rows In CSV`, `Count Data Rows In JSON`
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
    ...
    ...    *Arguments:*
    ...    - ``directory_path``: Path to the directory to remove
    ...
    ...    *Example:*
    ...    | Remove Directory Safely | ${CURDIR}/temp_output |
    [Arguments]    ${directory_path}

    ${exists}=    Run Keyword And Return Status    Directory Should Exist    ${directory_path}
    IF    ${exists}
        Remove Directory    ${directory_path}    recursive=True
        Log    Removed existing directory: ${directory_path}
    ELSE
        Log    Directory does not exist (no need to remove): ${directory_path}
    END

Get File Info
    [Documentation]    Gets comprehensive information about a file.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the file to inspect
    ...
    ...    *Returns:*
    ...    - Dictionary with keys: ``path``, ``name``, ``extension``, ``size``, ``directory``
    ...
    ...    *Example:*
    ...    | ${info}= | Get File Info | ${CURDIR}/data/report.csv |
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
    ...
    ...    *Arguments:*
    ...    - ``directory_path``: Path to the directory to ensure exists
    ...
    ...    *Example:*
    ...    | Ensure Directory Exists | ${CURDIR}/output |
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
    ...
    ...    *Arguments:*
    ...    - ``@paths``: One or more file or directory paths to remove
    ...
    ...    *Example:*
    ...    | Clean Up Test Files | ${CURDIR}/temp | ${CURDIR}/output/result.csv |
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
