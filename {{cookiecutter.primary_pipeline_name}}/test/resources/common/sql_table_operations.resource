*** Settings ***
Documentation       SQL Table Operations — Database-agnostic keywords for common SQL operations.
...
...                 *Sections:*
...                 - *Table management* — create, drop, truncate, rename
...                 - *CRUD operations* — insert, update, delete, select
...                 - *Query execution* — custom queries, count, single value, result processing
...                 - *SQL execution* — safe execution, script files, templates
...                 - *Table structure* — columns, indexes, views, constraints
...                 - *Validation* — table existence, row counts, column verification
...                 - *Transaction management* — begin, commit, rollback, atomic execution
...                 - *Data conversion* — query results to dictionaries, filtering, extraction
...                 - *Data export/import* — CSV export, JSON export, table-to-CSV comparison
...                 - *Stored procedures* — create, drop, call
...                 - *Performance* — analyze, table size
...
...                 *Prerequisites:*
...                 - ``DatabaseLibrary`` must be installed
...                 - Database connection must be established before using these keywords
...                 - Use ``database_connections.resource`` or database-specific resource files for connections
...
...                 *Example:*
...                 | *** Settings ***
...                 | Resource    database_connections.resource
...                 | Resource    sql_table_operations.resource
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
    [Documentation]    Returns fully qualified table name with schema prefix if provided.
    ...
    ...    Handles cases where ``table_name`` already includes a schema (e.g. ``schema.table``).
    ...    If the table name already contains a dot, the schema argument is ignored.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (may already include schema)
    ...    - ``schema``: Optional schema to prepend (default: empty — ignored if table_name already has schema)
    ...
    ...    *Returns:*
    ...    - Fully qualified table name string (e.g. ``myschema.employees``)
    ...
    ...    *Example:*
    ...    | ${name}= | Get Qualified Table Name | employees | schema=dbo |
    ...    | # Returns: dbo.employees |
    ...    | ${name}= | Get Qualified Table Name | dbo.employees | |
    ...    | # Returns: dbo.employees (schema ignored) |
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
    [Documentation]    Creates a new database table with the specified column definitions.
    ...
    ...    By default, drops any existing table with the same name before creating.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Name of the table to create (can include schema, e.g. ``dbo.employees``)
    ...    - ``table_definition``: SQL column definitions (e.g. ``(id INT, name VARCHAR(100))``)
    ...    - ``drop_if_exists``: If TRUE, drops existing table before creating (default: TRUE)
    ...    - ``schema``: Optional schema name if not included in ``table_name``
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Create Table | employees | (id INT, name VARCHAR(100), salary DECIMAL) |
    ...    | Create Table | employees | (id INT) | drop_if_exists=${FALSE} | schema=dbo |
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
    [Documentation]    Creates a table only if it does not already exist.
    ...
    ...    Uses the ``CREATE TABLE IF NOT EXISTS`` SQL clause.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Name of the table to create
    ...    - ``table_definition``: SQL column definitions
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Not all databases support the ``IF NOT EXISTS`` clause.
    ...
    ...    *Example:*
    ...    | Create Table If Not Exists | staging_data | (id INT, value TEXT) |
    [Arguments]    ${table_name}    ${table_definition}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${create_sql}=    Set Variable    CREATE TABLE IF NOT EXISTS ${qualified_name} ${table_definition}
    Execute Sql String    ${create_sql}
    Log    Table ${qualified_name} created (if not exists)    console=yes
    RETURN    ${TRUE}

Create Table From Template
    [Documentation]    Creates a table using a raw SQL statement or template.
    ...
    ...    Accepts any valid ``CREATE TABLE`` SQL and executes it safely.
    ...
    ...    *Arguments:*
    ...    - ``sql_query``: Complete SQL statement for table creation
    ...
    ...    *Example:*
    ...    | Create Table From Template | CREATE TABLE staging AS SELECT * FROM production WHERE 1=0 |
    [Arguments]    ${sql_query}

    Log    Creating table from template...    console=yes
    Log    SQL: ${sql_query}    console=yes

    Execute SQL String Safe    ${sql_query}
    Log    Table created successfully    console=yes

Drop Table
    [Documentation]    Drops a table from the database.
    ...
    ...    Supports optional ``IF EXISTS`` clause to prevent errors when the table
    ...    does not exist.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can be ``table`` or ``schema.table``)
    ...    - ``if_exists``: Whether to use ``IF EXISTS`` clause (default: TRUE)
    ...    - ``schema``: Optional schema name if not included in ``table_name``
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Drop Table | staging_data |
    ...    | Drop Table | employees | if_exists=${FALSE} | schema=dbo |
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
    [Documentation]    Safely drops a table if it exists, with optional ``CASCADE``.
    ...
    ...    Uses safe execution with error handling so the keyword does not fail
    ...    if the table does not exist or permissions are insufficient.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Name of the table to drop
    ...    - ``cascade``: If TRUE, appends ``CASCADE`` to drop dependent objects (default: FALSE)
    ...
    ...    *Example:*
    ...    | Drop Table If Exists | temp_staging |
    ...    | Drop Table If Exists | parent_table | cascade=${TRUE} |
    [Arguments]    ${table_name}    ${cascade}=${FALSE}

    Log    Dropping table if exists: ${table_name}    console=yes

    ${cascade_clause}=    Set Variable If    ${cascade}    CASCADE    ${EMPTY}
    ${sql}=    Set Variable    DROP TABLE IF EXISTS ${table_name} ${cascade_clause}

    Execute SQL String Safe    ${sql}
    Log    Table '${table_name}' dropped successfully    console=yes

Truncate Table
    [Documentation]    Removes all rows from a table while preserving the table structure.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can include schema, e.g. ``dbo.employees``)
    ...    - ``schema``: Optional schema name if not included in ``table_name``
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Truncate Table | staging_data |
    ...    | Truncate Table | employees | schema=dbo |
    [Arguments]    ${table_name}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    Execute Sql String    TRUNCATE TABLE ${qualified_name}
    Log    Table ${qualified_name} truncated    console=yes
    RETURN    ${TRUE}

