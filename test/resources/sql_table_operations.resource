*** Settings ***
Documentation       Generic SQL Table Operations Keywords
...                 This resource file contains database-agnostic keywords for common SQL operations.
...                 These keywords work with any database supported by DatabaseLibrary including:
...                 - MySQL, PostgreSQL, Oracle, SQL Server, SQLite, Snowflake, etc.
...                 
...                 Prerequisites:
...                 - DatabaseLibrary must be installed
...                 - Database connection must be established before using these keywords
...                 - Use database-specific resource files to establish connections
...
...                 Usage Example:
...                 | *** Settings ***
...                 | Resource    sql_table_operations.resource
...                 | Resource    snowflake2/snowflake_databaselib.resource
...                 |
...                 | *** Test Cases ***
...                 | Test Generic Operations
...                 |     Connect To Snowflake Via DatabaseLibrary
...                 |     Create Table    employees    (id INT, name VARCHAR(100))
...                 |     Insert Into Table    employees    id, name    1, 'John'
...                 |     ${count}=    Get Row Count    employees
...                 |     Should Be Equal As Integers    ${count}    1

Library             DatabaseLibrary
Library             Collections
Library             String
Library             BuiltIn
Library             OperatingSystem


*** Keywords ***
# ==================== TABLE MANAGEMENT OPERATIONS ====================

Create Table
    [Documentation]    Creates a table with the specified definition
    ...    Works with any SQL database
    ...    Arguments:
    ...        table_name: Name of the table to create
    ...        table_definition: SQL column definitions (e.g., "(id INT, name VARCHAR(100))")
    ...        drop_if_exists: If TRUE, drops existing table before creating (default: TRUE)
    [Arguments]    ${table_name}    ${table_definition}    ${drop_if_exists}=${TRUE}
    
    Log    Creating table: ${table_name}    console=yes
    
    # Drop existing table if requested
    IF    ${drop_if_exists}
        Execute Sql String    DROP TABLE IF EXISTS ${table_name}
        Log    Dropped existing table ${table_name} (if it existed)    console=yes
    END
    
    # Create the table
    ${create_sql}=    Set Variable    CREATE TABLE ${table_name} ${table_definition}
    Execute Sql String    ${create_sql}
    Log    Table ${table_name} created successfully    console=yes
    
    RETURN    ${TRUE}

Create Table If Not Exists
    [Documentation]    Creates a table only if it doesn't already exist
    ...    Note: Not all databases support IF NOT EXISTS clause
    [Arguments]    ${table_name}    ${table_definition}
    
    ${create_sql}=    Set Variable    CREATE TABLE IF NOT EXISTS ${table_name} ${table_definition}
    Execute Sql String    ${create_sql}
    Log    Table ${table_name} created (if not exists)    console=yes
    RETURN    ${TRUE}

Drop Table
    [Documentation]    Drops a table from the database
    [Arguments]    ${table_name}    ${if_exists}=${TRUE}
    
    IF    ${if_exists}
        Execute Sql String    DROP TABLE IF EXISTS ${table_name}
    ELSE
        Execute Sql String    DROP TABLE ${table_name}
    END
    
    Log    Table ${table_name} dropped    console=yes
    RETURN    ${TRUE}

Truncate Table
    [Documentation]    Removes all rows from a table but keeps the table structure
    [Arguments]    ${table_name}
    
    Execute Sql String    TRUNCATE TABLE ${table_name}
    Log    Table ${table_name} truncated    console=yes
    RETURN    ${TRUE}

Rename Table
    [Documentation]    Renames a table
    ...    Note: Syntax may vary between databases
    [Arguments]    ${old_table_name}    ${new_table_name}
    
    # Standard SQL syntax (works for most databases)
    Execute Sql String    ALTER TABLE ${old_table_name} RENAME TO ${new_table_name}
    Log    Table renamed from ${old_table_name} to ${new_table_name}    console=yes
    RETURN    ${TRUE}

