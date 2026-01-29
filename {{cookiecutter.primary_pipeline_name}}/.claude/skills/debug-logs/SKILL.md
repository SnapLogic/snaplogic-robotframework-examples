---
name: debug-logs
description: Helps debug test failures and view logs in the SnapLogic Robot Framework project. Use when the user wants to view test results, check container logs, debug specific test failures, or run environment diagnostics.
user-invocable: true
---

You are helping a user debug test failures and view logs in this SnapLogic Robot Framework project. Provide guidance based on these conventions.

## Quick Debugging Checklist

When a test fails, check in this order:

1. **Test Results** - `test/robot_output/log-*.html`
2. **Container Status** - `make status`
3. **Service Logs** - `make <service>-logs`
4. **Environment** - `make check-env`
5. **Network** - `make docker-networks`

## Viewing Test Results

### Robot Framework Logs
```bash
# Find the latest log file
ls -lt test/robot_output/log-*.html | head -1

# Open in browser (macOS)
open test/robot_output/log-*.html

# Open specific timestamped log
open test/robot_output/log-20240115-143022.html
```

### Log File Types
| File | Content |
|------|---------|
| `log-*.html` | Detailed execution log with all keyword steps |
| `report-*.html` | Summary report with pass/fail statistics |
| `output-*.xml` | Raw XML results (for CI/CD integration) |

### What to Look For in Logs
1. **Red highlighted rows** - Failed keywords
2. **Timestamps** - Identify slow operations
3. **Screenshots** - If captured on failure
4. **Variable values** - Expand to see actual values used
5. **Stack traces** - Python errors in library calls

## Container Logs

### View All Container Logs
```bash
# All logs (can be overwhelming)
docker compose logs

# Follow logs in real-time
docker compose logs -f

# Last 100 lines
docker compose logs --tail=100
```

### Service-Specific Logs
```bash
# Test execution container
docker compose logs tools
docker compose logs -f tools  # Follow

# Database logs
make oracle-logs      # Oracle
make postgres-logs    # PostgreSQL
make mysql-logs       # MySQL
make snowflake-logs   # Snowflake mock

# Messaging logs
make kafka-logs       # Kafka
make activemq-logs    # ActiveMQ

# Mock service logs
make minio-logs       # MinIO (S3)
make salesforce-logs  # Salesforce mock
make maildev-logs     # Email mock

# Groundplex logs
docker compose logs groundplex
```

### Filter Logs
```bash
# Search for errors
docker compose logs tools 2>&1 | grep -i error

# Search for specific test
docker compose logs tools 2>&1 | grep "Test Pipeline"

# Logs from specific time
docker compose logs --since 10m tools  # Last 10 minutes
```

## Common Failure Scenarios

### 1. Connection Refused

**Symptoms:**
```
ConnectionRefusedError: [Errno 111] Connection refused
Failed to connect to database
```

**Debug Steps:**
```bash
# Check if container is running
make status

# Check specific service
make oracle-status  # Replace with your service

# View service logs
make oracle-logs

# Verify ports
docker compose ps

# Check network
make docker-networks
```

**Common Causes:**
- Container not started
- Container still initializing (especially Oracle)
- Wrong port configuration
- Network isolation issues

### 2. Environment Variable Missing

**Symptoms:**
```
Missing required environment variables: URL, ORG_ADMIN_USER
KeyError: 'ORACLE_PASSWORD'
```

**Debug Steps:**
```bash
# Check environment
make check-env

# Verify .env file
cat .env | grep -v "^#" | grep -v "^$"

# Check specific variable
grep "ORACLE_PASSWORD" .env

# Verify it's being loaded
docker compose exec tools env | grep ORACLE
```

**Common Causes:**
- Missing `.env` file (copy from `.env.example`)
- Variable not defined
- Typo in variable name
- Environment file not in `env_files/`

### 3. Pipeline Execution Failed

**Symptoms:**
```
Pipeline status: Failed
Execution error: Connection timeout
```

**Debug Steps:**
```bash
# Check Groundplex status
docker compose ps groundplex

# View Groundplex logs
docker compose logs groundplex

# Check SnapLogic connection
# (Look for authentication or network errors)
make status

# Verify credentials
grep -E "^(URL|ORG_)" .env
```

**Common Causes:**
- Groundplex not running or not registered
- SnapLogic credentials expired
- Network connectivity to SnapLogic cloud
- Pipeline has errors

### 4. Timeout Errors

**Symptoms:**
```
TimeoutError: Operation timed out
Test case timeout exceeded
```

**Debug Steps:**
```bash
# Check service responsiveness
make status

# Look for slow operations in logs
docker compose logs tools 2>&1 | grep -i "time\|slow\|wait"

# Check system resources
docker stats
```

**Common Causes:**
- Service overloaded
- Insufficient resources
- Long-running database operations
- Network latency

### 5. Data/Assertion Failures

**Symptoms:**
```
AssertionError: Expected 100 rows, got 0
Data mismatch: expected 'SUCCESS', got 'PENDING'
```

**Debug Steps:**
```bash
# Check test data was loaded
make oracle-status  # Check DB
make oracle-load-data  # Reload if needed

# Verify pipeline output
# Check the log-*.html for actual values

# Check for race conditions
# (Test ran before data was ready)
```

**Common Causes:**
- Test data not loaded
- Previous test didn't clean up
- Race condition in async operations
- Pipeline logic error

## Advanced Debugging

### Interactive Container Access
```bash
# Shell into tools container
docker compose exec tools bash

# Then run commands inside:
cd /app/test
python -c "import os; print(os.environ.get('URL'))"
robot --dryrun suite/
```

### Database Query
```bash
# Oracle
docker compose exec oracle-db sqlplus testuser/testpass@//localhost:1521/FREEPDB1

# PostgreSQL
docker compose exec postgres-db psql -U testuser -d testdb

# MySQL
docker compose exec mysql-db mysql -u testuser -ptestpass testdb
```

### Network Debugging
```bash
# Check container networks
make docker-networks

# Test connectivity from tools container
docker compose exec tools ping -c 3 oracle-db
docker compose exec tools nc -zv oracle-db 1521
```

### Inspect Container
```bash
# Detailed container info
docker inspect <container_name>

# Environment variables
docker inspect <container_name> | jq '.[0].Config.Env'

# Network settings
docker inspect <container_name> | jq '.[0].NetworkSettings'
```

## Logging Best Practices

### Add Logging to Tests
```robotframework
*** Test Cases ***
Test With Debug Logging
    Log To Console    Starting test execution...
    Log    Variable value: ${MY_VAR}    level=DEBUG
    ${result}=    Execute Pipeline
    Log    Pipeline result: ${result}    level=INFO
    Capture Page Screenshot    # If using Browser library
```

### Enable Debug Mode
```bash
# Run with debug logging
docker compose exec -w /app/test tools robot \
    --loglevel DEBUG \
    --include oracle \
    --outputdir robot_output \
    suite/
```

## Getting Help

If you're stuck:

1. **Search logs for the exact error message**
2. **Check if the issue is environment-specific** (works locally but not in CI?)
3. **Try a clean restart**: Stop all services, flush data, start fresh
4. **Isolate the problem**: Run the smallest test that reproduces the issue

```bash
# Clean restart
make oracle-stop  # Replace with your service
docker compose down
make oracle-start
make robot-run-tests TAGS="smoke"  # Run minimal test first
```
