*** Variables ***
${CREATE_TABLE_EMPLOYEES_PG}
...                                     DROP TABLE IF EXISTS employees CASCADE;
...                                     CREATE TABLE IF NOT EXISTS employees (
...                                     id SERIAL PRIMARY KEY,
...                                     name TEXT NOT NULL,
...                                     role TEXT NOT NULL,
...                                     salary INTEGER
...                                     )

${CREATE_TABLE_EMPLOYEES2_PG}
...                                     DROP TABLE IF EXISTS employees2 CASCADE;
...                                     CREATE TABLE IF NOT EXISTS employees2 (
...                                     id SERIAL PRIMARY KEY,
...                                     name TEXT NOT NULL,
...                                     role TEXT NOT NULL,
...                                     salary INTEGER
...                                     )

${INSERT_INTO_TABLE_EMPLOYEES_PG}
...                                     INSERT INTO employees (name, role, salary) VALUES
...                                     ('Alice', 'Engineer', 90000),
...                                     ('Bob', 'Analyst', 75000),
...                                     ('Carol', 'Manager', 105000);