# ==================== DATA MANIPULATION OPERATIONS ====================

Insert Into Table
    [Documentation]    Inserts a single row into a table
    ...    Arguments:
    ...        table_name: Target table
    ...        columns: Comma-separated column names
    ...        values: Values to insert (with proper SQL formatting)
    [Arguments]    ${table_name}    ${columns}    ${values}
    
    ${insert_sql}=    Set Variable    INSERT INTO ${table_name} (${columns}) VALUES (${values})
    Execute Sql String    ${insert_sql}
    Log    Data inserted into ${table_name}    console=yes
    RETURN    ${TRUE}

Bulk Insert Into Table
    [Documentation]    Inserts multiple rows into a table
    ...    Arguments:
    ...        table_name: Target table
    ...        columns: Comma-separated column names
    ...        rows: List of value strings
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
    ...        table_name: Name of the table to update
    ...        set_clause: SET clause (e.g., "column1 = value1, column2 = value2")
    ...        where_clause: Optional WHERE condition (e.g., "id = 1")
    [Arguments]    ${table_name}    ${set_clause}    ${where_clause}=${EMPTY}
    
    # Check if where_clause is empty
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}
    
    IF    ${is_empty}
        ${update_sql}=    Set Variable    UPDATE ${table_name} SET ${set_clause}
        Log    WARNING: Updating ALL rows in ${table_name} (no WHERE clause)    WARN
    ELSE
        ${update_sql}=    Set Variable    UPDATE ${table_name} SET ${set_clause} WHERE ${where_clause}
    END
    
    Log    Executing: ${update_sql}    console=yes
    Execute Sql String    ${update_sql}
    Log    Table ${table_name} updated successfully    console=yes
    RETURN    ${TRUE}

Delete From Table
    [Documentation]    Deletes rows from a table based on a condition
    ...    If no where_clause provided, deletes all rows (use with caution!)
    [Arguments]    ${table_name}    ${where_clause}=${EMPTY}
    
    # Check if where_clause is empty
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}
    
    IF    ${is_empty}
        ${delete_sql}=    Set Variable    DELETE FROM ${table_name}
        Log    WARNING: Deleting ALL rows from ${table_name}    WARN
    ELSE
        ${delete_sql}=    Set Variable    DELETE FROM ${table_name} WHERE ${where_clause}
    END
    
    Execute Sql String    ${delete_sql}
    Log    Rows deleted from ${table_name}    console=yes
    RETURN    ${TRUE}

Upsert Into Table
    [Documentation]    Insert or update based on primary key (database-specific)
    ...    This is a generic template - actual syntax varies by database
    ...    MySQL: INSERT ... ON DUPLICATE KEY UPDATE
    ...    PostgreSQL: INSERT ... ON CONFLICT
    ...    Snowflake: MERGE INTO
    [Arguments]    ${table_name}    ${columns}    ${values}    ${update_clause}
    
    Log    UPSERT operation varies by database type    WARN
    Log    Using standard INSERT for now - override this keyword for specific databases    console=yes
    Insert Into Table    ${table_name}    ${columns}    ${values}
    RETURN    ${TRUE}

# ==================== QUERY OPERATIONS ====================

