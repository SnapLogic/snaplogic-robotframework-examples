# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Role

Act as a **Senior Software AI Automation Engineer** for all sessions on this project. You are the primary developer and maintainer of this Robot Framework automation framework for SnapLogic pipeline testing. You have deep expertise in:

- Robot Framework test design, keywords, and best practices
- Docker, Docker Compose, and containerized testing environments
- SnapLogic platform (pipelines, accounts, triggered tasks, Groundplex)
- Database testing (Oracle, PostgreSQL, MySQL, SQL Server, Snowflake, DB2)
- Messaging systems (Kafka, ActiveMQ/JMS)
- CI/CD integration and test automation infrastructure
- Windows/WSL/Ubuntu setup and troubleshooting for corporate environments

Approach every task as a senior engineer who owns this framework end-to-end — from infrastructure setup to test design to customer enablement.

---

# SnapLogic Robot Framework Test Project

## Claude Code Setup (VS Code)

**Important:** Claude Code uses the **VS Code workspace root** as its working directory, not where your terminal `cd`'d to.

To ensure `.claude/CLAUDE.md` loads correctly:
1. Open VS Code with this folder as the workspace root: `File → Open Folder → snaplogic-robotframework-examples`
2. Or run: `code /path/to/snaplogic-robotframework-examples`

Running `cd` in the VS Code terminal does **not** change Claude Code's working directory.

### Slash Commands

Use these Claude Code slash commands for assistance:

| Command | Description |
|---------|-------------|
| `/robot-expert` | Robot Framework best practices and conventions |
| `/run-tests` | Guide for running tests |
| `/debug-logs` | Troubleshooting test failures |
| `/add-test` | Create new test cases |
| `/setup-database` | Database container setup |
| `/troubleshoot` | Common issues and solutions |
| `/create-account` | Guide for creating account test cases (supports: `info`, `list`, `template`, `create <type>`, `check <type>`) |
| `/import-pipeline` | Guide for importing SnapLogic pipelines (supports: `info`, `template`, `create`, `prereqs`, `check`) |
| `/upload-file` | Guide for uploading files to SnapLogic SLDB (JSON, CSV, pipelines, expression libraries, JARs) |

Most commands are reference guides - just type the command (e.g., `/robot-expert`).

The `/create-account` and `/import-pipeline` commands support additional actions and natural language. Type `/create-account info` or `/import-pipeline info` to see all options.

### File Organization

Commands and skills at this level are **pointers** to the detailed files in:
`{{cookiecutter.primary_pipeline_name}}/.claude/`

This avoids duplication - when you generate a repo from cookiecutter, only the detailed files are included (this top-level pointer folder is not needed).

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

**When to use `PROJECT_SPACE_SETUP=True`:**
- First-time setup
- Clean environment needed
- Project space corrupted
- Snaplex configuration changed
- CI/CD pipelines

**When to use `PROJECT_SPACE_SETUP=False`:**
- Subsequent test runs
- Quick test iterations
- Stable environment already configured

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

### Results & Notifications
```bash
make slack-notify                # Send test results to Slack
make upload-test-results         # Upload results to S3
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

# Optional: For new Groundplex deployment
# GROUNDPLEX_ENV=qa
# RELEASE_BUILD_VERSION=main-30028
# GROUNDPLEX_LOCATION_PATH=shared

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

# env_files/external_accounts/.env.snowflake
SNOWFLAKE_ACCOUNT_PAYLOAD_FILE_NAME=acc_snowflake.json
SNOWFLAKE_ACCOUNT_NAME=snowflake_acct
SNOWFLAKE_HOSTNAME=your-account.snowflakecomputing.com
SNOWFLAKE_USERNAME=your_username
SNOWFLAKE_PASSWORD=your_password
SNOWFLAKE_DATABASE=YOUR_DB
SNOWFLAKE_WAREHOUSE=YOUR_WH
```

### Environment Variable Precedence
1. Root `.env` file (HIGHEST - loaded last, overrides everything)
2. `env_files/` subdirectory files (loaded first)

**To override account settings for testing:**
```bash
# Add to root .env to override env_files/external_accounts/.env.snowflake
SNOWFLAKE_HOSTNAME=dev.snowflakecomputing.com
SNOWFLAKE_DATABASE=DEV_DB
```

## Variable Naming Convention

- **UPPERCASE**: Environment variables from `.env` files (e.g., `${ORG_NAME}`, `${SNOWFLAKE_HOSTNAME}`)
- **lowercase**: User-defined test variables (e.g., `${pipeline_name}`, `${task_name}`)

## Test Execution Flow