Truncate Table If Exists
    [Documentation]    Removes all rows from a table if it exists, with optional verification.
    ...
    ...    If the table does not exist, logs a warning and continues without failing.
    ...    Optionally verifies the table is empty after truncation.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can include schema)
    ...    - ``schema``: Optional schema name
    ...    - ``verify_empty``: Whether to verify table has 0 rows after truncation (default: TRUE)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` if truncated successfully, ``${FALSE}`` if table does not exist
    ...
    ...    *Example:*
    ...    | ${result}= | Truncate Table If Exists | staging_data |
    ...    | Truncate Table If Exists | employees | schema=dbo | verify_empty=${FALSE} |
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
    [Documentation]    Renames a database table using ``ALTER TABLE ... RENAME TO``.
    ...
    ...    *Arguments:*
    ...    - ``old_table_name``: Current table name
    ...    - ``new_table_name``: New table name
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Rename syntax may vary between database engines.
    ...
    ...    *Example:*
    ...    | Rename Table | old_employees | employees_archive |
    [Arguments]    ${old_table_name}    ${new_table_name}    ${schema}=${EMPTY}

    ${old_qualified}=    Get Qualified Table Name    ${old_table_name}    ${schema}
    ${new_qualified}=    Get Qualified Table Name    ${new_table_name}    ${schema}

    Execute Sql String    ALTER TABLE ${old_qualified} RENAME TO ${new_qualified}
    Log    Table renamed from ${old_qualified} to ${new_qualified}    console=yes
    RETURN    ${TRUE}

# ==================== DATA MANIPULATION OPERATIONS (CRUD) ====================

Insert Into Table
    [Documentation]    Inserts a single row into a database table.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table (can include schema, e.g. ``dbo.employees``)
    ...    - ``columns``: Comma-separated column names (e.g. ``id, name, salary``)
    ...    - ``values``: Values to insert with proper SQL formatting (e.g. ``1, 'John', 50000``)
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Insert Into Table | employees | id, name | 1, 'John Doe' |
    ...    | Insert Into Table | dbo.employees | id, name | 2, 'Jane' | schema=dbo |
    [Arguments]    ${table_name}    ${columns}    ${values}    ${schema}=${EMPTY}

    ${qualified_name}=    Get Qualified Table Name    ${table_name}    ${schema}
    ${insert_sql}=    Set Variable    INSERT INTO ${qualified_name} (${columns}) VALUES (${values})
    Execute Sql String    ${insert_sql}
    Log    Data inserted into ${qualified_name}    console=yes
    RETURN    ${TRUE}

Bulk Insert Into Table
    [Documentation]    Inserts multiple rows into a table by calling ``Insert Into Table`` for each row.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``columns``: Comma-separated column names
    ...    - ``@{rows}``: List of value strings, each representing one row
    ...
    ...    *Returns:*
    ...    - Number of rows inserted
    ...
    ...    *Example:*
    ...    | ${count}= | Bulk Insert Into Table | employees | id, name |
    ...    | ... | 1, 'Alice' | 2, 'Bob' | 3, 'Charlie' |
    [Arguments]    ${table_name}    ${columns}    @{rows}

    ${row_count}=    Set Variable    ${0}
    FOR    ${row}    IN    @{rows}
        Insert Into Table    ${table_name}    ${columns}    ${row}
        ${row_count}=    Evaluate    ${row_count} + 1
    END

    Log    Inserted ${row_count} rows into ${table_name}    console=yes
    RETURN    ${row_count}

Update Table
    [Documentation]    Updates rows in a table based on a ``WHERE`` condition.
    ...
    ...    If no ``where_clause`` is provided, updates ALL rows and logs a warning.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Name of the table to update
    ...    - ``set_clause``: SQL SET clause (e.g. ``column1 = 'value1', column2 = 42``)
    ...    - ``where_clause``: Optional WHERE condition to filter rows (default: empty — updates all)
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Update Table | employees | salary = 60000 | id = 1 |
    ...    | Update Table | employees | status = 'inactive' | department = 'HR' | schema=dbo |
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
    [Documentation]    Deletes rows from a table based on a ``WHERE`` condition.
    ...
    ...    If no ``where_clause`` is provided, deletes ALL rows and logs a warning.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Name of the table
    ...    - ``where_clause``: Optional WHERE condition to filter rows (default: empty — deletes all)
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Delete From Table | staging_data | status = 'processed' |
    ...    | Delete From Table | employees | id > 100 | schema=dbo |
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
    [Documentation]    Inserts or updates a row based on primary key conflict.
    ...
    ...    Falls back to a standard ``INSERT`` in the default implementation.
    ...    Override this keyword for database-specific upsert syntax.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``columns``: Comma-separated column names
    ...    - ``values``: Values to insert
    ...    - ``update_clause``: SQL clause for conflict resolution
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Actual upsert syntax varies by database (MySQL ``ON DUPLICATE KEY``,
    ...    PostgreSQL ``ON CONFLICT``, Snowflake ``MERGE``).
    ...
    ...    *Example:*
    ...    | Upsert Into Table | employees | id, name | 1, 'John' | name = 'John' |
    [Arguments]    ${table_name}    ${columns}    ${values}    ${update_clause}

    Log    UPSERT operation varies by database type    WARN
    Log    Using standard INSERT for now - override this keyword for specific databases    console=yes
    Insert Into Table    ${table_name}    ${columns}    ${values}
    RETURN    ${TRUE}

# ==================== QUERY OPERATIONS ====================

Select All From Table
    [Documentation]    Selects all records from a database table.
    ...
    ...    Supports optional column selection, ordering, limiting, and schema qualification.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can include schema)
    ...    - ``columns``: Columns to select (default: ``*``)
    ...    - ``order_by``: Optional ``ORDER BY`` clause (e.g. ``id ASC``)
    ...    - ``limit``: Optional ``LIMIT`` value
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - List of result rows (each row is a tuple)
    ...
    ...    *Example:*
    ...    | ${rows}= | Select All From Table | employees |
    ...    | ${rows}= | Select All From Table | employees | columns=id, name | order_by=id |
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
    [Documentation]    Selects records from a table filtered by a ``WHERE`` condition.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can include schema)
    ...    - ``where_clause``: SQL WHERE condition (e.g. ``status = 'active'``)
    ...    - ``columns``: Columns to select (default: ``*``)
    ...    - ``order_by``: Optional ``ORDER BY`` clause
    ...    - ``limit``: Optional ``LIMIT`` value
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - List of result rows matching the condition
    ...
    ...    *Example:*
    ...    | ${rows}= | Select Where | employees | status = 'active' |
    ...    | ${rows}= | Select Where | employees | salary > 50000 | columns=id, name | order_by=salary DESC |
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
    [Documentation]    Returns the number of rows in a table using ``SELECT COUNT(*)``.
    ...
    ...    Supports optional ``WHERE`` filtering.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can include schema)
    ...    - ``where_clause``: Optional WHERE condition to filter counted rows
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - Integer row count
    ...
    ...    *Example:*
    ...    | ${count}= | Get Row Count | employees |
    ...    | ${count}= | Get Row Count | employees | where_clause=status = 'active' |
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
    [Documentation]    Gets the total number of rows in a table.
    ...
    ...    Simplified alias for ``Get Row Count`` without filtering options.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to count rows from
    ...
    ...    *Returns:*
    ...    - Integer row count
    ...
    ...    *Example:*
    ...    | ${count}= | Get Table Row Count | employees |
    ...
    ...    *See also:*
    ...    ``Get Row Count``
    [Arguments]    ${table_name}

    ${query}=    Set Variable    SELECT COUNT(*) FROM ${table_name}
    ${result}=    Query    ${query}
    ${count}=    Set Variable    ${result[0][0]}

    Log    Table '${table_name}' contains ${count} rows    console=yes
    RETURN    ${count}

Get Column Values
    [Documentation]    Returns all values from a specific column in a table.
    ...
    ...    Supports optional ``DISTINCT`` filtering and ``WHERE`` conditions.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can include schema)
    ...    - ``column_name``: Name of the column to retrieve values from
    ...    - ``distinct``: If TRUE, returns only unique values (default: FALSE)
    ...    - ``where_clause``: Optional WHERE condition
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - List of column values
    ...
    ...    *Example:*
    ...    | ${names}= | Get Column Values | employees | name |
    ...    | ${depts}= | Get Column Values | employees | department | distinct=${TRUE} |
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
    [Documentation]    Executes any ``SELECT`` query and returns the full result set.
    ...
    ...    *Arguments:*
    ...    - ``query``: Complete SQL SELECT query string
    ...
    ...    *Returns:*
    ...    - List of result rows
    ...
    ...    *Example:*
    ...    | ${results}= | Execute Custom Query | SELECT id, name FROM employees WHERE salary > 50000 |
    [Arguments]    ${query}

    Log    Executing custom query: ${query}    console=yes
    ${results}=    Query    ${query}

    ${row_count}=    Get Length    ${results}
    Log    Query returned ${row_count} rows    console=yes
    RETURN    ${results}

Execute Custom Command
    [Documentation]    Executes any SQL command (DDL/DML) without returning results.
    ...
    ...    Use for ``CREATE``, ``ALTER``, ``DROP``, ``INSERT``, ``UPDATE``, ``DELETE``
    ...    and other non-query statements.
    ...
    ...    *Arguments:*
    ...    - ``command``: Complete SQL command string
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Execute Custom Command | ALTER TABLE employees ADD COLUMN department VARCHAR(50) |
    [Arguments]    ${command}

    Log    Executing command: ${command}    console=yes
    Execute Sql String    ${command}
    Log    Command executed successfully    console=yes
    RETURN    ${TRUE}

Execute SQL Query And Get Count
    [Documentation]    Executes a ``COUNT`` query and returns the scalar result as an integer.
    ...
    ...    Expects the query to return a single row with a single numeric column.
    ...
    ...    *Arguments:*
    ...    - ``sql_query``: SQL query that returns a count (e.g. ``SELECT COUNT(*) FROM ...``)
    ...
    ...    *Returns:*
    ...    - Integer count value
    ...
    ...    *Example:*
    ...    | ${count}= | Execute SQL Query And Get Count | SELECT COUNT(*) FROM employees WHERE status = 'active' |
    [Arguments]    ${sql_query}

    Log    Executing count query: ${sql_query}    console=yes

    ${result}=    Query    ${sql_query}
    ${count_row}=    Get From List    ${result}    0
    ${count_value}=    Get From List    ${count_row}    0

    Log    Count query result: ${count_value}    console=yes
    RETURN    ${count_value}

Execute SQL Query And Get Results
    [Documentation]    Executes a SQL query and returns all result rows.
    ...
    ...    Includes error handling — fails with a descriptive message if the query errors.
    ...
    ...    *Arguments:*
    ...    - ``sql_query``: Complete SQL query string
    ...    - ``fetch_all``: If TRUE, returns list of tuples; if FALSE, returns as dictionaries (default: TRUE)
    ...
    ...    *Returns:*
    ...    - List of result rows
    ...
    ...    *Example:*
    ...    | ${results}= | Execute SQL Query And Get Results | SELECT * FROM employees |
    ...    | ${dicts}= | Execute SQL Query And Get Results | SELECT * FROM employees | fetch_all=${FALSE} |
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
    [Documentation]    Executes a SQL query and returns a single scalar value.
    ...
    ...    Fails if the query returns more or fewer than exactly one row.
    ...
    ...    *Arguments:*
    ...    - ``sql_query``: SQL query expected to return exactly one row with one column
    ...
    ...    *Returns:*
    ...    - The single scalar value from the query result
    ...
    ...    *Example:*
    ...    | ${name}= | Execute SQL Query And Get Single Value | SELECT name FROM employees WHERE id = 1 |
    ...    | ${max}= | Execute SQL Query And Get Single Value | SELECT MAX(salary) FROM employees |
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
    [Documentation]    Safely executes a SQL statement with ``TRY/EXCEPT`` error handling.
    ...
    ...    Catches execution errors and fails with a descriptive message.
    ...
    ...    *Arguments:*
    ...    - ``sql_statement``: Complete SQL statement to execute
    ...
    ...    *Example:*
    ...    | Execute SQL String Safe | CREATE TABLE staging (id INT, data TEXT) |
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
    [Documentation]    Reads and executes SQL statements from a script file.
    ...
    ...    Splits the file content by semicolons and executes each statement.
    ...    Comments (lines starting with ``--``) and empty lines are skipped.
    ...
    ...    *Arguments:*
    ...    - ``script_path``: Path to the ``.sql`` script file
    ...
    ...    *Example:*
    ...    | Execute SQL Script From File | ${CURDIR}/setup_tables.sql |
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
    [Documentation]    Splits raw SQL script content into individual executable statements.
    ...
    ...    Removes comment lines (``--``) and empty lines, then splits by semicolons.
    ...
    ...    *Arguments:*
    ...    - ``sql_content``: Raw SQL script content as a string
    ...
    ...    *Returns:*
    ...    - List of individual SQL statements (trimmed and filtered)
    ...
    ...    *Example:*
    ...    | ${stmts}= | Split SQL Script Content | ${sql_text} |
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
    [Documentation]    Reads a SQL file and executes all statements split by a delimiter.
    ...
    ...    *Arguments:*
    ...    - ``file_path``: Path to the SQL file
    ...    - ``delimiter``: Statement delimiter (default: ``;``)
    ...
    ...    *Returns:*
    ...    - ``${success}`` count and ``${errors}`` count
    ...
    ...    *Example:*
    ...    | ${ok} | ${err}= | Execute SQL File | ${CURDIR}/migrations.sql |
    ...    | ${ok} | ${err}= | Execute SQL File | ${CURDIR}/procs.sql | delimiter=GO |
    [Arguments]    ${file_path}    ${delimiter}=;

    ${file_content}=    Get File    ${file_path}
    @{statements}=    Split String    ${file_content}    ${delimiter}

    ${success}    ${errors}=    Execute SQL Script    @{statements}

    Log    Executed SQL file: ${file_path}    console=yes
    RETURN    ${success}    ${errors}

Execute SQL Script
    [Documentation]    Executes multiple SQL statements from a list with error tracking.
    ...
    ...    Skips empty statements and comment lines (``--``, ``#``).
    ...    Continues execution on error and reports success/failure counts.
    ...
    ...    *Arguments:*
    ...    - ``@{statements}``: List of SQL statement strings
    ...
    ...    *Returns:*
    ...    - ``${success_count}`` and ``${error_count}``
    ...
    ...    *Example:*
    ...    | ${ok} | ${err}= | Execute SQL Script | CREATE TABLE t1 (id INT) | INSERT INTO t1 VALUES (1) |
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
    [Documentation]    Executes a SQL template with variable substitution.
    ...
    ...    Replaces ``{variable_name}`` placeholders in the template with provided values.
    ...
    ...    *Arguments:*
    ...    - ``sql_template``: SQL string with ``{placeholder}`` tokens
    ...    - ``&{variables}``: Named variables to substitute into the template
    ...
    ...    *Example:*
    ...    | Execute SQL Template | INSERT INTO {table} ({col}) VALUES ('{val}') |
    ...    | ... | table=employees | col=name | val=John |
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
    [Documentation]    Adds a new column to an existing table using ``ALTER TABLE ADD COLUMN``.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``column_name``: Name of the new column
    ...    - ``column_definition``: Column type and constraints (e.g. ``VARCHAR(100) NOT NULL``)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Add Column To Table | employees | department | VARCHAR(50) DEFAULT 'General' |
    [Arguments]    ${table_name}    ${column_name}    ${column_definition}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ADD COLUMN ${column_name} ${column_definition}
    Execute Sql String    ${alter_sql}
    Log    Column ${column_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Drop Column From Table
    [Documentation]    Removes a column from a table using ``ALTER TABLE DROP COLUMN``.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``column_name``: Name of the column to remove
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Drop Column From Table | employees | legacy_field |
    [Arguments]    ${table_name}    ${column_name}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} DROP COLUMN ${column_name}
    Execute Sql String    ${alter_sql}
    Log    Column ${column_name} dropped from ${table_name}    console=yes
    RETURN    ${TRUE}

Modify Column
    [Documentation]    Modifies a column's data type or constraints.
    ...
    ...    Uses ``ALTER TABLE ... ALTER COLUMN`` syntax.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``column_name``: Column to modify
    ...    - ``new_definition``: New type/constraint definition
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Syntax varies between databases (``MODIFY COLUMN`` in MySQL, ``ALTER COLUMN`` in SQL Server).
    ...
    ...    *Example:*
    ...    | Modify Column | employees | salary | DECIMAL(12,2) |
    [Arguments]    ${table_name}    ${column_name}    ${new_definition}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ALTER COLUMN ${column_name} ${new_definition}
    Execute Sql String    ${alter_sql}
    Log    Column ${column_name} modified in ${table_name}    console=yes
    RETURN    ${TRUE}

Rename Column
    [Documentation]    Renames a column in a table using ``ALTER TABLE ... RENAME COLUMN``.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``old_column_name``: Current column name
    ...    - ``new_column_name``: New column name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Rename Column | employees | emp_name | employee_name |
    [Arguments]    ${table_name}    ${old_column_name}    ${new_column_name}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} RENAME COLUMN ${old_column_name} TO ${new_column_name}
    Execute Sql String    ${alter_sql}
    Log    Column renamed from ${old_column_name} to ${new_column_name}    console=yes
    RETURN    ${TRUE}

Get Table Columns
    [Documentation]    Gets column names from a database table.
    ...
    ...    Tries multiple approaches to retrieve columns (INFORMATION_SCHEMA, uppercase,
    ...    no-schema, DESCRIBE TABLE) to support different database engines including
    ...    Snowflake, Oracle, SQL Server, PostgreSQL, and MySQL.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name (can be ``table`` or ``schema.table``)
    ...    - ``schema``: Optional schema name (default: auto-detected)
    ...
    ...    *Returns:*
    ...    - List of column name strings
    ...
    ...    *Example:*
    ...    | @{cols}= | Get Table Columns | employees |
    ...    | @{cols}= | Get Table Columns | dbo.employees |
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
    [Documentation]    Gets detailed schema information for a table from ``INFORMATION_SCHEMA``.
    ...
    ...    Returns column name, data type, nullability, default value, and max character length.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to inspect
    ...    - ``schema``: Schema name (default: ``public``)
    ...
    ...    *Returns:*
    ...    - List of rows with column metadata (column_name, data_type, is_nullable, column_default, character_maximum_length)
    ...
    ...    *Example:*
    ...    | ${info}= | Get Table Schema Info | employees | schema=dbo |
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
    [Documentation]    Checks if a table exists in the database using ``INFORMATION_SCHEMA``.
    ...
    ...    Returns a boolean — does not fail if the table does not exist.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to check
    ...    - ``schema``: Schema name (default: ``public``)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` if table exists, ``${FALSE}`` otherwise
    ...
    ...    *Example:*
    ...    | ${exists}= | Check If Table Exists | employees | schema=dbo |
    ...
    ...    *See also:*
    ...    ``Table Should Exist``, ``Table Should Not Exist``
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
    [Documentation]    Returns the default schema name based on the detected database type.
    ...
    ...    *Returns:*
    ...    - Schema name string (e.g. ``dbo`` for SQL Server, ``public`` for PostgreSQL)
    ...
    ...    *Example:*
    ...    | ${schema}= | Get Default Schema |
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
    [Documentation]    Detects and returns the database engine type.
    ...
    ...    Uses cached result if available. Otherwise probes the connection with
    ...    engine-specific queries (Snowflake, Oracle, SQL Server, PostgreSQL, MySQL).
    ...
    ...    *Returns:*
    ...    - Database type string: ``SNOWFLAKE``, ``ORACLE``, ``SQLSERVER``, ``POSTGRESQL``, ``MYSQL``, or ``GENERIC``
    ...
    ...    *Example:*
    ...    | ${type}= | Get Database Type |
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
    [Documentation]    Returns the appropriate ``INFORMATION_SCHEMA`` query for column retrieval
    ...    based on the detected database type.
    ...
    ...    Generates engine-specific SQL for Snowflake, Oracle, SQL Server, PostgreSQL,
    ...    MySQL, or a generic fallback.
    ...
    ...    *Arguments:*
    ...    - ``table``: Table name (without schema)
    ...    - ``schema``: Schema name
    ...
    ...    *Returns:*
    ...    - SQL query string for retrieving column names
    ...
    ...    *Example:*
    ...    | ${query}= | Get Columns Query | employees | dbo |
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
    [Documentation]    Creates an index on a table, optionally unique.
    ...
    ...    *Arguments:*
    ...    - ``index_name``: Name of the index to create
    ...    - ``table_name``: Target table name
    ...    - ``columns``: Comma-separated column names to index
    ...    - ``unique``: If TRUE, creates a ``UNIQUE`` index (default: FALSE)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Create Index | idx_emp_name | employees | name |
    ...    | Create Index | uq_emp_email | employees | email | unique=${TRUE} |
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
    [Documentation]    Drops an index from the database.
    ...
    ...    *Arguments:*
    ...    - ``index_name``: Name of the index to drop
    ...    - ``table_name``: Table name (required by some databases like MySQL, optional for others)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Drop index syntax varies: MySQL requires ``ON table``, PostgreSQL does not.
    ...
    ...    *Example:*
    ...    | Drop Index | idx_emp_name |
    ...    | Drop Index | idx_emp_name | employees |
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
    [Documentation]    Creates a database view based on a ``SELECT`` query.
    ...
    ...    *Arguments:*
    ...    - ``view_name``: Name of the view to create
    ...    - ``select_query``: The ``SELECT`` query defining the view
    ...    - ``replace``: If TRUE, uses ``CREATE OR REPLACE`` (default: TRUE)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Create View | active_employees | SELECT * FROM employees WHERE status = 'active' |
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
    [Documentation]    Drops a database view.
    ...
    ...    *Arguments:*
    ...    - ``view_name``: Name of the view to drop
    ...    - ``if_exists``: If TRUE, uses ``IF EXISTS`` to avoid errors (default: TRUE)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Drop View | active_employees |
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
    [Documentation]    Adds a primary key constraint to a table.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``constraint_name``: Name for the constraint
    ...    - ``columns``: Comma-separated column names forming the primary key
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Add Primary Key | employees | pk_employees | id |
    ...    | Add Primary Key | order_items | pk_order_items | order_id, item_id |
    [Arguments]    ${table_name}    ${constraint_name}    ${columns}

    ${alter_sql}=    Set Variable
    ...    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} PRIMARY KEY (${columns})
    Execute Sql String    ${alter_sql}
    Log    Primary key ${constraint_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Add Foreign Key
    [Documentation]    Adds a foreign key constraint linking a column to a referenced table.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table containing the foreign key column
    ...    - ``constraint_name``: Name for the constraint
    ...    - ``column``: Column in the source table
    ...    - ``ref_table``: Referenced (parent) table
    ...    - ``ref_column``: Referenced column in the parent table
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Add Foreign Key | orders | fk_orders_customer | customer_id | customers | id |
    [Arguments]    ${table_name}    ${constraint_name}    ${column}    ${ref_table}    ${ref_column}

    ${alter_sql}=    Set Variable
    ...    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} FOREIGN KEY (${column}) REFERENCES ${ref_table}(${ref_column})
    Execute Sql String    ${alter_sql}
    Log    Foreign key ${constraint_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Add Unique Constraint
    [Documentation]    Adds a unique constraint to one or more columns.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``constraint_name``: Name for the constraint
    ...    - ``columns``: Comma-separated column names
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Add Unique Constraint | employees | uq_emp_email | email |
    [Arguments]    ${table_name}    ${constraint_name}    ${columns}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} ADD CONSTRAINT ${constraint_name} UNIQUE (${columns})
    Execute Sql String    ${alter_sql}
    Log    Unique constraint ${constraint_name} added to ${table_name}    console=yes
    RETURN    ${TRUE}