Select All From Table
    [Documentation]    Selects all records from a table
    [Arguments]    ${table_name}    ${columns}=*    ${order_by}=${EMPTY}    ${limit}=${EMPTY}
    
    # Build query
    ${query}=    Set Variable    SELECT ${columns} FROM ${table_name}
    
    # Add ORDER BY if specified
    ${has_order_by}=    Run Keyword And Return Status    Should Not Be Empty    ${order_by}
    IF    ${has_order_by}
        ${query}=    Set Variable    ${query} ORDER BY ${order_by}
    END
    
    # Add LIMIT if specified
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
    [Arguments]    ${table_name}    ${where_clause}    ${columns}=*    ${order_by}=${EMPTY}    ${limit}=${EMPTY}
    
    # Build query
    ${query}=    Set Variable    SELECT ${columns} FROM ${table_name} WHERE ${where_clause}
    
    # Add ORDER BY if specified
    ${has_order_by}=    Run Keyword And Return Status    Should Not Be Empty    ${order_by}
    IF    ${has_order_by}
        ${query}=    Set Variable    ${query} ORDER BY ${order_by}
    END
    
    # Add LIMIT if specified
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
    [Arguments]    ${table_name}    ${where_clause}=${EMPTY}
    
    # Check if where_clause is empty
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}
    
    IF    ${is_empty}
        ${query}=    Set Variable    SELECT COUNT(*) FROM ${table_name}
    ELSE
        ${query}=    Set Variable    SELECT COUNT(*) FROM ${table_name} WHERE ${where_clause}
    END
    
    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}
    
    Log    Row count for ${table_name}: ${count}    console=yes
    RETURN    ${count}

Get Column Values
    [Documentation]    Returns all values from a specific column
    [Arguments]    ${table_name}    ${column_name}    ${distinct}=${FALSE}    ${where_clause}=${EMPTY}
    
    # Build query with optional DISTINCT
    IF    ${distinct}
        ${select_part}=    Set Variable    SELECT DISTINCT ${column_name}
    ELSE
        ${select_part}=    Set Variable    SELECT ${column_name}
    END
    
    # Check if where_clause is empty
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}
    
    # Add WHERE clause if provided
    IF    ${is_empty}
        ${query}=    Set Variable    ${select_part} FROM ${table_name}
    ELSE
        ${query}=    Set Variable    ${select_part} FROM ${table_name} WHERE ${where_clause}
    END
    
    ${results}=    Query    ${query}
    
    # Extract values from result tuples
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
    
    # Try standard SQL syntax - may need adjustment for specific databases
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
    
    # Some databases need table name, others don't
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

# ==================== VALIDATION OPERATIONS ====================

Table Should Exist
    [Documentation]    Verifies that a table exists in the database
    ...    Uses information_schema which is standard across most databases
    [Arguments]    ${table_name}    ${schema}=${EMPTY}
    
    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}')
    ELSE
        ${query}=    Set Variable    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(table_schema) = UPPER('${schema}')
    END
    
    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}
    
    Should Be True    ${count} > 0    Table ${table_name} does not exist
    Log    ✅ Table ${table_name} exists    console=yes
    RETURN    ${TRUE}

Table Should Not Exist
    [Documentation]    Verifies that a table does not exist in the database
    [Arguments]    ${table_name}    ${schema}=${EMPTY}
    
    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}')
    ELSE
        ${query}=    Set Variable    SELECT COUNT(*) FROM information_schema.tables WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(table_schema) = UPPER('${schema}')
    END
    
    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}
    
    Should Be Equal As Integers    ${count}    0    Table ${table_name} exists but should not
    Log    ✅ Table ${table_name} does not exist    console=yes
    RETURN    ${TRUE}

Column Should Exist
    [Documentation]    Verifies that a column exists in a table
    [Arguments]    ${table_name}    ${column_name}    ${schema}=${EMPTY}
    
    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable    SELECT COUNT(*) FROM information_schema.columns WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(column_name) = UPPER('${column_name}')
    ELSE
        ${query}=    Set Variable    SELECT COUNT(*) FROM information_schema.columns WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(column_name) = UPPER('${column_name}') AND UPPER(table_schema) = UPPER('${schema}')
    END
    
    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}
    
    Should Be True    ${count} > 0    Column ${column_name} does not exist in table ${table_name}
    Log    ✅ Column ${column_name} exists in ${table_name}    console=yes
    RETURN    ${TRUE}

