*** Settings ***
Documentation       SQL Table Operations Resource File
...                 Contains all database-agnostic keywords for common SQL operations:
...                 - Table management (create, drop, truncate, rename)
...                 - CRUD operations (insert, update, delete, select)
...                 - Query execution and result processing
...                 - Table structure operations (columns, indexes, constraints)
...                 - Data validation and verification
...                 - Transaction management
...                 - Data export/import (CSV, JSON)
...
...                 Prerequisites:
...                 - DatabaseLibrary must be installed
...                 - Database connection must be established before using these keywords
...                 - Use database_connections.resource or database-specific resource files for connections
...
...                 Usage Example:
...                 | *** Settings ***
...                 | Resource    database_connections.resource
...                 | Resource    sql_operations.resource
...                 |
...                 | *** Test Cases ***
...                 | Test CRUD Operations
...                 |    Connect to Postgres Database    mydb    user    pass    localhost
...                 |    Create Table    employees    (id INT, name VARCHAR(100))
...                 |    Insert Into Table    employees    id, name    1, 'John'
...                 |    ${count}=    Get Row Count    employees
...                 |    Should Be Equal As Integers    ${count}    1
...                 |    Disconnect from Database

Library             DatabaseLibrary
Library             Collections
Library             String
Library             BuiltIn
Library             OperatingSystem
Resource            files.resource


*** Variables ***
${DB_TYPE}      ${NONE}


*** Keywords ***
# ==================== HELPER OPERATIONS ====================

Get Qualified Table Name
    [Documentation]    Returns fully qualified table name with schema if provided
    ...    Handles cases where table_name already includes schema (schema.table)
    ...    Arguments:
    ...    - table_name: Table name (may already include schema)
    ...    - schema: Optional schema to prepend (ignored if table_name already has schema)
    [Arguments]    ${table_name}    ${schema}=${EMPTY}

    ${has_schema}=    Run Keyword And Return Status    Should Contain    ${table_name}    .

    IF    ${has_schema}
        RETURN    ${table_name}
    ELSE IF    '${schema}' != '${EMPTY}'
        RETURN    ${schema}.${table_name}
    ELSE
        RETURN    ${table_name}
    END

# ==================== TABLE MANAGEMENT OPERATIONS ====================

Create Table
    [Documentation]    Creates a table with the specified definition
    ...    Arguments:
    ...    - table_name: Name of the table to create (can include schema)
    ...    - table_definition: SQL column definitions (e.g., "(id INT, name VARCHAR(100))")
    ...    - drop_if_exists: If TRUE, drops existing table before creating (default: TRUE)
    ...    - schema: Optional schema name (if not included in table_name)
    [Arguments]    ${table_name}    ${table_definition}    ${drop_if_exists}=${TRUE}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    Log    Creating table: ${qualified_name}    console=yes

    IF    ${drop_if_exists}
        Drop Table    ${table_name}    if_exists=${TRUE}    schema=${schema}
    END

    ${create_sql}=    Set Variable    CREATE TABLE ${qualified_name} ${table_definition}
    Execute Sql String    ${create_sql}
    Log    Table ${qualified_name} created successfully    console=yes
    RETURN    ${TRUE}

Create Table If Not Exists
    [Documentation]    Creates a table only if it doesn't already exist
    ...    Note: Not all databases support IF NOT EXISTS clause
    [Arguments]    ${table_name}    ${table_definition}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${create_sql}=    Set Variable    CREATE TABLE IF NOT EXISTS ${qualified_name} ${table_definition}
    Execute Sql String    ${create_sql}
    Log    Table ${qualified_name} created (if not exists)    console=yes
    RETURN    ${TRUE}

Create Table From Template
    [Documentation]    Creates table using SQL from template or direct SQL statement
    [Arguments]    ${sql_query}

    Log    Creating table from template...    console=yes
    Log    SQL: ${sql_query}    console=yes

    Execute SQL String Safe    ${sql_query}
    Log    Table created successfully    console=yes

Drop Table
    [Documentation]    Drops a table from the database
    ...    Arguments:
    ...    - table_name: Table name (can be 'table' or 'schema.table')
    ...    - if_exists: Whether to use IF EXISTS clause (default: TRUE)
    ...    - schema: Optional schema name (if not included in table_name)
    [Arguments]    ${table_name}    ${if_exists}=${TRUE}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}

    IF    ${if_exists}
        Execute Sql String    DROP TABLE IF EXISTS ${qualified_name}
        Log    Executed: DROP TABLE IF EXISTS ${qualified_name}    console=yes
    ELSE
        Execute Sql String    DROP TABLE ${qualified_name}
        Log    Executed: DROP TABLE ${qualified_name}    console=yes
    END

    Log    Table ${qualified_name} dropped successfully    console=yes
    RETURN    ${TRUE}

Drop Table If Exists
    [Documentation]    Safely drops a table if it exists (with optional CASCADE)
    [Arguments]    ${table_name}    ${cascade}=${FALSE}

    Log    Dropping table if exists: ${table_name}    console=yes

    ${cascade_clause}=    Set Variable If    ${cascade}    CASCADE    ${EMPTY}
    ${sql}=    Set Variable    DROP TABLE IF EXISTS ${table_name} ${cascade_clause}

    Execute SQL String Safe    ${sql}
    Log    Table '${table_name}' dropped successfully    console=yes

Truncate Table
    [Documentation]    Removes all rows from a table but keeps the table structure
    ...    Arguments:
    ...    - table_name: Table name (can include schema)
    ...    - schema: Optional schema name (if not included in table_name)
    [Arguments]    ${table_name}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    Execute Sql String    TRUNCATE TABLE ${qualified_name}
    Log    Table ${qualified_name} truncated    console=yes
    RETURN    ${TRUE}

Truncate Table If Exists
    [Documentation]    Removes all rows from a table but keeps the table structure
    ...    If table doesn't exist, logs a warning and continues without failing
    ...    Arguments:
    ...    - table_name: Table name (can include schema)
    ...    - schema: Optional schema name
    ...    - verify_empty: Whether to verify table is empty after truncation (default: TRUE)
    ...    Returns: ${TRUE} if truncated, ${FALSE} if table doesn't exist
    [Arguments]    ${table_name}    ${schema}=${EMPTY}    ${verify_empty}=${TRUE}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    Log    Attempting to truncate table: ${qualified_name}    console=yes

    TRY
        Execute Sql String    TRUNCATE TABLE ${qualified_name}
        Log    Table ${qualified_name} truncated successfully    console=yes

        IF    ${verify_empty}
            Log    Verifying table is empty after truncation...    console=yes
            ${count_after_truncate}=    Get Row Count    ${table_name}    schema=${schema}
            Should Be Equal As Integers    ${count_after_truncate}    0
            ...    TRUNCATE operation completed but table still has ${count_after_truncate} rows! Expected 0 rows.
            Log    Verification passed: Table has 0 rows after truncation    console=yes
        END
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    Could not truncate table ${qualified_name}: ${error}    level=WARN
        Log    Table may not exist or insufficient permissions    console=yes
        RETURN    ${FALSE}
    END

Rename Table
    [Documentation]    Renames a table
    ...    Note: Syntax may vary between databases
    [Arguments]    ${old_table_name}    ${new_table_name}    ${schema}=${EMPTY}

    ${old_qualified}=    Get Qualified Table Name    ${old_table_name}    ${schema}
    ${new_qualified}=    Get Qualified Table Name    ${new_table_name}    ${schema}

    Execute Sql String    ALTER TABLE ${old_qualified} RENAME TO ${new_qualified}
    Log    Table renamed from ${old_qualified} to ${new_qualified}    console=yes
    RETURN    ${TRUE}

# ==================== DATA MANIPULATION OPERATIONS (CRUD) ====================

Insert Into Table
    [Documentation]    Inserts a single row into a table
    ...    Arguments:
    ...    - table_name: Target table (can include schema)
    ...    - columns: Comma-separated column names
    ...    - values: Values to insert (with proper SQL formatting)
    ...    - schema: Optional schema name
    [Arguments]    ${table_name}    ${columns}    ${values}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${insert_sql}=    Set Variable    INSERT INTO ${qualified_name} (${columns}) VALUES (${values})
    Execute Sql String    ${insert_sql}
    Log    Data inserted into ${qualified_name}    console=yes
    RETURN    ${TRUE}

Bulk Insert Into Table
    [Documentation]    Inserts multiple rows into a table
    ...    Arguments:
    ...    - table_name: Target table
    ...    - columns: Comma-separated column names
    ...    - rows: List of value strings
    [Arguments]    ${table_name}    ${columns}    @{rows}

    ${row_count}=    Set Variable    ${0}
    FOR    ${row}    IN    @{rows}
        Insert Into Table    ${table_name}    ${columns}    ${row}
        ${row_count}=    Evaluate    ${row_count} + 1
    END

    Log    Inserted ${row_count} rows into ${table_name}    console=yes
    RETURN    ${row_count}

Update Table
    [Documentation]    Updates rows in a table based on a condition
    ...    Arguments:
    ...    - table_name: Name of the table to update
    ...    - set_clause: SET clause (e.g., "column1 = value1, column2 = value2")
    ...    - where_clause: Optional WHERE condition
    ...    - schema: Optional schema name
    [Arguments]    ${table_name}    ${set_clause}    ${where_clause}=${EMPTY}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}

    IF    ${is_empty}
        ${update_sql}=    Set Variable    UPDATE ${qualified_name} SET ${set_clause}
        Log    WARNING: Updating ALL rows in ${qualified_name} (no WHERE clause)    WARN
    ELSE
        ${update_sql}=    Set Variable    UPDATE ${qualified_name} SET ${set_clause} WHERE ${where_clause}
    END

    Log    Executing: ${update_sql}    console=yes
    Execute Sql String    ${update_sql}
    Log    Table ${qualified_name} updated successfully    console=yes
    RETURN    ${TRUE}