Drop Constraint
    [Documentation]    Drops a named constraint from a table.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table containing the constraint
    ...    - ``constraint_name``: Name of the constraint to drop
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Drop Constraint | employees | uq_emp_email |
    [Arguments]    ${table_name}    ${constraint_name}

    ${alter_sql}=    Set Variable    ALTER TABLE ${table_name} DROP CONSTRAINT ${constraint_name}
    Execute Sql String    ${alter_sql}
    Log    Constraint ${constraint_name} dropped from ${table_name}    console=yes
    RETURN    ${TRUE}

# ==================== VALIDATION OPERATIONS ====================

Table Should Exist
    [Documentation]    Asserts that a table exists in the database. Fails if not found.
    ...
    ...    Uses case-insensitive lookup via ``INFORMATION_SCHEMA``.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to verify
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success (fails if table does not exist)
    ...
    ...    *Example:*
    ...    | Table Should Exist | employees |
    ...    | Table Should Exist | employees | schema=dbo |
    ...
    ...    *See also:*
    ...    ``Table Should Not Exist``, ``Check If Table Exists``
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
    [Documentation]    Asserts that a table does NOT exist in the database. Fails if found.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to verify is absent
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success (fails if table exists)
    ...
    ...    *Example:*
    ...    | Table Should Not Exist | temp_staging |
    ...
    ...    *See also:*
    ...    ``Table Should Exist``, ``Check If Table Exists``
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
    [Documentation]    Asserts that a column exists in a table. Fails if not found.
    ...
    ...    Uses case-insensitive lookup via ``INFORMATION_SCHEMA``.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to check
    ...    - ``column_name``: Column name to verify
    ...    - ``schema``: Optional schema name
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success (fails if column does not exist)
    ...
    ...    *Example:*
    ...    | Column Should Exist | employees | email |
    ...    | Column Should Exist | employees | salary | schema=dbo |
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
    [Documentation]    Asserts that a table has exactly the expected number of rows.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to check
    ...    - ``expected_count``: Expected row count
    ...    - ``where_clause``: Optional WHERE condition to filter counted rows
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success (fails if count does not match)
    ...
    ...    *Example:*
    ...    | Row Count Should Be | employees | 100 |
    ...    | Row Count Should Be | employees | 5 | where_clause=department = 'HR' |
    [Arguments]    ${table_name}    ${expected_count}    ${where_clause}=${EMPTY}

    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}

    Should Be Equal As Integers    ${actual_count}    ${expected_count}
    ...    Table ${table_name} has ${actual_count} rows, expected ${expected_count}

    Log    Row count verified: ${actual_count} rows    console=yes
    RETURN    ${TRUE}

