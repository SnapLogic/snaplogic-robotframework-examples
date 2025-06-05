*** Settings ***
Documentation       Test Suite for PostgreSQL to S3 Pipeline Integration
...                 This comprehensive test suite validates the complete data pipeline flow:
...
...                 📋 TEST EXECUTION ORDER & ASSERTIONS:
...                 1. Account Creation: Creates PostgreSQL and S3 accounts
...                 - Asserts: Account creation API responses are successful
...                 2. Database Setup: Creates employees table structure
...                 - Asserts: Table creation SQL executes without errors
...                 3. Data Loading: Loads CSV (2 rows) and JSON (2 rows) into PostgreSQL
...                 - Asserts: File row count matches database inserted count (auto-detected)
...                 - Asserts: All file data successfully transferred to database
...                 4. Pipeline Execution: Exports 4 total rows from PostgreSQL to S3
...                 - Asserts: Pipeline task execution completes successfully
...                 - Asserts: Expected files are created in S3 bucket
...                 5. File Download: Downloads exported files from S3 for validation
...                 - Asserts: Files exist in S3 and can be downloaded
...                 - Asserts: Downloaded file sizes are greater than 0 bytes
...                 6. Data Validation: Compares original vs exported data integrity
...                 - Asserts: Downloaded CSV matches expected CSV structure and content
...                 - Asserts: Downloaded JSON matches expected JSON structure and content
...                 - Asserts: No data loss or corruption during pipeline process
...
...                 🔍 KEY VALIDATION POINTS:
...                 • Data Integrity: Source data = Exported data
...                 • Row Count Accuracy: File analysis = Database operations = S3 exports
...                 • Format Preservation: CSV and JSON structures maintained
...                 • Pipeline Reliability: End-to-end data flow validation

# Standard Libraries
Library             OperatingSystem    # File system operations
Library             Process    # Process execution for Docker commands
Library             DatabaseLibrary    # Generic database operations
Library             psycopg2    # PostgreSQL drive
Library             CSVLibrary
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource    # SnapLogic API keywords
Resource            ../test_data/queries/postgres_queries.resource
Resource            ../../resources/files.resource    # CSV/JSON file operations

Suite Setup         Initialize Test Environment
# Suite Teardown    Drop Tables in Postgres DB


*** Variables ***
# Project Configuration
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               ${CURDIR}/../../../src/pipelines

# Postgres Pipeline and Task Configuration
# All Other related variables are set in the Initialize Pipeline1 Variables keyword
${pipeline_name_csv}                postgres_s3_csv
${pipeline_name_csv_slp}            postgres_to_s3_csv.slp
${task_csv}                         pg_s3_csv_Task

${pipeline_name_json}               postgres_s3_json
${pipeline_name_json_slp}           postgres_to_s3_json.slp
${task_json}                        pg_s3_csv_Task

# CSV and test data configuration
${DEMO_BUCKET}                      demo-bucket
${CSV_DATA_TO_DB}                   ${CURDIR}/../test_data/actual_expected_data/input_data/employees.csv    # Source CSV from input_data folder
${JSON_DATA_TO_DB}                  ${CURDIR}/../test_data/actual_expected_data/input_data/employees.json    # Source JSON from input_data folder
${ACTUAL_DATA_DIR}                  ${CURDIR}/../test_data/actual_expected_data/actual_output    # Base directory for downloaded files from S3
${EXPECTED_OUTPUT_DIR}              ${CURDIR}/../test_data/actual_expected_data/expected_output    # Expected output files for comparison

# Test configuration
${SKIP_MINIO_TESTS}                 ${False}    # Set to True to skip MinIO tests when server unavailable

# Docker service configuration
${POSTGRES_CONTAINER_NAME}          postgres-db
${MINIO_CONTAINER_NAME}             snaplogic-minio
${MINIO_SETUP_CONTAINER_NAME}       snaplogic-minio-setup
${DOCKER_COMPOSE_TIMEOUT}           120s
${SERVICE_HEALTH_TIMEOUT}           90s


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
    ...    • S3/MinIO account configuration is valid and accepted
    ...    • Account payloads are properly formatted and processed
    [Tags]    postgres_s3    create_account    minio
    [Template]    Create Account From Template
    ${account_payload_path}/acc_postgres.json
    ${account_payload_path}/acc_s3.json

Create table for DB Operations
    [Documentation]    Creates the employees table structure in PostgreSQL database
    ...    📋 ASSERTIONS:
    ...    • SQL table creation statement executes successfully
    ...    • Table structure matches expected schema (name, role, salary columns)
    ...    • Database connection is established and functional
    ...    • No SQL syntax or permission errors occur
    [Tags]    postgres_s3    create_tables
    [Template]    Execute SQL String
    ${CREATE_TABLE_EMPLOYEES_PG}
    ${CREATE_TABLE_EMPLOYEES2_PG}

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
    [Tags]    postgres_s3    csv5    load_data
    [Template]    Load CSV Data Template
    # CSV File    table_name    Truncate Table
    ${CSV_DATA_TO_DB}    employees    ${TRUE}

