# ──────────────────────────────────────────────────────────────────────────────
# SQL Server Database — SQL Operations Tutorial
#
# Demonstrates ONE example of each common SQL operation using
# `resources/common/sql_table_operations.resource`.
#
# All examples operate on a small demo table EMPLOYEES_TUTORIAL in the dbo schema.
# Run with:  make robot-run-tests-no-gp TAGS="connect_to_sqlserver_database_sample"
#
# Test cases run sequentially: Account → DDL → DML → Read → Schema
# evolution → Index/View → Verifications → Raw SQL → Schema/Verify keywords → Cleanup.
#
# SQL Server-specific notes:
#  • Default schema is `dbo`, not `public`.
#  • `ALTER TABLE ... ADD col TYPE` does NOT accept the `COLUMN` keyword
#    (same as Oracle). The dialect-aware Add Column To Table handles this.
#  • `ALTER TABLE ... ALTER COLUMN col TYPE` is the modify syntax.
#  • Inline constraints (NOT NULL/DEFAULT) in `Modify Column` are rejected —
#    pass the type only and use a separate ALTER for constraints.
#  • Date literal syntax: '2024-01-15' (single-quoted string, no DATE prefix).
# ──────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation       Tutorial — common SQL Server SQL operations using sql_table_operations.resource

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../resources/common/general.resource
Resource            ../../../../resources/common/sql_table_operations.resource

Suite Setup         Initialize Variables


*** Variables ***
${TUTORIAL_TABLE}                EMPLOYEES_TUTORIAL


*** Test Cases ***
# ═══════════════════════════════════════════════════════════════
# 1. ACCOUNT
# ═══════════════════════════════════════════════════════════════

Create Account
    [Documentation]    Creates the SQL Server account in the project space.
    [Tags]    connect_to_sqlserver_database_sample
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${SQLSERVER_ACCOUNT_PAYLOAD_FILE_NAME}    ${SQLSERVER_ACCOUNT_NAME}

# ═══════════════════════════════════════════════════════════════
# 2. SETUP — DDL (Create / Truncate)
# ═══════════════════════════════════════════════════════════════

DDL — Drop, Create, Truncate
    [Documentation]    Demonstrates table-level DDL keywords on SQL Server.
    ...    Keywords shown:
    ...    • Drop Table If Exists       — idempotent drop (SQL Server 2016+ supports IF EXISTS)
    ...    • Execute Sql String         — direct CREATE (errors propagate)
    ...    • Truncate Table             — empty without dropping
    [Tags]    connect_to_sqlserver_database_sample

    Drop Table If Exists    ${TUTORIAL_TABLE}

    ${create_sql}=    Catenate    SEPARATOR=${SPACE}
    ...    CREATE TABLE ${TUTORIAL_TABLE} (
    ...        ID INT PRIMARY KEY,
    ...        NAME NVARCHAR(100) NOT NULL,
    ...        ROLE NVARCHAR(100),
    ...        SALARY DECIMAL(10,2),
    ...        HIRE_DATE DATE
    ...    )
    Log    Executing CREATE: ${create_sql}    console=yes
    Execute Sql String    ${create_sql}

    # Verify the table really exists (SQL Server has INFORMATION_SCHEMA)
    ${exists}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '${TUTORIAL_TABLE}'
    Should Be Equal As Integers    ${exists}    1
    ...    msg=Create failed silently — ${TUTORIAL_TABLE} not found in INFORMATION_SCHEMA

    Truncate Table    ${TUTORIAL_TABLE}

# ═══════════════════════════════════════════════════════════════
# 3. DML — Insert / Update / Delete
# ═══════════════════════════════════════════════════════════════

DML — Insert / Update / Delete
    [Documentation]    Demonstrates row-level DML keywords on SQL Server.
    ...    Note: SQL Server uses single-quoted strings for date literals — '2024-01-15' (no DATE prefix).
    [Tags]    connect_to_sqlserver_database_sample

    Insert Into Table    ${TUTORIAL_TABLE}    ID, NAME, ROLE, SALARY, HIRE_DATE    1, 'Alice', 'Engineer', 80000, '2024-01-15'

    Bulk Insert Into Table    ${TUTORIAL_TABLE}    ID, NAME, ROLE, SALARY, HIRE_DATE
    ...    2, 'Bob', 'Analyst', 65000, '2024-03-01'
    ...    3, 'Carol', 'Manager', 95000, '2023-11-20'
    ...    4, 'Dave', 'Lead', 110000, '2022-07-10'

    Update Table    ${TUTORIAL_TABLE}    SALARY = 85000    where_clause=ID = 1
    Delete From Table    ${TUTORIAL_TABLE}    where_clause=ROLE = 'Analyst'