Row Count Should Be Greater Than
    [Documentation]    Asserts that a table's row count exceeds a minimum threshold.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to check
    ...    - ``min_count``: Minimum row count (exclusive)
    ...    - ``where_clause``: Optional WHERE condition
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Row Count Should Be Greater Than | employees | 0 |
    ...    | Row Count Should Be Greater Than | orders | 10 | where_clause=status = 'pending' |
    [Arguments]    ${table_name}    ${min_count}    ${where_clause}=${EMPTY}

    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}

    Should Be True    ${actual_count} > ${min_count}
    ...    Table ${table_name} has ${actual_count} rows, expected more than ${min_count}

    Log    Row count verified: ${actual_count} > ${min_count}    console=yes
    RETURN    ${TRUE}

Row Count Should Be Less Than
    [Documentation]    Asserts that a table's row count is below a maximum threshold.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to check
    ...    - ``max_count``: Maximum row count (exclusive)
    ...    - ``where_clause``: Optional WHERE condition
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Row Count Should Be Less Than | error_log | 100 |
    [Arguments]    ${table_name}    ${max_count}    ${where_clause}=${EMPTY}

    ${actual_count}=    Get Row Count    ${table_name}    ${where_clause}

    Should Be True    ${actual_count} < ${max_count}
    ...    Table ${table_name} has ${actual_count} rows, expected less than ${max_count}

    Log    Row count verified: ${actual_count} < ${max_count}    console=yes
    RETURN    ${TRUE}

