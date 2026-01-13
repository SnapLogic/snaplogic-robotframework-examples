---
description: Guide for running Robot Framework tests in this SnapLogic project
---

# Robot Framework Test Execution Guide

## Claude Instructions

**IMPORTANT:** When user asks a simple question like "How do I run Oracle tests?", provide a **concise answer first** with just the command(s), then offer to explain more if needed. Do NOT dump all documentation.

**Response format for simple questions:**
1. Give the direct command(s) first
2. Add a brief note if relevant
3. Offer "Want me to explain more?" only if appropriate

---

## Quick Command Reference

| Test Type | Command |
|-----------|---------|
| Oracle | `make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True` |
| PostgreSQL | `make robot-run-all-tests TAGS="postgres" PROJECT_SPACE_SETUP=True` |
| Snowflake | `make robot-run-all-tests TAGS="snowflake" PROJECT_SPACE_SETUP=True` |
| Kafka | `make robot-run-all-tests TAGS="kafka" PROJECT_SPACE_SETUP=True` |
| MySQL | `make robot-run-all-tests TAGS="mysql" PROJECT_SPACE_SETUP=True` |
| Multiple | `make robot-run-all-tests TAGS="oracle OR postgres" PROJECT_SPACE_SETUP=True` |

**Note:** Use `PROJECT_SPACE_SETUP=True` for first run, omit for subsequent runs.

---

## Usage Examples

| What You Want | Example Prompt |
|---------------|----------------|
| Explain test execution | `/run-tests Explain how to run robot tests in this project` |
| Run specific tests | `/run-tests How do I run Oracle tests?` |
| First time setup | `/run-tests I'm running tests for the first time, what should I do?` |
| Understand tags | `/run-tests What tags are available for running tests?` |
| Run multiple tests | `/run-tests How do I run both Snowflake and Kafka tests?` |
| View results | `/run-tests Where are the test results stored?` |
| Troubleshoot | `/run-tests My tests are failing, how do I debug?` |
| Quick iteration | `/run-tests I want to run tests quickly without Groundplex setup` |

---

## Why Make Commands Instead of Robot Command?

**Important:** In a standard Robot Framework setup, you would run tests directly using:
```bash
robot --include oracle test/suite/
```

**However, this project uses a dockerized environment.** This means:

1. **Tests run inside Docker containers** - Not on your local machine
2. **Services (databases, Kafka, etc.) run in containers** - They communicate via Docker networks
3. **Environment variables are managed** - Loaded from `.env` files into containers
4. **Groundplex runs in a container** - For SnapLogic pipeline execution

**The `make` commands handle all this complexity for you:**
- Start the correct Docker containers
- Set up networking between services
- Load environment variables
- Execute Robot Framework inside the tools container
- Manage Groundplex lifecycle

---

## Quick Start

### First Time Setup (Full Workflow)
```bash
# Complete workflow: create project space, launch Groundplex, run tests
make robot-run-all-tests TAGS="snowflake_demo" PROJECT_SPACE_SETUP=True
```

### Subsequent Runs (Project Space Exists)
```bash
# Run tests using existing project space
make robot-run-all-tests TAGS="snowflake_demo"
```

### Quick Iteration (Groundplex Already Running)
```bash
# Run tests without Groundplex management
make robot-run-tests-no-gp TAGS="snowflake_demo"
```

---

## Understanding the Make Targets

### 1. `robot-run-all-tests` - Full Workflow with Groundplex

**Use this when:** First time setup, CI/CD pipelines, or you need Groundplex managed automatically.

```bash
make robot-run-all-tests TAGS="your_tags" PROJECT_SPACE_SETUP=True|False
```

**Execution Flow:**
```
Phase 1: Project Space Setup
        ↓
Phase 2: Launch Groundplex
        ↓
Phase 2.1: Set Permissions (Travis CI)
        ↓
Phase 3: Run Tests
```

**Behavior with PROJECT_SPACE_SETUP:**

| Setting | Phase 1 Behavior | Phase 2 Behavior |
|---------|------------------|------------------|
| `True` | Deletes existing project space, creates new one with Snaplex | Launches Groundplex container |
| `False` (default) | Verifies project space exists (fails if missing) | Launches Groundplex container |

### 2. `robot-run-tests-no-gp` - Without Groundplex Launch

**Use this when:** Groundplex is already running, or tests don't need Groundplex.

```bash
make robot-run-tests-no-gp TAGS="your_tags" PROJECT_SPACE_SETUP=True|False
```

**Execution Flow:**
```
Phase 1: Project Space Setup
        ↓
Phase 2: SKIPPED (No Groundplex)
        ↓
Phase 2.1: Set Permissions (Travis CI)
        ↓
Phase 3: Run Tests
```

**Behavior with PROJECT_SPACE_SETUP:**