Row Count Should Be
    [Documentation]    Verifies that a table has the expected number of rows
    [Arguments]    ${table_name}    ${expected_count}    ${where_clause}=${EMPTY}
    
    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}
    
    Should Be Equal As Integers    ${actual_count}    ${expected_count}
    ...    Table ${table_name} has ${actual_count} rows, expected ${expected_count}
    
    Log    ✅ Row count verified: ${actual_count} rows    console=yes
    RETURN    ${TRUE}

Row Count Should Be Greater Than
    [Documentation]    Verifies that row count is greater than a threshold
    [Arguments]    ${table_name}    ${min_count}    ${where_clause}=${EMPTY}
    
    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}
    
    Should Be True    ${actual_count} > ${min_count}
    ...    Table ${table_name} has ${actual_count} rows, expected more than ${min_count}
    
    Log    ✅ Row count verified: ${actual_count} > ${min_count}    console=yes
    RETURN    ${TRUE}

Row Count Should Be Less Than
    [Documentation]    Verifies that row count is less than a threshold
    [Arguments]    ${table_name}    ${max_count}    ${where_clause}=${EMPTY}
    
    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}
    
    Should Be True    ${actual_count} < ${max_count}
    ...    Table ${table_name} has ${actual_count} rows, expected less than ${max_count}
    
    Log    ✅ Row count verified: ${actual_count} < ${max_count}    console=yes
    RETURN    ${TRUE}

# ==================== UTILITY OPERATIONS ====================

Get Table Columns
    [Documentation]    Returns list of columns in a table
    [Arguments]    ${table_name}    ${schema}=${EMPTY}
    
    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable    SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE UPPER(table_name) = UPPER('${table_name}') ORDER BY ordinal_position
    ELSE
        ${query}=    Set Variable    SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE UPPER(table_name) = UPPER('${table_name}') AND UPPER(table_schema) = UPPER('${schema}') ORDER BY ordinal_position
    END
    
    ${columns}=    Query    ${query}
    
    Log    Table ${table_name} has ${columns.__len__()} columns    console=yes
    FOR    ${column}    IN    @{columns}
        Log    Column: ${column[0]}, Type: ${column[1]}, Nullable: ${column[2]}    console=yes
    END
    
    RETURN    ${columns}

Get Table List
    [Documentation]    Returns list of all tables in the database/schema
    [Arguments]    ${schema}=${EMPTY}
    
    IF    '${schema}' == '${EMPTY}'
        ${query}=    Set Variable    SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE'
    ELSE
        ${query}=    Set Variable    SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND UPPER(table_schema) = UPPER('${schema}')
    END
    
    ${tables}=    Query    ${query}
    
    @{table_list}=    Create List
    FOR    ${table}    IN    @{tables}
        Append To List    ${table_list}    ${table[0]}
    END
    
    ${count}=    Get Length    ${table_list}
    Log    Found ${count} tables    console=yes
    
    RETURN    ${table_list}

Execute SQL Script
    [Documentation]    Executes multiple SQL statements from a list
    [Arguments]    @{statements}
    
    ${success_count}=    Set Variable    ${0}
    ${error_count}=    Set Variable    ${0}
    
    FOR    ${statement}    IN    @{statements}
        ${clean_statement}=    Strip String    ${statement}
        
        # Skip empty lines and comments
        IF    '${clean_statement}' == ''    CONTINUE
        IF    $clean_statement.startswith('--')    CONTINUE
        IF    $clean_statement.startswith('#')    CONTINUE
        
        Log    Executing: ${clean_statement}    console=yes
        
        TRY
            Execute Sql String    ${clean_statement}
            ${success_count}=    Evaluate    ${success_count} + 1
            Log    ✅ Statement executed successfully    console=yes
        EXCEPT    AS    ${error}
            ${error_count}=    Evaluate    ${error_count} + 1
            Log    ❌ Statement failed: ${error}    WARN
        END
    END
    
    Log    Script execution complete: ${success_count} successful, ${error_count} failed    console=yes
    RETURN    ${success_count}    ${error_count}