Validate Table Data Count
    [Documentation]    Validates that a table contains exactly the expected number of rows.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to validate
    ...    - ``expected_count``: Expected row count
    ...
    ...    *Example:*
    ...    | Validate Table Data Count | employees | 50 |
    ...
    ...    *See also:*
    ...    ``Row Count Should Be``
    [Arguments]    ${table_name}    ${expected_count}

    Log    Validating data count for table: ${table_name}    console=yes
    Log    Expected count: ${expected_count}    console=yes

    ${actual_count}=    Get Table Row Count    ${table_name}

    Should Be Equal As Numbers    ${actual_count}    ${expected_count}
    ...    Table '${table_name}' has ${actual_count} rows, expected ${expected_count}

    Log    Table data count validation passed: ${actual_count} rows    console=yes

Compare Table Row Counts
    [Documentation]    Compares the row counts between two database tables.
    ...
    ...    *Arguments:*
    ...    - ``table1``: First table name
    ...    - ``table2``: Second table name
    ...    - ``should_match``: If TRUE, asserts counts are equal; if FALSE, asserts they differ (default: TRUE)
    ...
    ...    *Example:*
    ...    | Compare Table Row Counts | source_table | target_table |
    ...    | Compare Table Row Counts | staging | archive | should_match=${FALSE} |
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
    [Documentation]    Asserts that a table contains at least one row.
    ...
    ...    Fails if the table is empty (0 rows).
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to validate
    ...
    ...    *Example:*
    ...    | Validate Table Has Data | employees |
    ...
    ...    *See also:*
    ...    ``Validate Table Is Empty``
    [Arguments]    ${table_name}

    Log    Validating table has data: ${table_name}    console=yes

    ${count}=    Get Table Row Count    ${table_name}

    Should Be True    ${count} > 0
    ...    Table '${table_name}' is empty (0 rows)

    Log    Table '${table_name}' contains data: ${count} rows    console=yes

Validate Table Is Empty
    [Documentation]    Asserts that a table contains zero rows.
    ...
    ...    Fails if the table has any data.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to validate
    ...
    ...    *Example:*
    ...    | Validate Table Is Empty | staging_data |
    ...
    ...    *See also:*
    ...    ``Validate Table Has Data``
    [Arguments]    ${table_name}

    Log    Validating table is empty: ${table_name}    console=yes

    ${count}=    Get Table Row Count    ${table_name}

    Should Be Equal As Numbers    ${count}    0
    ...    Table '${table_name}' is not empty (${count} rows)

    Log    Table '${table_name}' is empty as expected    console=yes

Verify Table Columns
    [Documentation]    Verifies that a table contains all expected columns.
    ...
    ...    Uses case-insensitive comparison to handle databases like Snowflake
    ...    that uppercase column names. Reports missing and extra columns.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to verify
    ...    - ``@{expected_columns}``: List of expected column names
    ...
    ...    *Returns:*
    ...    - List of actual column names (fails if any expected columns are missing)
    ...
    ...    *Example:*
    ...    | @{cols}= | Verify Table Columns | employees | id | name | email | salary |
    ...
    ...    *See also:*
    ...    ``Verify Table Columns Match Exactly``, ``Verify Table Has Minimum Columns``
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
    [Documentation]    Verifies that a table's columns match exactly — both names and count.
    ...
    ...    Fails if there are missing columns OR extra columns beyond the expected list.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to verify
    ...    - ``@{expected_columns}``: Exact list of expected column names
    ...
    ...    *Returns:*
    ...    - List of actual column names
    ...
    ...    *Example:*
    ...    | @{cols}= | Verify Table Columns Match Exactly | employees | id | name | email |
    ...
    ...    *See also:*
    ...    ``Verify Table Columns``
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
    [Documentation]    Verifies that a table has at least the specified required columns.
    ...
    ...    Additional columns beyond the required list are allowed.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to verify
    ...    - ``@{required_columns}``: List of minimum required column names
    ...
    ...    *Returns:*
    ...    - List of actual column names
    ...
    ...    *Example:*
    ...    | @{cols}= | Verify Table Has Minimum Columns | employees | id | name |
    ...
    ...    *See also:*
    ...    ``Verify Table Columns``, ``Verify Table Columns Match Exactly``
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
    [Documentation]    Starts a new database transaction.
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Begin Transaction |
    ...
    ...    *See also:*
    ...    ``Commit Transaction``, ``Rollback Transaction``, ``Execute In Transaction``

    Execute Sql String    BEGIN TRANSACTION
    Log    Transaction started    console=yes
    RETURN    ${TRUE}

Commit Transaction
    [Documentation]    Commits the current database transaction.
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Commit Transaction |

    Execute Sql String    COMMIT
    Log    Transaction committed    console=yes
    RETURN    ${TRUE}

Rollback Transaction
    [Documentation]    Rolls back the current database transaction, undoing all changes.
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Rollback Transaction |

    Execute Sql String    ROLLBACK
    Log    Transaction rolled back    console=yes
    RETURN    ${TRUE}

