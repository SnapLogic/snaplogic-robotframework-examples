# ──────────────────────────────────────────────────────────────────────────────
# Oracle Database — SQL Operations Tutorial
#
# Demonstrates ONE example of each common SQL operation using
# `resources/common/sql_table_operations.resource`.
#
# All examples operate on a small demo table EMPLOYEES_TUTORIAL.
# Run with:  make robot-run-tests-no-gp TAGS="connect_to_oracle_database_sample"
#
# Test cases run sequentially: Account → DDL → DML → Read → Schema
# evolution → Index/View → Verifications → Raw SQL → Cleanup.
#
# Oracle-specific notes:
#  • Oracle does NOT support CREATE TABLE IF NOT EXISTS — use
#    `Create Table From Template` with a full SQL string + a guarded drop
#    if you need idempotency.
#  • `Table Should Exist` / `Check If Table Exists` from the shared resource
#    use INFORMATION_SCHEMA (MySQL/Postgres/SQL Server). For Oracle, use the
#    raw-SQL helper against USER_TABLES — shown in the VERIFY section.
# ──────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation       Tutorial — common Oracle SQL operations using sql_table_operations.resource

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource
Resource            ../../../../../resources/common/sql_table_operations.resource
Resource            ../../../../test_data/queries/oracle2_queries.resource

Suite Setup         Initialize Variables


*** Variables ***
${TUTORIAL_TABLE}                EMPLOYEES_TUTORIAL


*** Test Cases ***
# ═══════════════════════════════════════════════════════════════
# 1. ACCOUNT
# ═══════════════════════════════════════════════════════════════

Create Account
    [Documentation]    Creates the Oracle account in the project space.
    [Tags]    connect_to_oracle_database_sample
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}

# ═══════════════════════════════════════════════════════════════
# 2. SETUP — DDL (Create / Truncate)
# ═══════════════════════════════════════════════════════════════

DDL — Drop, Create, Truncate
    [Documentation]    Demonstrates table-level DDL keywords.
    ...    Keywords shown:
    ...    • Drop Table If Exists       — idempotent drop
    ...    • Execute Sql String         — direct CREATE (errors propagate, unlike *_Safe variants)
    ...    • Truncate Table             — empty without dropping
    ...
    ...    Note on multi-line SQL: Robot Framework's `...` continuation creates
    ...    SEPARATE arguments — not a multi-line string. We use `Catenate` to
    ...    join the lines into one string before passing it to the SQL keyword.
    ...
    ...    Note on safe vs unsafe SQL keywords:
    ...    `Execute SQL String Safe` and `Create Table From Template` wrap SQL
    ...    in try/except and SWALLOW errors — fine for cleanup, dangerous for
    ...    setup (a malformed CREATE will silently pass). Use `Execute Sql
    ...    String` (from DatabaseLibrary) when you want errors to fail the test.
    [Tags]    connect_to_oracle_database_sample

    # Always start clean (idempotent — succeeds whether or not the table exists)
    Drop Table If Exists    ${TUTORIAL_TABLE}

    # Build the multi-line CREATE SQL as a SINGLE string via Catenate
    ${create_sql}=    Catenate    SEPARATOR=${SPACE}
    ...    CREATE TABLE ${TUTORIAL_TABLE} (
    ...        ID NUMBER PRIMARY KEY,
    ...        NAME VARCHAR2(100) NOT NULL,
    ...        ROLE VARCHAR2(100),
    ...        SALARY NUMBER(10,2),
    ...        HIRE_DATE DATE
    ...    )
    Log    Executing CREATE: ${create_sql}    console=yes

    # Use Execute Sql String (DatabaseLibrary) — errors propagate and fail the test
    Execute Sql String    ${create_sql}

    # Verify the table really exists before downstream tests rely on it
    ${exists}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = '${TUTORIAL_TABLE}'
    Should Be Equal As Integers    ${exists}    1
    ...    msg=Create failed silently — ${TUTORIAL_TABLE} not found in USER_TABLES

    # Empty the table (keeps structure)
    Truncate Table    ${TUTORIAL_TABLE}

