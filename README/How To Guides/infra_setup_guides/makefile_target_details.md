# Makefile Targets Documentation

This document provides a comprehensive overview of all available targets in the SnapLogic Robot Framework Automation Makefile, organized by functional categories.

## Table of Contents
- [General Targets](#general-targets)
- [Robot Framework Test Targets](#robot-framework-test-targets)
- [Groundplex Management](#groundplex-management)
- [Database Services](#database-services)
  - [Oracle Database](#oracle-database)
  - [PostgreSQL Database](#postgresql-database)
  - [MySQL Database](#mysql-database)
  - [SQL Server Database](#sql-server-database)
  - [Teradata Database](#teradata-database)
  - [DB2 Database](#db2-database)
  - [Snowflake](#snowflake)
- [Messaging Services](#messaging-services)
  - [Kafka](#kafka)
  - [ActiveMQ JMS](#activemq-jms)
- [Storage Services](#storage-services)
  - [MinIO S3 Emulator](#minio-s3-emulator)
- [Mock Services](#mock-services)
  - [Salesforce Mock](#salesforce-mock)
  - [Email Server](#email-server)
- [Development Tools](#development-tools)
- [CI/CD and Reporting](#cicd-and-reporting)

---

## General Targets

Core targets for managing the overall testing environment and services.

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `start-services` | Start all services using Docker Compose with selected profiles | `make start-services` | Uses COMPOSE_PROFILES environment variable |
| `clean-start` | Complete clean restart: stops all services, starts fresh, creates project space and launches Groundplex | `make clean-start` | Full environment reset |
| `snaplogic-start-services` | Start services/containers using COMPOSE_PROFILES | `make snaplogic-start-services` | Waits 30 seconds for services to stabilize |
| `snaplogic-stop` | Stop all SnapLogic containers and clean up | `make snaplogic-stop` | Removes containers and snaplogic-network |
| `snaplogic-build-tools` | Build tools container image | `make snaplogic-build-tools` | Builds without cache |
| `snaplogic-stop-tools` | Stop and remove tools container | `make snaplogic-stop-tools` | Cleans up tools container |
| `check-env` | Validate presence of required .env file | `make check-env` | Exits with error if .env not found |
| `ensure-config-dir` | Create required config directory | `make ensure-config-dir` | Creates ./test/.config directory |

---

## Robot Framework Test Targets

Targets for executing Robot Framework tests and related operations.

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `robot-run-tests` | Run Robot Framework tests with optional tags | `make robot-run-tests TAGS="oracle,minio"` | Default target. Can set PROJECT_SPACE_SETUP=True |
| `robot-run-all-tests` | Complete test workflow including environment setup | `make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True` | Handles project space creation and Groundplex launch |
| `createplex-launch-groundplex` | Create project space, create plex, and launch Groundplex | `make createplex-launch-groundplex` | Runs createplex tests then launches Groundplex |
| `robotidy` | Format Robot files using Robotidy | `make robotidy` | Auto-formats .robot files |
| `robocop` | Run Robocop for static lint checks | `make robocop` | Performs linting on Robot files |
| `lint` | Run both formatter and linter | `make lint` | Combines robotidy and robocop |

---

## Groundplex Management

Targets for managing SnapLogic Groundplex containers and certificates.

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `launch-groundplex` | Launch SnapLogic Groundplex container | `make launch-groundplex` | Validates status after launch |
| `groundplex-status` | Check Groundplex JCC readiness | `make groundplex-status` | Polls up to 20 attempts with 10s intervals |
| `stop-groundplex` | Stop JCC and shutdown Groundplex container | `make stop-groundplex` | Graceful shutdown with retries |
| `restart-groundplex` | Restart Groundplex (stop and launch) | `make restart-groundplex` | Complete restart cycle |
| `setup-groundplex-cert` | Setup certificates for HTTPS connections | `make setup-groundplex-cert` | Imports WireMock certificate |
| `launch-groundplex-with-cert` | Launch Groundplex with certificate setup | `make launch-groundplex-with-cert` | Combined launch and cert setup |
| `groundplex-check-cert` | Check certificate status in Groundplex | `make groundplex-check-cert` | Verifies certificate installation |
| `groundplex-remove-cert` | Remove certificate from Groundplex | `make groundplex-remove-cert` | Removes WireMock certificate |

---

## Database Services

### Oracle Database

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `oracle-start` | Start Oracle DB container | `make oracle-start` | Uses oracle-dev profile |
| `oracle-stop` | Stop Oracle DB and clean up volumes | `make oracle-stop` | Removes container and volumes |

### PostgreSQL Database

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `postgres-start` | Start PostgreSQL DB container | `make postgres-start` | Uses postgres-dev profile |
| `postgres-stop` | Stop PostgreSQL DB and clean up | `make postgres-stop` | Removes container and volumes |

### MySQL Database

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `mysql-start` | Start MySQL DB container | `make mysql-start` | Uses mysql-dev profile |
| `mysql-stop` | Stop MySQL DB and clean up | `make mysql-stop` | Removes container and volumes |

### SQL Server Database

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `sqlserver-start` | Start SQL Server DB container | `make sqlserver-start` | Uses sqlserver-dev profile |
| `sqlserver-stop` | Stop SQL Server DB and clean up | `make sqlserver-stop` | Removes container and volumes |

### Teradata Database

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `teradata-start` | Start Teradata DB container | `make teradata-start` | Requires special access to Teradata images |
| `teradata-stop` | Stop Teradata DB and clean up | `make teradata-stop` | Removes container and volumes |

### DB2 Database

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `db2-start` | Start DB2 DB container | `make db2-start` | May take 3-5 minutes on first run |
| `db2-stop` | Stop DB2 DB and clean up | `make db2-stop` | Removes container and volumes |

### Snowflake

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `snowflake-start` | Start Snowflake SQL client container | `make snowflake-start` | Provides SnowSQL CLI client |
| `snowflake-stop` | Stop Snowflake SQL client | `make snowflake-stop` | Removes client container |
| `snowflake-setup` | Setup Snowflake test data | `make snowflake-setup` | Provides setup instructions |

---

## Messaging Services

### Kafka

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `kafka-start` | Start Kafka in KRaft mode with UI | `make kafka-start` | Includes Kafka UI on port 8080 |
| `kafka-dev-start` | Start Kafka for development | `make kafka-dev-start` | No automatic topic creation |
| `kafka-stop` | Stop Kafka and related services | `make kafka-stop` | Stops all Kafka containers |
| `kafka-restart` | Restart Kafka services | `make kafka-restart` | Complete restart cycle |
| `kafka-status` | Check Kafka services status | `make kafka-status` | Shows broker and UI status |
| `kafka-create-topic` | Create a Kafka topic | `make kafka-create-topic TOPIC=my-topic PARTITIONS=3` | Creates topic with specified partitions |
| `kafka-list-topics` | List all Kafka topics | `make kafka-list-topics` | Shows existing topics |
| `kafka-clean` | Clean Kafka data and volumes | `make kafka-clean` | Removes all Kafka data |
| `kafka-test` | Test Kafka connectivity | `make kafka-test` | Produces and consumes test messages |
| `kafka-send-test-messages` | Send test messages to topics | `make kafka-send-test-messages` | Uses test producer |
| `kafka-cleanup-topics` | Clean up all non-system topics | `make kafka-cleanup-topics` | Deletes user topics |

### ActiveMQ JMS

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `activemq-start` | Start ActiveMQ JMS server with setup | `make activemq-start` | Web console on port 8161 |
| `activemq-stop` | Stop ActiveMQ JMS server | `make activemq-stop` | Stops ActiveMQ containers |
| `activemq-status` | Check ActiveMQ status | `make activemq-status` | Shows connection details |
| `activemq-setup` | Run ActiveMQ setup | `make activemq-setup` | Displays connection info |
| `run-jms-demo` | Run JMS demo script | `make run-jms-demo` | Placeholder for JMS demo |

---

## Storage Services

### MinIO S3 Emulator

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `start-s3-emulator` | Start MinIO S3-compatible emulator | `make start-s3-emulator` | Runs on port 9010 |
| `stop-s3-emulator` | Stop MinIO S3 emulator | `make stop-s3-emulator` | Stops MinIO container |
| `run-s3-demo` | Run S3 demo Python script | `make run-s3-demo` | Uses MinIO credentials |

---

## Mock Services

### Salesforce Mock

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `salesforce-mock-start` | Start Salesforce Mock API server | `make salesforce-mock-start` | WireMock on port 8089 |
| `salesforce-mock-stop` | Stop Salesforce Mock server | `make salesforce-mock-stop` | Removes containers and volumes |
| `salesforce-mock-status` | Check Salesforce Mock status | `make salesforce-mock-status` | Shows service health |
| `salesforce-mock-restart` | Restart Salesforce Mock server | `make salesforce-mock-restart` | Complete restart cycle |

### Email Server

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `email-start` | Start MailDev email testing server | `make email-start` | SMTP on 1025, Web UI on 1080 |
| `email-stop` | Stop MailDev email server | `make email-stop` | Removes container and volumes |
| `email-restart` | Restart MailDev email server | `make email-restart` | Complete restart cycle |
| `email-status` | Check MailDev server status | `make email-status` | Shows service health |
| `email-clean` | Clean and restart email server | `make email-clean` | Fresh start with no data |

---

## Development Tools

Targets for managing development dependencies and tools.

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `rebuild-tools` | Rebuild tools container with updated requirements | `make rebuild-tools` | Complete rebuild without cache |
| `quick-update-snaplogic-robot-only` | Update snaplogic-common-robot to latest | `make quick-update-snaplogic-robot-only` | Quick update without rebuild |
| `install-requirements-local` | Install requirements in local venv | `make install-requirements-local` | Requires activated venv |
| `install-requirements-venv` | Setup venv and install requirements | `make install-requirements-venv` | Creates venv if needed |
| `update-requirements-all` | Update requirements in venv and Docker | `make update-requirements-all` | Updates both environments |
| `clean-install-requirements` | Clean and reinstall requirements | `make clean-install-requirements` | Fresh install in venv |

---

## CI/CD and Reporting

Targets for continuous integration, deployment, and test reporting.

| Target | Description | Usage | Notes |
|--------|-------------|--------|-------|
| `slack-notify` | Send Slack notifications for test results | `make slack-notify` | Requires SLACK_WEBHOOK_URL |
| `upload-test-results` | Upload test results to S3 | `make upload-test-results` | Requires AWS credentials |
| `upload-test-results-cli` | Upload results using AWS CLI | `make upload-test-results-cli` | Alternative upload method |

---

## Environment Variables

### Key Environment Variables

| Variable | Description | Default/Example |
|----------|-------------|-----------------|
| `COMPOSE_PROFILES` | Docker Compose profiles to use | `tools,oracle-dev,minio,postgres-dev` |
| `TAGS` | Robot Framework test tags | `oracle,minio` |
| `PROJECT_SPACE_SETUP` | Create new project space | `True` or `False` |
| `TOPIC` | Kafka topic name | `my-topic` |
| `PARTITIONS` | Number of Kafka partitions | `3` |
| `AWS_ACCESS_KEY_ID` | AWS access key for S3 uploads | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for S3 uploads | Your AWS secret key |
| `SLACK_WEBHOOK_URL` | Slack webhook for notifications | Your Slack webhook URL |

---

## Quick Start Examples

### Basic Test Execution
```bash
# Run all tests
make robot-run-tests

# Run specific tagged tests
make robot-run-tests TAGS="oracle,postgres"
```

### Complete Environment Setup
```bash
# Clean start with full setup
make clean-start

# Run all tests with project space setup
make robot-run-all-tests PROJECT_SPACE_SETUP=True TAGS="oracle"
```

### Database Operations
```bash
# Start Oracle database
make oracle-start

# Start multiple databases
make oracle-start postgres-start mysql-start
```

### Kafka Operations
```bash
# Start Kafka with UI
make kafka-start

# Create a topic
make kafka-create-topic TOPIC=events PARTITIONS=5

# Test Kafka setup
make kafka-test
```

---

## Notes

- Always ensure the `.env` file is properly configured before running targets
- Some services require significant resources (e.g., Teradata needs 6GB RAM)
- Database containers may take several minutes to initialize on first run
- Use `docker compose logs -f <service-name>` to monitor service startup
- Most stop targets also clean up associated volumes to ensure fresh starts

---

*Last Updated: 2025*
*Framework: SnapLogic Robot Framework Automation*