*** Settings ***
Documentation       Snowflake Database Integration Tests
...                 Using snowflake_keywords.resource which wraps the SnowflakeHelper Python library
...                 Environment variables are automatically loaded from .env file via Docker

Library             Collections
Library             OperatingSystem
# Use the resource file instead of directly importing Python library
Resource            ../../../resources/snowflake2/snowflake_keywords_pythonlib.resource
Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../resources/files.resource

Suite Setup         Check connections    # Check if the connection to the MySQL database is successful and snaplex is up


*** Variables ***
${project_path}                     ${org_name}/${project_space}/${project_name}
${pipeline_file_path}               /app/src/pipelines
${expression_library_file_path}     ${org_name}/${project_space}/shared

# SnowflakePipeline details
${pipeline_name}                    snowflake
${pipeline_slp}                     snowflake.slp
${task_name}                        snowflake_task

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

# ${JSON_DATA_FILE}    ${CURDIR}/test_data/employees.json
${JSON_DATA_FILE}                   ${CURDIR}/../../test_data/actual_expected_data/input_data/snowflake/employees.json
${CSV_DATA_FILE}                    ${CURDIR}/test_data/employees.csv

# All data rows as a list of values
@{ALL_DATA}                         1, 'John', 1000.50
...                                 2, 'Jane', 2000.75
...                                 3, 'Bob', 3000.00
...                                 4, 'Alice', 4000.25
...                                 5, 'Tom', 5000.50


*** Test Cases ***
Create Account
    [Documentation]    Creates an account in the project space using the provided payload file.
    [Tags]    snowflake    snowflakeaccount    regression
    [Template]    Create Account From Template
    ${account_payload_path}/${ACCOUNT_PAYLOAD_FILE}

Upload Expression Library
    [Documentation]    Uploads the expression library to project level shared folder
    [Tags]    snowflake_pl    upload_expression_library
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
    [Tags]    snowflake_pl    regression
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name}    ${pipeline_slp}

Load JSON Data To Snowflake
    [Documentation]    Loads JSON employee data into Snowflake using the SAME template as MySQL
    ...    This proves the template is database-agnostic and works with Snowflake too!
    [Tags]    snowflake_load    json
    [Template]    Load JSON Data Template
    # JSON File    table_name    Truncate Table
    ${JSON_DATA_FILE}    ${TABLE_NAME1}    ${FALSE}    # Append to existing CSV data

Connect To Snowflake DB
    [Documentation]    Test connection using resource keywords
    ...    No need to set env variables - already loaded from .env
    [Tags]    snowflake6    connection

    # Connect using the resource keyword - it reads from environment
    snowflake_keywords.Connect To Snowflake Db
    ${result}=    Create Table    ${table_name}    ${table_definition}
    Log    Table created successfully!    console=yes

    # Insert all data using loop
    FOR    ${row}    IN    @{ALL_DATA}
        Insert Into Snowflake Table    ${table_name}    ${COLUMNS}    ${row}
        Log    Inserted: ${row}    console=yes
    END

    # Verify Inserved data
    ${count}=    Get Row Count From Snowflake Table    ${table_name}
    Log    Total rows inserted: ${count}    console=yes
    Should Be Equal As Integers    ${count}    5

    Log    ========== USING SELECT ALL RECORDS KEYWORD ==========    console=yes
    ${results}=    Select All Records From Table    ${table_name}    order_by=id

    # Verify we got all 5 records
    ${row_count}=    Get Length    ${results}
    Should Be Equal As Integers    ${row_count}    5
    Log    Successfully retrieved ${row_count} records using keyword    console=yes

    # Select specific records with WHERE clause using the new keyword
    Log    ========== USING SELECT WITH WHERE CLAUSE KEYWORD ==========    console=yes
    ${filtered_results}=    Select Records With Where Clause    ${TABLE_NAME}    amount > 3000    order_by=amount DESC

    ${filtered_count}=    Get Length    ${filtered_results}
    Should Be Equal As Integers    ${filtered_count}    2
    Log    Found ${filtered_count} records with amount > 3000 using keyword    console=yes


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

    snowflake_keywords.Connect To Snowflake Db
