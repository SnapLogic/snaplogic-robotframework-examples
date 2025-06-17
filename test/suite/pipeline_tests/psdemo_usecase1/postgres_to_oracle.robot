*** Settings ***
Documentation       Test Suite for PostgreSQL to S3 Pipeline Integration
...                 This comprehensive test suite validates the complete data pipeline flow:

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             Process    # Process execution for Docker commands
Library             DatabaseLibrary    # Generic database operations
Library             psycopg2    # PostgreSQL drive
Library             CSVLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords
Resource            ../../test_data/queries/postgres_queries.resource
Resource            ../../test_data/queries/oracle_queries.resource
Resource            ../../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Initialize Test Environment
# Suite Teardown    Drop Tables in Postgres DB


*** Variables ***
# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
# Use absolute path in container
${pipeline_file_path}               /app/src/pipelines
${upload_destination_file_path}     ${project_path}

# Postgres Pipeline and Task Configuration
${pipeline_name_csv}                postgres_oracle
${pipeline_name_csv_slp}            postgres_oracle.slp
${task_csv}                         pg_oracle_csv_Task

# CSV and test data configuration
${CSV_DATA_TO_DB}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/employees.csv    # Source CSV from input_data folder
${ACTUAL_DATA_DIR}                  ${CURDIR}/../../test_data/actual_expected_data/actual_output    # Base directory for downloaded files from S3
${EXPECTED_OUTPUT_DIR}              ${CURDIR}/../../test_data/actual_expected_data/expected_output    # Expected output files for comparison


*** Test Cases ***
################## DATA SETUP    ##################
# Test execution order:
# 1. Create accounts (PostgreSQL + S3)
# 2. Create database tables
# 3. Load CSV data (2 rows)
# 4. Load JSON data (2 more rows, total = 4 rows)
# 5. Run pipeline (exports 4 rows from DB to S3)
# 6. Download S3 files to src/actual_output/demo-bucket/
# 7. Compare original vs downloaded files
Create Account
    [Documentation]    Creates PostgreSQL and S3 accounts in the SnapLogic project space
    ...    📋 ASSERTIONS:
    ...    • Account creation API calls return HTTP 200/201 success responses
    ...    • PostgreSQL account configuration is valid and accepted
    ...    • S3/ account configuration is valid and accepted
    ...    • Account payloads are properly formatted and processed
    [Tags]    postgres_oracle    create_account
    [Template]    Create Account From Template
    ${account_payload_path}/acc_postgres.json
    ${account_payload_path}/acc_oracle.json

Create postgres table for DB Operations
    [Documentation]    Creates the employees table structure in PostgreSQL database
    ...    📋 ASSERTIONS:
    ...    • SQL table creation statement executes successfully
    ...    • Table structure matches expected schema (name, role, salary columns)
    ...    • Database connection is established and functional
    ...    • No SQL syntax or permission errors occur
    [Tags]    postgres_oracle
    Execute SQL On Database    ${CREATE_TABLE_EMPLOYEES_PG}    postgres
    Execute SQL On Database    ${CREATE_TABLE_EMPLOYEES2_PG}    postgres

Load CSV Data To PostgreSQL
    [Documentation]    Loads CSV employee data into PostgreSQL with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • CSV file exists and is readable
    ...    • Auto-detected row count from CSV file (excludes header)
    ...    • Database connection successful
    ...    • All CSV rows successfully inserted into employees table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table truncated before insertion (clean state)
    ...    • CSV column mapping to database columns successful
    [Tags]    postgres_oracle
    [Template]    Load CSV Data Template
    # CSV File    table_name    Truncate Table
    ${CSV_DATA_TO_DB}    employees    ${TRUE}

Create oracle table for DB Operations
    [Documentation]    Creates the employees table structure in Oracle database
    ...    📋 ASSERTIONS:
    ...    • SQL table creation statement executes successfully
    ...    • Table structure matches expected schema (name, role, salary columns)
    ...    • Database connection is established and functional
    ...    • No SQL syntax or permission errors occur
    [Tags]    postgres_oracle
    # Drop table if exists (ignore error if table doesn't exist)
    Run Keyword And Ignore Error    Execute SQL On Database    ${DROP_TABLE_EMPLOYEES}    oracle
    # Create table
    Execute SQL On Database    ${CREATE_TABLE_EMPLOYEES}    oracle

################## IMPORT PIPELINE-DATA IMPORTED FROM POSTGRES TO ORACLE--EXECUTION USING TRIGGER TASK    ##################