# ═══════════════════════════════════════════════════════════════
# 3. DML — Insert / Update / Delete
# ═══════════════════════════════════════════════════════════════

DML — Insert / Update / Delete
    [Documentation]    Demonstrates row-level DML keywords.
    ...    Keywords shown:
    ...    • Insert Into Table         — single row (columns string + values string)
    ...    • Bulk Insert Into Table    — many rows in one call
    ...    • Update Table              — SET clause + WHERE clause
    ...    • Delete From Table         — WHERE clause
    [Tags]    connect_to_oracle_database_sample

    # Single-row insert
    # Signature: table, "col1, col2, ..."    "val1, val2, ..."
    Insert Into Table    ${TUTORIAL_TABLE}    ID, NAME, ROLE, SALARY, HIRE_DATE    1, 'Alice', 'Engineer', 80000, DATE '2024-01-15'

    # Bulk insert — multiple value rows in one call
    Bulk Insert Into Table    ${TUTORIAL_TABLE}    ID, NAME, ROLE, SALARY, HIRE_DATE
    ...    2, 'Bob', 'Analyst', 65000, DATE '2024-03-01'
    ...    3, 'Carol', 'Manager', 95000, DATE '2023-11-20'
    ...    4, 'Dave', 'Lead', 110000, DATE '2022-07-10'

    # Update — give Alice a raise
    Update Table    ${TUTORIAL_TABLE}    SALARY = 85000    where_clause=ID = 1

    # Delete — remove anyone in the Analyst role
    Delete From Table    ${TUTORIAL_TABLE}    where_clause=ROLE = 'Analyst'

# ═══════════════════════════════════════════════════════════════
# 4. READ — Select / Count / Get values
# ═══════════════════════════════════════════════════════════════

READ — Select / Count / Get values
    [Documentation]    Demonstrates read-only query keywords.
    ...    Keywords shown:
    ...    • Select All From Table     — every row, returned as list of tuples
    ...    • Select Where              — filtered rows
    ...    • Get Row Count             — COUNT(*) with optional WHERE
    ...    • Get Table Row Count       — simpler alias, no filter
    ...    • Get Column Values         — list of values from one column
    ...    • Get Column Value          — single cell lookup
    [Tags]    connect_to_oracle_database_sample

    @{all_rows}=    Select All From Table    ${TUTORIAL_TABLE}    order_by=ID
    Log    All rows: ${all_rows}    console=yes

    @{filtered}=    Select Where    ${TUTORIAL_TABLE}    SALARY > 70000    order_by=ID
    Log    High earners: ${filtered}    console=yes

    ${total_count}=    Get Row Count    ${TUTORIAL_TABLE}
    ${high_paid_count}=    Get Row Count    ${TUTORIAL_TABLE}    where_clause=SALARY > 80000
    ${simple_count}=    Get Table Row Count    ${TUTORIAL_TABLE}
    Log    Total: ${total_count} | High-paid: ${high_paid_count} | Simple: ${simple_count}    console=yes

    @{names}=    Get Column Values    ${TUTORIAL_TABLE}    NAME
    Log    All names: ${names}    console=yes

    ${alice_role}=    Get Column Value    ${TUTORIAL_TABLE}    NAME    Alice    ROLE
    Log    Alice's role: ${alice_role}    console=yes

# ═══════════════════════════════════════════════════════════════
# 5. SCHEMA EVOLUTION — Add / Modify / Rename / Drop columns
# ═══════════════════════════════════════════════════════════════

