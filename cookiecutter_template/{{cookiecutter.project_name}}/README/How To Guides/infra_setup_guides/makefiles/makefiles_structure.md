# Makefile Organization for Snaplogic Robot Framework

## Overview

The Snaplogic Robot Framework Makefile has been reorganized into category-specific files for better maintainability, clarity, and scalability. This modular approach makes it easier to find, understand, and modify specific functionality.

## Directory Structure

```
snaplogic-robotframework-examples/
├── Makefile                    # Main orchestrator (includes all categories)
├── Makefile.backup            # Original monolithic Makefile (for reference)
└── makefiles/
    ├── Makefile.testing       # Test execution and reporting
    ├── Makefile.groundplex    # Groundplex management
    ├── Makefile.databases     # Database services
    ├── Makefile.messaging     # Kafka and ActiveMQ
    ├── Makefile.mocks         # Mock services
    ├── Makefile.docker        # Container management
    └── Makefile.quality       # Code quality and dependencies
```

## Categories Explained

### 🧪 Testing (`Makefile.testing`)
Handles all Robot Framework test execution, including:
- Single test runs with tags
- End-to-end test workflows
- Slack notifications
- S3 upload of test results
- Test orchestration with project space setup

**Key targets:**
- `robot-run-tests` - Run tests with optional tags
- `robot-run-all-tests` - Complete test workflow
- `slack-notify` - Send results to Slack
- `upload-test-results` - Upload to S3

### 🚀 Groundplex (`Makefile.groundplex`)
Manages SnapLogic Groundplex containers:
- Launching and stopping Groundplex
- JCC status monitoring
- Certificate management for HTTPS
- Project space and plex creation

**Key targets:**
- `launch-groundplex` - Start Groundplex
- `groundplex-status` - Check JCC status
- `setup-groundplex-cert` - Configure HTTPS certificates
- `createplex-launch-groundplex` - Full setup workflow

### 🛢️ Databases (`Makefile.databases`)
Manages various database systems:
- Oracle, PostgreSQL, MySQL, SQL Server
- Teradata, DB2
- Snowflake SQL client

**Key targets:**
- `{db}-start` - Start specific database
- `{db}-stop` - Stop and clean up database
- `snowflake-setup` - Configure Snowflake test data

### 📡 Messaging (`Makefile.messaging`)
Handles message queue and streaming services:
- Kafka (KRaft mode) with UI
- ActiveMQ JMS server
- Topic/queue management
- Testing and monitoring

**Key targets:**
- `kafka-start/stop/restart` - Kafka lifecycle
- `kafka-create-topic` - Create topics
- `kafka-test` - Test connectivity
- `activemq-start/stop` - ActiveMQ lifecycle

### 🔌 Mocks (`Makefile.mocks`)
Manages mock and testing services:
- MinIO (S3-compatible storage)
- Salesforce API mock (WireMock)
- JSON Server for CRUD operations
- MailDev email server

**Key targets:**
- `start-s3-emulator` - MinIO S3 service
- `salesforce-mock-start` - Salesforce API mock
- `email-start` - Email testing server

### 🐳 Docker (`Makefile.docker`)
Container and environment management:
- Docker Compose orchestration
- Tools container building
- Environment validation
- Service lifecycle

**Key targets:**
- `snaplogic-build-tools` - Build tools container
- `clean-start` - Fresh environment setup
- `check-env` - Validate .env file
- `rebuild-tools` - Update tools container

### ✨ Quality (`Makefile.quality`)
Code quality and dependency management:
- Robot Framework formatting (Robotidy)
- Static analysis (Robocop)
- Python dependency management
- Virtual environment setup

**Key targets:**
- `robotidy` - Format .robot files
- `robocop` - Static analysis
- `lint` - Run all quality checks
- `install-requirements-venv` - Setup dependencies

## Usage Examples

### Basic Commands

```bash
# Get help
make help

# List all categories
make list-categories

# Check system status
make status
```

### Testing Workflows

```bash
# Run specific tests
make robot-run-tests TAGS="oracle,minio"

# Full test workflow with environment setup
make robot-run-all-tests TAGS="smoke" PROJECT_SPACE_SETUP=True

# Upload results to S3
make upload-test-results
```

### Service Management

```bash
# Start all configured services
make clean-start

# Start specific database
make oracle-start
make postgres-start

# Start messaging services
make kafka-start
make activemq-start

# Start mock services
make salesforce-mock-start
make email-start
```

### Development Workflows

```bash
# Format and lint Robot files
make lint

# Update dependencies
make update-requirements-all

# Rebuild tools container
make rebuild-tools

# Check environment setup
make check-env
```

## Environment Variables

Key environment variables (set in `.env` file):

```bash
# AWS Credentials (for S3 uploads)
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret

# Slack webhook (for notifications)
SLACK_WEBHOOK_URL=your_webhook_url

# Docker Compose profiles
COMPOSE_PROFILES=tools,oracle-dev,minio,postgres-dev
```

## Migration from Monolithic Makefile

The reorganization maintains 100% backward compatibility:

1. All existing commands work exactly as before
2. The original Makefile is backed up as `Makefile.backup`
3. No changes required to CI/CD pipelines or scripts
4. Team members can continue using familiar commands

## Benefits of Modular Structure

1. **Better Organization**: Related targets grouped logically
2. **Easier Maintenance**: Find and modify specific functionality quickly
3. **Improved Readability**: Smaller files are easier to understand
4. **Team Collaboration**: Different team members can work on different categories
5. **Scalability**: Easy to add new categories or extend existing ones
6. **Documentation**: Each category can have detailed inline documentation

## Troubleshooting

### Common Issues

1. **Target not found**: Ensure the main Makefile includes all category files
2. **Docker errors**: Run `make check-env` to validate environment
3. **Permission issues**: Check Docker daemon is running and user has permissions
4. **Port conflicts**: Ensure required ports are not in use by other services

### Getting Help

```bash
# Show all available commands
make help

# Check current system status
make status

# Validate environment setup
make check-env
```

## Contributing

When adding new functionality:

1. Identify the appropriate category
2. Add targets to the corresponding `makefiles/Makefile.<category>`
3. Update the help target in the main Makefile
4. Document complex targets with comments
5. Test the target independently and through the main Makefile

## Advanced Usage

### Direct Category Invocation

You can run targets directly from category files:

```bash
make -f makefiles/Makefile.testing robot-run-tests
make -f makefiles/Makefile.databases oracle-start
```

### Custom Profiles

Override Docker Compose profiles:

```bash
COMPOSE_PROFILES=tools,kafka,oracle-dev make start-services
```

### Parallel Execution

Some independent targets can be run in parallel:

```bash
make -j4 oracle-start postgres-start mysql-start kafka-start
```

## Best Practices

1. Always run `make check-env` before starting services
2. Use `make clean-start` for a fresh environment
3. Run `make status` to verify services are running
4. Use tags to run specific test suites
5. Keep `.env` file updated with required credentials
6. Run `make lint` before committing Robot Framework changes

## Support

For issues or questions:
1. Check this README first
2. Run `make help` for command reference
3. Review individual Makefile categories for detailed comments
4. Check `Makefile.backup` for original implementation if needed