Delete From Table
    [Documentation]    Deletes rows from a table based on a condition
    ...    If no where_clause provided, deletes all rows (use with caution!)
    [Arguments]    ${table_name}    ${where_clause}=${EMPTY}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}

    IF    ${is_empty}
        ${delete_sql}=    Set Variable    DELETE FROM ${qualified_name}
        Log    WARNING: Deleting ALL rows from ${qualified_name}    WARN
    ELSE
        ${delete_sql}=    Set Variable    DELETE FROM ${qualified_name} WHERE ${where_clause}
    END

    Execute Sql String    ${delete_sql}
    Log    Rows deleted from ${qualified_name}    console=yes
    RETURN    ${TRUE}

Upsert Into Table
    [Documentation]    Insert or update based on primary key (database-specific)
    ...    Note: Actual syntax varies by database (MySQL, PostgreSQL, Snowflake)
    [Arguments]    ${table_name}    ${columns}    ${values}    ${update_clause}

    Log    UPSERT operation varies by database type    WARN
    Log    Using standard INSERT for now - override this keyword for specific databases    console=yes
    Insert Into Table    ${table_name}    ${columns}    ${values}
    RETURN    ${TRUE}

# ==================== QUERY OPERATIONS ====================

Select All From Table
    [Documentation]    Selects all records from a table
    ...    Arguments:
    ...    - table_name: Table name (can include schema)
    ...    - columns: Columns to select (default: *)
    ...    - order_by: Optional ORDER BY clause
    ...    - limit: Optional LIMIT clause
    ...    - schema: Optional schema name
    [Arguments]    ${table_name}    ${columns}=*    ${order_by}=${EMPTY}    ${limit}=${EMPTY}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${query}=    Set Variable    SELECT ${columns} FROM ${qualified_name}

    ${has_order_by}=    Run Keyword And Return Status    Should Not Be Empty    ${order_by}
    IF    ${has_order_by}
        ${query}=    Set Variable    ${query} ORDER BY ${order_by}
    END

    ${has_limit}=    Run Keyword And Return Status    Should Not Be Empty    ${limit}
    IF    ${has_limit}
        ${query}=    Set Variable    ${query} LIMIT ${limit}
    END

    Log    Executing: ${query}    console=yes
    ${results}=    Query    ${query}

    ${row_count}=    Get Length    ${results}
    Log    Retrieved ${row_count} records from ${table_name}    console=yes
    RETURN    ${results}

Select Where
    [Documentation]    Selects records based on a WHERE condition
    [Arguments]
    ...    ${table_name}
    ...    ${where_clause}
    ...    ${columns}=*
    ...    ${order_by}=${EMPTY}
    ...    ${limit}=${EMPTY}
    ...    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${query}=    Set Variable    SELECT ${columns} FROM ${qualified_name} WHERE ${where_clause}

    ${has_order_by}=    Run Keyword And Return Status    Should Not Be Empty    ${order_by}
    IF    ${has_order_by}
        ${query}=    Set Variable    ${query} ORDER BY ${order_by}
    END

    ${has_limit}=    Run Keyword And Return Status    Should Not Be Empty    ${limit}
    IF    ${has_limit}
        ${query}=    Set Variable    ${query} LIMIT ${limit}
    END

    Log    Executing: ${query}    console=yes
    ${results}=    Query    ${query}

    ${row_count}=    Get Length    ${results}
    Log    Retrieved ${row_count} records matching condition    console=yes
    RETURN    ${results}

Get Row Count
    [Documentation]    Returns the number of rows in a table
    ...    Arguments:
    ...    - table_name: Table name (can include schema)
    ...    - where_clause: Optional WHERE condition
    ...    - schema: Optional schema name
    [Arguments]    ${table_name}    ${where_clause}=${EMPTY}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}

    IF    ${is_empty}
        ${query}=    Set Variable    SELECT COUNT(*) FROM ${qualified_name}
    ELSE
        ${query}=    Set Variable    SELECT COUNT(*) FROM ${qualified_name} WHERE ${where_clause}
    END

    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}

    Log    Row count for ${table_name}: ${count}    console=yes
    RETURN    ${count}

Get Table Row Count
    [Documentation]    Gets the total number of rows in a table (alias for Get Row Count)
    [Arguments]    ${table_name}

    ${query}=    Set Variable    SELECT COUNT(*) FROM ${table_name}
    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}

    Log    Table '${table_name}' contains ${count} rows    console=yes
    RETURN    ${count}

Get Column Values
    [Documentation]    Returns all values from a specific column
    [Arguments]
    ...    ${table_name}
    ...    ${column_name}
    ...    ${distinct}=${FALSE}
    ...    ${where_clause}=${EMPTY}
    ...    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}

    IF    ${distinct}
        ${select_part}=    Set Variable    SELECT DISTINCT ${column_name}
    ELSE
        ${select_part}=    Set Variable    SELECT ${column_name}
    END

    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}

    IF    ${is_empty}
        ${query}=    Set Variable    ${select_part} FROM ${qualified_name}
    ELSE
        ${query}=    Set Variable    ${select_part} FROM ${qualified_name} WHERE ${where_clause}
    END

    ${results}=    Query    ${query}

    @{values}=    Create List
    FOR    ${row}    IN    @{results}
        Append To List    ${values}    ${row[0]}
    END

    ${count}=    Get Length    ${values}
    Log    Retrieved ${count} values from column ${column_name}    console=yes
    RETURN    ${values}

Execute Custom Query
    [Documentation]    Executes any SELECT query and returns results
    [Arguments]    ${query}

    Log    Executing custom query: ${query}    console=yes
    ${results}=    Query    ${query}

    ${row_count}=    Get Length    ${results}
    Log    Query returned ${row_count} rows    console=yes
    RETURN    ${results}

Execute Custom Command
    [Documentation]    Executes any SQL command (DDL/DML) without returning results
    [Arguments]    ${command}

    Log    Executing command: ${command}    console=yes
    Execute Sql String    ${command}
    Log    Command executed successfully    console=yes
    RETURN    ${TRUE}

Execute SQL Query And Get Count
    [Documentation]    Executes a COUNT query and returns the result as integer
    [Arguments]    ${sql_query}

    Log    Executing count query: ${sql_query}    console=yes

    ${result}=    Query    ${sql_query}
    ${count_row}=    Get From List    ${result}    0
    ${count_value}=    Get From List    ${count_row}    0

    Log    Count query result: ${count_value}    console=yes
    RETURN    ${count_value}

Execute SQL Query And Get Results
    [Documentation]    Executes SQL query and returns all results
    [Arguments]    ${sql_query}    ${fetch_all}=${TRUE}

    Log    Executing query: ${sql_query}    console=yes

    TRY
        IF    ${fetch_all}
            ${results}=    Query    ${sql_query}
        ELSE
            ${results}=    Query    ${sql_query}    returnAsDict=${TRUE}
        END

        ${row_count}=    Get Length    ${results}
        Log    Query returned ${row_count} rows    console=yes
        RETURN    ${results}
    EXCEPT    AS    ${error}
        Log    Query execution failed: ${error}    console=yes
        Fail    Query execution failed: ${error}
    END

Execute SQL Query And Get Single Value
    [Documentation]    Executes SQL query and returns single scalar value
    [Arguments]    ${sql_query}

    Log    Executing single value query: ${sql_query}    console=yes

    ${results}=    Query    ${sql_query}
    ${row_count}=    Get Length    ${results}

    Should Be Equal As Numbers    ${row_count}    1
    ...    Query should return exactly 1 row, but returned ${row_count}

    ${first_row}=    Get From List    ${results}    0
    ${value}=    Get From List    ${first_row}    0

    Log    Single value result: ${value}    console=yes
    RETURN    ${value}

# ==================== SQL EXECUTION WITH ERROR HANDLING ====================

Execute SQL String Safe
    [Documentation]    Safely executes SQL string with error handling
    [Arguments]    ${sql_statement}

    Log    Executing SQL statement...    console=yes
    Log    SQL: ${sql_statement}    console=yes

    TRY
        Execute SQL String    ${sql_statement}
        Log    SQL statement executed successfully    console=yes
    EXCEPT    AS    ${error}
        Log    SQL execution failed: ${error}    console=yes
        Fail    SQL execution failed: ${error}
    END

Execute SQL Script From File
    [Documentation]    Executes SQL statements from a script file
    [Arguments]    ${script_path}

    File Should Exist    ${script_path}
    ${sql_content}=    Get File    ${script_path}
    Log    Executing SQL script: ${script_path}    console=yes

    ${sql_statements}=    Split SQL Script Content    ${sql_content}

    ${executed_count}=    Set Variable    0
    FOR    ${statement}    IN    @{sql_statements}
        ${trimmed_statement}=    Strip String    ${statement}
        IF    '${trimmed_statement}' != '' and not '${trimmed_statement}'.startswith('--')
            Log    Executing: ${trimmed_statement}    console=yes
            Execute SQL String Safe    ${trimmed_statement}
            ${executed_count}=    Evaluate    ${executed_count} + 1
        END
    END

    Log    SQL script executed successfully (${executed_count} statements)    console=yes

