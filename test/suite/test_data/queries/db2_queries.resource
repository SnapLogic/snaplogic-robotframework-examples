*** Variables ***
${DROP_TABLE_EMPLOYEES}         DROP TABLE IF EXISTS employees
${DROP_TABLE_EMPLOYEES2}        DROP TABLE IF EXISTS employees2
${DROP_TABLE_CONTROL_DATE}      DROP TABLE IF EXISTS control_date
${DROP_VIEW_HIGH_EARNERS}       DROP VIEW IF EXISTS high_earners
${DROP_BACKUP_TABLE}            DROP TABLE IF EXISTS employees_backup
${DROP_STORED_PROCEDURE}        DROP PROCEDURE IF EXISTS update_employee_salary
${DROP_INDEX_EMPLOYEES}         DROP INDEX IF EXISTS idx_employees_name
${DROP_INDEX_EMPLOYEES2}        DROP INDEX IF EXISTS idx_employees2_name

${CREATE_TABLE_EMPLOYEES}
...                             CREATE TABLE employees (
...                             id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1, INCREMENT BY 1),
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2),
...                             PRIMARY KEY (id)
...                             )

${CREATE_TABLE_EMPLOYEES2}
...                             CREATE TABLE employees2 (
...                             id INTEGER NOT NULL GENERATED ALWAYS AS IDENTITY (START WITH 1, INCREMENT BY 1),
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2),
...                             PRIMARY KEY (id)
...                             )

${CREATE_TABLE_CONTROL_DATE}
...                             CREATE TABLE control_date (
...                             domain_name VARCHAR(50) NOT NULL PRIMARY KEY,
...                             control_date DATE NOT NULL,
...                             last_updated TIMESTAMP NOT NULL DEFAULT CURRENT TIMESTAMP
...                             )

${INSERT_CONTROL_DATE}
...                             MERGE INTO control_date AS target
...                             USING (VALUES ('SLIM_DOM1', CURRENT DATE)) AS source (domain_name, control_date)
...                             ON target.domain_name = source.domain_name
...                             WHEN MATCHED THEN
...                             UPDATE SET control_date = source.control_date,
...                             last_updated = CURRENT TIMESTAMP
...                             WHEN NOT MATCHED THEN
...                             INSERT (domain_name, control_date, last_updated)
...                             VALUES (source.domain_name, source.control_date, CURRENT TIMESTAMP)

${UPDATE_CONTROL_DATE}
...                             UPDATE control_date
...                             SET control_date = TO_DATE(%s, 'MM/DD/YYYY'),
...                             last_updated = CURRENT TIMESTAMP
...                             WHERE domain_name = %s

${SELECT_CONTROL_DATE}
...                             SELECT domain_name,
...                             VARCHAR_FORMAT(control_date, 'MM/DD/YYYY') AS formatted_date,
...                             last_updated
...                             FROM control_date
...                             WHERE domain_name = %s

${CREATE_STORED_PROCEDURE}
...                             CREATE OR REPLACE PROCEDURE update_employee_salary(
...                             IN emp_id INTEGER,
...                             IN new_salary DECIMAL(10,2)
...                             )
...                             LANGUAGE SQL
...                             BEGIN
...                             UPDATE employees
...                             SET salary = new_salary
...                             WHERE id = emp_id;
...                             END

${CALL_STORED_PROCEDURE}        CALL update_employee_salary(%s, %s)

${SELECT_ALL_EMPLOYEES}         SELECT * FROM employees ORDER BY id
${SELECT_ALL_EMPLOYEES2}        SELECT * FROM employees2 ORDER BY id

${INSERT_EMPLOYEE}
...                             INSERT INTO employees (name, role, salary)
...                             VALUES (%s, %s, %s)

${INSERT_EMPLOYEE2}
...                             INSERT INTO employees2 (name, role, salary)
...                             VALUES (%s, %s, %s)

${TRUNCATE_EMPLOYEES}           TRUNCATE TABLE employees IMMEDIATE
${TRUNCATE_EMPLOYEES2}          TRUNCATE TABLE employees2 IMMEDIATE

${COUNT_EMPLOYEES}              SELECT COUNT(*) AS count FROM employees
${COUNT_EMPLOYEES2}             SELECT COUNT(*) AS count FROM employees2

${CREATE_INDEX_EMPLOYEES}       CREATE INDEX idx_employees_name ON employees(name)
${CREATE_INDEX_EMPLOYEES2}      CREATE INDEX idx_employees2_name ON employees2(name)

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

${SELECT_FROM_VIEW}             SELECT * FROM high_earners

${BACKUP_TABLE_EMPLOYEES}
...                             CREATE TABLE employees_backup AS
...                             (SELECT * FROM employees)
...                             WITH DATA

${SHOW_TABLES}
...                             SELECT TABNAME FROM SYSCAT.TABLES WHERE TABSCHEMA = CURRENT SCHEMA AND TYPE = 'T'

${DESCRIBE_TABLE}
...                             SELECT COLNAME, TYPENAME, LENGTH, SCALE, NULLS
...                             FROM SYSCAT.COLUMNS
...                             WHERE TABNAME = 'EMPLOYEES' AND TABSCHEMA = CURRENT SCHEMA
...                             ORDER BY COLNO

${CHECK_TABLE_EXISTS}
...                             SELECT COUNT(*) AS table_exists
...                             FROM SYSCAT.TABLES
...                             WHERE TABSCHEMA = CURRENT SCHEMA
...                             AND TABNAME = UPPER(%s)