Execute In Transaction
    [Documentation]    Executes multiple SQL statements within a transaction.
    ...
    ...    Automatically rolls back all changes if any statement fails.
    ...    Commits on success.
    ...
    ...    *Arguments:*
    ...    - ``@{statements}``: List of SQL statements to execute atomically
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success (fails and rolls back on any error)
    ...
    ...    *Example:*
    ...    | Execute In Transaction |
    ...    | ... | INSERT INTO accounts (id, balance) VALUES (1, 1000) |
    ...    | ... | UPDATE accounts SET balance = balance - 100 WHERE id = 2 |
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
    [Documentation]    Executes SQL statement(s) within a transaction with optional auto-commit.
    ...
    ...    Accepts a single SQL string or a list of SQL strings.
    ...    Rolls back automatically on error.
    ...
    ...    *Arguments:*
    ...    - ``sql_statements``: Single SQL string or list of SQL strings
    ...    - ``auto_commit``: If TRUE, commits after execution (default: TRUE)
    ...
    ...    *Example:*
    ...    | Execute SQL With Transaction | INSERT INTO log (msg) VALUES ('test') |
    ...    | Execute SQL With Transaction | ${list_of_statements} | auto_commit=${FALSE} |
    ...
    ...    *See also:*
    ...    ``Execute In Transaction``
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
    [Documentation]    Returns a list of all base tables in the database or schema.
    ...
    ...    Queries ``INFORMATION_SCHEMA.TABLES`` for tables of type ``BASE TABLE``.
    ...
    ...    *Arguments:*
    ...    - ``schema``: Optional schema name to filter tables
    ...
    ...    *Returns:*
    ...    - List of table name strings
    ...
    ...    *Example:*
    ...    | @{tables}= | Get Table List |
    ...    | @{tables}= | Get Table List | schema=dbo |
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
    [Documentation]    Compares data between two database tables directly in memory.
    ...
    ...    Queries both tables and asserts the result sets are identical using
    ...    ``Lists Should Be Equal``. No CSV export is involved.
    ...
    ...    *Arguments:*
    ...    - ``table1``: First table name
    ...    - ``table2``: Second table name
    ...    - ``columns``: Columns to compare (default: ``*``)
    ...    - ``order_by``: Optional ``ORDER BY`` clause for consistent ordering
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` if data is identical (fails on mismatch)
    ...
    ...    *Example:*
    ...    | Compare Table Data | source_table | target_table |
    ...    | Compare Table Data | staging | production | columns=id, name | order_by=id |
    ...
    ...    *See also:*
    ...    ``Compare Two Tables``, ``Verify Tables Are Identical``
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
    [Documentation]    Creates a backup copy of a table using ``CREATE TABLE ... AS SELECT``.
    ...
    ...    *Arguments:*
    ...    - ``source_table``: Source table to back up
    ...    - ``backup_table``: Name for the backup table
    ...    - ``drop_if_exists``: If TRUE, drops existing backup table first (default: TRUE)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Backup Table | employees | employees_backup |
    ...
    ...    *See also:*
    ...    ``Backup Table Data``
    [Arguments]    ${source_table}    ${backup_table}    ${drop_if_exists}=${TRUE}

    IF    ${drop_if_exists}
        Drop Table    ${backup_table}    if_exists=${TRUE}
    END

    Execute Sql String    CREATE TABLE ${backup_table} AS SELECT * FROM ${source_table}

    ${count}=    Get Row Count    ${backup_table}
    Log    Table ${source_table} backed up to ${backup_table} (${count} rows)    console=yes

    RETURN    ${TRUE}

Backup Table Data
    [Documentation]    Creates a backup of a table with row count verification.
    ...
    ...    After creating the backup, verifies the row counts match between
    ...    source and backup tables.
    ...
    ...    *Arguments:*
    ...    - ``source_table``: Source table to back up
    ...    - ``backup_table``: Name for the backup table
    ...    - ``drop_if_exists``: If TRUE, drops existing backup table first (default: TRUE)
    ...
    ...    *Example:*
    ...    | Backup Table Data | employees | employees_bak |
    ...
    ...    *See also:*
    ...    ``Backup Table``
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
    [Documentation]    Removes all data from a table. Alias for ``Truncate Table``.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to clear
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Clear Table Data | staging_data |
    [Arguments]    ${table_name}

    Truncate Table    ${table_name}
    RETURN    ${TRUE}

Clean Database Tables
    [Documentation]    Cleans up test tables by truncating or dropping them.
    ...
    ...    Accepts a list of table names or a single table name.
    ...    Continues on error so one failed cleanup does not block others.
    ...
    ...    *Arguments:*
    ...    - ``tables``: Table name string or list of table name strings
    ...    - ``operation``: ``TRUNCATE`` or ``DROP`` (default: ``TRUNCATE``)
    ...
    ...    *Example:*
    ...    | Clean Database Tables | ${table_list} |
    ...    | Clean Database Tables | ${table_list} | operation=DROP |
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
    [Documentation]    Truncates a table before test execution to ensure a clean state.
    ...
    ...    Wrapper around ``Truncate Table If Exists`` with schema support.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to clean
    ...    - ``schema_name``: Schema name for the table
    ...
    ...    *Example:*
    ...    | Clean Table | staging_data | dbo |
    [Arguments]    ${table_name}    ${schema_name}
    Log    Cleaning table before execution    console=yes
    Truncate Table If Exists    ${table_name}    schema=${schema_name}

# ==================== DATABASE/SCHEMA MANAGEMENT ====================

Use Database
    [Documentation]    Switches the active database context.
    ...
    ...    *Arguments:*
    ...    - ``database_name``: Name of the database to switch to
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Not all databases support ``USE DATABASE`` (e.g. PostgreSQL does not).
    ...
    ...    *Example:*
    ...    | Use Database | analytics_db |
    [Arguments]    ${database_name}

    Execute Sql String    USE DATABASE ${database_name}
    Log    Switched to database: ${database_name}    console=yes
    RETURN    ${TRUE}

Use Schema
    [Documentation]    Switches the active schema context.
    ...
    ...    *Arguments:*
    ...    - ``schema_name``: Name of the schema to switch to
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Schema support varies by database engine.
    ...
    ...    *Example:*
    ...    | Use Schema | analytics |
    [Arguments]    ${schema_name}

    Execute Sql String    USE SCHEMA ${schema_name}
    Log    Switched to schema: ${schema_name}    console=yes
    RETURN    ${TRUE}

Get Current Database Context
    [Documentation]    Returns the current database context information.
    ...
    ...    Queries ``SELECT DATABASE()`` to identify the active database.
    ...
    ...    *Returns:*
    ...    - Dictionary with ``database`` key, or empty string if unsupported
    ...
    ...    *Example:*
    ...    | ${ctx}= | Get Current Database Context |
    ...    | Log | Current DB: ${ctx}[database] |
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
    [Documentation]    Converts query result tuples to a list of dictionaries.
    ...
    ...    Maps each result row to a dictionary using the provided column names.
    ...
    ...    *Arguments:*
    ...    - ``query_results``: List of result row tuples from a ``Query`` call
    ...    - ``column_names``: List of column name strings (must match column order)
    ...
    ...    *Returns:*
    ...    - List of dictionaries (one per row)
    ...
    ...    *Example:*
    ...    | ${results}= | Query | SELECT id, name FROM employees |
    ...    | ${dicts}= | Convert Query Results To Dictionary | ${results} | id | name |
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
    [Documentation]    Returns the first row from a table as a dictionary.
    ...
    ...    Automatically retrieves column names and maps the first row's values.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to query
    ...    - ``where_clause``: Optional WHERE condition to filter rows
    ...
    ...    *Returns:*
    ...    - Dictionary with column names as keys and first row values as values
    ...
    ...    *Example:*
    ...    | ${row}= | Get First Row As Dictionary | employees |
    ...    | ${row}= | Get First Row As Dictionary | employees | where_clause=id = 1 |
    ...    | Log | Name: ${row}[name] |
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
    [Documentation]    Selects all records from a table and returns them as a list of dictionaries.
    ...
    ...    Each row is a dictionary with column names as keys.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to query
    ...    - ``order_by``: Optional ``ORDER BY`` clause
    ...    - ``where_clause``: Optional WHERE condition
    ...
    ...    *Returns:*
    ...    - List of row dictionaries
    ...
    ...    *Example:*
    ...    | @{data}= | Get Table Data As Dictionary | employees | order_by=id |
    ...    | Log | First employee: ${data}[0][name] |
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
    [Documentation]    Extracts all values for a specific column from dictionary results.
    ...
    ...    *Arguments:*
    ...    - ``dict_results``: List of row dictionaries (from ``Get Table Data As Dictionary``)
    ...    - ``column_name``: Column name to extract
    ...
    ...    *Returns:*
    ...    - List of values for the specified column
    ...
    ...    *Example:*
    ...    | @{data}= | Get Table Data As Dictionary | employees |
    ...    | @{names}= | Extract Column Values From Dictionary | ${data} | name |
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
    [Documentation]    Extracts values for multiple columns from dictionary results.
    ...
    ...    Returns a dictionary where each key is a column name and each value
    ...    is a list of that column's values across all rows.
    ...
    ...    *Arguments:*
    ...    - ``dict_results``: List of row dictionaries
    ...    - ``@{column_names}``: Column names to extract
    ...
    ...    *Returns:*
    ...    - Dictionary of ``{column_name: [values]}``
    ...
    ...    *Example:*
    ...    | ${extracted}= | Extract Multiple Columns From Dictionary | ${data} | name | salary |
    ...    | Log | Names: ${extracted}[name] |
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
    [Documentation]    Extracts unique (deduplicated) values for a column from dictionary results.
    ...
    ...    Returns sorted unique values.
    ...
    ...    *Arguments:*
    ...    - ``dict_results``: List of row dictionaries
    ...    - ``column_name``: Column name to extract unique values from
    ...
    ...    *Returns:*
    ...    - Sorted list of unique values
    ...
    ...    *Example:*
    ...    | @{departments}= | Get Unique Column Values | ${data} | department |
    [Arguments]    ${dict_results}    ${column_name}

    @{all_values}=    Extract Column Values From Dictionary    ${dict_results}    ${column_name}

    ${unique_values}=    Evaluate    list(set(${all_values}))
    ${unique_values}=    Evaluate    sorted(${unique_values})

    ${count}=    Get Length    ${unique_values}
    Log    Found ${count} unique values for ${column_name}: ${unique_values}    console=yes
    RETURN    ${unique_values}

Filter Dictionary Results By Column Value
    [Documentation]    Filters dictionary results based on a column value condition.
    ...
    ...    Supported operators: ``==``, ``!=``, ``>``, ``>=``, ``<``, ``<=``, ``IN``, ``LIKE``.
    ...
    ...    *Arguments:*
    ...    - ``dict_results``: List of row dictionaries
    ...    - ``column_name``: Column name to filter on
    ...    - ``operator``: Comparison operator
    ...    - ``value``: Value to compare against
    ...
    ...    *Returns:*
    ...    - Filtered list of row dictionaries matching the condition
    ...
    ...    *Example:*
    ...    | ${active}= | Filter Dictionary Results By Column Value | ${data} | status | == | active |
    ...    | ${high_sal}= | Filter Dictionary Results By Column Value | ${data} | salary | > | 50000 |
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
    [Documentation]    Helper keyword to evaluate a single condition for column filtering.
    ...
    ...    Used internally by ``Filter Dictionary Results By Column Value``.
    ...
    ...    *Arguments:*
    ...    - ``actual_value``: The actual column value from the row
    ...    - ``operator``: Comparison operator (``==``, ``!=``, ``>``, ``>=``, ``<``, ``<=``, ``IN``, ``LIKE``)
    ...    - ``expected_value``: The value to compare against
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` if condition matches, ``${FALSE}`` otherwise
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
    [Documentation]    Builds an ``INSERT`` SQL statement from a dictionary row and table column list.
    ...
    ...    Maps dictionary keys to table columns (case-insensitive), handles NULL values,
    ...    escapes quotes, and detects column name casing conventions.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Target table name
    ...    - ``row_dict``: Dictionary representing one row of data
    ...    - ``table_columns``: List of column names from the target table
    ...
    ...    *Returns:*
    ...    - Complete ``INSERT INTO ... VALUES (...)`` SQL string
    ...
    ...    *Example:*
    ...    | ${sql}= | Build Insert SQL From Dict | employees | ${row_data} | ${columns} |
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
    [Documentation]    Exports a database table to a CSV file.
    ...
    ...    Retrieves all data from the table, formats values for CSV (handling NULLs,
    ...    quoting, special characters), and writes to the specified output file.
    ...    Logs progress every 100 rows.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to export
    ...    - ``output_file``: Path for the output CSV file
    ...    - ``include_headers``: Whether to include column headers as first row (default: TRUE)
    ...    - ``order_by``: Optional ``ORDER BY`` clause
    ...    - ``where_clause``: Optional WHERE condition to filter exported rows
    ...
    ...    *Returns:*
    ...    - Dictionary with keys: ``file_path``, ``row_count``, ``columns``, ``table_name``, ``include_headers``
    ...
    ...    *Example:*
    ...    | ${result}= | Export Table To CSV | employees | /tmp/employees.csv |
    ...    | ${result}= | Export Table To CSV | orders | /tmp/orders.csv | order_by=id | where_clause=status='active' |
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
    [Documentation]    Formats a single value for CSV output.
    ...
    ...    Handles NULL conversion to empty string, escapes double quotes,
    ...    and wraps values containing commas, quotes, or newlines in double quotes.
    ...
    ...    *Arguments:*
    ...    - ``value``: The value to format
    ...
    ...    *Returns:*
    ...    - CSV-safe string representation of the value
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
    [Documentation]    Compares a database table's data against an expected CSV file.
    ...
    ...    Exports the table to a temporary CSV, then delegates to ``Compare CSV Files``
    ...    for a detailed diff. On success, cleans up the temp file (unless ``KEEP_ACTUAL_FILES``
    ...    is set). On failure, preserves the actual CSV for investigation.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to compare
    ...    - ``expected_csv``: Path to the expected CSV file
    ...    - ``ignore_order``: If TRUE, compares rows regardless of order (default: FALSE)
    ...    - ``order_by``: Optional ``ORDER BY`` clause for consistent ordering
    ...    - ``where_clause``: Optional WHERE condition to filter table data
    ...    - ``temp_dir``: Directory for temporary CSV (default: ``ACTUAL_DATA_DIR`` or ``/tmp``)
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary with ``status``, ``total_differences``, ``actual_file``, ``export_details``
    ...
    ...    *Example:*
    ...    | ${result}= | Compare Table With CSV File | employees | ${EXPECTED_DIR}/employees.csv |
    ...    | Should Be Equal | ${result}[status] | IDENTICAL |
    ...
    ...    *See also:*
    ...    ``Verify Table Matches CSV``, ``Compare Two Tables``
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
    [Documentation]    High-level assertion that verifies a table's data matches an expected CSV file.
    ...
    ...    Wraps ``Compare Table With CSV File`` and asserts the result status is ``IDENTICAL``.
    ...    Fails with the number of differences and path to the actual data file.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to verify
    ...    - ``expected_csv``: Path to the expected CSV file
    ...    - ``ignore_order``: If TRUE, compares rows regardless of order (default: FALSE)
    ...    - ``order_by``: Optional ``ORDER BY`` clause
    ...    - ``temp_dir``: Directory for temporary CSV
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary (fails if not ``IDENTICAL``)
    ...
    ...    *Example:*
    ...    | Verify Table Matches CSV | employees | ${EXPECTED_DIR}/employees.csv |
    ...    | Verify Table Matches CSV | orders | ${EXPECTED_DIR}/orders.csv | ignore_order=${TRUE} |
    ...
    ...    *See also:*
    ...    ``Compare Table With CSV File``
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
    [Documentation]    Executes a custom SQL query and exports the results to a CSV file.
    ...
    ...    Unlike ``Export Table To CSV`` which takes a table name, this keyword
    ...    accepts a raw SQL query for flexible data extraction.
    ...
    ...    *Arguments:*
    ...    - ``query``: SQL SELECT query to execute
    ...    - ``output_file``: Path for the output CSV file
    ...    - ``@{column_names}``: Optional column names for the CSV header
    ...    - ``include_headers``: Whether to write headers (default: TRUE, requires ``column_names``)
    ...
    ...    *Returns:*
    ...    - Dictionary with keys: ``file_path``, ``row_count``, ``query``
    ...
    ...    *Example:*
    ...    | ${result}= | Export Query Results To CSV |
    ...    | ... | SELECT id, name FROM employees WHERE dept = 'HR' |
    ...    | ... | /tmp/hr_employees.csv | id | name |
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
    [Documentation]    Compares data between two database tables via CSV export.
    ...
    ...    Exports both tables to temporary CSV files, then delegates to
    ...    ``Compare CSV Files`` for a detailed diff. Cleans up temp files after comparison.
    ...
    ...    *Arguments:*
    ...    - ``table1``: First table name
    ...    - ``table2``: Second table name
    ...    - ``ignore_order``: If TRUE, compares rows regardless of order (default: FALSE)
    ...    - ``order_by``: Optional ``ORDER BY`` clause for consistent ordering
    ...    - ``temp_dir``: Directory for temporary CSV files (default: ``/tmp``)
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary with ``status``, ``total_differences``, ``table1``, ``table2``
    ...
    ...    *Example:*
    ...    | ${result}= | Compare Two Tables | source_table | target_table |
    ...    | ${result}= | Compare Two Tables | staging | production | ignore_order=${TRUE} | order_by=id |
    ...
    ...    *See also:*
    ...    ``Verify Tables Are Identical``, ``Compare Table Data``
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
    [Documentation]    Asserts that two database tables contain identical data.
    ...
    ...    Wraps ``Compare Two Tables`` and asserts the result status is ``IDENTICAL``.
    ...
    ...    *Arguments:*
    ...    - ``table1``: First table name
    ...    - ``table2``: Second table name
    ...    - ``ignore_order``: If TRUE, compares rows regardless of order (default: FALSE)
    ...    - ``order_by``: Optional ``ORDER BY`` clause
    ...
    ...    *Returns:*
    ...    - Comparison result dictionary (fails if not ``IDENTICAL``)
    ...
    ...    *Example:*
    ...    | Verify Tables Are Identical | source_table | target_table |
    ...
    ...    *See also:*
    ...    ``Compare Two Tables``, ``Compare Table Data``
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
    [Documentation]    Exports a database table to a JSON file.
    ...
    ...    Converts table data to a list of dictionaries and writes as formatted JSON.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to export
    ...    - ``output_file``: Path for the output JSON file
    ...    - ``order_by``: Optional ``ORDER BY`` clause
    ...    - ``where_clause``: Optional WHERE condition
    ...
    ...    *Returns:*
    ...    - Dictionary with keys: ``file_path``, ``row_count``, ``table_name``
    ...
    ...    *Example:*
    ...    | ${result}= | Export Table To JSON | employees | /tmp/employees.json |
    ...    | ${result}= | Export Table To JSON | orders | /tmp/orders.json | order_by=id | where_clause=status='active' |
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
    [Documentation]    Simplified wrapper to export a database table to CSV for verification.
    ...
    ...    Delegates to ``Export Table To CSV`` with headers enabled.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to export
    ...    - ``order_by_column``: Column name to order results by
    ...    - ``output_file``: Path for the output CSV file
    ...
    ...    *Example:*
    ...    | Export DB Table Data To CSV | employees | id | /tmp/employees_actual.csv |
    ...
    ...    *See also:*
    ...    ``Export Table To CSV``
    [Arguments]    ${table_name}    ${order_by_column}    ${output_file}

    ${export_result}=    Export Table To CSV
    ...    ${table_name}
    ...    ${output_file}
    ...    include_headers=${TRUE}
    ...    order_by=${order_by_column}

    Log    Exported ${export_result}[row_count] rows to ${export_result}[file_path]    console=yes
    Log    CSV file location: ${output_file}    console=yes

