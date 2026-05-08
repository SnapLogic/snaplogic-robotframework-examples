# ──────────────────────────────────────────────────────────────────────────────
# PostgreSQL Database — SQL Operations Tutorial
#
# Demonstrates ONE example of each common SQL operation using
# `resources/common/sql_table_operations.resource`.
#
# All examples operate on a small demo table EMPLOYEES_TUTORIAL.
# Run with:  make robot-run-tests-no-gp TAGS="connect_to_postgres_database_sample"
#
# Test cases run sequentially: Account → DDL → DML → Read → Schema
# evolution → Index/View → Verifications → Raw SQL → Schema/Verify keywords → Cleanup.
# ──────────────────────────────────────────────────────────────────────────────

*** Settings ***
Documentation       Tutorial — common Postgres SQL operations using sql_table_operations.resource

Resource            snaplogic_common_robot/snaplogic_apis_keywords/snaplogic_keywords.resource
Resource            ../../../../../resources/common/general.resource
Resource            ../../../../../resources/common/sql_table_operations.resource

Suite Setup         Initialize Variables


*** Variables ***
${TUTORIAL_TABLE}                EMPLOYEES_TUTORIAL


*** Test Cases ***
# ═══════════════════════════════════════════════════════════════
# 1. ACCOUNT
# ═══════════════════════════════════════════════════════════════

Create Account
    [Documentation]    Creates the Postgres account in the project space.
    [Tags]    connect_to_postgres_database_sample
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${POSTGRES_ACCOUNT_PAYLOAD_FILE_NAME}    ${POSTGRES_ACCOUNT_NAME}

# ═══════════════════════════════════════════════════════════════
# 2. SETUP — DDL (Create / Truncate)
# ═══════════════════════════════════════════════════════════════

DDL — Drop, Create, Truncate
    [Documentation]    Demonstrates table-level DDL keywords on Postgres.
    ...    Keywords shown:
    ...    • Drop Table If Exists       — idempotent drop (Postgres supports IF EXISTS natively)
    ...    • Execute Sql String         — direct CREATE (errors propagate)
    ...    • Truncate Table             — empty without dropping
    [Tags]    connect_to_postgres_database_sample

    Drop Table If Exists    ${TUTORIAL_TABLE}

    ${create_sql}=    Catenate    SEPARATOR=${SPACE}
    ...    CREATE TABLE ${TUTORIAL_TABLE} (
    ...        ID INTEGER PRIMARY KEY,
    ...        NAME VARCHAR(100) NOT NULL,
    ...        ROLE VARCHAR(100),
    ...        SALARY NUMERIC(10,2),
    ...        HIRE_DATE DATE
    ...    )
    Log    Executing CREATE: ${create_sql}    console=yes
    Execute Sql String    ${create_sql}

    # Verify the table really exists (Postgres has INFORMATION_SCHEMA)
    ${exists}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '${TUTORIAL_TABLE.lower()}'
    Should Be Equal As Integers    ${exists}    1
    ...    msg=Create failed silently — ${TUTORIAL_TABLE} not found in information_schema

    Truncate Table    ${TUTORIAL_TABLE}

# ═══════════════════════════════════════════════════════════════
# 3. DML — Insert / Update / Delete
# ═══════════════════════════════════════════════════════════════

DML — Insert / Update / Delete
    [Documentation]    Demonstrates row-level DML keywords.
    [Tags]    connect_to_postgres_database_sample

    Insert Into Table    ${TUTORIAL_TABLE}    ID, NAME, ROLE, SALARY, HIRE_DATE    1, 'Alice', 'Engineer', 80000, DATE '2024-01-15'

    Bulk Insert Into Table    ${TUTORIAL_TABLE}    ID, NAME, ROLE, SALARY, HIRE_DATE
    ...    2, 'Bob', 'Analyst', 65000, DATE '2024-03-01'
    ...    3, 'Carol', 'Manager', 95000, DATE '2023-11-20'
    ...    4, 'Dave', 'Lead', 110000, DATE '2022-07-10'

    Update Table    ${TUTORIAL_TABLE}    SALARY = 85000    where_clause=ID = 1
    Delete From Table    ${TUTORIAL_TABLE}    where_clause=ROLE = 'Analyst'

