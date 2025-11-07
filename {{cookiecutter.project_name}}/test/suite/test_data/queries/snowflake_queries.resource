*** Variables ***
${DROP_TABLE_EMPLOYEES}         DROP TABLE IF EXISTS employees

${DROP_TABLE_EMPLOYEES2}        DROP TABLE IF EXISTS employees2

${CREATE_TABLE_EMPLOYEES}
...                             CREATE TABLE employees (
...                             id NUMBER AUTOINCREMENT PRIMARY KEY,
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary NUMBER(10,2)
...                             )

${CREATE_TABLE_EMPLOYEES2}
...                             CREATE TABLE employees2 (
...                             id NUMBER AUTOINCREMENT PRIMARY KEY,
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary NUMBER(10,2)
...                             )

${CREATE_TABLE_CONTROL_DATE}
...                             CREATE TABLE IF NOT EXISTS control_date (
...                             domain_name VARCHAR(50) PRIMARY KEY,
...                             control_date DATE NOT NULL,
...                             last_updated TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
...                             )

${DROP_TABLE_CONTROL_DATE}      DROP TABLE IF EXISTS control_date

${INSERT_CONTROL_DATE}
...                             MERGE INTO control_date AS target
...                             USING (SELECT 'SLIM_DOM1' AS domain_name, CURRENT_DATE() AS control_date) AS source
...                             ON target.domain_name = source.domain_name
...                             WHEN MATCHED THEN
...                             UPDATE SET control_date = source.control_date,
...                             last_updated = CURRENT_TIMESTAMP()
...                             WHEN NOT MATCHED THEN
...                             INSERT (domain_name, control_date, last_updated)
...                             VALUES (source.domain_name, source.control_date, CURRENT_TIMESTAMP())

${UPDATE_CONTROL_DATE}
...                             UPDATE control_date
...                             SET control_date = TO_DATE(%s, 'MM/DD/YYYY'),
...                             last_updated = CURRENT_TIMESTAMP()
...                             WHERE domain_name = %s

${SELECT_CONTROL_DATE}
...                             SELECT domain_name, 
...                             TO_CHAR(control_date, 'MM/DD/YYYY') as formatted_date,
...                             last_updated
...                             FROM control_date
...                             WHERE domain_name = %s

${CREATE_STORED_PROCEDURE}
...                             CREATE OR REPLACE PROCEDURE update_employee_salary(
...                             emp_id NUMBER,
...                             new_salary NUMBER
...                             )
...                             RETURNS VARCHAR
...                             LANGUAGE SQL
...                             AS
...                             $$
...                             BEGIN
...                             UPDATE employees
...                             SET salary = :new_salary
...                             WHERE id = :emp_id;
...                             RETURN 'Salary updated successfully';
...                             END;
...                             $$

${DROP_STORED_PROCEDURE}        DROP PROCEDURE IF EXISTS update_employee_salary(NUMBER, NUMBER)

${CALL_STORED_PROCEDURE}        CALL update_employee_salary(%s, %s)

${SELECT_ALL_EMPLOYEES}         SELECT * FROM employees ORDER BY id

${SELECT_ALL_EMPLOYEES2}        SELECT * FROM employees2 ORDER BY id

${INSERT_EMPLOYEE}
...                             INSERT INTO employees (name, role, salary)
...                             VALUES (%s, %s, %s)

${INSERT_EMPLOYEE2}
...                             INSERT INTO employees2 (name, role, salary)
...                             VALUES (%s, %s, %s)

${TRUNCATE_EMPLOYEES}           TRUNCATE TABLE employees

${TRUNCATE_EMPLOYEES2}          TRUNCATE TABLE employees2

${COUNT_EMPLOYEES}              SELECT COUNT(*) as count FROM employees

${COUNT_EMPLOYEES2}             SELECT COUNT(*) as count FROM employees2

${CREATE_INDEX_EMPLOYEES}       CREATE INDEX idx_employees_name ON employees(name)

${CREATE_INDEX_EMPLOYEES2}      CREATE INDEX idx_employees2_name ON employees2(name)

${DROP_INDEX_EMPLOYEES}         DROP INDEX idx_employees_name

${DROP_INDEX_EMPLOYEES2}        DROP INDEX idx_employees2_name

