*** Variables ***
${CREATE_TABLE_EMPLOYEES}
...                             CREATE TABLE employees (
...                             id NUMBER PRIMARY KEY,
...                             name VARCHAR2(100),
...                             department VARCHAR2(50)
...                             )

${CREATE_PROC_ADD_EMPLOYEE}
...                             CREATE OR REPLACE PROCEDURE add_employee(
...                             p_id IN NUMBER,
...                             p_name IN VARCHAR2,
...                             p_dept IN VARCHAR2
...                             )
...                             AS
...                             BEGIN
...                             INSERT INTO employees VALUES (p_id, p_name, p_dept);
...                             COMMIT;
...                             END;

${CREATE_PROC_GET_STATS}
...                             CREATE OR REPLACE PROCEDURE get_employee_stats(
...                             p_dept IN VARCHAR2,
...                             p_count OUT NUMBER
...                             )
...                             AS
...                             BEGIN
...                             SELECT COUNT(*) INTO p_count
...                             FROM employees
...                             WHERE department = p_dept;
...                             END;

# REF_VALUES_TABLE
${CREATE_TABLE_REF_VALUES}
...                             CREATE TABLE ref_values (
...                             id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
...                             domain_name    VARCHAR2(100),
...                             name_cd_1    VARCHAR2(100),
...                             number_flag    NUMBER,
...                             modification_date DATE,
...                             name_cd_2    VARCHAR2(100),
...                             modified_by_user VARCHAR2(100)
...                             )

# Procedure creation
${CREATE_PROC_REF_VALUES}
...                             CREATE OR REPLACE PROCEDURE add_ref_value(
...                             p_domain_name IN VARCHAR2,
...                             p_name_cd_1 IN VARCHAR2,
...                             p_number_flag IN NUMBER,
...                             p_modification_date IN DATE,
...                             p_name_cd_2 IN VARCHAR2,
...                             p_modified_by_user IN VARCHAR2
...                             )
...                             AS
...                             BEGIN
...                             INSERT INTO ref_values (domain_name, name_cd_1, number_flag, modification_date, name_cd_2, modified_by_user)
...                             VALUES (p_domain_name, p_name_cd_1, p_number_flag, p_modification_date, p_name_cd_2, p_modified_by_user);
...                             COMMIT;
...                             END;