Upload Files With File Protocol
    [Documentation]    Upload files using file:/// protocol URLs - all options in template format
    [Tags]    postgres_oracle
    [Template]    Upload File Using File Protocol Template

    # files exist via Docker mounts:
    # - ./test/suite/test_data/.../expression_libraries -> /opt/snaplogic/expression-libraries

    # file_url    destination_path
    # === From Container Mount Points (files exist via mounts) ===
    # testing the same pattern CAT uses
    file:///opt/snaplogic/expression-libraries/test.expr    ${upload_destination_file_path}
    # Similar to CAT tests: /l$11 DEV GEN/.../EAI_Service_DEV/

    # === From App Mount (always available - entire test directory is mounted) ===
    file:///app/test/suite/test_data/actual_expected_data/expression_libraries/test.expr    ${upload_destination_file_path}/app_mount

    # === Using CURDIR Relative Paths (resolves to mounted paths) ===
    # Need to go up TWO directories from postgres_oracle to reach suite level
    file://${CURDIR}/../../test_data/actual_expected_data/expression_libraries/test.expr    ${upload_destination_file_path}/curdir

Import Pipelines
    [Documentation]    Imports the PostgreSQL to S3 pipeline into SnapLogic project
    ...    📋 ASSERTIONS:
    ...    • Pipeline file (.slp) exists and is readable
    ...    • Pipeline import API call succeeds
    ...    • Unique pipeline ID is generated and returned
    ...    • Pipeline nodes and configuration are valid
    ...    • Pipeline is successfully deployed to the project space
    [Tags]    postgres_oracle
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name_csv}    ${pipeline_name_csv_slp}

Create Triggered_task
    [Documentation]    Creates a triggered task for the imported pipeline
    ...    📋 ASSERTIONS:
    ...    • Task creation API call succeeds
    ...    • Task name and configuration are accepted
    ...    • Task is linked to the correct pipeline
    ...    • Task snode ID is generated and returned
    ...    • Task payload structure is valid
    [Tags]    postgres_oracle
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name_csv}    ${task_csv}

Execute Triggered Task
    [Documentation]    Executes the pipeline task to export data from PostgreSQL to S3
    ...    📋 ASSERTIONS:
    ...    • Task execution API call succeeds
    ...    • Pipeline runs without errors
    ...    • Data successfully exported from PostgreSQL (4 rows)
    ...    • Files created in S3 bucket (demo-bucket)
    ...    • Task completes within expected timeframe
    ...    • No pipeline execution errors or timeouts
    [Tags]    postgres_oracle
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name_csv}    ${task_csv}    bucket=demo-bucket    actual_output_file=employees.csv

Export Oracle Table To CSV After Pipeline
    [Documentation]    Exports Oracle employees table to CSV after the pipeline has transferred data
    ...    📋 ASSERTIONS:
    ...    • Oracle database connection successful
    ...    • Employees table exists with data from pipeline
    ...    • CSV file created with proper headers and data
    ...    • File saved in actual output directory
    ...    • Row count matches expected data
    ...    • CSV format is valid and can be parsed
    [Tags]    postgres_oracle
    [Template]    Export DB Table To CSV Template
    # db_type    table_name    csv_dir    order_by    filename
    oracle    employees    ${ACTUAL_DATA_DIR}    None    oracle_employees.csv
    oracle    employees    ${ACTUAL_DATA_DIR}    name    oracle_employees_sorted_by_name.csv
    oracle    employees    ${ACTUAL_DATA_DIR}    salary DESC    oracle_employees_sorted_by_salary.csv

################## COMPARISION TESTING    ##################

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing downloaded CSV against expected output
    ...    📋 ASSERTIONS:
    ...    • Downloaded CSV file exists locally
    ...    • Expected CSV file exists for comparison
    ...    • File structures are identical (headers match)
    ...    • Row counts are identical (no data loss)
    ...    • All field values match exactly (no data corruption)
    ...    • No extra or missing rows (complete data transfer)
    ...    • CSV formatting is preserved through pipeline
    [Tags]    postgres_oracle
    [Template]    Compare CSV Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${ACTUAL_DATA_DIR}/oracle_employees_sorted_by_name.csv    ${EXPECTED_OUTPUT_DIR}/oracle_insert_expected_output.csv    ${FALSE}    ${TRUE}    IDENTICAL

#### Extra Verifications ####

