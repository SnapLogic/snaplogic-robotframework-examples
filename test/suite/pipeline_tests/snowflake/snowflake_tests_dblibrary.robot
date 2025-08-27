*** Settings ***
Documentation       Snowflake Database Integration Tests
...                 Using snowflake_keywords.resource which wraps the SnowflakeHelper Python library
...                 Environment variables are automatically loaded from .env file via Docker

Library             Collections
Library             OperatingSystem
Resource            ../../../resources/snowflake2/snowflake_keywords_databaselib.resource    # For Snowflake connection
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/files.resource
Resource            ../../../resources/sql_table_operations.resource    # Generic SQL operations
Resource            ../../test_data/queries/snowflake_queries.resource    # Snowflake SQL queries

Suite Setup         Check connections    # Check if the connection to the MySQL database is successful and snaplex is up


*** Variables ***
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               /app/src/pipelines
${expression_library_file_path}     ${org_name}/${project_space}/shared

# SnowflakePipeline details
${pipeline_name}                    snowflake
${pipeline_slp}                     snowflake.slp
${task1}                            snowflake_Task

# Task notification settings
@{notification_states}              Completed    Failed
&{task_notifications}
...                                 recipients=newemail@gmail.com
...                                 states=${notification_states}

&{task_params_set1}
...                                 snowflake_acct=../shared/snowflake_acct
...                                 actual_output=file:///opt/snaplogic/test_data/actual_expected_data/actual_output/snowflake/table1.csv
...                                 schema_name="INTUIT"
...                                 table_name=""INTUIT"."LIFEEVENTSDATA""

${ACCOUNT_PAYLOAD_FILE}             acc_snowflake_s3_db.json

${table_name}                       RF_TEST_CREATE_TABLE
${table_definition}                 (id NUMBER PRIMARY KEY, name VARCHAR(100), amount DECIMAL(10,2))
${COLUMNS}                          id, name, amount
${table_name1}                      TEST_SNOWFLAKE_TABLE

${JSON_DATA_FILE}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/employees.json

${ACTUAL_DATA_DIR}                  /app/test/suite/test_data/actual_expected_data/actual_output/snowflake
${EXPECTED_OUTPUT_DIR}              ${CURDIR}/../../test_data/actual_expected_data/expected_output/snowflake    # Expected output files for comparison

# All data rows as a list of values
@{ALL_DATA}                         1, 'John', 1000.50
...                                 2, 'Jane', 2000.75
...                                 3, 'Bob', 3000.00
...                                 4, 'Alice', 4000.25
...                                 5, 'Tom', 5000.50


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    [Tags]    snowflake_intuit
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Upload Expression Library
    [Documentation]    Uploads the expression library to project level shared folder
    [Tags]    snowflake_intuit    upload_expression_library
    [Template]    Upload File Using File Protocol Template
    file:///opt/snaplogic/test_data/actual_expected_data/expression_libraries/snowflake/snowflake_library.expr    ${expression_library_file_path}

Import Pipeline
    [Documentation]    Imports the file snowflake pipeline that demonstrates
    ...    reading from and writing to mounted file locations
    ...    📋 ASSERTIONS:
    ...    • Pipeline file (.slp) exists and is readable
    ...    • Pipeline import API call succeeds
    ...    • Unique pipeline ID is generated and returned
    ...    • Pipeline contains file reader and writer snaps configured for mounts
    ...    • Pipeline is successfully deployed to the project space
    [Tags]    snowflake_intuit
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_slp}

Create Triggered_task
    [Documentation]    Creates triggered task and returns the task name and task snode id
    ...    which is used to execute the task.
    ...    Prereq: Need unique_id,pipeline_snodeid (from Import Pipelines)
    ...    Returns:
    ...    task_payload --> which is used to update the task params
    ...    task_snodeid --> which is used to update the task params
    [Tags]    snowflake_intuit    regression
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    ${task_params_set1}    ${task_notifications}

Execute Triggered Task With Parameters
    [Documentation]    Updates the task parameters and runs the task
    ...    Prereq: Need task_payload,task_snodeid (from Create Triggered_task)
    [Tags]    snowflake_intuit
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name}    ${task1}    snowflake_acct=../shared/snowflake_acct

Create Table For DB Operations
    [Documentation]    Creates the employees table structure in Snowflake database
    ...    📋 ASSERTIONS:
    ...    • SQL table creation statement executes successfully
    ...    • Table structure matches expected schema (id, name, role, salary columns)
    ...    • Database connection is established and functional
    ...    • No SQL syntax or permission errors occur
    ...    • Snowflake-specific features (AUTOINCREMENT, NUMBER types) work correctly
    [Tags]    snowflake_intuit
    [Template]    Execute SQL String
    ${DROP_TABLE_EMPLOYEES}
    ${CREATE_TABLE_EMPLOYEES}
    ${DROP_TABLE_EMPLOYEES2}
    ${CREATE_TABLE_EMPLOYEES2}