Split SQL Script Content
    [Documentation]    Splits SQL script content into individual executable statements
    [Arguments]    ${sql_content}

    ${lines}=    Split To Lines    ${sql_content}
    ${cleaned_lines}=    Create List

    FOR    ${line}    IN    @{lines}
        ${trimmed_line}=    Strip String    ${line}
        IF    not '${trimmed_line}'.startswith('--') and '${trimmed_line}' != ''
            Append To List    ${cleaned_lines}    ${trimmed_line}
        END
    END

    ${cleaned_sql}=    Catenate    SEPARATOR= ${SPACE}    @{cleaned_lines}
    ${statements}=    Split String    ${cleaned_sql}    ;

    ${filtered_statements}=    Create List
    FOR    ${stmt}    IN    @{statements}
        ${trimmed_stmt}=    Strip String    ${stmt}
        IF    '${trimmed_stmt}' != ''
            Append To List    ${filtered_statements}    ${trimmed_stmt}
        END
    END

    Log    Split SQL script into ${filtered_statements.__len__()} statements    console=yes
    RETURN    ${filtered_statements}

Execute SQL File
    [Documentation]    Executes SQL statements from a file
    [Arguments]    ${file_path}    ${delimiter}=;

    ${file_content}=    Get File    ${file_path}
    @{statements}=    Split String    ${file_content}    ${delimiter}

    ${success}    ${errors}=    Execute SQL Script    @{statements}

    Log    Executed SQL file: ${file_path}    console=yes
    RETURN    ${success}    ${errors}

Execute SQL Script
    [Documentation]    Executes multiple SQL statements from a list
    [Arguments]    @{statements}

    ${success_count}=    Set Variable    ${0}
    ${error_count}=    Set Variable    ${0}

    FOR    ${statement}    IN    @{statements}
        ${clean_statement}=    Strip String    ${statement}

        IF    '${clean_statement}' == ''    CONTINUE
        IF    $clean_statement.startswith('--')    CONTINUE
        IF    $clean_statement.startswith('#')    CONTINUE

        Log    Executing: ${clean_statement}    console=yes

        TRY
            Execute Sql String    ${clean_statement}
            ${success_count}=    Evaluate    ${success_count} + 1
            Log    Statement executed successfully    console=yes
        EXCEPT    AS    ${error}
            ${error_count}=    Evaluate    ${error_count} + 1
            Log    Statement failed: ${error}    WARN
        END
    END

    Log    Script execution complete: ${success_count} successful, ${error_count} failed    console=yes
    RETURN    ${success_count}    ${error_count}

Execute SQL Template
    [Documentation]    Executes SQL with variable substitution from template
    [Arguments]    ${sql_template}    &{variables}

    Log    Executing SQL template with variables...    console=yes
    Log    Variables: ${variables}    console=yes

    ${sql_with_vars}=    Set Variable    ${sql_template}
    FOR    ${var_name}    ${var_value}    IN    &{variables}
        ${sql_with_vars}=    Replace String    ${sql_with_vars}    {${var_name}}    ${var_value}
    END

    Log    Final SQL: ${sql_with_vars}    console=yes
    Execute SQL String Safe    ${sql_with_vars}
    Log    SQL template executed successfully    console=yes

# ==================== TABLE STRUCTURE OPERATIONS ====================

Add Column To Table
    [Documentation]    Adds a new column to an existing table
    [Arguments]    ${table_name}    ${column_name}    ${column_definition}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ADD COLUMN ${column_name} ${column_definition}
    Execute Sql String    ${alter_sql}
    Log    Column ${column_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Drop Column From Table
    [Documentation]    Removes a column from a table
    [Arguments]    ${table_name}    ${column_name}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} DROP COLUMN ${column_name}
    Execute Sql String    ${alter_sql}
    Log    Column ${column_name} dropped from ${table_name}    console=yes
    RETURN    ${TRUE}

Modify Column
    [Documentation]    Modifies a column definition
    ...    Note: Syntax varies between databases (MODIFY/ALTER COLUMN)
    [Arguments]    ${table_name}    ${column_name}    ${new_definition}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ALTER COLUMN ${column_name} ${new_definition}
    Execute Sql String    ${alter_sql}
    Log    Column ${column_name} modified in ${table_name}    console=yes
    RETURN    ${TRUE}

Rename Column
    [Documentation]    Renames a column in a table
    [Arguments]    ${table_name}    ${old_column_name}    ${new_column_name}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} RENAME COLUMN ${old_column_name} TO ${new_column_name}
    Execute Sql String    ${alter_sql}
    Log    Column renamed from ${old_column_name} to ${new_column_name}    console=yes
    RETURN    ${TRUE}

Get Table Columns
    [Documentation]    Gets column names from database table
    ...    Can accept table name in format: table_name or schema.table_name
    [Arguments]    ${table_name}    ${schema}=${NONE}

    ${contains_dot}=    Run Keyword And Return Status    Should Contain    ${table_name}    .
    IF    ${contains_dot}
        ${parts}=    Split String    ${table_name}    .
        ${schema}=    Get From List    ${parts}    0
        ${table}=    Get From List    ${parts}    1
    ELSE
        ${table}=    Set Variable    ${table_name}
        IF    '${schema}' == '${NONE}' or '${schema}' == 'public' or '${schema}' == ''
            ${schema}=    Get Default Schema
        END
    END

    Log    Looking for columns in table: ${table}, schema: ${schema}

    ${columns}=    Create List

    # Approach 1: Try with the standard query
    ${query}=    Get Columns Query    ${table}    ${schema}
    Log    Trying query: ${query}
    ${result}=    Run Keyword And Ignore Error    Query    ${query}

    IF    '${result[0]}' == 'PASS' and ${result[1]} != @{EMPTY}
        FOR    ${row}    IN    @{result[1]}
            ${column}=    Get From List    ${row}    0
            Append To List    ${columns}    ${column}
        END
    END

    # Approach 2: Try with uppercase table name (Snowflake specific)
    IF    ${columns} == @{EMPTY}
        ${upper_table}=    Convert To Upper Case    ${table}
        ${query_upper}=    Set Variable
        ...    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${upper_table}' AND TABLE_SCHEMA = CURRENT_SCHEMA() ORDER BY ORDINAL_POSITION
        Log    Trying uppercase query: ${query_upper}
        ${result_upper}=    Run Keyword And Ignore Error    Query    ${query_upper}

        IF    '${result_upper[0]}' == 'PASS' and ${result_upper[1]} != @{EMPTY}
            FOR    ${row}    IN    @{result_upper[1]}
                ${column}=    Get From List    ${row}    0
                Append To List    ${columns}    ${column}
            END
        END
    END

    # Approach 3: Try without schema restriction
    IF    ${columns} == @{EMPTY}
        ${upper_table}=    Convert To Upper Case    ${table}
        ${query_no_schema}=    Set Variable
        ...    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${upper_table}' ORDER BY ORDINAL_POSITION
        Log    Trying without schema restriction: ${query_no_schema}
        ${result_no_schema}=    Run Keyword And Ignore Error    Query    ${query_no_schema}

        IF    '${result_no_schema[0]}' == 'PASS' and ${result_no_schema[1]} != @{EMPTY}
            FOR    ${row}    IN    @{result_no_schema[1]}
                ${column}=    Get From List    ${row}    0
                Append To List    ${columns}    ${column}
            END
        END
    END

    # Approach 4: Try DESCRIBE TABLE for Snowflake
    IF    ${columns} == @{EMPTY}
        Log    Trying DESCRIBE TABLE approach for Snowflake
        ${desc_result}=    Run Keyword And Ignore Error    Query    DESCRIBE TABLE ${table}

        IF    '${desc_result[0]}' == 'PASS' and ${desc_result[1]} != @{EMPTY}
            FOR    ${row}    IN    @{desc_result[1]}
                ${column}=    Get From List    ${row}    0
                ${column_lower}=    Convert To Lower Case    ${column}
                Append To List    ${columns}    ${column_lower}
            END
        END
    END

    IF    ${columns} == @{EMPTY}
        Log    WARNING: No columns found for table ${table} in schema ${schema}.    level=WARN
    ELSE
        Log    Found columns: ${columns}
    END

    RETURN    ${columns}

Get Table Schema Info
    [Documentation]    Gets detailed schema information for a table
    [Arguments]    ${table_name}    ${schema}=public

    Log    Getting schema info for table: ${table_name}    console=yes

    ${query}=    Set Variable
    ...    SELECT column_name, data_type, is_nullable, column_default, character_maximum_length
    ...    FROM information_schema.columns
    ...    WHERE table_schema='${schema}' AND table_name='${table_name}'
    ...    ORDER BY ordinal_position

    ${results}=    Execute SQL Query And Get Results    ${query}

    Log    Schema info for '${table_name}': ${results.__len__()} columns    console=yes
    RETURN    ${results}

Check If Table Exists
    [Documentation]    Checks if a table exists in the database
    [Arguments]    ${table_name}    ${schema}=public

    ${query}=    Set Variable
    ...    SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${schema}' AND table_name='${table_name}'

    ${count}=    Execute SQL Query And Get Count    ${query}
    ${exists}=    Evaluate    ${count} > 0

    IF    ${exists}
        Log    Table '${table_name}' exists in schema '${schema}'    console=yes
    ELSE
        Log    Table '${table_name}' does not exist in schema '${schema}'    console=yes
    END

    RETURN    ${exists}

Get Default Schema
    [Documentation]    Returns default schema based on database type
    ${db_type}=    Get Database Type
    IF    '${db_type}' == 'SQLSERVER'
        RETURN    dbo
    ELSE IF    '${db_type}' == 'POSTGRESQL'
        RETURN    public
    ELSE IF    '${db_type}' == 'MYSQL'
        RETURN    DATABASE()
    ELSE
        RETURN    CURRENT_SCHEMA()
    END

