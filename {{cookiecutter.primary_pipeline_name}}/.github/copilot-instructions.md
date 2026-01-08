# SnapLogic Robot Framework Test Project

## Project Overview

This is an automated testing framework for SnapLogic pipelines using Robot Framework. It provides end-to-end testing capabilities for data integration pipelines with support for multiple database systems, messaging platforms, and mock services.

### Purpose
- Automated testing of SnapLogic pipelines
- CI/CD integration via Travis CI
- Support for multiple data sources (Oracle, PostgreSQL, MySQL, SQL Server, Snowflake, etc.)
- Mock services for Salesforce, S3 (MinIO), and Email

## 5-Step Quick Start

### Step 1: Install Docker Desktop
Download and install Docker Desktop for your OS, start it, and verify with `docker --version`

### Step 2: Clone the Repository
```bash
git clone https://github.com/SnapLogic/snaplogic-robotframework-examples
```

### Step 3: Open Project
```bash
# Change to project directory
eval $(make change-dir)
# OR
cd {{cookiecutter.primary_pipeline_name}}
```

### Step 4: Configure Environment
```bash
# Copy environment template
cp .env.example .env
# Edit .env with your SnapLogic credentials
```

### Step 5: Build and Execute

**Case 1: Framework-Managed Groundplex (Recommended for first time)**
```bash
# Build Docker containers
make start-services

# Run tests with full setup (creates project space, launches Groundplex)
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True

# Subsequent runs (project space already exists)
make robot-run-all-tests TAGS="oracle"
```

**Case 2: Using Existing Groundplex**
```bash
# Build Docker containers
make start-services

# Run tests without Groundplex management
make robot-run-tests-no-gp TAGS="oracle" PROJECT_SPACE_SETUP=True

# Subsequent runs
make robot-run-tests-no-gp TAGS="oracle"
```

## Project Structure

```
{{cookiecutter.primary_pipeline_name}}/
├── .claude/                    # Claude Code configuration
│   └── commands/               # Slash commands for LLM assistance
├── .github/                    # GitHub Copilot configuration
│   └── copilot-instructions.md # This file
├── .env                        # Environment variables (secrets - DO NOT COMMIT)
├── .env.example                # Template for environment variables
├── docker-compose.yml          # Docker service definitions
├── Makefile                    # Primary interface for all operations
├── makefiles/                  # Modular Makefile includes
│   ├── common_services/        # Testing, Docker, Groundplex configs
│   ├── database_services/      # Oracle, PostgreSQL, MySQL, etc.
│   ├── messaging_services/     # Kafka, ActiveMQ
│   └── mock_services/          # MinIO, Salesforce mock, MailDev
├── src/
│   ├── pipelines/              # SnapLogic pipeline files (.slp) - UPLOAD YOUR PIPELINES HERE
│   └── generative_pipelines/   # SLIM-generated pipelines
├── test/
│   ├── suite/                  # Robot Framework test suites
│   │   ├── __init__.robot      # Suite setup (loads env, creates accounts)
│   │   ├── pipeline_tests/     # Tests organized by system type
│   │   └── test_data/          # Test data and account payloads
│   ├── resources/              # Shared Robot Framework resources
│   │   └── common/             # Common keywords and utilities
│   ├── libraries/              # Custom Python libraries
│   └── robot_output/           # Test execution results
├── env_files/                  # Account-specific environment files
│   ├── database_accounts/      # .env.oracle, .env.postgres, .env.mysql
│   ├── external_accounts/      # .env.snowflake
│   ├── messaging_service_accounts/  # .env.kafka, .env.jms
│   └── mock_service_accounts/  # .env.s3, .env.salesforce, .env.email
├── docker/                     # Docker configurations for services
└── docs/                       # Documentation
```

## Makefile Commands (Primary Interface)

**The Makefile is your main interface.** Use `make help` to see all available commands.

### Service Management

#### Starting Services
```bash
make start-services              # Start all services (databases, messaging, mocks)
make start-tools-service-only    # Start only the test tools container
```

#### Clean Start (After Updates)
```bash
make clean-start                 # Full rebuild after code updates
make clean-start-tools           # Rebuild only tools container
```

### Running Tests

#### With Framework-Managed Groundplex
```bash
# Full workflow: setup project space, launch Groundplex, run tests
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True

# Subsequent runs (reuse existing project space)
make robot-run-all-tests TAGS="oracle"

# Multiple tags (OR logic)
make robot-run-all-tests TAGS="oracle,postgres,snowflake"
```

#### Without Groundplex Management
```bash
# Use existing Groundplex (skip Groundplex creation)
make robot-run-tests-no-gp TAGS="oracle" PROJECT_SPACE_SETUP=True

# Subsequent runs
make robot-run-tests-no-gp TAGS="oracle"
```

#### Direct Test Execution (No Setup)
```bash
# Run tests directly (assumes environment is ready)
make robot-run-tests TAGS="oracle"
```

### PROJECT_SPACE_SETUP Parameter