# ═══════════════════════════════════════════════════════════════
# 4. READ — Select / Count / Get values
# ═══════════════════════════════════════════════════════════════

READ — Select / Count / Get values
    [Documentation]    Demonstrates read-only query keywords.
    [Tags]    connect_to_postgres_database_sample

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
    [Documentation]    Demonstrates ALTER TABLE keywords on Postgres.
    ...    All four keywords work natively on Postgres because they were originally
    ...    written for PG/MySQL syntax. The dialect branches we added preserve this.
    [Tags]    connect_to_postgres_database_sample

    Add Column To Table       ${TUTORIAL_TABLE}    EMAIL    VARCHAR(150)

    # Postgres ALTER COLUMN does NOT accept inline NOT NULL — pass type only.
    Modify Column             ${TUTORIAL_TABLE}    EMAIL    VARCHAR(255)

    Rename Column             ${TUTORIAL_TABLE}    EMAIL    EMAIL_ADDRESS
    Drop Column From Table    ${TUTORIAL_TABLE}    EMAIL_ADDRESS

# ═══════════════════════════════════════════════════════════════
# 6. INDEXES & VIEWS
# ═══════════════════════════════════════════════════════════════

INDEXES & VIEWS — Create / Drop
    [Documentation]    Demonstrates index and view keywords.
    [Tags]    connect_to_postgres_database_sample

    Create Index    IDX_EMP_NAME    ${TUTORIAL_TABLE}    NAME
    Drop Index      IDX_EMP_NAME

    Create View     V_HIGH_EARNERS    SELECT * FROM ${TUTORIAL_TABLE} WHERE SALARY > 80000
    Drop View       V_HIGH_EARNERS

# ═══════════════════════════════════════════════════════════════
# 7. VERIFICATIONS
# ═══════════════════════════════════════════════════════════════

VERIFY — Row counts and table existence
    [Documentation]    Demonstrates assertion keywords on Postgres.
    [Tags]    connect_to_postgres_database_sample

    Row Count Should Be                  ${TUTORIAL_TABLE}    3
    Row Count Should Be Greater Than    ${TUTORIAL_TABLE}    1
    Row Count Should Be Less Than       ${TUTORIAL_TABLE}    10

    # Postgres "table exists" check via INFORMATION_SCHEMA
    ${exists_count}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '${TUTORIAL_TABLE.lower()}'
    Should Be Equal As Integers    ${exists_count}    1

# ═══════════════════════════════════════════════════════════════
# 8. RAW SQL
# ═══════════════════════════════════════════════════════════════

RAW SQL — direct SQL when keywords don't fit
    [Documentation]    Demonstrates raw-SQL execution keywords.
    [Tags]    connect_to_postgres_database_sample

    Execute SQL String Safe    UPDATE ${TUTORIAL_TABLE} SET ROLE = 'Senior Engineer' WHERE NAME = 'Alice'

    @{rows}=    Execute Custom Query    SELECT NAME, SALARY FROM ${TUTORIAL_TABLE} ORDER BY SALARY DESC
    Log    Salary ranking: ${rows}    console=yes

    Execute Custom Command    DELETE FROM ${TUTORIAL_TABLE} WHERE SALARY < 50000

    ${count}=    Execute SQL Query And Get Count    SELECT COUNT(*) FROM ${TUTORIAL_TABLE}
    ${max_salary}=    Execute SQL Query And Get Single Value    SELECT MAX(SALARY) FROM ${TUTORIAL_TABLE}
    Log    Count: ${count} | Max salary: ${max_salary}    console=yes