Get Database Type
    [Documentation]    Returns cached or detected database type
    IF    '${DB_TYPE}' != '${NONE}'    RETURN    ${DB_TYPE}

    ${is_snowflake}=    Run Keyword And Return Status    Query    SELECT CURRENT_WAREHOUSE()
    IF    ${is_snowflake}
        Set Suite Variable    ${DB_TYPE}    SNOWFLAKE
        RETURN    SNOWFLAKE
    END

    ${is_oracle}=    Run Keyword And Return Status    Query    SELECT * FROM v$version WHERE ROWNUM = 1
    IF    ${is_oracle}
        Set Suite Variable    ${DB_TYPE}    ORACLE
        RETURN    ORACLE
    END

    ${is_sqlserver}=    Run Keyword And Return Status    Query    SELECT @@VERSION
    IF    ${is_sqlserver}
        Set Suite Variable    ${DB_TYPE}    SQLSERVER
        RETURN    SQLSERVER
    END

    ${is_postgres}=    Run Keyword And Return Status    Query    SELECT current_database()
    IF    ${is_postgres}
        Set Suite Variable    ${DB_TYPE}    POSTGRESQL
        RETURN    POSTGRESQL
    END

    ${is_mysql}=    Run Keyword And Return Status    Query    SELECT @@version_comment
    IF    ${is_mysql}
        Set Suite Variable    ${DB_TYPE}    MYSQL
        RETURN    MYSQL
    END

    Set Suite Variable    ${DB_TYPE}    GENERIC
    RETURN    GENERIC

Get Columns Query
    [Documentation]    Returns appropriate query based on database type
    [Arguments]    ${table}    ${schema}

    ${db_type}=    Get Database Type

    IF    '${db_type}' == 'SNOWFLAKE'
        ${upper_table}=    Convert To Upper Case    ${table}
        RETURN    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${upper_table}' AND TABLE_SCHEMA = CURRENT_SCHEMA() ORDER BY ORDINAL_POSITION
    ELSE IF    '${db_type}' == 'ORACLE'
        ${upper_table}=    Convert To Upper Case    ${table}
        ${upper_schema}=    Convert To Upper Case    ${schema}
        RETURN    SELECT COLUMN_NAME FROM ALL_TAB_COLUMNS WHERE TABLE_NAME = '${upper_table}' AND OWNER = '${upper_schema}' ORDER BY COLUMN_ID
    ELSE IF    '${db_type}' == 'SQLSERVER'
        RETURN    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${table}' AND TABLE_SCHEMA = '${schema}' AND COLUMN_NAME != 'ID' ORDER BY ORDINAL_POSITION
    ELSE IF    '${db_type}' == 'POSTGRESQL'
        RETURN    SELECT column_name FROM information_schema.columns WHERE table_name = lower('${table}') AND table_schema = lower('${schema}') AND column_name != 'id' ORDER BY ordinal_position
    ELSE IF    '${db_type}' == 'MYSQL'
        RETURN    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${table}' AND TABLE_SCHEMA = DATABASE() ORDER BY ORDINAL_POSITION
    ELSE
        RETURN    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE LOWER(TABLE_NAME) = LOWER('${table}') AND LOWER(TABLE_SCHEMA) = LOWER('${schema}') AND UPPER(COLUMN_NAME) != 'ID' ORDER BY ORDINAL_POSITION
    END

# ==================== INDEX OPERATIONS ====================

Create Index
    [Documentation]    Creates an index on a table
    [Arguments]    ${index_name}    ${table_name}    ${columns}    ${unique}=${FALSE}

    IF    ${unique}
        ${create_sql}=    Set Variable    CREATE UNIQUE INDEX ${index_name} ON ${table_name} (${columns})
    ELSE
        ${create_sql}=    Set Variable    CREATE INDEX ${index_name} ON ${table_name} (${columns})
    END

    Execute Sql String    ${create_sql}
    Log    Index ${index_name} created on ${table_name}    console=yes
    RETURN    ${TRUE}

Drop Index
    [Documentation]    Drops an index
    ...    Note: Syntax varies between databases
    [Arguments]    ${index_name}    ${table_name}=${EMPTY}

    IF    '${table_name}' != '${EMPTY}'
        ${drop_sql}=    Set Variable    DROP INDEX ${index_name} ON ${table_name}
    ELSE
        ${drop_sql}=    Set Variable    DROP INDEX ${index_name}
    END

    Execute Sql String    ${drop_sql}
    Log    Index ${index_name} dropped    console=yes
    RETURN    ${TRUE}

# ==================== VIEW OPERATIONS ====================

Create View
    [Documentation]    Creates a view based on a SELECT query
    [Arguments]    ${view_name}    ${select_query}    ${replace}=${TRUE}

    IF    ${replace}
        ${create_sql}=    Set Variable    CREATE OR REPLACE VIEW ${view_name} AS ${select_query}
    ELSE
        ${create_sql}=    Set Variable    CREATE VIEW ${view_name} AS ${select_query}
    END

    Execute Sql String    ${create_sql}
    Log    View ${view_name} created    console=yes
    RETURN    ${TRUE}

Drop View
    [Documentation]    Drops a view
    [Arguments]    ${view_name}    ${if_exists}=${TRUE}

    IF    ${if_exists}
        Execute Sql String    DROP VIEW IF EXISTS ${view_name}
    ELSE
        Execute Sql String    DROP VIEW ${view_name}
    END

    Log    View ${view_name} dropped    console=yes
    RETURN    ${TRUE}

# ==================== CONSTRAINT OPERATIONS ====================

Add Primary Key
    [Documentation]    Adds a primary key constraint to a table
    [Arguments]    ${table_name}    ${constraint_name}    ${columns}

    ${alter_sql}=    Set Variable
    ...    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} PRIMARY KEY (${columns})
    Execute Sql String    ${alter_sql}
    Log    Primary key ${constraint_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Add Foreign Key
    [Documentation]    Adds a foreign key constraint
    [Arguments]    ${table_name}    ${constraint_name}    ${column}    ${ref_table}    ${ref_column}

    ${alter_sql}=    Set Variable
    ...    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} FOREIGN KEY (${column}) REFERENCES ${ref_table}(${ref_column})
    Execute Sql String    ${alter_sql}
    Log    Foreign key ${constraint_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Add Unique Constraint
    [Documentation]    Adds a unique constraint to columns
    [Arguments]    ${table_name}    ${constraint_name}    ${columns}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} UNIQUE (${columns})
    Execute Sql String    ${alter_sql}
    Log    Unique constraint ${constraint_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Drop Constraint
    [Documentation]    Drops a constraint from a table
    [Arguments]    ${table_name}    ${constraint_name}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} DROP CONSTRAINT ${constraint_name}
    Execute Sql String    ${alter_sql}
    Log    Constraint ${constraint_name} dropped from ${table_name}    console=yes
    RETURN    ${TRUE}

# ==================== VALIDATION OPERATIONS ====================

Table Should Exist
    [Documentation]    Verifies that a table exists in the database
    [Arguments]    ${table_name}    ${schema}=${EMPTY}

    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable
        ...    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}')
    ELSE
        ${query}=    Set Variable
        ...    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(table_schema) = UPPER('${schema}')
    END

    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}

    Should Be True    ${count} > 0    Table ${table_name} does not exist
    Log    Table ${table_name} exists    console=yes
    RETURN    ${TRUE}

Table Should Not Exist
    [Documentation]    Verifies that a table does not exist in the database
    [Arguments]    ${table_name}    ${schema}=${EMPTY}

    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable
        ...    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}')
    ELSE
        ${query}=    Set Variable
        ...    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(table_schema) = UPPER('${schema}')
    END

    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}

    Should Be Equal As Integers    ${count}    0    Table ${table_name} exists but should not
    Log    Table ${table_name} does not exist    console=yes
    RETURN    ${TRUE}

Column Should Exist
    [Documentation]    Verifies that a column exists in a table
    [Arguments]    ${table_name}    ${column_name}    ${schema}=${EMPTY}

    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable
        ...    SELECT COUNT(*) FROM information_schema.columns WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(column_name) = UPPER('${column_name}')
    ELSE
        ${query}=    Set Variable
        ...    SELECT COUNT(*) FROM information_schema.columns WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(column_name) = UPPER('${column_name}') AND UPPER(table_schema) = UPPER('${schema}')
    END

    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}

    Should Be True    ${count} > 0    Column ${column_name} does not exist in table ${table_name}
    Log    Column ${column_name} exists in ${table_name}    console=yes
    RETURN    ${TRUE}

Row Count Should Be
    [Documentation]    Verifies that a table has the expected number of rows
    [Arguments]    ${table_name}    ${expected_count}    ${where_clause}=${EMPTY}

    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}

    Should Be Equal As Integers    ${actual_count}    ${expected_count}
    ...    Table ${table_name} has ${actual_count} rows, expected ${expected_count}

    Log    Row count verified: ${actual_count} rows    console=yes
    RETURN    ${TRUE}

Row Count Should Be Greater Than
    [Documentation]    Verifies that row count is greater than a threshold
    [Arguments]    ${table_name}    ${min_count}    ${where_clause}=${EMPTY}

    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}

    Should Be True    ${actual_count} > ${min_count}
    ...    Table ${table_name} has ${actual_count} rows, expected more than ${min_count}

    Log    Row count verified: ${actual_count} > ${min_count}    console=yes
    RETURN    ${TRUE}

