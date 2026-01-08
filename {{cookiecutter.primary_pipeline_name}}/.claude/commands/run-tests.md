---
description: Guide for running Robot Framework tests in this SnapLogic project
---

You are helping a user run Robot Framework tests in this SnapLogic pipeline testing project. Provide guidance based on these conventions.

## Quick Reference

### Basic Test Execution
```bash
# Run tests with a specific tag
make robot-run-tests TAGS="oracle"

# Run tests with multiple tags (OR logic - runs tests matching ANY tag)
make robot-run-tests TAGS="oracle,postgres,snowflake"

# Run all tests (not recommended - use tags)
make robot-run-tests
```

### Full Workflow (with Environment Setup)
```bash
# Complete workflow: setup project space, start Groundplex, run tests
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True

# Run without Groundplex management (when Groundplex is already running)
make robot-run-tests-no-gp TAGS="oracle" PROJECT_SPACE_SETUP=True
```

## Available Test Tags

### By System Type
| Tag | Description | Requires |
|-----|-------------|----------|
| `oracle` | Oracle database tests | `make oracle-start` |
| `postgres` | PostgreSQL tests | `make postgres-start` |
| `mysql` | MySQL tests | `make mysql-start` |
| `sqlserver` | SQL Server tests | `make sqlserver-start` |
| `snowflake` | Snowflake tests | `make snowflake-mock-start` |
| `db2` | DB2 tests | `make db2-start` |
| `teradata` | Teradata tests | `make teradata-start` |
| `kafka` | Kafka messaging tests | `make kafka-start` |
| `jms` | ActiveMQ/JMS tests | `make activemq-start` |
| `salesforce` | Salesforce mock tests | `make salesforce-mock-start` |
| `s3` / `minio` | S3/MinIO tests | `make minio-start` |
| `email` | Email tests | `make maildev-start` |

### By Test Type
| Tag | Description |
|-----|-------------|
| `smoke` | Quick validation tests |
| `regression` | Full regression suite |
| `createplex` | Groundplex setup tests |
| `verify_project_space_exists` | Project space validation |
| `export_assets` | Asset export operations |
| `import_assets` | Asset import operations |
| `upload_pipeline` | Pipeline upload tests |

## Pre-requisites Checklist

Before running tests, ensure:

### 1. Environment Configuration
```bash
# Verify .env file exists and is configured
cat .env | grep -E "^(URL|ORG_|PROJECT_)"

# Or use the check command
make check-env
```

### 2. Required Services Running
```bash
# Check overall status
make status

# Check specific service
make oracle-status  # or postgres-status, etc.
```

### 3. Docker Environment
```bash
# Verify Docker is running
docker ps

# Check project containers
make show-running
```

## Step-by-Step Guide

### Running Oracle Tests
```bash
# 1. Start Oracle database
make oracle-start

# 2. Wait for Oracle to be ready (check logs)
make oracle-logs

# 3. Load test data (if needed)
make oracle-load-data

# 4. Run Oracle tests
make robot-run-tests TAGS="oracle"

# 5. View results
open test/robot_output/report-*.html
```

### Running Kafka Tests
```bash
# 1. Start Kafka cluster
make kafka-start

# 2. Create test topics
make kafka-create-topics

# 3. Run Kafka tests
make robot-run-tests TAGS="kafka"
```

### Running Multiple System Tests
```bash
# Start required services
make oracle-start
make postgres-start

# Run tests for both (OR logic)
make robot-run-tests TAGS="oracle,postgres"
```

## Test Results

### Location
```
test/robot_output/
├── output-YYYYMMDD-HHMMSS.xml   # Raw results
├── log-YYYYMMDD-HHMMSS.html     # Detailed log
└── report-YYYYMMDD-HHMMSS.html  # Summary report
```

### Viewing Results
```bash
# Open the latest report (macOS)
open test/robot_output/report-*.html

# Or find the latest
ls -lt test/robot_output/report-*.html | head -1
```

### Sharing Results
```bash
# Send to Slack
make slack-notify

# Upload to S3
make upload-test-results
```

## Troubleshooting Failed Tests

### 1. Check Test Logs
```bash
# View detailed execution log
open test/robot_output/log-*.html
```

### 2. Check Container Logs
```bash
make logs-tools        # Test container logs
make oracle-logs       # Database logs (replace with your system)
```

### 3. Verify Environment
```bash
make check-env
make status
```

### 4. Re-run with Fresh Setup
```bash
# Stop everything
make oracle-stop  # or relevant service

# Start fresh
make oracle-start
make robot-run-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
```

## Common Issues

### "Environment variable not found"
- Check `.env` file exists and has required variables
- Run `make check-env` to identify missing variables

### "Connection refused" to database
- Ensure container is running: `make <db>-status`
- Check container logs: `make <db>-logs`
- Verify network: `make docker-networks`

### "Groundplex not available"
- Start Groundplex: `make launch-groundplex`
- Or use no-GP mode: `make robot-run-tests-no-gp TAGS="..."`

### Tests hang or timeout
- Check service health: `make status`
- Increase timeout in test if needed
- Check network connectivity between containers

## Advanced Options

### Run with Project Space Recreation
```bash
# Deletes and recreates project space before tests
make robot-run-tests TAGS="oracle" PROJECT_SPACE_SETUP=True
```

### Run Specific Test File
```bash
# Run tests from specific directory
docker compose exec -w /app/test tools robot \
    --include oracle \
    --outputdir robot_output \
    suite/pipeline_tests/oracle/
```

### Dry Run (No Execution)
```bash
docker compose exec -w /app/test tools robot \
    --dryrun \
    --include oracle \
    suite/
```