Copy Files With File Protocol
    [Documentation]    Copy files between mounts using file:/// protocol URLs
    [Tags]    postgres_oracle
    [Template]    Copy File Using File Protocol Template

    # source_url    destination_url
    file:///opt/snaplogic/expression-libraries/test.expr    file:///opt/snaplogic/shared/test_copy.expr

List Files With File Protocol
    [Documentation]    List files in directories using file:/// protocol URLs
    [Tags]    postgres_oracle

    # List expression files
    @{expr_files}=    List Files Using File Protocol Template    file:///opt/snaplogic/expression-libraries    *.expr
    Log    Expression files: ${expr_files}

    # List CSV files in shared mount
    @{csv_files}=    List Files Using File Protocol Template    file:///opt/snaplogic/shared    *.csv
    Log    CSV files: ${csv_files}


*** Keywords ***
Initialize Test Environment
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}

    # Connect to databases with aliases
    Connect to Postgres Database
    ...    ${POSTGRES_DBNAME}
    ...    ${POSTGRES_DBUSER}
    ...    ${POSTGRES_DBPASS}
    ...    ${POSTGRES_HOST}

    Connect to Oracle Database
    ...    ${ORACLE_DBNAME}
    ...    ${ORACLE_DBUSER}
    ...    ${ORACLE_DBPASS}
    ...    ${ORACLE_HOST}

    # Set PostgreSQL as default connection
    # Since Oracle was connected last, it's the active connection

    # Create actual_output directory if it doesn't exist
    Create Directory    ${ACTUAL_DATA_DIR}
    Log    Created directory for actual output: ${ACTUAL_DATA_DIR}

    # Execute setup script
    Log    Setting up PostgreSQL tables from script

Drop Tables in Postgres DB
    [Documentation]    Cleans up test data and database tables after test suite completion
    ...    This keyword performs cleanup without stopping containers,
    ...    allowing the services to remain running for subsequent test runs.
    ...
    ...    Cleanup Actions:
    ...    • Drops test tables from PostgreSQL database

    Log    🧹 Starting Test Environment Cleanup    INFO

    # Clean up database tables
    Log    📋 Dropping test tables from PostgreSQL...    INFO
    Execute SQL String    ${DROP_TABLE_EMPLOYEES_PG}
    Log    ✅ Dropped 'employees' table    INFO

    # Drop employees2 table
    Execute SQL String    ${DROP_TABLE_EMPLOYEES2_PG}
    Log    ✅ Dropped 'employees2' table    INFO
    Log    ✅ Test DB Tables cleanup completed successfully    INFO