Row Count Should Be Less Than
    [Documentation]    Verifies that row count is less than a threshold
    [Arguments]    ${table_name}    ${max_count}    ${where_clause}=${EMPTY}

    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}

    Should Be True    ${actual_count} < ${max_count}
    ...    Table ${table_name} has ${actual_count} rows, expected less than ${max_count}

    Log    Row count verified: ${actual_count} < ${max_count}    console=yes
    RETURN    ${TRUE}

Validate Table Data Count
    [Documentation]    Validates that table contains expected number of rows
    [Arguments]    ${table_name}    ${expected_count}

    Log    Validating data count for table: ${table_name}    console=yes
    Log    Expected count: ${expected_count}    console=yes

    ${actual_count}=    Get Table Row Count    ${table_name}

    Should Be Equal As Numbers    ${actual_count}    ${expected_count}
    ...    Table '${table_name}' has ${actual_count} rows, expected ${expected_count}

    Log    Table data count validation passed: ${actual_count} rows    console=yes

Compare Table Row Counts
    [Documentation]    Compares row counts between two tables
    [Arguments]    ${table1}    ${table2}    ${should_match}=${TRUE}

    Log    Comparing row counts between tables...    console=yes

    ${count1}=    Get Table Row Count    ${table1}
    ${count2}=    Get Table Row Count    ${table2}

    Log    ${table1}: ${count1} rows    console=yes
    Log    ${table2}: ${count2} rows    console=yes

    IF    ${should_match}
        Should Be Equal As Numbers    ${count1}    ${count2}
        ...    Table row counts don't match: ${table1}(${count1}) != ${table2}(${count2})
        Log    Table row counts match: ${count1} rows each    console=yes
    ELSE
        Should Not Be Equal As Numbers    ${count1}    ${count2}
        ...    Table row counts should not match but both have ${count1} rows
        Log    Table row counts differ as expected: ${count1} vs ${count2}    console=yes
    END

Validate Table Has Data
    [Documentation]    Validates that table contains at least one row
    [Arguments]    ${table_name}

    Log    Validating table has data: ${table_name}    console=yes

    ${count}=    Get Table Row Count    ${table_name}

    Should Be True    ${count} > 0
    ...    Table '${table_name}' is empty (0 rows)

    Log    Table '${table_name}' contains data: ${count} rows    console=yes

Validate Table Is Empty
    [Documentation]    Validates that table is empty (0 rows)
    [Arguments]    ${table_name}

    Log    Validating table is empty: ${table_name}    console=yes

    ${count}=    Get Table Row Count    ${table_name}

    Should Be Equal As Numbers    ${count}    0
    ...    Table '${table_name}' is not empty (${count} rows)

    Log    Table '${table_name}' is empty as expected    console=yes

Verify Table Columns
    [Documentation]    Verifies that a table has all expected columns
    ...    Handles case-insensitive comparison for databases like Snowflake
    [Arguments]    ${table_name}    @{expected_columns}

    Log    ========== VERIFYING TABLE COLUMNS ==========    console=yes
    Log    Table: ${table_name}    console=yes
    Log    Expected columns: ${expected_columns}    console=yes

    @{actual_columns}=    Get Table Columns    ${table_name}
    Log    Actual columns found: ${actual_columns}    console=yes

    @{missing_columns}=    Create List
    @{verified_columns}=    Create List

    FOR    ${expected_col}    IN    @{expected_columns}
        ${expected_lower}=    Convert To Lower Case    ${expected_col}
        ${found}=    Set Variable    ${FALSE}

        FOR    ${actual_col}    IN    @{actual_columns}
            ${actual_lower}=    Convert To Lower Case    ${actual_col}
            IF    '${expected_lower}' == '${actual_lower}'
                ${found}=    Set Variable    ${TRUE}
                Append To List    ${verified_columns}    ${expected_col}
                BREAK
            END
        END

        IF    ${found}
            Log    Column '${expected_col}' verified    console=yes
        ELSE
            Append To List    ${missing_columns}    ${expected_col}
            Log    Column '${expected_col}' NOT FOUND    console=yes
        END
    END

    @{extra_columns}=    Create List
    FOR    ${actual_col}    IN    @{actual_columns}
        ${actual_lower}=    Convert To Lower Case    ${actual_col}
        ${is_expected}=    Set Variable    ${FALSE}

        FOR    ${expected_col}    IN    @{expected_columns}
            ${expected_lower}=    Convert To Lower Case    ${expected_col}
            IF    '${actual_lower}' == '${expected_lower}'
                ${is_expected}=    Set Variable    ${TRUE}
                BREAK
            END
        END

        IF    not ${is_expected}
            Append To List    ${extra_columns}    ${actual_col}
        END
    END

    ${missing_count}=    Get Length    ${missing_columns}
    ${extra_count}=    Get Length    ${extra_columns}
    ${verified_count}=    Get Length    ${verified_columns}

    IF    ${extra_count} > 0
        Log    Extra columns found (not in expected list): ${extra_columns}    console=yes    level=WARN
    END

    Log    ========== COLUMN VERIFICATION SUMMARY ==========    console=yes
    Log    Verified: ${verified_count}/${expected_columns.__len__()} columns    console=yes

    IF    ${missing_count} > 0
        Fail    Missing required columns: ${missing_columns}
    END

    Log    All expected columns verified successfully!    console=yes
    RETURN    ${actual_columns}

Verify Table Columns Match Exactly
    [Documentation]    Verifies that table columns match exactly (count and names)
    [Arguments]    ${table_name}    @{expected_columns}

    @{actual_columns}=    Verify Table Columns    ${table_name}    @{expected_columns}

    ${actual_count}=    Get Length    ${actual_columns}
    ${expected_count}=    Get Length    ${expected_columns}

    Should Be Equal As Integers
    ...    ${actual_count}
    ...    ${expected_count}
    ...    Column count mismatch. Expected exactly ${expected_count} columns but found ${actual_count}. Actual columns: ${actual_columns}

    Log    Table structure matches exactly: ${expected_count} columns    console=yes
    RETURN    ${actual_columns}

Verify Table Has Minimum Columns
    [Documentation]    Verifies that table has at least the expected columns
    [Arguments]    ${table_name}    @{required_columns}

    @{actual_columns}=    Verify Table Columns    ${table_name}    @{required_columns}

    ${actual_count}=    Get Length    ${actual_columns}
    ${required_count}=    Get Length    ${required_columns}

    Should Be True    ${actual_count} >= ${required_count}
    ...    Table should have at least ${required_count} columns but has only ${actual_count}

    Log    Table has required columns plus ${actual_count - required_count} additional columns    console=yes
    RETURN    ${actual_columns}

# ==================== TRANSACTION MANAGEMENT ====================

Begin Transaction
    [Documentation]    Starts a database transaction

    Execute Sql String    BEGIN TRANSACTION
    Log    Transaction started    console=yes
    RETURN    ${TRUE}

Commit Transaction
    [Documentation]    Commits the current transaction

    Execute Sql String    COMMIT
    Log    Transaction committed    console=yes
    RETURN    ${TRUE}

Rollback Transaction
    [Documentation]    Rolls back the current transaction

    Execute Sql String    ROLLBACK
    Log    Transaction rolled back    console=yes
    RETURN    ${TRUE}

Execute In Transaction
    [Documentation]    Executes statements within a transaction with automatic rollback on error
    [Arguments]    @{statements}

    Begin Transaction

    TRY
        FOR    ${statement}    IN    @{statements}
            Execute Sql String    ${statement}
        END
        Commit Transaction
        Log    Transaction completed successfully    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Rollback Transaction
        Log    Transaction failed and rolled back: ${error}    ERROR
        Fail    Transaction failed: ${error}
    END

Execute SQL With Transaction
    [Documentation]    Executes SQL statements within a transaction with automatic rollback on error
    [Arguments]    ${sql_statements}    ${auto_commit}=${TRUE}

    Log    Executing SQL with transaction management...    console=yes

    TRY
        Begin Transaction

        ${is_list}=    Evaluate    isinstance($sql_statements, list)

        IF    ${is_list}
            FOR    ${statement}    IN    @{sql_statements}
                Execute SQL String Safe    ${statement}
            END
        ELSE
            Execute SQL String Safe    ${sql_statements}
        END

        IF    ${auto_commit}
            Commit Transaction
            Log    SQL executed and committed successfully    console=yes
        ELSE
            Log    SQL executed successfully (transaction not committed)    console=yes
        END
    EXCEPT    AS    ${error}
        Log    SQL execution failed, rolling back transaction: ${error}    console=yes
        Rollback Transaction
        Fail    SQL execution failed: ${error}
    END

# ==================== UTILITY OPERATIONS ====================

Get Table List
    [Documentation]    Returns list of all tables in the database/schema
    [Arguments]    ${schema}=${EMPTY}

    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable    SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE'
    ELSE
        ${query}=    Set Variable
        ...    SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND UPPER(table_schema) = UPPER('${schema}')
    END

    ${tables}=    Query    ${query}

    @{table_list}=    Create List
    FOR    ${table}    IN    @{tables}
        Append To List    ${table_list}    ${table[0]}
    END

    ${count}=    Get Length    ${table_list}
    Log    Found ${count} tables    console=yes

    RETURN    ${table_list}

