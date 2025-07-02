#!/bin/bash
# SQL Server Setup Script
# This script runs after SQL Server is healthy to create the TEST database and user

echo 'SQL Server is healthy, creating TEST database and user...'

/opt/mssql-tools18/bin/sqlcmd -S sqlserver-db -U sa -P 'Snaplogic123!' -C -Q "
-- Create TEST database if not exists
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'TEST')
BEGIN
    CREATE DATABASE TEST;
    PRINT 'TEST database created successfully';
END
ELSE
BEGIN
    PRINT 'TEST database already exists';
END
GO

-- Switch to TEST database
USE TEST;
GO

-- Create login if not exists
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'testuser')
BEGIN
    CREATE LOGIN testuser WITH PASSWORD = 'Snaplogic123!';
    PRINT 'testuser login created successfully';
END
ELSE
BEGIN
    PRINT 'testuser login already exists';
END
GO

-- Create user in TEST database
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'testuser')
BEGIN
    CREATE USER testuser FOR LOGIN testuser;
    PRINT 'testuser database user created successfully';
END
ELSE
BEGIN
    PRINT 'testuser database user already exists';
END
GO

-- Grant permissions
ALTER ROLE db_owner ADD MEMBER testuser;
GRANT CREATE TABLE TO testuser;
GRANT CREATE VIEW TO testuser;
GRANT CREATE PROCEDURE TO testuser;
GRANT CREATE FUNCTION TO testuser;
GO

-- Verify setup
SELECT name, type_desc, create_date FROM sys.database_principals WHERE name = 'testuser';
GO
"

if [ $? -eq 0 ]; then
    echo 'TEST database and user setup completed successfully!'
    echo ''
    echo '=== SQL Server Connection Details ==='
    echo 'Host: sqlserver-db (or localhost:1433 from host)'
    echo 'Port: 1433'
    echo 'Database: TEST'
    echo ''
    echo '=== User Credentials ==='
    echo 'Test User:'
    echo '  Username: testuser'
    echo '  Password: Snaplogic123!'
    echo ''
    echo 'SA (Admin) User:'
    echo '  Username: sa'
    echo '  Password: Snaplogic123!'
    echo ''
    echo '=== Permissions Granted to testuser ==='
    echo '- db_owner role (full database permissions)'
    echo '- CREATE TABLE: Create tables'
    echo '- CREATE VIEW: Create views'
    echo '- CREATE PROCEDURE: Create stored procedures'
    echo '- CREATE FUNCTION: Create functions'
    echo ''
    echo '=== Connection String Examples ==='
    echo 'JDBC: jdbc:sqlserver://localhost:1433;databaseName=TEST;user=testuser;password=Snaplogic123!'
    echo '.NET: Server=localhost,1433;Database=TEST;User Id=testuser;Password=Snaplogic123!'
    echo 'ODBC: DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost,1433;DATABASE=TEST;UID=testuser;PWD=Snaplogic123!'
    echo ''
    echo 'You can now connect to SQL Server using the testuser account!'
else
    echo 'ERROR: Failed to setup TEST database and user'
    exit 1
fi
