# Docker Scripts

This directory contains setup scripts used by docker-compose services.

## Making Scripts Executable

Before using docker-compose, make sure all scripts are executable:

```bash
chmod +x docker/scripts/*.sh
```

## ActiveMQ Setup Script

**File:** `activemq-setup.sh`

This script runs after ActiveMQ Artemis is healthy to display connection information and setup details.

### What it does:
1. Waits for ActiveMQ to be fully ready
2. Tests the web console connection
3. Displays connection information
4. Shows queue and topic suggestions
5. Provides routing type information

### Usage:
The script is automatically executed by the `activemq-setup` service defined in `docker-compose.activemq.yml`.

### Connection Details Provided:
- Web Console: http://localhost:8161/console
- JMS URL: tcp://localhost:61616
- STOMP URL: tcp://localhost:61613
- Username: admin
- Password: admin

### Suggested Queues:
- test.queue
- demo.queue
- sap.idoc.queue

### Suggested Topics:
- test.topic
- notifications
- price.updates

## MySQL Setup Script

**File:** `mysql-setup.sh`

This script runs after MySQL is healthy to configure the TEST database and set up user permissions.

### What it does:
1. Configures the TEST database
2. Creates and grants permissions to testuser
3. Sets up both '%' and 'localhost' access
4. Creates a verification table
5. Displays connection information

### Usage:
The script is automatically executed by the `mysql-schema-init` service defined in `docker-compose.mysql.yml`.

### Connection Details:
- Host: mysql-db (or localhost:3306 from host)
- Database: TEST
- Username: testuser
- Password: snaplogic
- Root Password: snaplogic

### Permissions Granted:
- Full database administration on TEST database
- CREATE, ALTER, DROP tables
- INSERT, SELECT, UPDATE, DELETE data
- CREATE/ALTER procedures and functions
- CREATE/SHOW views
- Execute stored procedures
- Manage triggers and events

### Verification:
The script creates a `test_verification` table with sample data. You can verify the setup by running:
```sql
SELECT * FROM TEST.test_verification;
```

## Oracle Setup Script

**File:** `oracle-setup.sh`

This script runs after Oracle Database is healthy to create the TEST schema and configure user permissions.

### What it does:
1. Creates the TEST user/schema
2. Handles existing user gracefully
3. Grants necessary permissions
4. Verifies user creation
5. Displays connection information

### Usage:
The script is automatically executed by the `oracle-schema-init` service defined in `docker-compose.oracle.yml`.

### Connection Details:
- Host: oracle-db (or localhost:1521 from host)
- Service Name: FREEPDB1
- Port: 1521

### Schema Credentials:
- TEST Schema:
  - Username: TEST
  - Password: Test123
- System User:
  - Username: system
  - Password: Oracle123

### Permissions Granted:
- CONNECT: Basic connection privilege
- RESOURCE: Create objects like tables, sequences
- UNLIMITED TABLESPACE: No space restrictions
- CREATE SESSION: Login capability
- CREATE TABLE: Create tables
- CREATE VIEW: Create views
- CREATE PROCEDURE: Create stored procedures
- CREATE SEQUENCE: Create sequences
- CREATE TRIGGER: Create triggers

### Connection String Examples:
- JDBC: `jdbc:oracle:thin:@oracle-db:1521:FREEPDB1`
- TNS: `oracle-db:1521/FREEPDB1`
- SQLPlus: `sqlplus TEST/Test123@oracle-db:1521/FREEPDB1`

## SQL Server Setup Script

**File:** `sqlserver-setup.sh`

This script runs after SQL Server is healthy to create the TEST database and configure user permissions.

### What it does:
1. Creates the TEST database
2. Creates testuser login and database user
3. Handles existing database/user gracefully
4. Grants comprehensive permissions
5. Displays connection information

### Usage:
The script is automatically executed by the `sqlserver-schema-init` service defined in `docker-compose.sqlserver.yml`.

### Connection Details:
- Host: sqlserver-db (or localhost:1433 from host)
- Port: 1433
- Database: TEST

### User Credentials:
- Test User:
  - Username: testuser
  - Password: Snaplogic123!
- SA (Admin) User:
  - Username: sa
  - Password: Snaplogic123!

### Permissions Granted:
- db_owner role (full database permissions)
- CREATE TABLE: Create tables
- CREATE VIEW: Create views
- CREATE PROCEDURE: Create stored procedures
- CREATE FUNCTION: Create functions

### Connection String Examples:
- JDBC: `jdbc:sqlserver://localhost:1433;databaseName=TEST;user=testuser;password=Snaplogic123!`
- .NET: `Server=localhost,1433;Database=TEST;User Id=testuser;Password=Snaplogic123!`
- ODBC: `DRIVER={ODBC Driver 18 for SQL Server};SERVER=localhost,1433;DATABASE=TEST;UID=testuser;PWD=Snaplogic123!`

## MinIO (S3 Emulator) Setup Script

**File:** `minio-setup.sh`

This script runs after MinIO is healthy to configure buckets, users, and sample data.

### What it does:
1. Configures MinIO client (mc)
2. Creates demo user with readwrite policy
3. Creates demo-bucket and test-bucket
4. Uploads sample files to buckets
5. Displays connection information

### Usage:
The script is automatically executed by the `minio-setup` service defined in `docker-compose.s3emulator.yml`.

### Connection Details:
- Endpoint: http://localhost:9000
- Console: http://localhost:9001

### Credentials:
- Root User:
  - Access Key: minioadmin
  - Secret Key: minioadmin
- Demo User:
  - Access Key: demouser
  - Secret Key: demopassword
  - Policy: readwrite

### Created Resources:
- **Buckets:**
  - demo-bucket (contains: welcome.txt, config.json)
  - test-bucket (contains: setup-info.txt)
- **Users:**
  - demouser (with readwrite policy)

### S3 Client Configuration Examples:

**AWS CLI:**
```bash
aws configure set aws_access_key_id demouser
aws configure set aws_secret_access_key demopassword
aws --endpoint-url http://localhost:9000 s3 ls
```

**Python boto3:**
```python
s3 = boto3.client('s3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='demouser',
    aws_secret_access_key='demopassword')
```

**SnapLogic S3 Account:**
- Endpoint: http://minio:9000 (from within Docker network)
- Access Key: demouser
- Secret Key: demopassword