${ALTER_TABLE_ADD_COLUMN}
...                             ALTER TABLE employees
...                             ADD COLUMN department VARCHAR(100) DEFAULT 'General'

${ALTER_TABLE_DROP_COLUMN}
...                             ALTER TABLE employees
...                             DROP COLUMN department

${CREATE_VIEW_HIGH_EARNERS}
...                             CREATE OR REPLACE VIEW high_earners AS
...                             SELECT id, name, role, salary
...                             FROM employees
...                             WHERE salary > 50000
...                             ORDER BY salary DESC

${DROP_VIEW_HIGH_EARNERS}       DROP VIEW IF EXISTS high_earners

${SELECT_FROM_VIEW}             SELECT * FROM high_earners

${BACKUP_TABLE_EMPLOYEES}
...                             CREATE TABLE employees_backup AS
...                             SELECT * FROM employees

${DROP_BACKUP_TABLE}            DROP TABLE IF EXISTS employees_backup

${SHOW_TABLES}                  SHOW TABLES

${DESCRIBE_TABLE}               DESCRIBE TABLE employees

${CHECK_TABLE_EXISTS}
...                             SELECT COUNT(*) as table_exists
...                             FROM information_schema.tables
...                             WHERE table_schema = CURRENT_SCHEMA()
...                             AND table_name = UPPER(%s)

# Snowflake-specific queries
${CREATE_TRANSIENT_TABLE}
...                             CREATE TRANSIENT TABLE employees_temp (
...                             id NUMBER AUTOINCREMENT PRIMARY KEY,
...                             name VARCHAR(100),
...                             role VARCHAR(100),
...                             salary NUMBER(10,2)
...                             )

${CREATE_TEMPORARY_TABLE}
...                             CREATE TEMPORARY TABLE employees_session (
...                             id NUMBER AUTOINCREMENT PRIMARY KEY,
...                             name VARCHAR(100),
...                             role VARCHAR(100),
...                             salary NUMBER(10,2)
...                             )

${CLONE_TABLE}
...                             CREATE TABLE employees_clone CLONE employees

${DROP_CLONE_TABLE}             DROP TABLE IF EXISTS employees_clone

${CREATE_STREAM}
...                             CREATE OR REPLACE STREAM employees_stream
...                             ON TABLE employees

${DROP_STREAM}                  DROP STREAM IF EXISTS employees_stream

${SELECT_FROM_STREAM}           SELECT * FROM employees_stream

${CREATE_TASK}
...                             CREATE OR REPLACE TASK daily_cleanup
...                             WAREHOUSE = COMPUTE_WH
...                             SCHEDULE = 'USING CRON 0 2 * * * UTC'
...                             AS
...                             DELETE FROM employees WHERE salary < 0

${DROP_TASK}                    DROP TASK IF EXISTS daily_cleanup

${ALTER_TASK_RESUME}            ALTER TASK daily_cleanup RESUME

${ALTER_TASK_SUSPEND}           ALTER TASK daily_cleanup SUSPEND

${CREATE_STAGE}
...                             CREATE OR REPLACE STAGE employees_stage
...                             FILE_FORMAT = (TYPE = CSV FIELD_DELIMITER = ',' SKIP_HEADER = 1)

${DROP_STAGE}                   DROP STAGE IF EXISTS employees_stage

${COPY_INTO_FROM_STAGE}
...                             COPY INTO employees
...                             FROM @employees_stage
...                             FILE_FORMAT = (TYPE = CSV FIELD_DELIMITER = ',')
...                             ON_ERROR = 'CONTINUE'

${UNLOAD_TO_STAGE}
...                             COPY INTO @employees_stage
...                             FROM employees
...                             FILE_FORMAT = (TYPE = CSV)
...                             OVERWRITE = TRUE

${CREATE_WAREHOUSE}
...                             CREATE WAREHOUSE IF NOT EXISTS test_warehouse
...                             WITH WAREHOUSE_SIZE = 'XSMALL'
...                             AUTO_SUSPEND = 60
...                             AUTO_RESUME = TRUE

${DROP_WAREHOUSE}               DROP WAREHOUSE IF EXISTS test_warehouse