| Value | Behavior |
|-------|----------|
| `True` | Deletes existing project space, creates new one, sets up Snaplex |
| `False` (default) | Verifies project space exists, fails if missing |

### Database Services
```bash
make oracle-start                # Start Oracle database
make oracle-stop                 # Stop Oracle
make oracle-status               # Check Oracle status
make oracle-logs                 # View Oracle logs
make oracle-load-data            # Load test data

# Same pattern for other databases:
make postgres-start / postgres-stop / postgres-status
make mysql-start / mysql-stop / mysql-status
make sqlserver-start / sqlserver-stop
make snowflake-mock-start / snowflake-mock-stop
make db2-start / db2-stop
make teradata-start / teradata-stop
```

### Messaging Services
```bash
make kafka-start                 # Start Kafka + UI
make kafka-stop                  # Stop Kafka
make kafka-create-topics         # Create test topics
make kafka-logs                  # View Kafka logs

make activemq-start              # Start ActiveMQ
make activemq-stop               # Stop ActiveMQ
```

### Mock Services
```bash
make minio-start                 # Start MinIO (S3 mock)
make minio-stop                  # Stop MinIO

make salesforce-mock-start       # Start Salesforce mock
make salesforce-mock-stop        # Stop Salesforce mock

make maildev-start               # Start email mock server
make maildev-stop                # Stop email mock
```

### Groundplex Management
```bash
make launch-groundplex           # Start SnapLogic Groundplex
make stop-groundplex             # Stop Groundplex gracefully (waits for deregistration)
make groundplex-status           # Check Groundplex status
make restart-groundplex          # Restart Groundplex
```

### Asset Management
```bash
make sl-export-assets            # Export assets from SnapLogic
make sl-import-assets            # Import assets to SnapLogic
make import-slim-generated-pipelines  # Import .slp pipeline files
```

### Status and Monitoring
```bash
make status                      # Show all running services
make show-running                # Display running containers
make check-env                   # Verify environment configuration
make docker-networks             # Show Docker network status
```

## Environment Configuration

### Main Environment File (.env)

```bash
# SnapLogic Connection
URL=https://elastic.snaplogic.com
ORG_ADMIN_USER=your_username
ORG_ADMIN_PASSWORD=your_password
ORG_NAME=your_org_name
PROJECT_SPACE=your_project_space
PROJECT_NAME=your_project_name

# Groundplex Configuration
GROUNDPLEX_NAME=your_groundplex_name

# Account Location
ACCOUNT_LOCATION_PATH=shared
```

### Account-Specific Environment Files

Located in `env_files/` directory:

```bash
# env_files/database_accounts/.env.oracle
ORACLE_ACCOUNT_PAYLOAD_FILE_NAME=acc_oracle.json
ORACLE_ACCOUNT_NAME=oracle_acct
ORACLE_HOSTNAME=oracle-db
ORACLE_PORT=1521
ORACLE_USERNAME=testuser
ORACLE_PASSWORD=testpass

# env_files/database_accounts/.env.snowflake_s3_keypair
SNOWFLAKE_ACCOUNT_PAYLOAD_KEY_PAIR_FILE_NAME=acc_snowflake_s3_keypair.json
SNOWFLAKE_KEYPAIR_ACCOUNT_NAME=snowflake_keypair_acct
SNOWFLAKE_KEYPAIR_HOSTNAME=your-account.snowflakecomputing.com
SNOWFLAKE_KEYPAIR_USERNAME=your_username
SNOWFLAKE_KEYPAIR_DATABASE=YOUR_DB
SNOWFLAKE_KEYPAIR_WAREHOUSE=YOUR_WH
```

### Environment Variable Precedence
1. Root `.env` file (HIGHEST - loaded last, overrides everything)
2. `env_files/` subdirectory files (loaded first)

## Variable Naming Convention

- **UPPERCASE**: Environment variables from `.env` files (e.g., `${ORG_NAME}`, `${SNOWFLAKE_HOSTNAME}`)
- **lowercase**: User-defined test variables (e.g., `${pipeline_name}`, `${task_name}`)

## Creating Account Test Cases

### Step-by-Step Workflow

1. **Identify the account type** you need based on your pipeline
2. **Check the environment file** in `env_files/` to understand available variables
3. **Update variable values** in the env file or override in root `.env`
4. **Create the Robot Framework test case** using the variables

### Supported Account Types