Capture And Verify Number of records From DB Table
    [Documentation]    Queries a table and verifies the row count matches the expected value.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to query
    ...    - ``schema_name``: Schema name for the table
    ...    - ``order_by_column``: Column name to order results by
    ...    - ``expected_records_count``: Expected number of rows
    ...
    ...    *Example:*
    ...    | Capture And Verify Number of records From DB Table | employees | dbo | id | 150 |
    ...
    ...    *See also:*
    ...    ``Row Count Should Be``, ``Validate Table Data Count``
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
    [Documentation]    Creates a stored procedure by executing the provided SQL body.
    ...
    ...    *Arguments:*
    ...    - ``procedure_name``: Name of the procedure (used for logging)
    ...    - ``procedure_body``: Complete ``CREATE PROCEDURE`` SQL statement
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Note:*
    ...    Stored procedure syntax varies between database engines.
    ...
    ...    *Example:*
    ...    | Create Stored Procedure | sp_cleanup | CREATE PROCEDURE sp_cleanup AS DELETE FROM staging WHERE processed = 1 |
    [Arguments]    ${procedure_name}    ${procedure_body}

    Log    Creating stored procedure: ${procedure_name}    console=yes
    Execute Sql String    ${procedure_body}
    Log    Stored procedure ${procedure_name} created    console=yes
    RETURN    ${TRUE}

