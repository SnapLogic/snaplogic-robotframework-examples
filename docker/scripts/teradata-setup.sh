#!/bin/bash
# Teradata Setup Script
# This script runs after Teradata is healthy to configure the TEST database and user permissions

echo 'Waiting for Teradata to be fully operational...'
sleep 30  # Additional wait time as Teradata takes time to fully initialize

echo 'Teradata is healthy, configuring TEST database and user permissions...'

# Create BTEQ script for database setup
cat > /tmp/teradata_setup.bteq <<'EOF'
.LOGON teradata-db/dbc,dbc;

-- Create TEST database
CREATE DATABASE TEST 
  AS PERMANENT = 100e6  -- 100MB
  SPOOL = 50e6          -- 50MB spool space
  TEMPORARY = 50e6;     -- 50MB temp space

-- Create test user
CREATE USER testuser 
  AS PERMANENT = 50e6   -- 50MB
  SPOOL = 30e6          -- 30MB spool space
  TEMPORARY = 30e6      -- 30MB temp space
  PASSWORD = snaplogic
  DEFAULT DATABASE = TEST;

-- Grant privileges to testuser on TEST database
GRANT ALL ON TEST TO testuser WITH GRANT OPTION;
GRANT CREATE DATABASE ON testuser TO testuser;
GRANT CREATE USER ON testuser TO testuser;
GRANT CREATE TABLE ON TEST TO testuser;
GRANT CREATE VIEW ON TEST TO testuser;
GRANT CREATE MACRO ON TEST TO testuser;
GRANT CREATE PROCEDURE ON TEST TO testuser;
GRANT CREATE FUNCTION ON TEST TO testuser;
GRANT EXECUTE PROCEDURE ON TEST TO testuser;
GRANT EXECUTE FUNCTION ON TEST TO testuser;

-- Additional grants for full functionality
GRANT SELECT ON DBC TO testuser;
GRANT EXECUTE ON SYSLIB TO testuser;

-- Create sample table to verify permissions
DATABASE TEST;

CREATE TABLE test_verification (
    id INTEGER NOT NULL,
    message VARCHAR(100),
    created_at TIMESTAMP(0) DEFAULT CURRENT_TIMESTAMP(0),
    PRIMARY KEY (id)
);

INSERT INTO test_verification (id, message) VALUES (1, 'Database setup completed successfully');

-- Verify setup
SELECT * FROM test_verification;

-- Show database and user info
SELECT DatabaseName, PermSpace, SpoolSpace, TempSpace 
FROM DBC.Databases 
WHERE DatabaseName IN ('TEST', 'testuser');

.LOGOFF;
.QUIT;
EOF

# Execute BTEQ script
bteq < /tmp/teradata_setup.bteq

# Clean up
rm -f /tmp/teradata_setup.bteq

echo 'TEST database and user permissions configured successfully!'
echo ''
echo '=== Teradata Connection Details ==='
echo 'Host: teradata-db (or localhost:1025 from host)'
echo 'Database: TEST'
echo 'Username: testuser'
echo 'Password: snaplogic'
echo ''
echo 'DBC User: dbc'
echo 'DBC Password: dbc'
echo ''
echo '=== Database Space Allocation ==='
echo 'TEST Database:'
echo '  - Permanent Space: 100MB'
echo '  - Spool Space: 50MB'
echo '  - Temporary Space: 50MB'
echo ''
echo 'testuser:'
echo '  - Permanent Space: 50MB'
echo '  - Spool Space: 30MB'
echo '  - Temporary Space: 30MB'
echo ''
echo '=== Permissions Granted ==='
echo '- Full database administration on TEST database'
echo '- CREATE, ALTER, DROP tables'
echo '- INSERT, SELECT, UPDATE, DELETE data'
echo '- CREATE/ALTER procedures, functions, and macros'
echo '- CREATE/SHOW views'
echo '- Execute stored procedures and functions'
echo ''
echo '=== Verification ==='
echo 'A test_verification table has been created with sample data.'
echo 'You can verify the setup by connecting and running:'
echo 'SELECT * FROM TEST.test_verification;'
echo ''
echo '=== Connection Options ==='
echo '1. BTEQ: bteq .logon localhost/testuser,snaplogic'
echo '2. JDBC: jdbc:teradata://localhost/DATABASE=TEST'
echo '3. ODBC: Use Teradata ODBC driver with DSN configuration'