| Account Type | Env File | Payload File |
|--------------|----------|--------------|
| Oracle | `env_files/database_accounts/.env.oracle` | `acc_oracle.json` |
| PostgreSQL | `env_files/database_accounts/.env.postgres` | `acc_postgres.json` |
| MySQL | `env_files/database_accounts/.env.mysql` | `acc_mysql.json` |
| SQL Server | `env_files/database_accounts/.env.sqlserver` | `acc_sqlserver.json` |
| Snowflake | `env_files/database_accounts/.env.snowflake` | `acc_snowflake_s3_db.json` |
| Snowflake (Key Pair) | `env_files/database_accounts/.env.snowflake_s3_keypair` | `acc_snowflake_s3_keypair.json` |
| Kafka | `env_files/messaging_service_accounts/.env.kafka` | `acc_kafka.json` |
| JMS | `env_files/messaging_service_accounts/.env.jms` | `acc_jms.json` |
| S3 / MinIO | `env_files/mock_service_accounts/.env.s3` | `acc_s3.json` |
| Email | `env_files/mock_service_accounts/.env.email` | `acc_email.json` |
| Salesforce | `env_files/mock_service_accounts/.env.salesforce` | `acc_salesforce.json` |

### Example: Creating an Account Test Case

```robotframework
*** Test Cases ***
Create Oracle Account
    [Documentation]    Creates an Oracle database account in SnapLogic.
    [Tags]    oracle    account_setup
    [Template]    Create Account From Template
    ${ACCOUNT_LOCATION_PATH}    ${ORACLE_ACCOUNT_PAYLOAD_FILE_NAME}    ${ORACLE_ACCOUNT_NAME}    overwrite_if_exists=${TRUE}
```

## Common Test Tags

| Tag | Description | Required Service |
|-----|-------------|------------------|
| `oracle` | Oracle database tests | `make oracle-start` |
| `postgres` | PostgreSQL tests | `make postgres-start` |
| `mysql` | MySQL tests | `make mysql-start` |
| `sqlserver` | SQL Server tests | `make sqlserver-start` |
| `snowflake` | Snowflake tests | `make snowflake-mock-start` |
| `kafka` | Kafka messaging tests | `make kafka-start` |
| `jms` | ActiveMQ/JMS tests | `make activemq-start` |
| `minio` / `s3` | S3/MinIO tests | `make minio-start` |
| `salesforce` | Salesforce mock tests | `make salesforce-mock-start` |
| `email` | Email tests | `make maildev-start` |

## Troubleshooting

### Common Issues

**"cannot be deleted while it contains active nodes"**
- Automatic recovery in `robot-run-all-tests`: stops Groundplex, waits 60s, retries

**"Project space 'X' is not created"**
- Run with `PROJECT_SPACE_SETUP=True` to create environment

**Environment variables not loading**
- Check `.env` file format (no spaces around `=`)
- Verify file exists and has correct permissions

**Connection refused to database**
- Start the required service: `make oracle-start`
- Wait for initialization (Oracle takes 5-10 min first time)
- Check logs: `make oracle-logs`

### Debug Commands
```bash
make status                      # Check all services
make check-env                   # Verify environment
make docker-networks             # Check network connectivity
docker logs snaplogic-groundplex # View Groundplex logs
```

## Port Reference

| Service | Port |
|---------|------|
| Oracle | 1521 |
| PostgreSQL | 5432 |
| MySQL | 3306 |
| SQL Server | 1433 |
| Kafka | 9092 |
| Kafka UI | 8080 |
| ActiveMQ Console | 8161 |
| MinIO API | 9000 |
| MinIO Console | 9001 |
| Salesforce Mock | 8089 |
| MailDev Web | 1080 |
| MailDev SMTP | 1025 |

## Best Practices

1. **Use Makefile commands** - They handle Docker Compose complexity
2. **Parameterize pipelines** - Use pipeline parameters for accounts, paths, schemas
3. **Tag tests appropriately** - Enables selective test execution
4. **Use environment files** - Keep secrets out of code
5. **Check status before running** - `make status` to verify services
6. **Use meaningful variable names** - `${snowflake_account_ref}` not `${acc}`

## Robot Framework Test Patterns

### Basic Test Template
```robotframework
*** Settings ***
Documentation    Description of what this test suite covers
Resource         ../../resources/common/general.resource
Library          Collections

*** Variables ***
${PIPELINE_NAME}       my_pipeline

*** Test Cases ***
Test Pipeline Executes Successfully
    [Documentation]    Verify the pipeline completes without errors
    [Tags]    oracle    smoke
    # Given
    ${unique_id}=    Get Unique Id
    # When
    Upload Pipeline    ${PIPELINE_NAME}_${unique_id}
    Execute Pipeline    ${PIPELINE_NAME}_${unique_id}
    # Then
    ${status}=    Get Pipeline Status    ${PIPELINE_NAME}_${unique_id}
    Should Be Equal    ${status}    Completed
```

### Data-Driven Test Template
```robotframework
*** Test Cases ***
Test Multiple Data Scenarios
    [Template]    Execute And Verify Pipeline
    # input_file    expected_count    expected_status
    small_data.csv     100    Completed
    medium_data.csv    1000   Completed
    empty_data.csv     0      Completed

*** Keywords ***
Execute And Verify Pipeline
    [Arguments]    ${input_file}    ${expected_count}    ${expected_status}
    Load Test Data    ${input_file}
    ${status}=    Execute Pipeline    data_processor
    Should Be Equal    ${status}    ${expected_status}
```