Drop Stored Procedure
    [Documentation]    Drops a stored procedure from the database.
    ...
    ...    *Arguments:*
    ...    - ``procedure_name``: Name of the procedure to drop
    ...    - ``if_exists``: If TRUE, uses ``IF EXISTS`` clause (default: TRUE)
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Drop Stored Procedure | sp_cleanup |
    [Arguments]    ${procedure_name}    ${if_exists}=${TRUE}

    IF    ${if_exists}
        Execute Sql String    DROP PROCEDURE IF EXISTS ${procedure_name}
    ELSE
        Execute Sql String    DROP PROCEDURE ${procedure_name}
    END

    Log    Stored procedure ${procedure_name} dropped    console=yes
    RETURN    ${TRUE}

Call Stored Procedure
    [Documentation]    Calls a stored procedure with the specified parameters.
    ...
    ...    *Arguments:*
    ...    - ``procedure_name``: Name of the procedure to call
    ...    - ``@{parameters}``: List of parameter values
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Call Stored Procedure | sp_process_batch | 2024 | Q1 |
    [Arguments]    ${procedure_name}    @{parameters}

    ${params}=    Evaluate    ', '.join(${parameters})
    ${call_sql}=    Set Variable    CALL ${procedure_name}(${params})

    Execute Sql String    ${call_sql}
    Log    Stored procedure ${procedure_name} called with parameters: ${params}    console=yes
    RETURN    ${TRUE}

# ==================== PERFORMANCE OPERATIONS ====================

Analyze Table
    [Documentation]    Runs ``ANALYZE TABLE`` to update table statistics for query optimization.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to analyze
    ...
    ...    *Returns:*
    ...    - ``${TRUE}`` on success
    ...
    ...    *Example:*
    ...    | Analyze Table | employees |
    [Arguments]    ${table_name}

    Execute Sql String    ANALYZE TABLE ${table_name}
    Log    Table ${table_name} analyzed    console=yes
    RETURN    ${TRUE}

Get Table Size
    [Documentation]    Returns the approximate size of a table as a row count.
    ...
    ...    *Arguments:*
    ...    - ``table_name``: Table name to measure
    ...
    ...    *Returns:*
    ...    - Row count (as a proxy for table size)
    ...
    ...    *Example:*
    ...    | ${size}= | Get Table Size | employees |
    [Arguments]    ${table_name}

    ${count}=    Get Row Count    ${table_name}
    Log    Table ${table_name} has ${count} rows    console=yes
    RETURN    ${count}
