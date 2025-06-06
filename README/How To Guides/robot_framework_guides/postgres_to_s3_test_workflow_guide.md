# PostgreSQL to S3 Pipeline Test Workflow Guide
*Comprehensive Test Execution Flow for postgres_to_s3.robot*

## Overview

The **postgres_to_s3.robot** test suite validates a complete data integration pipeline that extracts employee data from PostgreSQL and exports it to S3-compatible storage (MinIO). This test demonstrates end-to-end data flow validation with comprehensive assertions at every step.

## Table of Contents

1. [Test Architecture Overview](#test-architecture-overview)
2. [Data Flow Diagram](#data-flow-diagram)
3. [Test Execution Phases](#test-execution-phases)
4. [Detailed Workflow Steps](#detailed-workflow-steps)
5. [Assertion Strategy](#assertion-strategy)
6. [File Structure and Data](#file-structure-and-data)
7. [Running the Tests](#running-the-tests)
8. [Troubleshooting Guide](#troubleshooting-guide)

## Test Architecture Overview

### 🎯 Testing Objective
Validate complete data pipeline integrity from PostgreSQL database to S3 storage, ensuring:
- **Data Integrity**: No corruption during transfer
- **Format Preservation**: CSV and JSON structures maintained
- **Complete Transfer**: All rows successfully exported
- **File Accessibility**: Generated files can be downloaded and validated

### 🏗️ Infrastructure Components

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      PostgreSQL to S3 Test Architecture                        │
│                                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐ │
│  │   Robot     │    │ SnapLogic   │    │ PostgreSQL  │    │ MinIO S3 Storage│ │
│  │ Framework   │◄──►│ Groundplex  │◄──►│ Database    │    │   (Mock AWS)    │ │
│  │   Tests     │    │             │    │             │    │                 │ │
│  └─────────────┘    └─────────────┘    │ employees   │◄──►│  demo-bucket    │ │
│                                         │ employees2  │    │                 │ │
│  Test Data Flow:                        │             │    │ employees.csv   │ │
│  CSV/JSON Files → Database → Pipeline → S3 Bucket     │    │ employees.json  │ │
│                                         └─────────────┘    └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 📊 Service Dependencies

| Service | Purpose | Container | Port |
|---------|---------|-----------|------|
| **PostgreSQL** | Source database | `postgres-db` | 5432 |
| **MinIO** | S3-compatible storage | `snaplogic-minio` | 9000/9001 |
| **SnapLogic Groundplex** | Pipeline runtime | `snaplogic-groundplex` | 8081/8090 |
| **Robot Framework** | Test execution | `tools` | N/A |

## Data Flow Diagram

```
📁 Test Data Sources                    🗄️ PostgreSQL Database                 ☁️ S3 Storage (MinIO)
────────────────────                    ──────────────────────                 ─────────────────────
                                        
employees.csv (2 rows)                 employees table:                       demo-bucket:
├─ Alice, Manager, 75000    ────────►   ├─ Alice, Manager, 75000  ────────►   ├─ employees.csv
└─ Bob, Developer, 65000                └─ Bob, Developer, 65000              │  (exported via pipeline)
                                                                              │
employees.json (2 rows)                employees2 table:                     └─ employees.json
├─ Charlie, Designer, 60000 ────────►   ├─ Charlie, Designer, 60000             (exported via pipeline)
└─ Diana, QA, 55000                     └─ Diana, QA, 55000
                                        
                                        Total: 4 rows across 2 tables
                                        
                                                      ↓ SnapLogic Pipeline
                                                      
📥 Downloaded Results                   📋 Validation                         
──────────────────────                 ──────────────                         
                                        
actual_output/employees.csv             expected_output/employees.csv          
actual_output/employees.json            expected_output/employees.json         
                                        
                    ↓ File Comparison                   ↓
                    
            ✅ Data Integrity Validation Complete
```

## Test Execution Phases

### Phase 1: Environment Setup 🛠️
**Objective**: Prepare test infrastructure and establish connections

**Actions**:
- Initialize unique test ID for pipeline isolation
- Verify SnapLogic Groundplex is running and accessible
- Establish PostgreSQL database connection
- Validate all required services are healthy

**Key Assertions**:
- Groundplex status shows "running"
- Database connection successful
- All containers are healthy

### Phase 2: Account Configuration 🔐
**Objective**: Create SnapLogic accounts for external system access

**Actions**:
- Create PostgreSQL account with database credentials
- Create S3 account with MinIO endpoint configuration
- Validate account configurations in SnapLogic

**Key Assertions**:
- Account creation API returns HTTP 200/201
- PostgreSQL account configuration accepted
- S3/MinIO account configuration accepted

### Phase 3: Database Preparation 📋
**Objective**: Set up database schema and load test data

**Actions**:
- Create `employees` table (for CSV data)
- Create `employees2` table (for JSON data)
- Load 2 rows from `employees.csv` into `employees` table
- Load 2 rows from `employees.json` into `employees2` table

**Key Assertions**:
- SQL table creation executes successfully
- CSV row count matches database inserted count
- JSON record count matches database inserted count
- Total database rows = 4 (2 CSV + 2 JSON)

### Phase 4: Pipeline Deployment 🚀
**Objective**: Deploy and configure SnapLogic pipelines

**Actions**:
- Import PostgreSQL to S3 CSV pipeline (`postgres_to_s3_csv.slp`)
- Import PostgreSQL to S3 JSON pipeline (`postgres_to_s3_json.slp`)
- Create triggered tasks for both pipelines
- Configure task parameters (bucket names, output files)

**Key Assertions**:
- Pipeline files exist and are readable
- Pipeline import API calls succeed
- Unique pipeline IDs generated
- Task creation API calls succeed

### Phase 5: Pipeline Execution ⚡
**Objective**: Execute data export pipelines

**Actions**:
- Run CSV pipeline task (exports `employees` table to `employees.csv`)
- Run JSON pipeline task (exports `employees2` table to `employees.json`)
- Monitor task execution status
- Verify files created in S3 bucket

**Key Assertions**:
- Task execution API calls succeed
- Pipelines run without errors
- Files appear in S3 `demo-bucket`
- Task completes within expected timeframe

### Phase 6: Result Validation ✅
**Objective**: Verify data integrity and completeness

**Actions**:
- Download `employees.csv` from S3 to local `actual_output` directory
- Download `employees.json` from S3 to local `actual_output` directory
- Compare downloaded files against expected output files
- Validate file structures, row counts, and data content

**Key Assertions**:
- Files exist in S3 and can be downloaded
- Downloaded file sizes > 0 bytes
- CSV structures are identical (headers, rows, values)
- JSON structures are identical (schema, arrays, objects)
- No data loss or corruption detected

## Detailed Workflow Steps

### Step 1: Initialize Test Environment

```robot
Initialize Test Environment
    ${unique_id}=    Get Unique Id
    Set Suite Variable    ${unique_id}    ${unique_id}
    Wait Until Plex Status Is Up    /${ORG_NAME}/${GROUNDPLEX_LOCATION_PATH}/${GROUNDPLEX_NAME}
    Connect to Postgres Database    ${POSTGRES_DBNAME}    ${POSTGRES_DBUSER}    ${POSTGRES_DBPASS}    ${POSTGRES_HOST}
```

**Purpose**: Sets up test isolation and service connectivity
**Unique ID**: Ensures pipeline names don't conflict between test runs
**Connection Validation**: Confirms PostgreSQL is accessible

### Step 2: Create SnapLogic Accounts

```robot
Create Account
    [Template]    Create Account From Template
    ${account_payload_path}/acc_postgres.json
    ${account_payload_path}/acc_s3.json
```

**PostgreSQL Account Configuration**:
```json
{
  "class_id": "com.snaplogic.account.postgresql",
  "settings": {
    "hostname": "postgres-db",
    "port": 5432,
    "database": "testdb",
    "username": "postgres",
    "password": "postgres"
  }
}
```

**S3 Account Configuration**:
```json
{
  "class_id": "com.snaplogic.account.s3",
  "settings": {
    "service_endpoint": "http://snaplogic-minio:9000",
    "access_key_id": "minioadmin",
    "secret_access_key": "minioadmin",
    "region": "us-east-1",
    "enable_path_style_access": true
  }
}
```

### Step 3: Database Schema Setup

```robot
Create table for DB Operations
    [Template]    Execute SQL String
    ${CREATE_TABLE_EMPLOYEES_PG}
    ${CREATE_TABLE_EMPLOYEES2_PG}
```

**employees table**:
```sql
CREATE TABLE IF NOT EXISTS employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    role VARCHAR(50),
    salary INTEGER
);
```

**employees2 table**:
```sql
CREATE TABLE IF NOT EXISTS employees2 (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    role VARCHAR(50),
    salary INTEGER
);
```

### Step 4: Test Data Loading

**CSV Data Loading**:
```robot
Load CSV Data To PostgreSQL
    [Template]    Load CSV Data Template
    ${CSV_DATA_TO_DB}    employees    ${TRUE}
```

**Source File**: `employees.csv`
```csv
name,role,salary
Alice,Manager,75000
Bob,Developer,65000
```

**JSON Data Loading**:
```robot
Load JSON Data To PostgreSQL
    [Template]    Load JSON Data Template
    ${JSON_DATA_TO_DB}    employees2    ${TRUE}
```

**Source File**: `employees.json`
```json
[
  {"name": "Charlie", "role": "Designer", "salary": 60000},
  {"name": "Diana", "role": "QA", "salary": 55000}
]
```

### Step 5: Pipeline Import and Task Creation

```robot
Import Pipelines
    [Template]    Import Pipelines From Template
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name_csv}    ${pipeline_name_csv_slp}
    ${unique_id}    ${pipeline_file_path}    ${pipeline_name_json}    ${pipeline_name_json_slp}
```

**Pipeline Files**:
- `postgres_to_s3_csv.slp`: Exports `employees` table to CSV format
- `postgres_to_s3_json.slp`: Exports `employees2` table to JSON format

```robot
Create Triggered_task
    [Template]    Create Triggered Task From Template
    ${unique_id}    ${project_path}    ${pipeline_name_csv}    ${task_csv}
    ${unique_id}    ${project_path}    ${pipeline_name_json}    ${task_json}
```

### Step 6: Pipeline Execution

```robot
Execute Triggered Task
    [Template]    Run Triggered Task With Parameters From Template
    ${unique_id}    ${project_path}    ${pipeline_name_csv}    ${task_csv}    bucket=demo-bucket    actual_output_file=employees.csv
    ${unique_id}    ${project_path}    ${pipeline_name_json}    ${task_json}    bucket=demo-bucket    actual_output_file=employees.json
```

**Task Parameters**:
- `bucket=demo-bucket`: Target S3 bucket
- `actual_output_file=employees.csv/json`: Output file names

### Step 7: Result Download and Validation

```robot
Download actual Output data from S3
    [Template]    Download And Validate File
    ${ACTUAL_DATA_DIR}    ${DEMO_BUCKET}    employees.csv
    ${ACTUAL_DATA_DIR}    ${DEMO_BUCKET}    employees.json
```

**File Comparison**:
```robot
Compare Actual vs Expected CSV Output
    [Template]    Compare CSV Files Template
    ${ACTUAL_DATA_DIR}/employees.csv    ${EXPECTED_OUTPUT_DIR}/employees.csv    ${FALSE}    ${TRUE}    IDENTICAL

Compare Actual vs Expected JSON Output
    [Template]    Compare JSON Files Template
    ${ACTUAL_DATA_DIR}/employees.json    ${EXPECTED_OUTPUT_DIR}/employees.json    ${FALSE}    ${TRUE}    IDENTICAL
```

## Assertion Strategy

### 🔍 Comprehensive Validation Points

#### **Account Creation Assertions**
- ✅ API response codes (200/201)
- ✅ Account payload validation
- ✅ Configuration acceptance

#### **Database Operation Assertions**
- ✅ SQL execution success
- ✅ Table creation validation
- ✅ Row count verification
- ✅ Data insertion confirmation

#### **Pipeline Execution Assertions**
- ✅ Import success
- ✅ Task creation
- ✅ Execution completion
- ✅ Error-free processing

#### **Data Integrity Assertions**
- ✅ File existence in S3
- ✅ Download capability
- ✅ Non-zero file sizes
- ✅ Structure preservation
- ✅ Content accuracy
- ✅ No data loss/corruption

### 📊 Expected vs Actual Validation

| Validation Type | Source | Target | Assertion |
|-----------------|--------|--------|-----------|
| **Row Count** | CSV file (2 rows) | Database (2 rows) | Exact match |
| **Row Count** | JSON file (2 rows) | Database (2 rows) | Exact match |
| **Data Content** | Database (4 total rows) | S3 files | Complete transfer |
| **File Structure** | Expected CSV/JSON | Downloaded CSV/JSON | Identical format |
| **Field Values** | Original data | Exported data | No corruption |

## File Structure and Data

### 📁 Test Directory Structure

```
test/suite/pipeline_tests/postgres_to_s3.robot
├── test_data/
│   ├── actual_expected_data/
│   │   ├── input_data/
│   │   │   ├── employees.csv        # Source CSV (2 rows)
│   │   │   └── employees.json       # Source JSON (2 rows)
│   │   ├── expected_output/
│   │   │   ├── employees.csv        # Expected CSV output
│   │   │   └── employees.json       # Expected JSON output
│   │   └── actual_output/           # Downloaded S3 files (generated)
│   │       ├── employees.csv        # Actual pipeline output
│   │       └── employees.json       # Actual pipeline output
│   └── queries/
│       └── postgres_queries.resource  # SQL statements
├── accounts_payload/
│   ├── acc_postgres.json            # PostgreSQL account config
│   └── acc_s3.json                  # S3/MinIO account config
└── src/pipelines/
    ├── postgres_to_s3_csv.slp       # CSV export pipeline
    └── postgres_to_s3_json.slp      # JSON export pipeline
```

### 📋 Data Samples

**Input CSV** (`employees.csv`):
```csv
name,role,salary
Alice,Manager,75000
Bob,Developer,65000
```

**Input JSON** (`employees.json`):
```json
[
  {"name": "Charlie", "role": "Designer", "salary": 60000},
  {"name": "Diana", "role": "QA", "salary": 55000}
]
```

**Expected Output** matches input format but comes from database export

## Running the Tests

### 🚀 Execute PostgreSQL to S3 Tests

#### **Full Test Suite with Setup**
```bash
# Complete infrastructure setup + test execution
make robot-run-all-tests TAGS="postgres_s3" PROJECT_SPACE_SETUP=True
```

#### **Use Existing Infrastructure**
```bash
# Run tests with existing project space
make robot-run-all-tests TAGS="postgres_s3"
```

#### **Specific Test Categories**
```bash
# Account creation only
make robot-run-tests TAGS="create_account"

# Data loading tests only
make robot-run-tests TAGS="load_data"

# Pipeline execution only
make robot-run-tests TAGS="postgres_s3 AND create_triggered_task"

# Validation tests only
make robot-run-tests TAGS="comparison"
```

#### **Service-Specific Testing**
```bash
# PostgreSQL + MinIO focused testing
make robot-run-all-tests TAGS="postgres_s3" COMPOSE_PROFILES="tools,postgres-dev,minio"

# Include CSV and JSON specific tests
make robot-run-tests TAGS="csv5 OR json5"
```

### 🔧 Prerequisites

**Required Services**:
```bash
# Ensure all services are running
docker compose --profile postgres-dev --profile minio --profile gp up -d

# Check service health
docker compose ps
make groundplex-status
```

**Environment Variables** (in `.env`):
```bash
# PostgreSQL Configuration
POSTGRES_HOST=postgres-db
POSTGRES_DBNAME=testdb
POSTGRES_DBUSER=postgres
POSTGRES_DBPASS=postgres

# MinIO Configuration
MINIO_ENDPOINT=http://snaplogic-minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin

# SnapLogic Configuration
ORG_NAME=your-org
PROJECT_SPACE=/your-org/projects
PROJECT_NAME=TestAutomation
GROUNDPLEX_NAME=your-groundplex
```

## Troubleshooting Guide

### 🔍 Common Issues and Solutions

#### **1. Database Connection Failures**

**Symptoms**:
```
DatabaseError: could not connect to server
```

**Solutions**:
```bash
# Check PostgreSQL container status
docker compose ps postgres-db

# Verify PostgreSQL health
docker compose exec postgres-db pg_isready -U postgres

# Check connection parameters
docker compose exec postgres-db psql -U postgres -d testdb -c "SELECT 1;"
```

#### **2. MinIO Access Issues**

**Symptoms**:
```
S3 bucket not accessible
File download failures
```

**Solutions**:
```bash
# Check MinIO container status
docker compose ps snaplogic-minio

# Verify MinIO health
curl http://localhost:9000/minio/health/live

# Test MinIO connectivity
docker compose exec snaplogic-minio mc alias set local http://localhost:9000 minioadmin minioadmin
docker compose exec snaplogic-minio mc ls local/demo-bucket
```

#### **3. Pipeline Execution Errors**

**Symptoms**:
```
Pipeline task execution failed
Account not found errors
```

**Solutions**:
```bash
# Check Groundplex status
make groundplex-status

# Verify accounts exist
# Check SnapLogic Manager UI for account creation

# Review pipeline import
# Verify .slp files exist in src/pipelines/
ls -la src/pipelines/postgres_to_s3_*.slp
```

#### **4. File Comparison Failures**

**Symptoms**:
```
Files do not match
IDENTICAL assertion failed
```

**Investigation Steps**:
```bash
# Check actual output files exist
ls -la test/suite/test_data/actual_expected_data/actual_output/

# Compare file sizes
wc -l test/suite/test_data/actual_expected_data/actual_output/employees.csv
wc -l test/suite/test_data/actual_expected_data/expected_output/employees.csv

# Manual file comparison
diff test/suite/test_data/actual_expected_data/actual_output/employees.csv \
     test/suite/test_data/actual_expected_data/expected_output/employees.csv
```

### 🛠️ Debug Commands

```bash
# Monitor test execution
docker compose logs -f tools

# Check all service logs
docker compose logs postgres-db
docker compose logs snaplogic-minio
docker compose logs snaplogic-groundplex

# Database debugging
docker compose exec postgres-db psql -U postgres -d testdb -c "SELECT * FROM employees;"
docker compose exec postgres-db psql -U postgres -d testdb -c "SELECT COUNT(*) FROM employees;"

# MinIO debugging
docker compose exec snaplogic-minio mc ls local/demo-bucket
docker compose exec snaplogic-minio mc cat local/demo-bucket/employees.csv
```

### 📊 Test Output Analysis

**Successful Test Results**:
```
📋 Test Execution Summary:
✅ Account Creation: PASS (2/2 accounts created)
✅ Database Setup: PASS (2 tables created)
✅ Data Loading: PASS (4 rows inserted)
✅ Pipeline Import: PASS (2 pipelines imported)
✅ Task Creation: PASS (2 tasks created)
✅ Pipeline Execution: PASS (2 files exported)
✅ File Download: PASS (2 files downloaded)
✅ Data Validation: PASS (Files identical)

Total: 8/8 test phases completed successfully
```

**Key Performance Metrics**:
- **Setup Time**: ~30-60 seconds
- **Data Loading**: <5 seconds
- **Pipeline Execution**: 10-30 seconds
- **File Validation**: <5 seconds
- **Total Runtime**: 2-3 minutes

---

## 📚 Related Documentation

- **[Robot Framework Test Execution Flow](robot_framework_test_execution_flow.md)** - Understanding the overall test execution process
- **[SnapLogic Common Robot Library Guide](snaplogic_common_robot_library_guide.md)** - Available keywords and functions
- **[Docker Compose Guide](../infra_setup_guides/docker_compose_guide.md)** - Service orchestration and management
- **[PostgreSQL Setup Guide](../infra_setup_guides/postgresql_setup_guide.md)** - PostgreSQL service configuration
- **[MinIO Setup Guide](../infra_setup_guides/minio_setup_guide.md)** - S3-compatible storage setup

---

## 📚 Explore More Documentation

💡 **Need help finding other guides?** Check out our **[📖 Complete Documentation Reference](../../reference.md)** for a comprehensive overview of all available tutorials, how-to guides, and quick start paths. It's your one-stop navigation hub for the entire SnapLogic Test Framework documentation!

---

*This workflow guide provides comprehensive documentation for the postgres_to_s3.robot test suite, enabling teams to understand, execute, and troubleshoot the complete data pipeline validation process.*