SCHEMA — Add / Modify / Rename / Drop columns
    [Documentation]    Demonstrates ALTER TABLE keywords.
    ...
    ...    Note: 2 of the 4 ALTER keywords in `sql_table_operations.resource`
    ...    generate MySQL/PG/SQL-Server syntax that Oracle rejects:
    ...     • `Add Column To Table` → `ALTER TABLE x ADD COLUMN y` — Oracle
    ...        wants `ADD y` (no `COLUMN` keyword) → ORA-03050
    ...     • `Modify Column`       → `ALTER TABLE x ALTER COLUMN y` — Oracle
    ...        wants `MODIFY y`     → ORA-00905
    ...
    ...    For these two we use raw SQL via `Execute Sql String`. The other
    ...    two (`Rename Column`, `Drop Column From Table`) are Oracle-compatible.
    [Tags]    connect_to_oracle_database_sample

    # ADD column — Oracle syntax (no `COLUMN` keyword between ADD and the name)
    Execute Sql String    ALTER TABLE ${TUTORIAL_TABLE} ADD EMAIL VARCHAR2(150)

    # MODIFY column — Oracle uses `MODIFY`, not `ALTER COLUMN`
    Execute Sql String    ALTER TABLE ${TUTORIAL_TABLE} MODIFY EMAIL VARCHAR2(255)

    # RENAME column — keyword works on Oracle
    Rename Column          ${TUTORIAL_TABLE}    EMAIL    EMAIL_ADDRESS

    # DROP column — keyword works on Oracle
    Drop Column From Table    ${TUTORIAL_TABLE}    EMAIL_ADDRESS

# ═══════════════════════════════════════════════════════════════
# 6. INDEXES & VIEWS
# ═══════════════════════════════════════════════════════════════

INDEXES & VIEWS — Create / Drop
    [Documentation]    Demonstrates index and view keywords.
    ...    Keywords shown:
    ...    • Create Index    • Drop Index
    ...    • Create View     • Drop View
    [Tags]    connect_to_oracle_database_sample

    Create Index    IDX_EMP_NAME    ${TUTORIAL_TABLE}    NAME
    Drop Index      IDX_EMP_NAME

    Create View     V_HIGH_EARNERS    SELECT * FROM ${TUTORIAL_TABLE} WHERE SALARY > 80000
    Drop View       V_HIGH_EARNERS

# ═══════════════════════════════════════════════════════════════
# 7. VERIFICATIONS — Oracle-friendly assertions
# ═══════════════════════════════════════════════════════════════

VERIFY — Row counts and Oracle table existence
    [Documentation]    Demonstrates assertion keywords that work on Oracle.
    ...
    ...    Keywords shown:
    ...    • Row Count Should Be              — COUNT(*) assertion
    ...    • Row Count Should Be Greater Than
    ...    • Row Count Should Be Less Than
    ...    • Execute SQL Query And Get Count  — used here as Oracle-friendly
    ...    "table exists" check (queries USER_TABLES instead of INFORMATION_SCHEMA)
    ...
    ...    Note: `Table Should Exist` / `Column Should Exist` from the shared
    ...    resource query INFORMATION_SCHEMA which Oracle doesn't have. For
    ...    Oracle, query USER_TABLES / USER_TAB_COLUMNS directly as shown below.
    [Tags]    connect_to_oracle_database_sample

    # Row-count assertions — these work on any DB (use COUNT(*) on the table itself)
    Row Count Should Be                  ${TUTORIAL_TABLE}    3
    Row Count Should Be Greater Than    ${TUTORIAL_TABLE}    1
    Row Count Should Be Less Than       ${TUTORIAL_TABLE}    10

    # Oracle "table exists" check via USER_TABLES
    ${exists_count}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = '${TUTORIAL_TABLE}'
    Should Be Equal As Integers    ${exists_count}    1
    ...    msg=Expected ${TUTORIAL_TABLE} to exist in the user schema

    # Oracle "column exists" check via USER_TAB_COLUMNS
    ${col_exists}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = '${TUTORIAL_TABLE}' AND COLUMN_NAME = 'NAME'
    Should Be Equal As Integers    ${col_exists}    1
    ...    msg=Expected NAME column on ${TUTORIAL_TABLE}

# ═══════════════════════════════════════════════════════════════
# 8. RAW SQL — when you need full control
# ═══════════════════════════════════════════════════════════════