Compare Table Data
    [Documentation]    Compares data between two tables
    [Arguments]    ${table1}    ${table2}    ${columns}=*    ${order_by}=${EMPTY}

    ${data1}=    Select All From Table    ${table1}    ${columns}    ${order_by}
    ${data2}=    Select All From Table    ${table2}    ${columns}    ${order_by}

    ${count1}=    Get Length    ${data1}
    ${count2}=    Get Length    ${data2}

    Should Be Equal As Integers    ${count1}    ${count2}
    ...    Row count mismatch: ${table1} has ${count1} rows, ${table2} has ${count2} rows

    Lists Should Be Equal    ${data1}    ${data2}
    ...    Data mismatch between ${table1} and ${table2}

    Log    Tables ${table1} and ${table2} have identical data    console=yes
    RETURN    ${TRUE}

Backup Table
    [Documentation]    Creates a backup copy of a table
    [Arguments]    ${source_table}    ${backup_table}    ${drop_if_exists}=${TRUE}

    IF    ${drop_if_exists}
        Drop Table    ${backup_table}    if_exists=${TRUE}
    END

    Execute Sql String    CREATE TABLE ${backup_table} AS SELECT * FROM ${source_table}

    ${count}=    Get Row Count    ${backup_table}
    Log    Table ${source_table} backed up to ${backup_table} (${count} rows)    console=yes

    RETURN    ${TRUE}

Backup Table Data
    [Documentation]    Creates a backup of table data (with verification)
    [Arguments]    ${source_table}    ${backup_table}    ${drop_if_exists}=${TRUE}

    Log    Creating backup of table: ${source_table} -> ${backup_table}    console=yes

    IF    ${drop_if_exists}    Drop Table If Exists    ${backup_table}

    ${sql}=    Set Variable    CREATE TABLE ${backup_table} AS SELECT * FROM ${source_table}
    Execute SQL String Safe    ${sql}

    ${source_count}=    Get Table Row Count    ${source_table}
    ${backup_count}=    Get Table Row Count    ${backup_table}

    Should Be Equal As Numbers    ${source_count}    ${backup_count}
    ...    Backup failed: source has ${source_count} rows, backup has ${backup_count}

    Log    Table backup completed: ${backup_count} rows copied    console=yes

Clear Table Data
    [Documentation]    Removes all data from a table (alias for Truncate Table)
    [Arguments]    ${table_name}

    Truncate Table    ${table_name}
    RETURN    ${TRUE}

Clean Database Tables
    [Documentation]    Cleans up test tables by truncating or dropping them
    [Arguments]    ${tables}    ${operation}=TRUNCATE

    Log    Cleaning database tables (${operation})...    console=yes
    Log    Tables: ${tables}    console=yes

    ${is_list}=    Evaluate    isinstance($tables, list)
    ${table_list}=    Set Variable If    ${is_list}    ${tables}    [${tables}]

    FOR    ${table}    IN    @{table_list}
        TRY
            IF    '${operation}' == 'TRUNCATE'
                Truncate Table    ${table}
            ELSE IF    '${operation}' == 'DROP'
                Drop Table If Exists    ${table}
            ELSE
                Log    Unknown operation: ${operation}, skipping table ${table}    console=yes
            END
        EXCEPT    AS    ${error}
            Log    Failed to clean table ${table}: ${error}    console=yes
        END
    END

    Log    Database cleanup completed    console=yes

Clean Table
    [Documentation]    Truncates a table before test execution to ensure clean state
    [Arguments]    ${table_name}    ${schema_name}
    Log    Cleaning table before execution    console=yes
    Truncate Table If Exists    ${table_name}    schema=${schema_name}

# ==================== DATABASE/SCHEMA MANAGEMENT ====================

Use Database
    [Documentation]    Switch to a different database
    ...    Note: Not all databases support this operation
    [Arguments]    ${database_name}

    Execute Sql String    USE DATABASE ${database_name}
    Log    Switched to database: ${database_name}    console=yes
    RETURN    ${TRUE}

Use Schema
    [Documentation]    Switch to a different schema
    ...    Note: Schema support varies by database
    [Arguments]    ${schema_name}

    Execute Sql String    USE SCHEMA ${schema_name}
    Log    Switched to schema: ${schema_name}    console=yes
    RETURN    ${TRUE}

Get Current Database Context
    [Documentation]    Get current database context information
    TRY
        ${db_result}=    Query    SELECT DATABASE() as current_db
        ${current_db}=    Set Variable    ${db_result[0][0]}

        ${context}=    Create Dictionary
        ...    database=${current_db}

        Log    Current Database: ${current_db}    console=yes
        RETURN    ${context}
    EXCEPT
        Log    Could not get database context - function may not be supported    WARN
        RETURN    ${EMPTY}
    END

# ==================== DATA CONVERSION OPERATIONS ====================

Convert Query Results To Dictionary
    [Documentation]    Converts query results to a list of dictionaries
    [Arguments]    ${query_results}    ${column_names}

    @{dict_results}=    Create List

    FOR    ${row}    IN    @{query_results}
        &{row_dict}=    Create Dictionary
        ${index}=    Set Variable    ${0}

        FOR    ${col_name}    IN    @{column_names}
            Set To Dictionary    ${row_dict}    ${col_name}=${row[${index}]}
            ${index}=    Evaluate    ${index} + 1
        END

        Append To List    ${dict_results}    ${row_dict}
    END

    Log    Converted ${query_results.__len__()} rows to dictionary format    console=yes
    RETURN    ${dict_results}

Get First Row As Dictionary
    [Documentation]    Returns the first row of a query result as a dictionary
    [Arguments]    ${table_name}    ${where_clause}=${EMPTY}

    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}

    IF    ${is_empty}
        ${results}=    Select All From Table    ${table_name}    limit=1
    ELSE
        ${results}=    Select Where    ${table_name}    ${where_clause}    limit=1
    END

    Should Not Be Empty    ${results}    No rows found in ${table_name}

    ${columns}=    Get Table Columns    ${table_name}
    @{column_names}=    Create List
    FOR    ${col}    IN    @{columns}
        Append To List    ${column_names}    ${col[0]}
    END

    &{row_dict}=    Create Dictionary
    ${index}=    Set Variable    ${0}
    FOR    ${col_name}    IN    @{column_names}
        Set To Dictionary    ${row_dict}    ${col_name}=${results[0][${index}]}
        ${index}=    Evaluate    ${index} + 1
    END

    RETURN    ${row_dict}

Get Table Data As Dictionary
    [Documentation]    Select all records from a table and return as a list of dictionaries
    [Arguments]    ${table_name}    ${order_by}=${EMPTY}    ${where_clause}=${EMPTY}

    Log    ========== GETTING TABLE DATA AS DICTIONARY ==========    console=yes

    ${columns_info}=    Get Table Columns    ${table_name}
    @{column_names}=    Create List
    FOR    ${col_info}    IN    @{columns_info}
        Append To List    ${column_names}    ${col_info[0]}
    END
    Log    Column names: ${column_names}    console=yes

    ${has_where}=    Run Keyword And Return Status    Should Not Be Empty    ${where_clause}
    IF    ${has_where}
        ${results}=    Select Where    ${table_name}    ${where_clause}    order_by=${order_by}
    ELSE
        ${results}=    Select All From Table    ${table_name}    order_by=${order_by}
    END

    @{dict_results}=    Create List
    FOR    ${row}    IN    @{results}
        &{row_dict}=    Create Dictionary
        ${index}=    Set Variable    ${0}
        FOR    ${col_name}    IN    @{column_names}
            Set To Dictionary    ${row_dict}    ${col_name}=${row[${index}]}
            ${index}=    Evaluate    ${index} + 1
        END
        Append To List    ${dict_results}    ${row_dict}
    END

    ${count}=    Get Length    ${dict_results}
    Log    Converted ${count} rows to dictionary format    console=yes
    RETURN    ${dict_results}

Extract Column Values From Dictionary
    [Documentation]    Extract all values for a specific column from dictionary results
    [Arguments]    ${dict_results}    ${column_name}

    @{column_values}=    Create List

    FOR    ${row_dict}    IN    @{dict_results}
        ${has_column}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key
        ...    ${row_dict}
        ...    ${column_name}
        IF    ${has_column}
            Append To List    ${column_values}    ${row_dict}[${column_name}]
        ELSE
            Log    Warning: Column ${column_name} not found in record    WARN
        END
    END

    ${count}=    Get Length    ${column_values}
    Log    Extracted ${count} values for column ${column_name}    console=yes
    RETURN    ${column_values}

Extract Multiple Columns From Dictionary
    [Documentation]    Extract values for multiple columns from dictionary results
    [Arguments]    ${dict_results}    @{column_names}

    &{extracted_data}=    Create Dictionary

    FOR    ${col_name}    IN    @{column_names}
        @{col_values}=    Create List
        Set To Dictionary    ${extracted_data}    ${col_name}=${col_values}
    END

    FOR    ${row_dict}    IN    @{dict_results}
        FOR    ${col_name}    IN    @{column_names}
            ${has_column}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key
            ...    ${row_dict}
            ...    ${col_name}
            IF    ${has_column}
                Append To List    ${extracted_data}[${col_name}]    ${row_dict}[${col_name}]
            END
        END
    END

    Log    Extracted data for columns ${column_names}    console=yes
    RETURN    ${extracted_data}

Get Unique Column Values
    [Documentation]    Extract unique values for a specific column from dictionary results
    [Arguments]    ${dict_results}    ${column_name}

    @{all_values}=    Extract Column Values From Dictionary    ${dict_results}    ${column_name}

    ${unique_values}=    Evaluate    list(set(${all_values}))
    ${unique_values}=    Evaluate    sorted(${unique_values})

    ${count}=    Get Length    ${unique_values}
    Log    Found ${count} unique values for ${column_name}: ${unique_values}    console=yes
    RETURN    ${unique_values}

