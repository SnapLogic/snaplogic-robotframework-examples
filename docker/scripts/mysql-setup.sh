#!/bin/bash
# MySQL Setup Script
# This script runs after MySQL is healthy to configure the TEST database and user permissions

echo 'MySQL is healthy, configuring TEST database and user permissions...'

mysql -h mysql-db -u root -psnaplogic <<'EOF'
-- Select the TEST database
USE TEST;

-- Grant all privileges on TEST database to testuser
GRANT ALL PRIVILEGES ON TEST.* TO 'testuser'@'%';
GRANT CREATE, ALTER, DROP, INDEX, INSERT, SELECT, UPDATE, DELETE, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON TEST.* TO 'testuser'@'%';

-- Additional grants for full functionality
GRANT PROCESS ON *.* TO 'testuser'@'%';
GRANT REFERENCES ON TEST.* TO 'testuser'@'%';

-- Ensure user can connect from any host
CREATE USER IF NOT EXISTS 'testuser'@'localhost' IDENTIFIED BY 'snaplogic';
GRANT ALL PRIVILEGES ON TEST.* TO 'testuser'@'localhost';

-- Flush privileges to ensure they take effect
FLUSH PRIVILEGES;

-- Verify user setup
SELECT user, host, Grant_priv, Super_priv FROM mysql.user WHERE user = 'testuser';
SHOW GRANTS FOR 'testuser'@'%';

-- Create sample table to verify permissions
CREATE TABLE IF NOT EXISTS test_verification (
    id INT PRIMARY KEY AUTO_INCREMENT,
    message VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_verification (message) VALUES ('Database setup completed successfully');

SELECT * FROM test_verification;
EOF

echo 'TEST database and user permissions configured successfully!'
echo ''
echo '=== MySQL Connection Details ==='
echo 'Host: mysql-db (or localhost:3306 from host)'
echo 'Database: TEST'
echo 'Username: testuser'
echo 'Password: snaplogic'
echo ''
echo 'Root User: root'
echo 'Root Password: snaplogic'
echo ''
echo '=== Permissions Granted ==='
echo '- Full database administration on TEST database'
echo '- CREATE, ALTER, DROP tables'
echo '- INSERT, SELECT, UPDATE, DELETE data'
echo '- CREATE/ALTER procedures and functions'
echo '- CREATE/SHOW views'
echo '- Execute stored procedures'
echo '- Manage triggers and events'
echo ''
echo '=== Verification ==='
echo 'A test_verification table has been created with sample data.'
echo 'You can verify the setup by connecting and running:'
echo 'SELECT * FROM TEST.test_verification;'