# ═══════════════════════════════════════════════════════════════
# 4. READ — Select / Count / Get values
# ═══════════════════════════════════════════════════════════════

READ — Select / Count / Get values
    [Documentation]    Demonstrates read-only query keywords.
    [Tags]    connect_to_sqlserver_database_sample

    @{all_rows}=    Select All From Table    ${TUTORIAL_TABLE}    order_by=ID
    Log    All rows: ${all_rows}    console=yes

    @{filtered}=    Select Where    ${TUTORIAL_TABLE}    SALARY > 70000    order_by=ID
    Log    High earners: ${filtered}    console=yes

    ${total_count}=    Get Row Count    ${TUTORIAL_TABLE}
    ${high_paid_count}=    Get Row Count    ${TUTORIAL_TABLE}    where_clause=SALARY > 80000
    Log    Total: ${total_count} | High-paid: ${high_paid_count}    console=yes

    @{names}=    Get Column Values    ${TUTORIAL_TABLE}    NAME
    Log    All names: ${names}    console=yes

    ${alice_role}=    Get Column Value    ${TUTORIAL_TABLE}    NAME    Alice    ROLE
    Log    Alice's role: ${alice_role}    console=yes

# ═══════════════════════════════════════════════════════════════
# 5. SCHEMA EVOLUTION — Add / Modify / Rename / Drop columns
# ═══════════════════════════════════════════════════════════════

SCHEMA — Add / Modify / Rename / Drop columns
    [Documentation]    Demonstrates ALTER TABLE keywords on SQL Server.
    ...    All four work via the dialect-aware keywords:
    ...     • Add Column To Table  → ADD col TYPE (no COLUMN keyword)
    ...     • Modify Column        → ALTER COLUMN col TYPE
    ...     • Rename Column        → uses sp_rename internally? — see note below
    ...     • Drop Column From Table → DROP COLUMN col
    ...
    ...    NOTE on RENAME: SQL Server does NOT have `ALTER TABLE ... RENAME COLUMN`.
    ...    The shared `Rename Column` keyword emits that syntax which fails on SQL Server.
    ...    For now we use raw `EXEC sp_rename` here. (Consider extending the keyword later.)
    [Tags]    connect_to_sqlserver_database_sample

    Add Column To Table       ${TUTORIAL_TABLE}    EMAIL    NVARCHAR(150)

    # SQL Server ALTER COLUMN does not accept inline NOT NULL — type only.
    Modify Column             ${TUTORIAL_TABLE}    EMAIL    NVARCHAR(255)

    # SQL Server-specific rename via sp_rename (raw SQL — keyword would fail here)
    Execute Sql String    EXEC sp_rename '${TUTORIAL_TABLE}.EMAIL', 'EMAIL_ADDRESS', 'COLUMN'

    Drop Column From Table    ${TUTORIAL_TABLE}    EMAIL_ADDRESS

# ═══════════════════════════════════════════════════════════════
# 6. INDEXES & VIEWS
# ═══════════════════════════════════════════════════════════════

INDEXES & VIEWS — Create / Drop
    [Documentation]    Demonstrates index and view keywords.
    [Tags]    connect_to_sqlserver_database_sample

    Create Index    IDX_EMP_NAME    ${TUTORIAL_TABLE}    NAME
    Drop Index      IDX_EMP_NAME    ${TUTORIAL_TABLE}

    Create View     V_HIGH_EARNERS    SELECT * FROM ${TUTORIAL_TABLE} WHERE SALARY > 80000
    Drop View       V_HIGH_EARNERS

# ═══════════════════════════════════════════════════════════════
# 7. VERIFICATIONS
# ═══════════════════════════════════════════════════════════════

VERIFY — Row counts and table existence
    [Documentation]    Demonstrates assertion keywords on SQL Server.
    [Tags]    connect_to_sqlserver_database_sample

    Row Count Should Be                  ${TUTORIAL_TABLE}    3
    Row Count Should Be Greater Than    ${TUTORIAL_TABLE}    1
    Row Count Should Be Less Than       ${TUTORIAL_TABLE}    10

    # SQL Server "table exists" check via INFORMATION_SCHEMA
    ${exists_count}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = '${TUTORIAL_TABLE}'
    Should Be Equal As Integers    ${exists_count}    1

# ═══════════════════════════════════════════════════════════════
# 8. RAW SQL
# ═══════════════════════════════════════════════════════════════

