---
description: Guide for setting up database containers for testing
---

You are helping a user set up database containers for SnapLogic pipeline testing. Provide guidance based on these conventions.

## Available Databases

| Database | Container Name | Port | Make Commands |
|----------|---------------|------|---------------|
| Oracle | oracle-db | 1521 | `make oracle-*` |
| PostgreSQL | postgres-db | 5432 | `make postgres-*` |
| MySQL | mysql-db | 3306 | `make mysql-*` |
| SQL Server | sqlserver-db | 1433 | `make sqlserver-*` |
| DB2 | db2-db | 50000 | `make db2-*` |
| Teradata | teradata-db | 1025 | `make teradata-*` |
| Snowflake (Mock) | snowflake-mock | 8080 | `make snowflake-*` |

## Quick Start

### Oracle Database
```bash
# Start Oracle
make oracle-start

# Check status (wait for "healthy")
make oracle-status

# View logs
make oracle-logs

# Load test data
make oracle-load-data

# Connect to database
make oracle-shell
# Or: docker compose exec oracle-db sqlplus testuser/testpass@//localhost:1521/FREEPDB1

# Stop Oracle
make oracle-stop
```

### PostgreSQL
```bash
# Start PostgreSQL
make postgres-start

# Check status
make postgres-status

# Load test data
make postgres-load-data

# Connect to database
make postgres-shell
# Or: docker compose exec postgres-db psql -U testuser -d testdb

# Stop PostgreSQL
make postgres-stop
```

### MySQL
```bash
# Start MySQL
make mysql-start

# Check status
make mysql-status

# Load test data
make mysql-load-data

# Connect to database
make mysql-shell
# Or: docker compose exec mysql-db mysql -u testuser -ptestpass testdb

# Stop MySQL
make mysql-stop
```

### SQL Server
```bash
# Start SQL Server
make sqlserver-start

# Check status
make sqlserver-status

# Connect to database
make sqlserver-shell

# Stop SQL Server
make sqlserver-stop
```

### Snowflake (Mock)
```bash
# Start Snowflake mock service
make snowflake-mock-start

# Check status
make snowflake-status

# Stop Snowflake mock
make snowflake-mock-stop
```

## Environment Configuration

### Database Credentials

Add to your `.env` file:

```bash
# Oracle
ORACLE_USER=testuser
ORACLE_PASSWORD=testpass
ORACLE_DATABASE=FREEPDB1
ORACLE_HOST=oracle-db
ORACLE_PORT=1521

# PostgreSQL
POSTGRES_USER=testuser
POSTGRES_PASSWORD=testpass
POSTGRES_DATABASE=testdb
POSTGRES_HOST=postgres-db
POSTGRES_PORT=5432

# MySQL
MYSQL_USER=testuser
MYSQL_PASSWORD=testpass
MYSQL_DATABASE=testdb
MYSQL_HOST=mysql-db
MYSQL_PORT=3306

# SQL Server
SQLSERVER_USER=sa
SQLSERVER_PASSWORD=YourStrong!Passw0rd
SQLSERVER_DATABASE=testdb
SQLSERVER_HOST=sqlserver-db
SQLSERVER_PORT=1433

# Snowflake
SNOWFLAKE_ACCOUNT=mock_account
SNOWFLAKE_USER=testuser
SNOWFLAKE_PASSWORD=testpass
SNOWFLAKE_DATABASE=testdb
SNOWFLAKE_WAREHOUSE=test_wh
```

### Service-Specific Environment Files

For complex configurations, create files in `env_files/`:

```
env_files/
├── .env.oracle
├── .env.postgres
├── .env.mysql
└── .env.snowflake
```

## Loading Test Data

### From SQL Files
```bash
# Oracle - load from SQL file
docker compose exec oracle-db sqlplus testuser/testpass@//localhost:1521/FREEPDB1 @/path/to/script.sql

# PostgreSQL - load from SQL file
docker compose exec postgres-db psql -U testuser -d testdb -f /path/to/script.sql

# MySQL - load from SQL file
docker compose exec mysql-db mysql -u testuser -ptestpass testdb < /path/to/script.sql
```

### Using Make Targets
```bash
# Load predefined test data
make oracle-load-data
make postgres-load-data
make mysql-load-data
```

### Custom Data Loading
Create a test data SQL file in `test/suite/test_data/` and reference it in your tests:

```robotframework
*** Keywords ***
Load Custom Test Data
    [Arguments]    ${sql_file}
    ${result}=    Run Process    docker    compose    exec    -T    oracle-db
    ...    sqlplus    testuser/testpass@//localhost:1521/FREEPDB1    @${sql_file}
    Should Be Equal As Integers    ${result.rc}    0
```

## Troubleshooting

### Container Won't Start

```bash
# Check for port conflicts
lsof -i :1521  # Oracle
lsof -i :5432  # PostgreSQL
lsof -i :3306  # MySQL

# Check Docker resources
docker system df
docker stats

# Remove and recreate
make oracle-stop
docker compose rm -f oracle-db
make oracle-start
```

### Connection Refused

```bash
# 1. Verify container is running
make oracle-status

# 2. Check container logs for errors
make oracle-logs

# 3. Verify network connectivity
docker compose exec tools ping -c 3 oracle-db
docker compose exec tools nc -zv oracle-db 1521

# 4. Check environment variables
docker compose exec tools env | grep ORACLE
```

### Oracle Specific Issues

**Initialization takes too long:**
Oracle can take 5-10 minutes on first start. Check logs:
```bash
make oracle-logs | grep -i "database ready"
```

**ORA-12514: TNS listener does not currently know of service:**
```bash
# Wait for database to fully initialize
# Check listener status
docker compose exec oracle-db lsnrctl status
```

### PostgreSQL Specific Issues

**FATAL: database "testdb" does not exist:**
```bash
# Create the database
docker compose exec postgres-db createdb -U testuser testdb
```

### MySQL Specific Issues

**Access denied for user:**
```bash
# Reset user permissions
docker compose exec mysql-db mysql -u root -p
# Then: GRANT ALL PRIVILEGES ON testdb.* TO 'testuser'@'%';
```

## Database Schema Management

### Creating Tables

```robotframework
*** Keywords ***
Create Test Table
    [Arguments]    ${table_name}
    ${sql}=    Catenate    SEPARATOR=\n
    ...    CREATE TABLE ${table_name} (
    ...        id NUMBER PRIMARY KEY,
    ...        name VARCHAR2(100),
    ...        value NUMBER,
    ...        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ...    )
    Execute SQL    ${sql}
```

### Dropping Tables

```robotframework
*** Keywords ***
Drop Test Table If Exists
    [Arguments]    ${table_name}
    Run Keyword And Ignore Error
    ...    Execute SQL    DROP TABLE ${table_name}
```

## Best Practices

### 1. Use Unique Table Names
```robotframework
${unique_id}=    Get Unique Id
${table_name}=    Set Variable    test_table_${unique_id}
```

### 2. Clean Up After Tests
```robotframework
[Teardown]    Run Keywords
...    Drop Test Table If Exists    ${table_name}
...    AND    Close Database Connection
```

### 3. Wait for Database Ready
```robotframework
*** Keywords ***
Wait For Database Ready
    [Arguments]    ${timeout}=120
    Wait Until Keyword Succeeds    ${timeout}    10s
    ...    Test Database Connection
```

### 4. Use Connection Pooling
For tests that make many database calls, consider connection reuse rather than opening new connections for each operation.

### 5. Isolate Test Data
Each test should create and clean up its own data to avoid interference with other tests.