RAW SQL — direct SQL when keywords don't fit
    [Documentation]    Demonstrates raw-SQL execution keywords.
    ...    Keywords shown:
    ...    • Execute SQL String Safe              — DDL/DML with try/except
    ...    • Execute Custom Query                  — SELECT, returns rows
    ...    • Execute Custom Command                — INSERT/UPDATE/DELETE
    ...    • Execute SQL Query And Get Count       — scalar count
    ...    • Execute SQL Query And Get Single Value — scalar value
    ...    • Execute SQL Query And Get Results     — rows with error handling
    [Tags]    connect_to_oracle_database_sample

    Execute SQL String Safe    UPDATE ${TUTORIAL_TABLE} SET ROLE = 'Senior Engineer' WHERE NAME = 'Alice'

    @{rows}=    Execute Custom Query    SELECT NAME, SALARY FROM ${TUTORIAL_TABLE} ORDER BY SALARY DESC
    Log    Salary ranking: ${rows}    console=yes

    Execute Custom Command    DELETE FROM ${TUTORIAL_TABLE} WHERE SALARY < 50000

    ${count}=    Execute SQL Query And Get Count    SELECT COUNT(*) FROM ${TUTORIAL_TABLE}
    ${max_salary}=    Execute SQL Query And Get Single Value    SELECT MAX(SALARY) FROM ${TUTORIAL_TABLE}
    @{results}=    Execute SQL Query And Get Results    SELECT * FROM ${TUTORIAL_TABLE} WHERE ROLE LIKE '%Manager%'
    Log    Count: ${count} | Max salary: ${max_salary} | Managers: ${results}    console=yes

# ═══════════════════════════════════════════════════════════════
# 9. SCHEMA & VERIFY (keyword-based) — Oracle
# ═══════════════════════════════════════════════════════════════
# These four tests use the higher-level keywords from
# sql_table_operations.resource directly — Add Column, Modify Column,
# Check If Table Exists, Drop Table If Exists — all working on Oracle.
# ═══════════════════════════════════════════════════════════════

KEYWORD — Add Column To Table on Oracle
    [Documentation]    Demonstrates `Add Column To Table` adding a new column on Oracle.
    [Tags]    connect_to_oracle_database_sample

    Add Column To Table    ${TUTORIAL_TABLE}    DEPARTMENT    VARCHAR2(50)

    # Confirm the column actually landed in the schema
    ${col_count}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM USER_TAB_COLUMNS WHERE TABLE_NAME = '${TUTORIAL_TABLE}' AND COLUMN_NAME = 'DEPARTMENT'
    Should Be Equal As Integers    ${col_count}    1
    ...    msg=Add Column To Table did not add DEPARTMENT

KEYWORD — Modify Column on Oracle
    [Documentation]    Demonstrates `Modify Column` widening a column on Oracle.
    [Tags]    connect_to_oracle_database_sample

    # Widen the column we added in the previous test
    Modify Column    ${TUTORIAL_TABLE}    DEPARTMENT    VARCHAR2(200)

    # Confirm the new length actually applied
    ${new_length}=    Execute SQL Query And Get Single Value
    ...    SELECT DATA_LENGTH FROM USER_TAB_COLUMNS WHERE TABLE_NAME = '${TUTORIAL_TABLE}' AND COLUMN_NAME = 'DEPARTMENT'
    Should Be Equal As Integers    ${new_length}    200
    ...    msg=Modify Column did not widen DEPARTMENT to VARCHAR2(200)

KEYWORD — Check If Table Exists on Oracle
    [Documentation]    Demonstrates `Check If Table Exists` returning TRUE for an
    ...    existing table and FALSE for a missing one — without raising an exception.
    [Tags]    connect_to_oracle_database_sample

    # Existing table → TRUE
    ${exists}=    Check If Table Exists    ${TUTORIAL_TABLE}
    Should Be True    ${exists}
    ...    msg=Check If Table Exists returned FALSE for an existing table

    # Missing table → FALSE (no exception)
    ${missing}=    Check If Table Exists    NONEXISTENT_TABLE_XYZ_999
    Should Not Be True    ${missing}
    ...    msg=Check If Table Exists returned TRUE for a missing table