Execute SQL File
    [Documentation]    Executes SQL statements from a file
    [Arguments]    ${file_path}    ${delimiter}=;
    
    ${file_content}=    Get File    ${file_path}
    @{statements}=    Split String    ${file_content}    ${delimiter}
    
    ${success}    ${errors}=    Execute SQL Script    @{statements}
    
    Log    Executed SQL file: ${file_path}    console=yes
    RETURN    ${success}    ${errors}

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
    
    Log    ✅ Tables ${table1} and ${table2} have identical data    console=yes
    RETURN    ${TRUE}

Backup Table
    [Documentation]    Creates a backup copy of a table
    [Arguments]    ${source_table}    ${backup_table}    ${drop_if_exists}=${TRUE}
    
    IF    ${drop_if_exists}
        Drop Table    ${backup_table}    if_exists=${TRUE}
    END
    
    # Create backup table with same structure and data
    Execute Sql String    CREATE TABLE ${backup_table} AS SELECT * FROM ${source_table}
    
    ${count}=    Get Row Count    ${backup_table}
    Log    Table ${source_table} backed up to ${backup_table} (${count} rows)    console=yes
    
    RETURN    ${TRUE}

Clear Table Data
    [Documentation]    Removes all data from a table (alias for Truncate Table)
    [Arguments]    ${table_name}
    
    Truncate Table    ${table_name}
    RETURN    ${TRUE}

# ==================== TRANSACTION OPERATIONS ====================

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
    
    # Check if where_clause is empty
    ${is_empty}=    Run Keyword And Return Status    Should Be Empty    ${where_clause}
    
    IF    ${is_empty}
        ${results}=    Select All From Table    ${table_name}    limit=1
    ELSE
        ${results}=    Select Where    ${table_name}    ${where_clause}    limit=1
    END
    
    Should Not Be Empty    ${results}    No rows found in ${table_name}
    
    # Get column names
    ${columns}=    Get Table Columns    ${table_name}
    @{column_names}=    Create List
    FOR    ${col}    IN    @{columns}
        Append To List    ${column_names}    ${col[0]}
    END
    
    # Convert first row to dictionary
    &{row_dict}=    Create Dictionary
    ${index}=    Set Variable    ${0}
    FOR    ${col_name}    IN    @{column_names}
        Set To Dictionary    ${row_dict}    ${col_name}=${results[0][${index}]}
        ${index}=    Evaluate    ${index} + 1
    END
    
    RETURN    ${row_dict}

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
    
    # This is a generic approach - specific databases may have better methods
    ${count}=    Get Row Count    ${table_name}
    Log    Table ${table_name} has ${count} rows    console=yes
    RETURN    ${count}

# ==================== CONSTRAINT OPERATIONS ====================

Add Primary Key
    [Documentation]    Adds a primary key constraint to a table
    [Arguments]    ${table_name}    ${constraint_name}    ${columns}
    
    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} PRIMARY KEY (${columns})
    Execute Sql String    ${alter_sql}
    Log    Primary key ${constraint_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Add Foreign Key
    [Documentation]    Adds a foreign key constraint
    [Arguments]    ${table_name}    ${constraint_name}    ${column}    ${ref_table}    ${ref_column}
    
    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} FOREIGN KEY (${column}) REFERENCES ${ref_table}(${ref_column})
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

# ==================== DATA DICTIONARY OPERATIONS ====================

