*** Variables ***
${DROP_TABLE_EMPLOYEES}         DROP TABLE IF EXISTS employees

${DROP_TABLE_EMPLOYEES2}        DROP TABLE IF EXISTS employees2

${CREATE_TABLE_EMPLOYEES}
...                             CREATE TABLE employees (
...                             id INT IDENTITY(1,1) PRIMARY KEY,
...                             name NVARCHAR(100) NOT NULL,
...                             role NVARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2)
...                             )

${CREATE_TABLE_EMPLOYEES2}
...                             CREATE TABLE employees2 (
...                             id INT IDENTITY(1,1) PRIMARY KEY,
...                             name NVARCHAR(100) NOT NULL,
...                             role NVARCHAR(100) NOT NULL,
...                             salary DECIMAL(10,2)
...                             )