KEYWORD — Drop Table If Exists is idempotent on Oracle
    [Documentation]    Demonstrates `Drop Table If Exists` is safe to call twice —
    ...    the second call on a missing table does not fail.
    [Tags]    connect_to_oracle_database_sample

    # Create a throwaway table so we can drop it
    Execute Sql String    CREATE TABLE TUTORIAL_TEMP_DROP (ID NUMBER)

    # First drop — table exists, should succeed
    Drop Table If Exists    TUTORIAL_TEMP_DROP

    # Second drop — table is already gone; should NOT fail
    Drop Table If Exists    TUTORIAL_TEMP_DROP

    # Confirm it really is gone
    ${still_exists}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM USER_TABLES WHERE TABLE_NAME = 'TUTORIAL_TEMP_DROP'
    Should Be Equal As Integers    ${still_exists}    0
    ...    msg=TUTORIAL_TEMP_DROP still exists after Drop Table If Exists

# ═══════════════════════════════════════════════════════════════
# 10. EXPORT — Dump table / query results to CSV
# ═══════════════════════════════════════════════════════════════
# Demonstrates the two CSV-export keywords from sql_table_operations.resource:
#  • Export Table To CSV          — full table to a file
#  • Export Query Results To CSV  — custom SELECT to a file
#
# Output lands under test_data/actual_expected_data/actual_output/oracle/
# (bind-mounted from the host, so files appear on your Mac immediately).
# ═══════════════════════════════════════════════════════════════

EXPORT — Table To CSV (full table)
    [Documentation]    Exports the entire EMPLOYEES_TUTORIAL table to a CSV file.
    ...    Headers are included by default. ORDER BY ensures deterministic output.
    [Tags]    connect_to_oracle_database_sample

    ${csv_path}=    Set Variable    ${CURDIR}/../../../../test_data/actual_expected_data/actual_output/oracle/employees_full.csv

    ${result}=    Export Table To CSV
    ...    ${TUTORIAL_TABLE}
    ...    ${csv_path}
    ...    order_by=ID

    File Should Exist    ${csv_path}
    ${size}=    Get File Size    ${csv_path}
    Should Be True    ${size} > 0    msg=Exported CSV is empty
    ${row_count}=    Evaluate    $result.get('row_count', 0)
    Should Be True    ${row_count} > 0    msg=Export reported zero rows

EXPORT — Query Results To CSV (filtered)
    [Documentation]    Runs a custom SELECT and writes only the matching rows to CSV.
    ...    Column headers are passed explicitly so they match the SELECT projection.
    [Tags]    connect_to_oracle_database_sample

    ${csv_path}=    Set Variable    ${CURDIR}/../../../../test_data/actual_expected_data/actual_output/oracle/high_earners.csv
    ${query}=    Set Variable    SELECT NAME, ROLE, SALARY FROM ${TUTORIAL_TABLE} WHERE SALARY > 80000 ORDER BY SALARY DESC

    Export Query Results To CSV    ${query}    ${csv_path}    NAME    ROLE    SALARY

    File Should Exist    ${csv_path}
    ${size}=    Get File Size    ${csv_path}
    Should Be True    ${size} > 0    msg=Exported high-earners CSV is empty

# ═══════════════════════════════════════════════════════════════
# 11. CLEANUP
# ═══════════════════════════════════════════════════════════════

CLEANUP — Drop the tutorial table
    [Documentation]    Drops the demo table so the suite leaves no trace.
    [Tags]    connect_to_oracle_database_sample

    Drop Table If Exists    ${TUTORIAL_TABLE}


*** Keywords ***
Initialize Variables
    [Documentation]    Connects to Oracle and generates ${unique_id} as a suite variable.
    ...    Runs once before any test case.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes

    Connect to Oracle Database
    ...    ${ORACLE_DATABASE}
    ...    ${ORACLE_USER}
    ...    ${ORACLE_PASSWORD}
    ...    ${ORACLE_HOST}
    ...    ${ORACLE_PORT}