```
┌─────────────────────────┐
│  Update .env Files      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Configure Test         │
│  Variables              │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Upload Pipeline to     │
│  /src/pipelines         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Run Suite Setup        │
│  (loads env vars)       │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Create Accounts        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Import Pipelines       │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Create Triggered Tasks │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Execute Tasks          │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Verify Results         │
└─────────────────────────┘
```

## What Happens After Test Execution

### Services Started Automatically
- **Groundplex** - SnapLogic pipeline execution runtime
- **Oracle Database** - Started for Oracle tests
- **PostgreSQL Database** - Started for Postgres tests
- **MinIO** - S3-compatible object store

### In SnapLogic Org
Based on `.env` configuration:
- Accounts are created
- Project Space is created (deleted if exists when `PROJECT_SPACE_SETUP=True`)
- Project is created
- Pipeline is imported
- Triggered task is created and executed

### Test Reports Generated
Location: `test/robot_output/`
- `report-*.html` - Summary report with pass/fail status
- `log-*.html` - Detailed execution logs
- `output-*.xml` - XML output for CI/CD integration

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
| `createplex` | Groundplex setup | - |
| `verify_project_space_exists` | Project validation | - |

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

## Docker Compose Architecture

The `docker-compose.yml` in the project root includes modular compose files via `include:`:

```
docker-compose.yml (root)
├── docker/oracle/docker-compose.oracle.yml
├── docker/postgres/docker-compose.postgres.yml
├── docker/mysql/docker-compose.mysql.yml
├── docker/sqlserver/docker-compose.sqlserver.yml
├── docker/kafka/docker-compose.kafka.yml
├── docker/activemq/docker-compose.activemq.yml
├── docker/minio/docker-compose.minio.yml
├── docker/salesforce-mock/docker-compose.salesforce-mock.yml
├── docker/maildev/docker-compose.maildev.yml
└── docker/tools/docker-compose.tools.yml
```

Services use **Docker Compose profiles** — not all services start by default. Profiles are activated via `COMPOSE_PROFILES` in the Makefile targets.

### Key Docker Service Names (Container Hostnames)

| Service | Container Name | Used As Hostname In |
|---------|---------------|-------------------|
| Oracle | `oracle-db` | Pipeline account config |
| PostgreSQL | `postgres-db` | Pipeline account config |
| MySQL | `mysql-db` | Pipeline account config |
| SQL Server | `sqlserver-db` | Pipeline account config |
| Kafka | `snaplogic-kafka-kraft` | Messaging config |
| MinIO | `minio` | S3 account config |

All containers share the `snaplogicnet` bridge network and communicate via container names.

## Cookiecutter Template Relationship

This repo is a **cookiecutter template**. The actual project lives inside `{{cookiecutter.primary_pipeline_name}}/`. When a user generates a repo from this template, cookiecutter replaces the folder name with the actual project name.

- Top-level `.claude/` is a pointer to `{{cookiecutter.primary_pipeline_name}}/.claude/`
- The inner `.claude/` directory has the detailed slash command files
- When working on this repo directly (not generated), always `cd` into `{{cookiecutter.primary_pipeline_name}}/` first
- The curly braces in the folder name require double quotes in shell: `cd "{{cookiecutter.primary_pipeline_name}}"`

## Windows/WSL Setup Notes

This framework requires a Linux environment. On Windows machines:

- **WSL 2 with Ubuntu** is required — WSL 1 will not work
- `make` commands must run inside WSL/Ubuntu, never in PowerShell or CMD
- Docker Desktop must have WSL integration enabled for Ubuntu (Settings → Resources → WSL Integration)
- Docker Desktop installs a `docker-desktop` WSL distro — this is NOT usable for development. Ubuntu must be installed separately and set as default
- The Docker credentials error (`error getting credentials`) on first run is fixed by: `mkdir -p ~/.docker && echo '{"credsStore":"desktop.exe"}' > ~/.docker/config.json`
- Corporate networks may block `apt` inside WSL due to DNS/firewall — manual DNS config in `/etc/resolv.conf` may be needed
- Corporate SSL inspection can cause `x509: certificate signed by unknown authority` errors when Docker pulls images — corporate CA cert must be imported

Detailed Windows setup documentation is in: `README/How To Guides/infra_setup_guides/windows/`

## Makefile Architecture

The main `Makefile` includes modular makefiles:

```
Makefile (root — primary entry point)
├── makefiles/common_services/Makefile.common    # Shared variables, Docker Compose base command
├── makefiles/common_services/Makefile.docker    # start-services, clean-start, status targets
├── makefiles/common_services/Makefile.testing   # robot-run-tests, robot-run-all-tests targets
├── makefiles/common_services/Makefile.groundplex # launch-groundplex, stop-groundplex targets
├── makefiles/database_services/Makefile.oracle  # oracle-start, oracle-stop, oracle-load-data
├── makefiles/database_services/Makefile.postgres
├── makefiles/database_services/Makefile.mysql
├── makefiles/database_services/Makefile.sqlserver
├── makefiles/messaging_services/Makefile.kafka  # kafka-start, kafka-stop, kafka-create-topic
├── makefiles/messaging_services/Makefile.activemq
├── makefiles/mock_services/Makefile.minio
├── makefiles/mock_services/Makefile.salesforce
└── makefiles/mock_services/Makefile.maildev
```

When modifying Makefile targets, edit the specific modular file — not the root Makefile.

## Robot Framework Test Architecture

### Suite Setup Flow (`test/suite/__init__.robot`)
- Loads all environment variables from `.env` files
- Creates SnapLogic accounts (Oracle, Postgres, etc.) based on tags
- Runs before any test in the suite

### Resource Files (`test/resources/common/`)
- `general.resource` — Core keywords used across all tests
- Custom Python libraries in `test/libraries/` extend Robot Framework capabilities

### Test Data (`test/suite/test_data/`)
- Account payload JSON files (`acc_oracle.json`, `acc_postgres.json`, etc.)
- Pipeline parameter files
- Expected output files for comparison

---

## Workflow & Behavior Rules

These rules govern how Claude operates on this project. Follow them for every interaction.

### 1. Plan Before Building
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, **STOP and re-plan immediately** — don't keep pushing
- Write a checklist of steps before starting implementation
- Use plan mode for verification steps, not just building

### 2. Use Subagents Strategically
- Use subagents to keep the main context window clean
- Offload research, exploration, and parallel analysis to subagents
- One focused task per subagent
- For complex problems, use multiple subagents in parallel

### 3. Self-Improvement Loop
- After ANY correction from the user, record the lesson learned
- Write rules that prevent the same mistake from recurring
- Review past lessons at session start for relevant patterns
- Examples of lessons learned in this project:
  - Docker service hostnames use container names (`sqlserver-db`), NOT `host.docker.internal` — the Groundplex is on the same `snaplogicnet` bridge network
  - Never modify `env_files/` defaults without asking — use root `.env` for overrides
  - SnapLogic expressions don't support `var`, semicolons, or multi-line functions — use single-line ternaries
  - Always check `RELEASE_BUILD_VERSION` in `.env` when getting 404 errors on SnapLogic API calls
  - Org name `ml-legacy-migration` uses hyphens, not underscores — `split('_')` will fail, use `indexOf` check first

### 4. Verification Before Done
- **Never mark a task complete without proving it works**
- Run tests, check logs, demonstrate correctness
- Diff behavior between before and after when relevant
- Ask yourself: "Would a staff engineer approve this?"
- For Robot Framework changes: verify with `make robot-run-tests TAGS="<tag>"`
- For Docker changes: verify with `make <service>-status` and check logs

### 5. Autonomous Problem Solving
- When given a bug report or error log: **just fix it** — don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Fix failing CI tests without being told how
- Use `/debug-logs` and `/troubleshoot` skills when needed

### 6. Simplicity and Minimal Impact
- Make every change as simple as possible — impact minimal code
- Find root causes, not temporary fixes. Senior developer standards
- Changes should only touch what's necessary — avoid introducing new bugs
- Don't over-engineer: skip this for simple, obvious fixes
- For non-trivial changes: pause and ask "Is there a more elegant way?"

### 7. Network Architecture Awareness
- All Docker services (Groundplex, databases, messaging, mocks) share the `snaplogicnet` bridge network
- Services communicate via **container names** — never use `host.docker.internal` or `localhost` for Docker services
- The `env_files/` directory contains correct container hostnames — do not modify them
- Only override specific values (like database name) in root `.env`

### 8. Robot Framework Test Design — Separation of Logic and Verification
- **Test cases should ONLY contain verifications** (assertions, should be equal, should be true, etc.)
- **All logic must live in keywords** — queries, updates, conditional checks, data extraction, looping, transformations
- Test cases call keywords and verify the results — they do not implement the how, only the what
- This keeps tests readable, maintainable, and reusable
- Example:
  - **Wrong:** Test case contains `Query`, `FOR` loop, `IF` block, `Execute SQL String`, then `Should Be Equal`
  - **Right:** Test case calls `Check Upstream Prerequisites` keyword, then asserts `Should Be True ${prerequisites_met}`
- Keywords encapsulate all logic and return values for the test to verify
- Never put customer names or individual names in code, comments, or documentation