| Setting | Phase 1 Behavior | Groundplex |
|---------|------------------|------------|
| `True` | Deletes existing project space, creates new one (NO Snaplex) | Not launched |
| `False` (default) | Verifies project space exists | Not launched |

### 3. `robot-run-tests` - Base Target (Direct Execution)

**Use this when:** You need fine-grained control without any environment setup.

```bash
make robot-run-tests TAGS="your_tags" PROJECT_SPACE_SETUP=True|False
```

**Note:** This is the base target that the other two call internally. It only executes tests without project space or Groundplex management.

---

## Comparison Table

| Feature | robot-run-all-tests | robot-run-tests-no-gp |
|---------|---------------------|----------------------|
| Creates Project Space | Yes (when `PROJECT_SPACE_SETUP=True`) | Yes (when `PROJECT_SPACE_SETUP=True`) |
| Creates Snaplex/Plex | Yes (when `PROJECT_SPACE_SETUP=True`) | **No - Never** |
| Launches Groundplex | **Yes - Always** | **No - Never** |
| Auto-retry on Active Nodes | Yes (stops GP, waits 60s, retries) | No (only logs warning) |
| Verifies Project Space | Yes (when `PROJECT_SPACE_SETUP=False`) | Yes (when `PROJECT_SPACE_SETUP=False`) |
| Execution Time | Longer (includes GP startup) | Shorter (skips GP) |

---

## When to Use Which Target

| Scenario | Recommended Command |
|----------|---------------------|
| First time setup / Fresh environment | `make robot-run-all-tests TAGS="..." PROJECT_SPACE_SETUP=True` |
| CI/CD pipeline - full workflow | `make robot-run-all-tests TAGS="..." PROJECT_SPACE_SETUP=True` |
| Running tests after initial setup | `make robot-run-all-tests TAGS="..."` |
| Groundplex already running externally | `make robot-run-tests-no-gp TAGS="..."` |
| Tests don't need Groundplex | `make robot-run-tests-no-gp TAGS="..."` |
| Quick test iteration (GP already up) | `make robot-run-tests-no-gp TAGS="..."` |
| Create project space only (no plex) | `make robot-run-tests-no-gp TAGS="..." PROJECT_SPACE_SETUP=True` |
| Reset project space with new plex | `make robot-run-all-tests TAGS="..." PROJECT_SPACE_SETUP=True` |

---

## Understanding Robot Framework Tags

Tags are labels attached to test cases that allow you to selectively run tests.

### How Tags Work
```robotframework
*** Test Cases ***
Create Triggered Task
    [Documentation]    Creates a triggered task for pipeline execution
    [Tags]    snowflake_demo    task_creation    smoke
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${PIPELINES_LOCATION_PATH}    ${pipeline_name}    ${task_name}
```

### Using Tags with Make Commands
```bash
# Run only tests with 'snowflake_demo' tag
make robot-run-all-tests TAGS="snowflake_demo"

# Run tests with 'smoke' tag
make robot-run-all-tests TAGS="smoke"

# Run tests with multiple tags (OR logic - runs if ANY tag matches)
make robot-run-all-tests TAGS="snowflake_demo OR postgres_demo"

# Run tests with multiple tags (AND logic - runs only if ALL tags match)
make robot-run-all-tests TAGS="snowflake_demo AND task_creation"

# Exclude tests with specific tag
make robot-run-all-tests TAGS="NOT cleanup"
```

### Common Tag Categories

| Tag Type | Examples | Purpose |
|----------|----------|---------|
| Feature Tags | `snowflake_demo`, `postgres_demo`, `oracle` | Tests for specific features/databases |
| Action Tags | `task_creation`, `task_execution`, `account` | Categorize by operation type |
| Priority Tags | `smoke`, `regression`, `critical` | Test importance/frequency |
| Setup Tags | `setup`, `cleanup`, `teardown`, `createplex` | Setup and cleanup tests |
| Verification Tags | `verify_project_space_exists` | Environment state verification |

### Special Framework Tags

| Tag | Used By | Purpose |
|-----|---------|---------|
| `createplex` | `robot-run-all-tests` | Creates project space and Snaplex when `PROJECT_SPACE_SETUP=True` |
| `verify_project_space_exists` | Both targets | Verifies or creates project space |

---

## Available Test Tags by System

| Tag | Description | Required Service |
|-----|-------------|------------------|
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

---

## Step-by-Step Examples

### Example 1: Running Snowflake Tests (First Time)
```bash
# 1. Start required services
make start-services

# 2. Run tests with full setup
make robot-run-all-tests TAGS="snowflake_demo" PROJECT_SPACE_SETUP=True

# 3. View results
open test/robot_output/report-*.html
```