Get Table Data As Dictionary
    [Documentation]    Select all records from a table and return as a list of dictionaries
    ...    Each dictionary contains column names as keys and values as the row data
    ...    Useful for easier data manipulation in test cases
    [Arguments]    ${table_name}    ${order_by}=${EMPTY}    ${where_clause}=${EMPTY}
    
    Log    ========== GETTING TABLE DATA AS DICTIONARY ==========    console=yes
    
    # First get column names
    ${columns_info}=    Get Table Columns    ${table_name}
    @{column_names}=    Create List
    FOR    ${col_info}    IN    @{columns_info}
        Append To List    ${column_names}    ${col_info[0]}
    END
    Log    Column names: ${column_names}    console=yes
    
    # Get records based on whether WHERE clause is provided
    ${has_where}=    Run Keyword And Return Status    Should Not Be Empty    ${where_clause}
    IF    ${has_where}
        ${results}=    Select Where    ${table_name}    ${where_clause}    order_by=${order_by}
    ELSE
        ${results}=    Select All From Table    ${table_name}    order_by=${order_by}
    END
    
    # Convert to list of dictionaries
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
    ...    Returns a list containing only the values for the specified column
    ...    Useful for getting all values from a single column after Get Table Data As Dictionary
    [Arguments]    ${dict_results}    ${column_name}
    
    @{column_values}=    Create List
    
    FOR    ${row_dict}    IN    @{dict_results}
        # Check if column exists in the dictionary
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
    ...    Returns a dictionary with column names as keys and lists of values
    [Arguments]    ${dict_results}    @{column_names}
    
    &{extracted_data}=    Create Dictionary
    
    # Initialize lists for each column
    FOR    ${col_name}    IN    @{column_names}
        @{col_values}=    Create List
        Set To Dictionary    ${extracted_data}    ${col_name}=${col_values}
    END
    
    # Extract values for each record
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
    ...    Returns a sorted list of unique values (removes duplicates)
    [Arguments]    ${dict_results}    ${column_name}
    
    # First extract all values
    @{all_values}=    Extract Column Values From Dictionary    ${dict_results}    ${column_name}
    
    # Convert to set to remove duplicates, then back to list
    ${unique_values}=    Evaluate    list(set(${all_values}))
    ${unique_values}=    Evaluate    sorted(${unique_values})    # Sort for consistency
    
    ${count}=    Get Length    ${unique_values}
    Log    Found ${count} unique values for ${column_name}: ${unique_values}    console=yes
    RETURN    ${unique_values}

Filter Dictionary Results By Column Value
    [Documentation]    Filter dictionary results based on a column value condition
    ...    Returns only the records that match the condition
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
    ...    Supports various comparison operators
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

# ==================== DATABASE/SCHEMA MANAGEMENT ====================

Test Database Connection
    [Documentation]    Test if database connection is working
    ...    Executes a simple query to verify connectivity
    
    TRY
        # Try a simple query that works across most databases
        ${result}=    Query    SELECT 1 as test_connection
        ${value}=    Set Variable    ${result[0][0]}
        Should Be Equal As Numbers    ${value}    1
        Log    ✅ Database connection is working!    console=yes
        RETURN    ${TRUE}
    EXCEPT    AS    ${error}
        Log    ❌ Database connection test failed: ${error}    console=yes
        RETURN    ${FALSE}
    END

Use Database
    [Documentation]    Switch to a different database
    ...    Note: Not all databases support this operation
    ...    Works with: MySQL, SQL Server, Snowflake, PostgreSQL (with \\c in psql)
    [Arguments]    ${database_name}
    
    Execute Sql String    USE DATABASE ${database_name}
    Log    Switched to database: ${database_name}    console=yes
    RETURN    ${TRUE}

Use Schema
    [Documentation]    Switch to a different schema
    ...    Note: Schema support varies by database
    ...    Works with: PostgreSQL, SQL Server, Snowflake
    ...    MySQL uses 'USE database_name' instead
    [Arguments]    ${schema_name}
    
    Execute Sql String    USE SCHEMA ${schema_name}
    Log    Switched to schema: ${schema_name}    console=yes
    RETURN    ${TRUE}

Get Current Database Context
    [Documentation]    Get current database context information
    ...    Note: Functions vary by database type
    ...    This is a generic template - override for specific databases
    
    TRY
        # Try common database functions
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