${USE_WAREHOUSE}                USE WAREHOUSE COMPUTE_WH

${CREATE_DATABASE}              CREATE DATABASE IF NOT EXISTS test_database

${DROP_DATABASE}                DROP DATABASE IF EXISTS test_database

${USE_DATABASE}                 USE DATABASE test_database

${CREATE_SCHEMA}                CREATE SCHEMA IF NOT EXISTS test_schema

${DROP_SCHEMA}                  DROP SCHEMA IF EXISTS test_schema

${USE_SCHEMA}                   USE SCHEMA test_schema

${SHOW_WAREHOUSES}              SHOW WAREHOUSES

${SHOW_DATABASES}               SHOW DATABASES

${SHOW_SCHEMAS}                 SHOW SCHEMAS

${GET_DDL}                      SELECT GET_DDL('TABLE', 'employees')

${TIME_TRAVEL_QUERY}
...                             SELECT * FROM employees
...                             AT(TIMESTAMP => DATEADD('minutes', -5, CURRENT_TIMESTAMP()))

${CREATE_VARIANT_TABLE}
...                             CREATE TABLE json_data (
...                             id NUMBER AUTOINCREMENT PRIMARY KEY,
...                             data VARIANT,
...                             created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
...                             )

${INSERT_VARIANT_DATA}
...                             INSERT INTO json_data (data)
...                             SELECT PARSE_JSON(%s)

${QUERY_VARIANT_DATA}
...                             SELECT data:name::STRING as name,
...                             data:age::NUMBER as age
...                             FROM json_data
...                             WHERE data:active::BOOLEAN = TRUE

${CREATE_SECURE_VIEW}
...                             CREATE OR REPLACE SECURE VIEW secure_employees AS
...                             SELECT id, name, role
...                             FROM employees

${DROP_SECURE_VIEW}             DROP VIEW IF EXISTS secure_employees

${CREATE_MATERIALIZED_VIEW}
...                             CREATE OR REPLACE MATERIALIZED VIEW mv_high_earners AS
...                             SELECT id, name, role, salary
...                             FROM employees
...                             WHERE salary > 50000

${DROP_MATERIALIZED_VIEW}       DROP MATERIALIZED VIEW IF EXISTS mv_high_earners

${REFRESH_MATERIALIZED_VIEW}    ALTER MATERIALIZED VIEW mv_high_earners REFRESH

${CREATE_EXTERNAL_TABLE}
...                             CREATE OR REPLACE EXTERNAL TABLE ext_employees (
...                             id NUMBER AS (value:c1::NUMBER),
...                             name VARCHAR AS (value:c2::VARCHAR),
...                             role VARCHAR AS (value:c3::VARCHAR),
...                             salary NUMBER AS (value:c4::NUMBER)
...                             )
...                             WITH LOCATION = @employees_stage
...                             FILE_FORMAT = (TYPE = CSV)

${DROP_EXTERNAL_TABLE}          DROP EXTERNAL TABLE IF EXISTS ext_employees

${GRANT_PRIVILEGES}
...                             GRANT SELECT, INSERT, UPDATE, DELETE
...                             ON TABLE employees
...                             TO ROLE analyst_role

${REVOKE_PRIVILEGES}
...                             REVOKE ALL PRIVILEGES
...                             ON TABLE employees
...                             FROM ROLE analyst_role

${CREATE_ROLE}                  CREATE ROLE IF NOT EXISTS analyst_role

${DROP_ROLE}                    DROP ROLE IF EXISTS analyst_role

${CREATE_USER}
...                             CREATE USER IF NOT EXISTS test_user
...                             PASSWORD = 'TestPassword123!'
...                             DEFAULT_ROLE = analyst_role

${DROP_USER}                    DROP USER IF EXISTS test_user

${ALTER_SESSION}                ALTER SESSION SET QUERY_TAG = 'test_automation'

${SHOW_PARAMETERS}              SHOW PARAMETERS

${ACCOUNT_USAGE_QUERY}
...                             SELECT query_text, 
...                             database_name,
...                             warehouse_name,
...                             execution_time
...                             FROM snowflake.account_usage.query_history
...                             WHERE start_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
...                             ORDER BY start_time DESC
...                             LIMIT 10