### Example 2: Running Oracle Tests
```bash
# 1. Start Oracle database
make oracle-start

# 2. Wait for Oracle to be ready (check logs)
make oracle-logs

# 3. Load test data (if needed)
make oracle-load-data

# 4. Run Oracle tests
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True

# 5. View results
open test/robot_output/report-*.html
```

### Example 3: Running Kafka Tests
```bash
# 1. Start Kafka cluster
make kafka-start

# 2. Create test topics
make kafka-create-topics

# 3. Run Kafka tests
make robot-run-all-tests TAGS="kafka" PROJECT_SPACE_SETUP=True
```

### Example 4: Running Multiple System Tests
```bash
# Start required services
make oracle-start
make postgres-start

# Run tests for both (OR logic)
make robot-run-all-tests TAGS="oracle OR postgres" PROJECT_SPACE_SETUP=True
```

### Example 5: Quick Test Iteration (After Initial Setup)
```bash
# Groundplex is already running, just re-run tests
make robot-run-tests-no-gp TAGS="snowflake_demo"
```

---

## Pre-requisites Checklist

Before running tests, ensure:

### 1. Environment Configuration
```bash
# Verify .env file exists and is configured
make check-env

# Or manually check key variables
cat .env | grep -E "^(URL|ORG_|PROJECT_)"
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

---

## Test Results

### Location
```
test/robot_output/
├── output-YYYYMMDD-HHMMSS.xml   # Raw results (for CI/CD)
├── log-YYYYMMDD-HHMMSS.html     # Detailed execution log
└── report-YYYYMMDD-HHMMSS.html  # Summary report (open this)
```

### Viewing Results
```bash
# Open the latest report (macOS)
open test/robot_output/report-*.html

# Find the latest report
ls -lt test/robot_output/report-*.html | head -1
```

### Sharing Results
```bash
# Send to Slack
make slack-notify

# Upload to S3
make upload-test-results
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Environment variable not found" | Missing `.env` file or variables | Run `make check-env` |
| "Connection refused" to database | Service not running | Run `make <db>-start` and check `make <db>-status` |
| "Groundplex not available" | Groundplex not started | Use `robot-run-all-tests` or start manually with `make launch-groundplex` |
| "Project space not found" | First run without setup | Add `PROJECT_SPACE_SETUP=True` |
| "Active Snaplex nodes" error | Old Groundplex still registered | `robot-run-all-tests` auto-retries; for `no-gp` run `make stop-groundplex` manually |
| Tests hang or timeout | Service health issues | Check `make status` and container logs |

### Debug Steps

1. **Check Test Logs:**
   ```bash
   open test/robot_output/log-*.html
   ```

2. **Check Container Logs:**
   ```bash
   make logs-tools        # Test container logs
   make oracle-logs       # Database logs (replace with your system)
   ```

3. **Verify Environment:**
   ```bash
   make check-env
   make status
   ```

4. **Re-run with Fresh Setup:**
   ```bash
   make stop-groundplex
   make robot-run-all-tests TAGS="..." PROJECT_SPACE_SETUP=True
   ```

---

## Quick Reference Commands

```bash
# Full setup with new project space and plex
make robot-run-all-tests TAGS="snowflake_demo" PROJECT_SPACE_SETUP=True

# Run tests using existing project space (launch GP)
make robot-run-all-tests TAGS="snowflake_demo"

# Run tests when GP is already running
make robot-run-tests-no-gp TAGS="snowflake_demo"

# Create project space only (no plex, no GP launch)
make robot-run-tests-no-gp TAGS="oracle" PROJECT_SPACE_SETUP=True

# Check environment
make check-env

# View running containers
make status

# Stop Groundplex
make stop-groundplex

# View test results
open test/robot_output/report-*.html
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         User Commands                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌───────────────────────┐       ┌───────────────────────┐            │
│   │  robot-run-all-tests  │       │  robot-run-tests-no-gp │            │
│   │  (Full Workflow)      │       │  (No GP Workflow)      │            │
│   └───────────┬───────────┘       └───────────┬───────────┘            │
│               │                               │                         │
│               │   Phase 1: Project Space      │                         │
│               │   Phase 2: Launch GP          │   Phase 2: SKIPPED      │
│               │   Phase 2.1: Permissions      │   Phase 2.1: Permissions│
│               │   Phase 3: Run Tests          │   Phase 3: Run Tests    │
│               │                               │                         │
│               └───────────────┬───────────────┘                         │
│                               │                                         │
│                               ▼                                         │
│               ┌───────────────────────────────┐                         │
│               │       robot-run-tests         │                         │
│               │       (Base Target)           │                         │
│               │                               │                         │
│               │  - Executes Robot Framework   │                         │
│               │  - Inside Docker container    │                         │
│               │  - With specified TAGS        │                         │
│               └───────────────────────────────┘                         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