RAW SQL — direct SQL when keywords don't fit
    [Documentation]    Demonstrates raw-SQL execution keywords.
    [Tags]    connect_to_sqlserver_database_sample

    Execute SQL String Safe    UPDATE ${TUTORIAL_TABLE} SET ROLE = 'Senior Engineer' WHERE NAME = 'Alice'

    @{rows}=    Execute Custom Query    SELECT NAME, SALARY FROM ${TUTORIAL_TABLE} ORDER BY SALARY DESC
    Log    Salary ranking: ${rows}    console=yes

    Execute Custom Command    DELETE FROM ${TUTORIAL_TABLE} WHERE SALARY < 50000

    ${count}=    Execute SQL Query And Get Count    SELECT COUNT(*) FROM ${TUTORIAL_TABLE}
    ${max_salary}=    Execute SQL Query And Get Single Value    SELECT MAX(SALARY) FROM ${TUTORIAL_TABLE}
    Log    Count: ${count} | Max salary: ${max_salary}    console=yes

# ═══════════════════════════════════════════════════════════════
# 9. SCHEMA & VERIFY (keyword-based) — SQL Server
# ═══════════════════════════════════════════════════════════════
# These four tests use the higher-level keywords from
# sql_table_operations.resource directly — Add Column, Modify Column,
# Check If Table Exists, Drop Table If Exists — all working on SQL Server.
# ═══════════════════════════════════════════════════════════════

KEYWORD — Add Column To Table on SQL Server
    [Documentation]    Demonstrates `Add Column To Table` adding a new column on SQL Server.
    [Tags]    connect_to_sqlserver_database_sample

    Add Column To Table    ${TUTORIAL_TABLE}    DEPARTMENT    NVARCHAR(50)

    ${col_count}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${TUTORIAL_TABLE}' AND COLUMN_NAME = 'DEPARTMENT'
    Should Be Equal As Integers    ${col_count}    1
    ...    msg=Add Column To Table did not add DEPARTMENT

KEYWORD — Modify Column on SQL Server
    [Documentation]    Demonstrates `Modify Column` widening a column on SQL Server.
    ...    NOTE: pass the type only — SQL Server rejects inline NOT NULL/DEFAULT here.
    [Tags]    connect_to_sqlserver_database_sample

    Modify Column    ${TUTORIAL_TABLE}    DEPARTMENT    NVARCHAR(200)

    ${new_length}=    Execute SQL Query And Get Single Value
    ...    SELECT CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '${TUTORIAL_TABLE}' AND COLUMN_NAME = 'DEPARTMENT'
    Should Be Equal As Integers    ${new_length}    200
    ...    msg=Modify Column did not widen DEPARTMENT to NVARCHAR(200)

KEYWORD — Check If Table Exists on SQL Server
    [Documentation]    Demonstrates `Check If Table Exists` returning TRUE for an
    ...    existing table and FALSE for a missing one. Pass schema=dbo for SQL Server.
    [Tags]    connect_to_sqlserver_database_sample

    ${exists}=    Check If Table Exists    ${TUTORIAL_TABLE}    schema=dbo
    Should Be True    ${exists}
    ...    msg=Check If Table Exists returned FALSE for an existing table

    ${missing}=    Check If Table Exists    NONEXISTENT_TABLE_XYZ_999    schema=dbo
    Should Not Be True    ${missing}
    ...    msg=Check If Table Exists returned TRUE for a missing table

KEYWORD — Drop Table If Exists is idempotent on SQL Server
    [Documentation]    Demonstrates `Drop Table If Exists` is safe to call twice —
    ...    the second call on a missing table does not fail.
    [Tags]    connect_to_sqlserver_database_sample

    Execute Sql String    CREATE TABLE TUTORIAL_TEMP_DROP (ID INT)

    Drop Table If Exists    TUTORIAL_TEMP_DROP
    Drop Table If Exists    TUTORIAL_TEMP_DROP

    ${still_exists}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TUTORIAL_TEMP_DROP'
    Should Be Equal As Integers    ${still_exists}    0

# ═══════════════════════════════════════════════════════════════
# 10. CLEANUP
# ═══════════════════════════════════════════════════════════════

CLEANUP — Drop the tutorial table
    [Documentation]    Drops the demo table so the suite leaves no trace.
    [Tags]    connect_to_sqlserver_database_sample

    Drop Table If Exists    ${TUTORIAL_TABLE}


*** Keywords ***
Initialize Variables
    [Documentation]    Connects to SQL Server and generates ${unique_id} as a suite variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes

    Connect to SQL Server Database
    ...    ${SQLSERVER_DATABASE}
    ...    ${SQLSERVER_USER}
    ...    ${SQLSERVER_PASSWORD}
    ...    ${SQLSERVER_HOST}
    ...    ${SQLSERVER_PORT}
