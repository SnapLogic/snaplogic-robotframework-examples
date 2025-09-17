#!/bin/bash
# Oracle Setup Script
# This script runs after Oracle is healthy to create the TEST schema and user

echo 'Oracle is healthy, creating TEST schema...'

sqlplus system/Oracle123@oracle-db:1521/FREEPDB1 <<'EOF'
SET SERVEROUTPUT ON;
BEGIN
    EXECUTE IMMEDIATE 'CREATE USER TEST IDENTIFIED BY Test123';
    DBMS_OUTPUT.PUT_LINE('TEST user created successfully');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -1920 THEN
            DBMS_OUTPUT.PUT_LINE('TEST user already exists');
        ELSE
            RAISE;
        END IF;
END;
/
GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO TEST;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW TO TEST;
GRANT CREATE PROCEDURE, CREATE SEQUENCE, CREATE TRIGGER TO TEST;
SELECT username, account_status FROM dba_users WHERE username = 'TEST';
EXIT;
EOF

if [ $? -eq 0 ]; then
    echo 'TEST schema setup completed successfully!'
    echo ''
    echo '=== Oracle Connection Details ==='
    echo 'Host: oracle-db (or localhost:1521 from host)'
    echo 'Service Name: FREEPDB1'
    echo 'Port: 1521'
    echo ''
    echo '=== TEST Schema Credentials ==='
    echo 'Username: TEST'
    echo 'Password: Test123'
    echo ''
    echo '=== System User Credentials ==='
    echo 'Username: system'
    echo 'Password: Oracle123'
    echo ''
    echo '=== Permissions Granted to TEST ==='
    echo '- CONNECT: Basic connection privilege'
    echo '- RESOURCE: Create objects like tables, sequences'
    echo '- UNLIMITED TABLESPACE: No space restrictions'
    echo '- CREATE SESSION: Login capability'
    echo '- CREATE TABLE: Create tables'
    echo '- CREATE VIEW: Create views'
    echo '- CREATE PROCEDURE: Create stored procedures'
    echo '- CREATE SEQUENCE: Create sequences'
    echo '- CREATE TRIGGER: Create triggers'
    echo ''
    echo '=== Connection String Examples ==='
    echo 'JDBC: jdbc:oracle:thin:@oracle-db:1521:FREEPDB1'
    echo 'TNS: oracle-db:1521/FREEPDB1'
    echo 'SQLPlus: sqlplus TEST/Test123@oracle-db:1521/FREEPDB1'
    echo ''
    echo 'You can now connect to Oracle using the TEST schema!'
else
    echo 'ERROR: Failed to setup TEST schema'
    exit 1
fi
