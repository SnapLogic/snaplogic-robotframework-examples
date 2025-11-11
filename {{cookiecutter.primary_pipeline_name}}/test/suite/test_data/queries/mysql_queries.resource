*** Variables ***
${DROP_TABLE_EMPLOYEES}         DROP TABLE IF EXISTS employees

${DROP_TABLE_EMPLOYEES2}        DROP TABLE IF EXISTS employees2

${CREATE_TABLE_EMPLOYEES}
...                             CREATE TABLE employees (
...                             id INT AUTO_INCREMENT PRIMARY KEY,
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2)
...                             )

${CREATE_TABLE_EMPLOYEES2}
...                             CREATE TABLE employees2 (
...                             id INT AUTO_INCREMENT PRIMARY KEY,
...                             name VARCHAR(100) NOT NULL,
...                             role VARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2)
...                             )

${CREATE_TABLE_CONTROL_DATE}
...                             CREATE TABLE IF NOT EXISTS control_date (
...                             domain_name VARCHAR(50) PRIMARY KEY,
...                             control_date DATE NOT NULL,
...                             last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
...                             )

${DROP_TABLE_CONTROL_DATE}      DROP TABLE IF EXISTS control_date

${INSERT_CONTROL_DATE}
...                             INSERT INTO control_date (domain_name, control_date)
...                             VALUES ('SLIM_DOM1', CURDATE())
...                             ON DUPLICATE KEY UPDATE
...                             control_date = VALUES(control_date),
...                             last_updated = CURRENT_TIMESTAMP

${UPDATE_CONTROL_DATE}
...                             UPDATE control_date
...                             SET control_date = STR_TO_DATE(%s, '%%m/%%d/%%Y'),
...                             last_updated = CURRENT_TIMESTAMP
...                             WHERE domain_name = %s

${SELECT_CONTROL_DATE}
...                             SELECT domain_name, 
...                             DATE_FORMAT(control_date, '%%m/%%d/%%Y') as formatted_date,
...                             last_updated
...                             FROM control_date
...                             WHERE domain_name = %s

${CREATE_STORED_PROCEDURE}
...                             CREATE PROCEDURE IF NOT EXISTS update_employee_salary(
...                             IN emp_id INT,
...                             IN new_salary DECIMAL(10,2)
...                             )
...                             BEGIN
...                             UPDATE employees
...                             SET salary = new_salary
...                             WHERE id = emp_id;
...                             END

${DROP_STORED_PROCEDURE}        DROP PROCEDURE IF EXISTS update_employee_salary

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

${DROP_INDEX_EMPLOYEES}         DROP INDEX idx_employees_name ON employees

${DROP_INDEX_EMPLOYEES2}        DROP INDEX idx_employees2_name ON employees2

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

${DESCRIBE_TABLE}               DESCRIBE employees

${CHECK_TABLE_EXISTS}
...                             SELECT COUNT(*) as table_exists
...                             FROM information_schema.tables
...                             WHERE table_schema = DATABASE()
...                             AND table_name = %s