Filter Dictionary Results By Column Value
    [Documentation]    Filter dictionary results based on a column value condition
    ...    Supported operators: ==, !=, >, >=, <, <=, IN, LIKE
    [Arguments]    ${dict_results}    ${column_name}    ${operator}    ${value}

    @{filtered_results}=    Create List

    FOR    ${row_dict}    IN    @{dict_results}
        ${has_column}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key
        ...    ${row_dict}
        ...    ${column_name}
        IF    ${has_column}
            ${match}=    Evaluate Column Condition    ${row_dict}[${column_name}]    ${operator}    ${value}
            IF    ${match}
                Append To List    ${filtered_results}    ${row_dict}
            END
        END
    END

    ${count}=    Get Length    ${filtered_results}
    Log    Found ${count} records where ${column_name} ${operator} ${value}    console=yes
    RETURN    ${filtered_results}

Evaluate Column Condition
    [Documentation]    Helper keyword to evaluate conditions for filtering
    [Arguments]    ${actual_value}    ${operator}    ${expected_value}

    IF    '${operator}' == '=='
        ${result}=    Evaluate    '${actual_value}' == '${expected_value}'
    ELSE IF    '${operator}' == '!='
        ${result}=    Evaluate    '${actual_value}' != '${expected_value}'
    ELSE IF    '${operator}' == '>'
        ${result}=    Evaluate    ${actual_value} > ${expected_value}
    ELSE IF    '${operator}' == '>='
        ${result}=    Evaluate    ${actual_value} >= ${expected_value}
    ELSE IF    '${operator}' == '<'
        ${result}=    Evaluate    ${actual_value} < ${expected_value}
    ELSE IF    '${operator}' == '<='
        ${result}=    Evaluate    ${actual_value} <= ${expected_value}
    ELSE IF    '${operator}' == 'IN'
        ${result}=    Evaluate    '${actual_value}' in ${expected_value}
    ELSE IF    '${operator}' == 'LIKE'
        ${result}=    Evaluate    '${expected_value}' in '${actual_value}'
    ELSE
        Fail    Unsupported operator: ${operator}
    END

    RETURN    ${result}

Build Insert SQL From Dict
    [Documentation]    Builds INSERT SQL statement from dictionary/associative data
    [Arguments]    ${table_name}    ${row_dict}    ${table_columns}

    ${columns}=    Create List
    ${values}=    Create List

    Log    Building INSERT SQL for table: ${table_name}
    Log    Row data: ${row_dict}
    Log    Table columns: ${table_columns}

    FOR    ${csv_column}    ${csv_value}    IN    &{row_dict}
        ${csv_column_lower}=    Convert To Lower Case    ${csv_column}

        FOR    ${table_column}    IN    @{table_columns}
            ${table_column_lower}=    Convert To Lower Case    ${table_column}

            IF    '${csv_column_lower}' == '${table_column_lower}'
                ${value_type}=    Evaluate    type($csv_value).__name__

                IF    $csv_value is None or '${csv_value}' == 'None'
                    ${escaped_value}=    Set Variable    NULL
                ELSE IF    '${csv_value}' == '${EMPTY}' or '${csv_value}' == ''
                    ${escaped_value}=    Set Variable    NULL
                ELSE IF    '${value_type}' == 'bool'
                    IF    ${csv_value}
                        ${escaped_value}=    Set Variable    TRUE
                    ELSE
                        ${escaped_value}=    Set Variable    FALSE
                    END
                ELSE IF    '${value_type}' == 'int' or '${value_type}' == 'float'
                    ${escaped_value}=    Set Variable    ${csv_value}
                ELSE IF    'date' in '${table_column_lower}'
                    ${str_value}=    Convert To String    ${csv_value}
                    ${escaped_str}=    Replace String    ${str_value}    '    ''
                    ${escaped_value}=    Set Variable    '${escaped_str}'
                ELSE
                    ${str_value}=    Convert To String    ${csv_value}
                    ${escaped_str}=    Replace String    ${str_value}    '    ''
                    ${escaped_value}=    Set Variable    '${escaped_str}'
                END

                ${all_upper}=    Set Variable    ${TRUE}
                FOR    ${col}    IN    @{table_columns}
                    ${is_upper}=    Evaluate    $col.isupper()
                    IF    not ${is_upper}
                        ${all_upper}=    Set Variable    ${FALSE}
                        BREAK
                    END
                END

                IF    ${all_upper}
                    ${column_to_use}=    Convert To Upper Case    ${csv_column}
                ELSE
                    ${column_to_use}=    Set Variable    ${table_column}
                END

                Append To List    ${columns}    ${column_to_use}
                Append To List    ${values}    ${escaped_value}
                BREAK
            END
        END
    END

    ${column_count}=    Get Length    ${columns}
    IF    ${column_count} == 0
        Fail
        ...    No matching columns found between data and table. Data columns: ${row_dict.keys()}, Table columns: ${table_columns}
    END

    ${columns_str}=    Evaluate    ', '.join($columns)
    ${values_str}=    Evaluate    ', '.join(str(v) for v in $values)
    ${sql}=    Set Variable    INSERT INTO ${table_name} (${columns_str}) VALUES (${values_str})

    Log    Generated SQL: ${sql}
    RETURN    ${sql}

# ==================== DATA EXPORT/IMPORT OPERATIONS ====================

Export Table To CSV
    [Documentation]    Exports any database table to a CSV file
    [Arguments]
    ...    ${table_name}
    ...    ${output_file}
    ...    ${include_headers}=${TRUE}
    ...    ${order_by}=${EMPTY}
    ...    ${where_clause}=${EMPTY}

    Log    ========== EXPORTING TABLE TO CSV ==========    console=yes
    Log    Table: ${table_name}    console=yes
    Log    Output: ${output_file}    console=yes

    ${output_dir}=    Evaluate    os.path.dirname(r'${output_file}')    modules=os
    Create Directory    ${output_dir}

    IF    '${where_clause}' != '${EMPTY}'
        @{table_data}=    Select Where    ${table_name}    ${where_clause}    order_by=${order_by}
    ELSE
        @{table_data}=    Select All From Table    ${table_name}    order_by=${order_by}
    END

    ${row_count}=    Get Length    ${table_data}
    Log    Retrieved ${row_count} rows from database    console=yes

    @{columns}=    Get Table Columns    ${table_name}
    Log    Columns: ${columns}    console=yes

    Create File    ${output_file}    ${EMPTY}

    IF    ${include_headers}
        ${header_line}=    Catenate    SEPARATOR=,    @{columns}
        Append To File    ${output_file}    ${header_line}\n
    END

    ${rows_written}=    Set Variable    ${0}
    FOR    ${row}    IN    @{table_data}
        @{formatted_values}=    Create List
        FOR    ${value}    IN    @{row}
            ${formatted_value}=    Format Value For CSV    ${value}
            Append To List    ${formatted_values}    ${formatted_value}
        END
        ${line}=    Catenate    SEPARATOR=,    @{formatted_values}
        Append To File    ${output_file}    ${line}\n
        ${rows_written}=    Evaluate    ${rows_written} + 1

        ${is_milestone}=    Evaluate    ${rows_written} % 100 == 0
        IF    ${is_milestone}
            Log    Exported ${rows_written} rows...    console=yes
        END
    END

    Log    Exported ${rows_written} rows to ${output_file}    console=yes

    &{export_result}=    Create Dictionary
    ...    file_path=${output_file}
    ...    row_count=${rows_written}
    ...    columns=${columns}
    ...    table_name=${table_name}
    ...    include_headers=${include_headers}

    RETURN    ${export_result}

Format Value For CSV
    [Documentation]    Formats a single value for CSV output
    [Arguments]    ${value}

    ${str_value}=    Convert To String    ${value}

    IF    $str_value == 'None' or $value == '${None}'    RETURN    ${EMPTY}

    ${needs_quotes}=    Set Variable    ${FALSE}
    ${special_chars}=    Create List    ,    "    \n    \r
    FOR    ${char}    IN    @{special_chars}
        ${contains}=    Run Keyword And Return Status    Should Contain    ${str_value}    ${char}
        IF    ${contains}
            ${needs_quotes}=    Set Variable    ${TRUE}
            BREAK
        END
    END

    ${str_value}=    Replace String    ${str_value}    "    ""

    IF    ${needs_quotes}
        ${str_value}=    Set Variable    "${str_value}"
    END

    RETURN    ${str_value}