# ═══════════════════════════════════════════════════════════════
# 9. SCHEMA & VERIFY (keyword-based) — Postgres
# ═══════════════════════════════════════════════════════════════
# These four tests use the higher-level keywords from
# sql_table_operations.resource directly — Add Column, Modify Column,
# Check If Table Exists, Drop Table If Exists — all working on Postgres.
# ═══════════════════════════════════════════════════════════════

KEYWORD — Add Column To Table on Postgres
    [Documentation]    Demonstrates `Add Column To Table` adding a new column on Postgres.
    [Tags]    connect_to_postgres_database_sample

    Add Column To Table    ${TUTORIAL_TABLE}    DEPARTMENT    VARCHAR(50)

    ${col_count}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM information_schema.columns WHERE table_name = '${TUTORIAL_TABLE.lower()}' AND column_name = 'department'
    Should Be Equal As Integers    ${col_count}    1
    ...    msg=Add Column To Table did not add DEPARTMENT

KEYWORD — Modify Column on Postgres
    [Documentation]    Demonstrates `Modify Column` widening a column on Postgres.
    ...    NOTE: pass the type only — Postgres rejects inline NOT NULL/DEFAULT here.
    [Tags]    connect_to_postgres_database_sample

    Modify Column    ${TUTORIAL_TABLE}    DEPARTMENT    VARCHAR(200)

    ${new_length}=    Execute SQL Query And Get Single Value
    ...    SELECT character_maximum_length FROM information_schema.columns WHERE table_name = '${TUTORIAL_TABLE.lower()}' AND column_name = 'department'
    Should Be Equal As Integers    ${new_length}    200
    ...    msg=Modify Column did not widen DEPARTMENT to VARCHAR(200)

KEYWORD — Check If Table Exists on Postgres
    [Documentation]    Demonstrates `Check If Table Exists` returning TRUE for an
    ...    existing table and FALSE for a missing one — without raising an exception.
    [Tags]    connect_to_postgres_database_sample

    ${exists}=    Check If Table Exists    ${TUTORIAL_TABLE.lower()}
    Should Be True    ${exists}
    ...    msg=Check If Table Exists returned FALSE for an existing table

    ${missing}=    Check If Table Exists    nonexistent_table_xyz_999
    Should Not Be True    ${missing}
    ...    msg=Check If Table Exists returned TRUE for a missing table

KEYWORD — Drop Table If Exists is idempotent on Postgres
    [Documentation]    Demonstrates `Drop Table If Exists` is safe to call twice —
    ...    the second call on a missing table does not fail.
    [Tags]    connect_to_postgres_database_sample

    Execute Sql String    CREATE TABLE TUTORIAL_TEMP_DROP (ID INTEGER)

    Drop Table If Exists    TUTORIAL_TEMP_DROP
    Drop Table If Exists    TUTORIAL_TEMP_DROP

    ${still_exists}=    Execute SQL Query And Get Count
    ...    SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'tutorial_temp_drop'
    Should Be Equal As Integers    ${still_exists}    0

# ═══════════════════════════════════════════════════════════════
# 10. CLEANUP
# ═══════════════════════════════════════════════════════════════

CLEANUP — Drop the tutorial table
    [Documentation]    Drops the demo table so the suite leaves no trace.
    [Tags]    connect_to_postgres_database_sample

    Drop Table If Exists    ${TUTORIAL_TABLE}


*** Keywords ***
Initialize Variables
    [Documentation]    Connects to Postgres and generates ${unique_id} as a suite variable.

    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Log    Generated unique_id: ${unique_id}    console=yes

    # NOTE: We deliberately do NOT pass ${POSTGRES_PORT} here. In .env.postgres
    # POSTGRES_PORT=5435 is the HOST-side port (from docker-compose mapping
    # "5435:5432"). Inside the snaplogicnet bridge network — where the tools
    # container runs — postgres-db actually listens on 5432 (the container
    # internal port). Letting the keyword use its default (5432) is correct.
    Connect to Postgres Database
    ...    ${POSTGRES_DATABASE}
    ...    ${POSTGRES_USER}
    ...    ${POSTGRES_PASSWORD}
    ...    ${POSTGRES_HOST}