Export DB Table To CSV
    [Documentation]    Exports any database table to CSV file
    ...    Supports both Oracle and PostgreSQL databases
    ...    Returns the path to the created CSV file
    [Arguments]    ${db_type}    ${table_name}    ${csv_dir}=${ACTUAL_DATA_DIR}    ${order_by}=None    ${filename}=None

    # Handle DB connection based on type
    Run Keyword And Ignore Error    Disconnect From Database

    # Connect to appropriate database
    IF    '${db_type}' == 'oracle'
        Connect to Oracle Database
        ...    ${ORACLE_DBNAME}
        ...    ${ORACLE_DBUSER}
        ...    ${ORACLE_DBPASS}
        ...    ${ORACLE_HOST}
        ...    ${ORACLE_DBPORT}
    ELSE IF    '${db_type}' == 'postgres'
        Connect to Postgres Database
        ...    ${POSTGRES_DBNAME}
        ...    ${POSTGRES_DBUSER}
        ...    ${POSTGRES_DBPASS}
        ...    ${POSTGRES_HOST}
        ...    ${POSTGRES_DBPORT}
    ELSE
        Fail    Unsupported database type: ${db_type}
    END

    # Construct SELECT query
    ${query}=    Set Variable If    '${order_by}' == 'None'
    ...    SELECT * FROM ${table_name}
    ...    SELECT * FROM ${table_name} ORDER BY ${order_by}

    # Execute query
    ${db_data}=    Query    ${query}
    ${row_count}=    Get Length    ${db_data}
    Log    ✅ Found ${row_count} rows in table '${table_name}'
    Should Be True    ${row_count} > 0    No data found in table '${table_name}'

    # Get column headers - different approach for each DB type
    IF    '${db_type}' == 'oracle'
        ${columns}=    Query
        ...    SELECT column_name FROM user_tab_columns WHERE UPPER(table_name) = UPPER('${table_name}') ORDER BY column_id
        ${headers}=    Create List
        FOR    ${col}    IN    @{columns}
            Append To List    ${headers}    ${col[0]}
        END
    ELSE
        # For PostgreSQL, get column names from information_schema
        ${columns}=    Query
        ...    SELECT column_name FROM information_schema.columns WHERE table_name = '${table_name}' ORDER BY ordinal_position
        ${headers}=    Create List
        FOR    ${col}    IN    @{columns}
            Append To List    ${headers}    ${col[0]}
        END
    END

    # Create CSV file
    ${timestamp}=    Get Time    epoch
    # Use provided filename or generate default
    ${csv_filename}=    Set Variable If    '${filename}' != 'None'
    ...    ${filename}
    ...    ${table_name}_${db_type}_export_${timestamp}.csv
    ${csv_path}=    Set Variable    ${csv_dir}/${csv_filename}

    # Write headers
    ${header_line}=    Evaluate    ','.join(${headers})
    ${lines}=    Create List    ${header_line}

    # Build all data rows
    FOR    ${row}    IN    @{db_data}
        ${row_values}=    Create List
        FOR    ${value}    IN    @{row}
            ${formatted_value}=    Format CSV Value    ${value}
            Append To List    ${row_values}    ${formatted_value}
        END
        ${row_line}=    Evaluate    ','.join(${row_values})
        Append To List    ${lines}    ${row_line}
    END

    # Join all lines with newline and write at once
    ${csv_content}=    Evaluate    '\\n'.join(${lines})
    Create File    ${csv_path}    ${csv_content}

    # Verify file creation
    File Should Exist    ${csv_path}
    ${file_size}=    Get File Size    ${csv_path}
    Should Be True    ${file_size} > 0    CSV export failed for ${table_name}

    # Log summary
    Log    📂 CSV created: ${csv_path}
    Log    📊 Exported ${row_count} rows from ${db_type}:${table_name}

    # Set suite variable and return path
    Set Suite Variable    ${EXPORT_CSV_FILE}    ${csv_path}
    RETURN    ${csv_path}

Format CSV Value
    [Documentation]    Formats a value for CSV output, handling special cases
    [Arguments]    ${value}

    # Handle NULL/None values
    ${str_value}=    Set Variable If    '${value}' == 'None'    ${EMPTY}    ${value}

    # Convert to string
    ${str_value}=    Convert To String    ${str_value}

    # Escape quotes
    ${str_value}=    Replace String    ${str_value}    "    ""

    # Add quotes if value contains comma, newline, or quotes
    ${needs_quotes}=    Run Keyword And Return Status    Should Match Regexp    ${str_value}    [,\n"]
    ${str_value}=    Set Variable If    ${needs_quotes}    "${str_value}"    ${str_value}
    RETURN    ${str_value}

Export DB Table To CSV Template
    [Documentation]    Template wrapper for Export DB Table To CSV with validation
    [Arguments]    ${db_type}    ${table_name}    ${csv_dir}=${ACTUAL_DATA_DIR}    ${order_by}=None    ${filename}=None

    # Call the main export keyword
    ${csv_path}=    Export DB Table To CSV    ${db_type}    ${table_name}    ${csv_dir}    ${order_by}    ${filename}

    # Verify the export
    Log    ✅ ${db_type} data exported to: ${csv_path}

    # Read and validate the CSV content
    ${csv_content}=    Get File    ${csv_path}
    ${lines}=    Split String    ${csv_content}    \n
    ${line_count}=    Get Length    ${lines}

    # Remove empty lines at the end
    ${actual_line_count}=    Set Variable    ${0}
    FOR    ${line}    IN    @{lines}
        IF    '${line}' != '${EMPTY}'
            ${actual_line_count}=    Evaluate    ${actual_line_count} + 1
        END
    END

    Should Be True    ${actual_line_count} > 1    CSV should have header and at least one data row

    # Display first few lines for verification
    Log    📄 CSV Preview (first 3 lines):
    ${preview_count}=    Set Variable    ${3}
    ${max_lines}=    Set Variable If
    ...    ${actual_line_count} < ${preview_count}
    ...    ${actual_line_count}
    ...    ${preview_count}

    FOR    ${i}    IN RANGE    ${max_lines}
        ${line}=    Get From List    ${lines}    ${i}
        IF    '${line}' != '${EMPTY}'    Log    Line ${i}: ${line}
    END

    Log    📊 Export completed: ${actual_line_count} lines (including header)