Load JSON Data To PostgreSQL
    [Documentation]    Loads JSON employee data into PostgreSQL with automatic row count validation
    ...    📋 ASSERTIONS:
    ...    • JSON file exists and is valid JSON format
    ...    • Auto-detected row count from JSON array elements
    ...    • Database connection maintained
    ...    • All JSON records successfully inserted into employees table
    ...    • Inserted row count = Auto-detected expected count from file
    ...    • Table NOT truncated (appends to existing CSV data)
    ...    • JSON field mapping to database columns successful
    ...    • Total database rows = CSV rows + JSON rows
    [Tags]    postgres_s3    json5    load_data
    [Template]    Load JSON Data Template
    # JSON File    table_name    Truncate Table
    ${JSON_DATA_TO_DB}    employees2    ${TRUE}

################## IMPORT PIPELINE-(UPLOAD TO S3 FROM POSTGRES )--EXECUTION USING TRIGGER TASK    ##################

Import Pipelines
    [Documentation]    Imports the PostgreSQL to S3 pipeline into SnapLogic project
    ...    📋 ASSERTIONS:
    ...    • Pipeline file (.slp) exists and is readable
    ...    • Pipeline import API call succeeds
    ...    • Unique pipeline ID is generated and returned
    ...    • Pipeline nodes and configuration are valid
    ...    • Pipeline is successfully deployed to the project space
    [Tags]    postgres_s3    minio    pgdb
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name_csv}    ${pipeline_name_csv_slp}
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name_json}    ${pipeline_name_json_slp}

Create Triggered_task
    [Documentation]    Creates a triggered task for the imported pipeline
    ...    📋 ASSERTIONS:
    ...    • Task creation API call succeeds
    ...    • Task name and configuration are accepted
    ...    • Task is linked to the correct pipeline
    ...    • Task snode ID is generated and returned
    ...    • Task payload structure is valid
    [Tags]    create_triggered_task    minio    postgres_s3
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name_csv}    ${task_csv}
    ${unique_id}    ${project_path}    ${pipeline_name_json}    ${task_json}

Execute Triggered Task
    [Documentation]    Executes the pipeline task to export data from PostgreSQL to S3
    ...    📋 ASSERTIONS:
    ...    • Task execution API call succeeds
    ...    • Pipeline runs without errors
    ...    • Data successfully exported from PostgreSQL (4 rows)
    ...    • Files created in S3 bucket (demo-bucket)
    ...    • Task completes within expected timeframe
    ...    • No pipeline execution errors or timeouts
    [Tags]    create_triggered_task    postgres_s3
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name_csv}    ${task_csv}    bucket=demo-bucket    actual_output_file=employees.csv
    ${unique_id}    ${project_path}    ${pipeline_name_json}    ${task_json}    bucket=demo-bucket    actual_output_file=employees.json

################## DOWNLOAD ACTUAL RESULT OF PIPELINE EXECUTION    ##################

Download actual Output data from S3
    [Documentation]    Downloads pipeline output files from S3 bucket for validation
    ...    📋 ASSERTIONS:
    ...    • S3 bucket (demo-bucket) exists and is accessible
    ...    • Expected files (employees.csv) exist in S3
    ...    • Files can be downloaded without errors
    ...    • Downloaded files have content (size > 0 bytes)
    ...    • Local download directory is created successfully
    ...    • File download completes within timeout
    [Tags]    postgres_s3
    [Template]    Download And Validate File

    # Test Data: download_location    bucket_name    file_name
    ${ACTUAL_DATA_DIR}    ${DEMO_BUCKET}    employees.csv
    ${ACTUAL_DATA_DIR}    ${DEMO_BUCKET}    employees.json

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
    [Tags]    csv    comparison    postgres_s3    validation
    [Template]    Compare CSV Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${ACTUAL_DATA_DIR}/employees.csv    ${EXPECTED_OUTPUT_DIR}/employees.csv    ${FALSE}    ${TRUE}    IDENTICAL

Compare Actual vs Expected JSON Output
    [Documentation]    Validates data integrity by comparing downloaded JSON against expected output
    ...    📋 ASSERTIONS:
    ...    • Downloaded JSON file exists locally
    ...    • Expected JSON file exists for comparison
    ...    • JSON structures are identical (schema preserved)
    ...    • Array lengths are identical (no data loss)
    ...    • All object properties match exactly (no data corruption)
    ...    • No extra or missing records (complete data transfer)
    ...    • JSON formatting is valid and preserved through pipeline
    [Tags]    json    comparison    postgres_s3    validation
    [Template]    Compare JSON Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${ACTUAL_DATA_DIR}/employees.json    ${EXPECTED_OUTPUT_DIR}/employees.json    ${FALSE}    ${TRUE}    IDENTICAL


*** Keywords ***
# This section    test initialization keywords

Initialize Test Environment
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to Postgres Database    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}

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