Setup JSON Table For Snowflake
    [Documentation]    Creates the table needed for JSON data loading
    [Tags]    snowflake_intuit

    # Connect to Snowflake
    Connect To Snowflake Via DatabaseLibrary

    # Create the table for JSON data - matching the actual JSON structure
    Log    Creating table ${TABLE_NAME1} for JSON data...    console=yes
    ${table_definition}=    Set Variable
    ...    (NAME VARCHAR(100), DEPARTMENT VARCHAR(100), SALARY DECIMAL(10,2), HIRE_DATE DATE, IS_ACTIVE BOOLEAN)
    # Using generic keyword instead of Snowflake-specific
    Create Table If Not Exists    ${TABLE_NAME1}    ${table_definition}
    Log    Table ${TABLE_NAME1} created successfully    console=yes

Load JSON Data To Snowflake
    [Documentation]    Loads JSON employee data into Snowflake using the SAME template as MySQL
    ...    This proves the template is database-agnostic and works with Snowflake too!
    ...    NOTE: Run 'Setup JSON Table For Snowflake' test first to create the table
    [Tags]    snowflake_intuit
    [Template]    Load JSON Data Template
    # JSON File    table_name    Truncate Table
    ${JSON_DATA_FILE}    ${TABLE_NAME1}    ${TRUE}    # Truncate before loading

Verify Expected Results In DB
    [Documentation]    Test connection using generic SQL operations keywords
    ...    Demonstrates use of database-agnostic keywords that work with any database
    [Tags]    snowflake_intuit

    # Connect using the Snowflake-specific keyword for connection
    Connect To Snowflake Via DatabaseLibrary

    # Using generic Create Table keyword from sql_table_operations.resource
    ${result}=    Create Table    ${table_name}    ${table_definition}    drop_if_exists=${TRUE}
    Log    Table created successfully!    console=yes

    # Insert all data using generic Insert Into Table keyword
    FOR    ${row}    IN    @{ALL_DATA}
        Insert Into Table    ${table_name}    ${COLUMNS}    ${row}
        Log    Inserted: ${row}    console=yes
    END

    # Verify Inserted data using generic Get Row Count keyword
    ${count}=    Get Row Count    ${table_name}
    Log    Total rows inserted: ${count}    console=yes
    Should Be Equal As Integers    ${count}    5

    Log    ========== USING GENERIC SELECT ALL FROM TABLE KEYWORD ==========    console=yes
    # Using generic Select All From Table keyword
    ${results}=    Select All From Table    ${table_name}    order_by=id

    # Verify we got all 5 records
    ${row_count}=    Get Length    ${results}
    Should Be Equal As Integers    ${row_count}    5
    Log    Successfully retrieved ${row_count} records using generic keyword

    # Select specific records with WHERE clause using generic keyword
    Log    ========== USING GENERIC SELECT WHERE KEYWORD ==========    console=yes
    ${filtered_results}=    Select Where    ${table_name}    amount > 3000    order_by=amount DESC

    ${filtered_count}=    Get Length    ${filtered_results}
    Should Be Equal As Integers    ${filtered_count}    2
    Log    Found ${filtered_count} records with amount > 3000 using generic keyword    console=yes

    # Additional generic operations examples
    Log    ========== DEMONSTRATING MORE GENERIC OPERATIONS ==========    console=yes

    # Update operation using generic keyword
    # Note: set_clause and where_clause should be passed as separate arguments
    Update Table    ${table_name}    amount = 5500.00    name = 'Tom'

    # Verify the update
    ${tom_records}=    Select Where    ${table_name}    name = 'Tom'
    Log    Updated Tom's record: ${tom_records}    console=yes

    # Get column values using generic keyword
    @{names}=    Get Column Values    ${table_name}    name
    Log    All names in table: ${names}    console=yes

    # Validate row count using generic keyword
    Row Count Should Be    ${table_name}    5

    # Clean up - drop table using generic keyword
    Drop Table    ${table_name}    if_exists=${TRUE}
    Log    Table ${table_name} dropped successfully    console=yes

Compare Actual vs Expected CSV Output
    [Documentation]    Validates data integrity by comparing MySQL export against expected output
    ...    Ensures data processed through MySQL pipeline matches expectations
    ...    📋 ASSERTIONS:
    ...    • Exported MySQL CSV file exists locally
    ...    • Expected CSV file exists for comparison
    ...    • File structures are identical (headers match)
    ...    • Row counts are identical (no data loss during processing)
    ...    • All field values match exactly (no data corruption)
    ...    • No extra or missing rows (complete data processing)
    ...    • CSV formatting is preserved through pipeline
    [Tags]    snowflake_intuit
    [Template]    Compare CSV Files Template

    # Test Data: file1_path    file2_path    ignore_order    show_details    expected_status
    ${ACTUAL_DATA_DIR}/table1.csv    ${EXPECTED_OUTPUT_DIR}/table1.csv    ${FALSE}    ${TRUE}    IDENTICAL


*** Keywords ***
Check connections
    [Documentation]    Verifies snowflake database connection and Snaplex availability
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}

    Log    🔧 Initializing test environment for file mount demonstration
    Log    📋 Test ID: ${unique_id}
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect To Snowflake Cloud DB

Connect To Snowflake Cloud DB
    [Documentation]    Test connection using resource keywords
    ...    No need to set env variables - already loaded from .env
    Connect To Snowflake Via DatabaseLibrary
