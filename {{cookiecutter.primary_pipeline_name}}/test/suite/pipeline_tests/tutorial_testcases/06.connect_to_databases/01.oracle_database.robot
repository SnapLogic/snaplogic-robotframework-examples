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
Resource            ../../../../resources/common/general.resource
Resource            ../../../../resources/common/sql_table_operations.resource
Resource            ../../../test_data/queries/oracle2_queries.resource

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
# 9. CLEANUP
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
