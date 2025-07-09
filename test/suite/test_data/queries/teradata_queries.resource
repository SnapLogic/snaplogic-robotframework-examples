*** Variables ***
${DROP_TABLE_EMPLOYEES}         DROP TABLE employees

${DROP_TABLE_EMPLOYEES2}        DROP TABLE employees2

${CREATE_TABLE_EMPLOYEES}
...                             CREATE TABLE employees (
...                             id INTEGER NOT NULL,
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2),
...                             PRIMARY KEY (id)
...                             )

${CREATE_TABLE_EMPLOYEES2}
...                             CREATE TABLE employees2 (
...                             id INTEGER NOT NULL,
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2),
...                             PRIMARY KEY (id)
...                             )

${CREATE_TABLE_CONTROL_DATE}
...                             CREATE TABLE control_date (
...                             domain_name VARCHAR(50) NOT NULL,
...                             control_date DATE NOT NULL,
...                             last_updated TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP(0),
...                             PRIMARY KEY (domain_name)
...                             )

${DROP_TABLE_CONTROL_DATE}      DROP TABLE control_date

${INSERT_CONTROL_DATE}
...                             INSERT INTO control_date (domain_name, control_date)
...                             VALUES ('SLIM_DOM1', CURRENT_DATE)

${UPDATE_CONTROL_DATE}
...                             UPDATE control_date
...                             SET control_date = CAST(%s AS DATE FORMAT 'MM/DD/YYYY'),
...                             last_updated = CURRENT_TIMESTAMP(0)
...                             WHERE domain_name = %s

${SELECT_CONTROL_DATE}
...                             SELECT domain_name, 
...                             CAST(control_date AS VARCHAR(10) FORMAT 'MM/DD/YYYY') AS formatted_date,
...                             last_updated
...                             FROM control_date
...                             WHERE domain_name = %s

${CREATE_STORED_PROCEDURE}
...                             CREATE PROCEDURE update_employee_salary(
...                             IN emp_id INTEGER,
...                             IN new_salary DECIMAL(10,2)
...                             )
...                             BEGIN
...                             UPDATE employees
...                             SET salary = new_salary
...                             WHERE id = emp_id;
...                             END

${DROP_STORED_PROCEDURE}        DROP PROCEDURE update_employee_salary

${CALL_STORED_PROCEDURE}        CALL update_employee_salary(%s, %s)

${SELECT_ALL_EMPLOYEES}         SELECT * FROM employees ORDER BY id

${SELECT_ALL_EMPLOYEES2}        SELECT * FROM employees2 ORDER BY id

${INSERT_EMPLOYEE}
...                             INSERT INTO employees (id, name, role, salary)
...                             VALUES (%s, %s, %s, %s)

${INSERT_EMPLOYEE2}
...                             INSERT INTO employees2 (id, name, role, salary)
...                             VALUES (%s, %s, %s, %s)

${DELETE_ALL_EMPLOYEES}         DELETE FROM employees

${DELETE_ALL_EMPLOYEES2}        DELETE FROM employees2

${COUNT_EMPLOYEES}              SELECT COUNT(*) AS count FROM employees

${COUNT_EMPLOYEES2}             SELECT COUNT(*) AS count FROM employees2

${CREATE_INDEX_EMPLOYEES}       CREATE INDEX idx_employees_name ON employees(name)

${CREATE_INDEX_EMPLOYEES2}      CREATE INDEX idx_employees2_name ON employees2(name)

${DROP_INDEX_EMPLOYEES}         DROP INDEX idx_employees_name ON employees

${DROP_INDEX_EMPLOYEES2}        DROP INDEX idx_employees2_name ON employees2

${ALTER_TABLE_ADD_COLUMN}
...                             ALTER TABLE employees
...                             ADD department VARCHAR(100) DEFAULT 'General'

${ALTER_TABLE_DROP_COLUMN}
...                             ALTER TABLE employees
...                             DROP COLUMN department

${CREATE_VIEW_HIGH_EARNERS}
...                             CREATE VIEW high_earners AS
...                             SELECT id, name, role, salary
...                             FROM employees
...                             WHERE salary > 50000

${REPLACE_VIEW_HIGH_EARNERS}
...                             REPLACE VIEW high_earners AS
...                             SELECT id, name, role, salary
...                             FROM employees
...                             WHERE salary > 50000

${DROP_VIEW_HIGH_EARNERS}       DROP VIEW high_earners

${SELECT_FROM_VIEW}             SELECT * FROM high_earners ORDER BY salary DESC

${CREATE_BACKUP_TABLE}
...                             CREATE TABLE employees_backup AS employees WITH DATA

${DROP_BACKUP_TABLE}            DROP TABLE employees_backup

${SHOW_TABLES}                  SELECT TableName FROM DBC.Tables WHERE DatabaseName = DATABASE AND TableKind = 'T'

${DESCRIBE_TABLE}               SHOW TABLE employees

${CHECK_TABLE_EXISTS}
...                             SELECT COUNT(*) AS table_exists
...                             FROM DBC.Tables
...                             WHERE DatabaseName = DATABASE
...                             AND TableName = %s
...                             AND TableKind = 'T'

${CREATE_VOLATILE_TABLE}
...                             CREATE VOLATILE TABLE vt_temp_employees AS
...                             (SELECT * FROM employees)
...                             WITH DATA ON COMMIT PRESERVE ROWS

${DROP_VOLATILE_TABLE}          DROP TABLE vt_temp_employees

${COLLECT_STATS}                COLLECT STATISTICS ON employees COLUMN (id)

${SHOW_STATS}                   HELP STATISTICS employees

${CREATE_MACRO}
...                             CREATE MACRO get_employee_by_id(emp_id INTEGER) AS
...                             (SELECT * FROM employees WHERE id = :emp_id)

${DROP_MACRO}                   DROP MACRO get_employee_by_id

${EXEC_MACRO}                   EXEC get_employee_by_id(%s)