Compare Table With CSV File
    [Documentation]    Compares database table data with expected CSV file
    [Arguments]
    ...    ${table_name}
    ...    ${expected_csv}
    ...    ${ignore_order}=${FALSE}
    ...    ${order_by}=${EMPTY}
    ...    ${where_clause}=${EMPTY}
    ...    ${temp_dir}=${EMPTY}

    Log    ========== COMPARING TABLE WITH CSV ==========    console=yes
    Log    Table: ${table_name}    console=yes
    Log    Expected CSV: ${expected_csv}    console=yes

    File Should Exist    ${expected_csv}    Expected CSV file not found: ${expected_csv}

    IF    '${temp_dir}' == '${EMPTY}'
        ${has_actual_dir}=    Run Keyword And Return Status    Variable Should Exist    ${ACTUAL_DATA_DIR}
        IF    ${has_actual_dir}
            ${temp_dir}=    Set Variable    ${ACTUAL_DATA_DIR}
        ELSE
            ${temp_dir}=    Set Variable    /tmp
        END
    END

    ${table_base_name}=    Set Variable    ${table_name}
    ${table_base_name}=    Replace String    ${table_base_name}    .    _
    ${timestamp}=    Get Time    epoch
    ${actual_csv}=    Set Variable    ${temp_dir}/actual_${table_base_name}_${timestamp}.csv

    ${export_result}=    Export Table To CSV
    ...    ${table_name}
    ...    ${actual_csv}
    ...    include_headers=${TRUE}
    ...    order_by=${order_by}
    ...    where_clause=${where_clause}

    Log    Exported ${export_result}[row_count] rows for comparison    console=yes

    ${comparison_result}=    Compare CSV Files
    ...    ${actual_csv}
    ...    ${expected_csv}
    ...    ignore_order=${ignore_order}
    ...    show_details=${TRUE}

    Set To Dictionary    ${comparison_result}    actual_file=${actual_csv}
    Set To Dictionary    ${comparison_result}    export_details=${export_result}

    IF    '${comparison_result}[status]' == 'IDENTICAL'
        ${should_keep}=    Run Keyword And Return Status    Variable Should Exist    ${KEEP_ACTUAL_FILES}
        IF    ${should_keep} and ${KEEP_ACTUAL_FILES}
            Log    Comparison passed, keeping actual file at: ${actual_csv}    console=yes
        ELSE
            Remove File    ${actual_csv}
            Log    Comparison passed, removed temporary file    console=yes
        END
    ELSE
        Log    Comparison failed, keeping ${actual_csv} for investigation    console=yes    level=WARN
    END

    RETURN    ${comparison_result}

Verify Table Matches CSV
    [Documentation]    High-level keyword that verifies table matches expected CSV
    [Arguments]
    ...    ${table_name}
    ...    ${expected_csv}
    ...    ${ignore_order}=${FALSE}
    ...    ${order_by}=${EMPTY}
    ...    ${temp_dir}=${EMPTY}

    ${comparison}=    Compare Table With CSV File
    ...    ${table_name}
    ...    ${expected_csv}
    ...    ignore_order=${ignore_order}
    ...    order_by=${order_by}
    ...    temp_dir=${temp_dir}

    Should Be Equal
    ...    ${comparison}[status]
    ...    IDENTICAL
    ...    Table verification FAILED! Found ${comparison}[total_differences] differences. Actual data saved to: ${comparison}[actual_file]

    Log    Table verification PASSED! Database matches expected CSV    console=yes
    RETURN    ${comparison}

Export Query Results To CSV
    [Documentation]    Exports custom query results to CSV file
    [Arguments]    ${query}    ${output_file}    @{column_names}    ${include_headers}=${TRUE}

    Log    Executing query and exporting to CSV...    console=yes

    @{results}=    Query    ${query}
    ${row_count}=    Get Length    ${results}
    Log    Query returned ${row_count} rows    console=yes

    ${output_dir}=    Evaluate    os.path.dirname(r'${output_file}')    modules=os
    Create Directory    ${output_dir}

    Create File    ${output_file}    ${EMPTY}

    IF    ${include_headers} and ${column_names}
        ${header_line}=    Catenate    SEPARATOR=,    @{column_names}
        Append To File    ${output_file}    ${header_line}\n
    END

    FOR    ${row}    IN    @{results}
        @{formatted_values}=    Create List
        FOR    ${value}    IN    @{row}
            ${formatted_value}=    Format Value For CSV    ${value}
            Append To List    ${formatted_values}    ${formatted_value}
        END
        ${line}=    Catenate    SEPARATOR=,    @{formatted_values}
        Append To File    ${output_file}    ${line}\n
    END

    Log    Exported ${row_count} rows to ${output_file}    console=yes

    &{result}=    Create Dictionary
    ...    file_path=${output_file}
    ...    row_count=${row_count}
    ...    query=${query}

    RETURN    ${result}

Compare Two Tables
    [Documentation]    Compares data between two database tables
    [Arguments]    ${table1}    ${table2}    ${ignore_order}=${FALSE}    ${order_by}=${EMPTY}    ${temp_dir}=/tmp

    Log    ========== COMPARING TWO TABLES ==========    console=yes
    Log    Table 1: ${table1}    console=yes
    Log    Table 2: ${table2}    console=yes

    ${timestamp}=    Get Time    epoch
    ${file1}=    Set Variable    ${temp_dir}/table1_${timestamp}.csv
    ${file2}=    Set Variable    ${temp_dir}/table2_${timestamp}.csv

    ${export1}=    Export Table To CSV    ${table1}    ${file1}    order_by=${order_by}
    ${export2}=    Export Table To CSV    ${table2}    ${file2}    order_by=${order_by}

    Log    Table 1 has ${export1}[row_count] rows    console=yes
    Log    Table 2 has ${export2}[row_count] rows    console=yes

    ${comparison}=    Compare CSV Files
    ...    ${file1}
    ...    ${file2}
    ...    ignore_order=${ignore_order}
    ...    show_details=${TRUE}

    Remove File    ${file1}
    Remove File    ${file2}

    Set To Dictionary    ${comparison}    table1=${table1}    table2=${table2}

    RETURN    ${comparison}

Verify Tables Are Identical
    [Documentation]    Verifies two tables contain identical data
    [Arguments]    ${table1}    ${table2}    ${ignore_order}=${FALSE}    ${order_by}=${EMPTY}

    ${comparison}=    Compare Two Tables
    ...    ${table1}
    ...    ${table2}
    ...    ignore_order=${ignore_order}
    ...    order_by=${order_by}

    Should Be Equal    ${comparison}[status]    IDENTICAL
    ...    Tables don't match! Found ${comparison}[total_differences] differences between ${table1} and ${table2}

    Log    Tables ${table1} and ${table2} are identical    console=yes
    RETURN    ${comparison}

Export Table To JSON
    [Documentation]    Exports database table to JSON file
    [Arguments]    ${table_name}    ${output_file}    ${order_by}=${EMPTY}    ${where_clause}=${EMPTY}

    Log    Exporting ${table_name} to JSON...    console=yes

    @{dict_data}=    Get Table Data As Dictionary
    ...    ${table_name}
    ...    order_by=${order_by}
    ...    where_clause=${where_clause}

    ${row_count}=    Get Length    ${dict_data}
    Log    Exporting ${row_count} rows to JSON    console=yes

    ${json_string}=    Evaluate    json.dumps(${dict_data}, indent=2, default=str)    modules=json

    ${output_dir}=    Evaluate    os.path.dirname(r'${output_file}')    modules=os
    Create Directory    ${output_dir}
    Create File    ${output_file}    ${json_string}

    Log    Exported to ${output_file}    console=yes

    &{result}=    Create Dictionary
    ...    file_path=${output_file}
    ...    row_count=${row_count}
    ...    table_name=${table_name}

    RETURN    ${result}

Export DB Table Data To CSV
    [Documentation]    Exports data from database table to a CSV file for verification
    [Arguments]    ${table_name}    ${order_by_column}    ${output_file}

    ${export_result}=    Export Table To CSV
    ...    ${table_name}
    ...    ${output_file}
    ...    include_headers=${TRUE}
    ...    order_by=${order_by_column}

    Log    Exported ${export_result}[row_count] rows to ${export_result}[file_path]    console=yes
    Log    CSV file location: ${output_file}    console=yes

Capture And Verify Number of records From DB Table
    [Documentation]    Verifies data in table by executing a query and comparing row count
    [Arguments]    ${table_name}    ${schema_name}    ${order_by_column}    ${expected_records_count}

    ${results}=    Select All From Table
    ...    ${table_name}
    ...    order_by=${order_by_column}
    ...    schema=${schema_name}

    ${row_count}=    Get Length    ${results}
    Should Be Equal As Integers    ${row_count}    ${expected_records_count}
    Log    Retrieved ${row_count} rows from ${table_name} and schema name ${schema_name}    console=yes

# ==================== STORED PROCEDURE OPERATIONS ====================

Create Stored Procedure
    [Documentation]    Creates a stored procedure (syntax varies by database)
    [Arguments]    ${procedure_name}    ${procedure_body}

    Log    Creating stored procedure: ${procedure_name}    console=yes
    Execute Sql String    ${procedure_body}
    Log    Stored procedure ${procedure_name} created    console=yes
    RETURN    ${TRUE}

Drop Stored Procedure
    [Documentation]    Drops a stored procedure
    [Arguments]    ${procedure_name}    ${if_exists}=${TRUE}

    IF    ${if_exists}
        Execute Sql String    DROP PROCEDURE IF EXISTS ${procedure_name}
    ELSE
        Execute Sql String    DROP PROCEDURE ${procedure_name}
    END

    Log    Stored procedure ${procedure_name} dropped    console=yes
    RETURN    ${TRUE}

Call Stored Procedure
    [Documentation]    Calls a stored procedure with parameters
    [Arguments]    ${procedure_name}    @{parameters}

    ${params}=    Evaluate    ', '.join(${parameters})
    ${call_sql}=    Set Variable    CALL ${procedure_name}(${params})

    Execute Sql String    ${call_sql}
    Log    Stored procedure ${procedure_name} called with parameters: ${params}    console=yes
    RETURN    ${TRUE}

# ==================== PERFORMANCE OPERATIONS ====================

Analyze Table
    [Documentation]    Analyzes table statistics for query optimization
    [Arguments]    ${table_name}

    Execute Sql String    ANALYZE TABLE ${table_name}
    Log    Table ${table_name} analyzed    console=yes
    RETURN    ${TRUE}

Get Table Size
    [Documentation]    Returns the approximate size of a table (database-specific)
    [Arguments]    ${table_name}

    ${count}=    Get Row Count    ${table_name}
    Log    Table ${table_name} has ${count} rows    console=yes
    RETURN    ${count}
