# Environment Files Configuration Guide

## Overview

This guide explains how to use and configure environment files in the SnapLogic Robot Framework Examples project. The system **requires** a root `.env` file and optionally loads files from the `env_files/` directory (including subdirectories). It loads multiple `.env` files automatically, with later files overriding values from earlier ones.

### New Modular Structure

The environment files have been reorganized into individual service-specific files for better maintainability:
- Each service (Oracle, PostgreSQL, Kafka, etc.) has its own `.env` file
- Files can be organized in subdirectories for better structure
- Automatic recursive discovery of all env files

## Table of Contents

- [How It Works](#how-it-works)
- [Configuration Variables](#configuration-variables)
- [Usage Examples](#usage-examples)
- [File Loading Order](#file-loading-order)
- [Error Handling](#error-handling)
- [Debug Commands](#debug-commands)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## How It Works

The Makefile configuration automatically loads:
1. **Root `.env` file** (required) - Base configuration
2. **All `.env` files from `env_files/` directory and subdirectories** (optional) - Modular configurations

The root `.env` is mandatory, while files in `env_files/` are optional (will show a warning if missing).

### Key Features

- **Recursive Discovery**: Automatically finds all env files in `env_files/` and its subdirectories
- **Modular Configuration**: Each service has its own dedicated env file
- **Subdirectory Support**: Organize files in logical folders (databases/, messaging/, etc.)
- **Automatic Discovery**: Finds all `.env`, `.env.*`, and `*.env` files recursively
- **Multiple File Support**: Loads multiple env files using Docker Compose's `--env-file` flag
- **Manual Override**: Can specify exact files to load instead of auto-discovery
- **Flexible Configuration**: Can change the directory or specify individual files
- **WSL2 Compatible**: Works seamlessly on Linux, Mac, and Windows with WSL2

## Configuration Variables

### `ROOT_ENV_FILE`
- **Default**: `.env`
- **Purpose**: Root environment file (required)
- **Location**: Project root directory
- **Override**: Cannot be disabled, always required

### `ENV_DIR`
- **Default**: `env_files`
- **Purpose**: Directory to scan for additional environment files
- **Override**: Can be changed via command line

### `ENV_FILES`
- **Default**: `.env` + auto-discovered files from `ENV_DIR`
- **Purpose**: Complete list of environment files to load
- **Override**: Can be manually specified to bypass auto-discovery

### `ENV_FILE_FLAGS`
- **Generated**: Automatically created from `ENV_FILES`
- **Purpose**: Builds `--env-file` flags for Docker Compose
- **Format**: `--env-file .env --env-file env_files/file1 --env-file env_files/file2 ...`

## Usage Examples

### 1. Default Usage (Auto-Discovery)

Load root `.env` AND all files from the `env_files/` directory:

```bash
make robot-run-tests
```

This will automatically load (in alphabetical order):
- `.env` (root file - base configuration)
- `env_files/.env.accounts` (account credentials - deprecated, split into individual files)
- `env_files/.env.db2` (DB2 database configuration)
- `env_files/.env.email` (Email/SMTP configuration)
- `env_files/.env.jms` (JMS/ActiveMQ configuration)
- `env_files/.env.kafka` (Kafka configuration)
- `env_files/.env.mysql` (MySQL database configuration)
- `env_files/.env.oracle` (Oracle database configuration)
- `env_files/.env.ports` (Port mappings)
- `env_files/.env.postgres` (PostgreSQL database configuration)
- `env_files/.env.s3` (S3/MinIO configuration)
- `env_files/.env.salesforce` (Salesforce mock configuration)
- `env_files/.env.sqlserver` (SQL Server configuration)
- `env_files/.env.teradata` (Teradata configuration)
- Any files in subdirectories (loaded alphabetically)

### 2. Manual File Selection

#### Specify exact files to load:

```bash
make robot-run-tests ENV_FILES=".env .env.production"
```

#### Load files from different locations:

```bash
make robot-run-tests ENV_FILES="config/.env secrets/.env.secrets"
```

#### Use a single file:

```bash
make robot-run-tests ENV_FILES=".env"
```

### 3. Change Directory

#### Use a different directory for auto-discovery:

```bash
make robot-run-tests ENV_DIR="./production-env"
```

#### Use custom directory in CI/CD:

```bash
make robot-run-tests ENV_DIR="./ci-env"
```

### 4. Environment-Specific Configurations

#### Development:
```bash
make robot-run-tests ENV_FILES=".env.base .env.dev .env.local"
```

#### Testing:
```bash
make robot-run-tests ENV_FILES=".env.test"
```

#### Staging:
```bash
make robot-run-tests ENV_FILES=".env.base .env.staging"
```

#### Production:
```bash
make robot-run-tests ENV_FILES=".env.base .env.production .env.secrets"
```

### 5. Docker Compose Commands

All make targets that use Docker Compose will automatically use the configured env files:

```bash
# Start services with env files
make start-services

# Stop services
make stop-services

# Run tests
make robot-run-tests

# View logs
make logs
```

## File Loading Order

Files are loaded in the order they appear, with **later files overriding earlier ones**:

### Default Loading Order:
1. **`.env` (root)** - Loads first, base configuration
2. **`env_files/` directory files** - Load alphabetically, can override root values

```bash
# Example with multiple files
ENV_FILES=".env env_files/.env.accounts env_files/.env.ports"

# If .env has:
DATABASE_HOST=localhost
DATABASE_PORT=5432

# And env_files/.env.accounts has:
DATABASE_HOST=production.db.com

# The final values will be:
DATABASE_HOST=production.db.com  # From .env.accounts
DATABASE_PORT=5432                # From .env (not overridden)
```

### Current File Structure

The new modular structure organizes files by service:

```
env_files/
├── .env.accounts         # Legacy: All accounts (being phased out)
├── .env.ports           # Port configurations for all services
├── .env.oracle          # Oracle database configuration
├── .env.postgres        # PostgreSQL database configuration
├── .env.mysql           # MySQL database configuration
├── .env.sqlserver       # SQL Server configuration
├── .env.teradata        # Teradata database configuration
├── .env.db2             # IBM DB2 database configuration
├── .env.kafka           # Apache Kafka configuration
├── .env.jms             # JMS/ActiveMQ configuration
├── .env.s3              # S3/MinIO storage configuration
├── .env.salesforce      # Salesforce mock configuration
└── .env.email           # Email/SMTP configuration
```

### Organizing with Subdirectories

You can organize files into subdirectories for better structure:

```
env_files/
├── databases/
│   ├── .env.oracle
│   ├── .env.postgres
│   ├── .env.mysql
│   ├── .env.sqlserver
│   ├── .env.teradata
│   └── .env.db2
├── messaging/
│   ├── .env.kafka
│   └── .env.jms
├── cloud/
│   ├── .env.s3
│   └── .env.salesforce
└── communication/
    └── .env.email
```

**Note**: Files in subdirectories are discovered automatically and loaded alphabetically by their full path.

## Error Handling

### Root .env File Missing

If the root `.env` file is not found:

```bash
make robot-run-tests
# ERROR: Root .env file not found in project root!
# Please create a .env file in the project root directory
```

### No Files in env_files/ Directory

If no `.env` files are found in the `env_files/` directory:

```bash
make robot-run-tests
# Warning: No .env files found in env_files/ directory. Using only root .env file
```

**Note**: This is now just a warning, not an error. The system will continue with only the root `.env` file.

### How to Fix

1. **Ensure root .env exists**:
   ```bash
   # Create root .env with base configuration
   cp .env.example .env
   ```

2. **Add files to env_files/ directory**:
   ```bash
   # Create the directory if needed
   mkdir -p env_files
   
   # Add configuration files
   cp .env.accounts.example env_files/.env.accounts
   cp .env.ports.example env_files/.env.ports
   ```

3. **Or specify files manually** (still need both sources):
   ```bash
   make robot-run-tests ENV_FILES=".env config/.env.custom"
   ```

## Debug Commands

### Show Loaded Files

Display which env files are being loaded:

```bash
make show-env-files
```

Output:
```
========================================
Environment Files Configuration:
========================================
Root ENV file: .env
ENV_DIR: env_files

ENV_FILES being loaded (in order):
  ✓ .env (exists)
  ✓ env_files/.env.accounts (exists)
  ✓ env_files/.env.ports (exists)
========================================
Loading Order:
  1. Root .env loads first (base configuration)
  2. Files from env_files/ and subdirectories load next (sorted alphabetically)
========================================
Docker Compose Command:
docker compose --env-file .env --env-file env_files/.env.accounts --env-file env_files/.env.ports -f docker/docker-compose.yml
========================================
```

### List Available Files

Show all available env files in the configured directory:

```bash
make list-env-files
```

Output:
```
========================================
Available Environment Files:
========================================
In env_files/ directory:
  - .env.accounts
  - .env.ports
========================================
```

## Best Practices

### 1. Organize by Function

Use the new modular structure with individual service files:

```
project/
├── .env                    # Root: Base/shared configuration
└── env_files/
    ├── .env.ports         # Port configurations (shared)
    ├── .env.oracle        # Oracle-specific settings
    ├── .env.postgres      # PostgreSQL-specific settings
    ├── .env.mysql         # MySQL-specific settings
    ├── .env.kafka         # Kafka configuration
    ├── .env.jms           # JMS/ActiveMQ settings
    └── ...                # Other service-specific files
```

Or organize with subdirectories:

```
project/
├── .env                    # Root: Base configuration
└── env_files/
    ├── databases/         # Database configurations
    │   ├── .env.oracle
    │   ├── .env.postgres
    │   └── .env.mysql
    ├── messaging/         # Message broker configs
    │   ├── .env.kafka
    │   └── .env.jms
    └── cloud/             # Cloud service configs
        └── .env.s3
```

**Benefits of modular approach**:
- Each service configuration is isolated
- Easy to enable/disable specific services
- Clear separation of concerns
- Simpler to maintain and update

### 2. Use Clear Naming

- Use descriptive suffixes: `.env.production`, `.env.staging`
- Add comments in files to explain variables
- Group related variables together

### 3. Security Considerations

- Never commit sensitive `.env` files to git
- Use `.gitignore` to exclude env files:
  ```gitignore
  env_files/.env.*
  .env.local
  .env.secrets
  ```
- Store production secrets separately

### 4. Documentation

- Provide `.env.example` files with dummy values
- Document required variables in README
- Add comments explaining each variable's purpose

### 5. Validation

Create a validation target in your Makefile:

```makefile
validate-env:
	@echo "Validating environment configuration..."
	@test -n "$(ORACLE_HOST)" || (echo "ERROR: ORACLE_HOST not set" && exit 1)
	@test -n "$(POSTGRES_HOST)" || (echo "ERROR: POSTGRES_HOST not set" && exit 1)
	@echo "Environment validation passed!"
```

## Troubleshooting


### Issue: Variable conflicts between files

**Solution**: Check loading order:
```bash
make show-env-files
```
Remember: later files override earlier ones.

### Issue: Docker Compose not finding env files

**Solution**: Ensure paths are relative to where you run `make`:
```bash
# If running from project root
ENV_FILES="env_files/.env"  # Correct

# Not from absolute path unless necessary
ENV_FILES="/absolute/path/.env"  # Avoid
```

### Issue: Special characters in env values

**Solution**: Quote values in env files:
```bash
# In .env file
PASSWORD="p@ssw0rd#with$special"
DATABASE_URL='postgresql://user:pass@host/db'
```

## Advanced Usage

### Conditional Loading

Load different files based on conditions:

```makefile
ifdef PRODUCTION
    ENV_FILES := .env.base .env.production
else
    ENV_FILES := .env.base .env.development
endif
```



## Summary

The environment file system provides flexible configuration management:

- **Required files**: Root `.env` must exist; files in `env_files/` are optional
- **Modular structure**: Each service has its own dedicated `.env` file
- **Subdirectory support**: Files can be organized in subdirectories and are discovered recursively
- **Default behavior**: Loads `.env` + all files from `env_files/` and subdirectories
- **Loading order**: Root `.env` first, then `env_files/` alphabetically (including subdirectories)
- **Manual control**: Override with specific files when needed
- **Cross-platform**: Works on Linux, Mac, and Windows with WSL2
- **Debugging**: Built-in commands to inspect configuration
- **Runtime reload**: Use `make restart-tools` after env changes

### New Service-Specific Files

Each service now has its own configuration file:
- `.env.oracle` - Oracle database settings and credentials
- `.env.postgres` - PostgreSQL configuration
- `.env.mysql` - MySQL configuration
- `.env.sqlserver` - SQL Server settings
- `.env.teradata` - Teradata configuration
- `.env.db2` - IBM DB2 settings
- `.env.kafka` - Kafka broker and related settings
- `.env.jms` - JMS/ActiveMQ configuration
- `.env.s3` - S3/MinIO storage settings
- `.env.salesforce` - Salesforce mock API configuration
- `.env.email` - Email/SMTP settings
- `.env.ports` - Port mappings for all services

This modular approach ensures better organization, easier maintenance, and clearer separation of concerns across different services.

## Overriding Other Variables

You can override ALL variables from `Makefile.common` at runtime, not just environment file settings:

### Override Multiple Variables

```bash
# Complete custom configuration
make robot-run-tests \
  ENV_FILES=".env.staging .env.secrets" \
  COMPOSE_PROFILES=tools,kafka \
  DEFAULT_PROCESSES=8 \
  ROBOT_DEFAULT_TIMEOUT=45s \
  ROBOT_OUTPUT_DIR=staging_results \
  S3_BUCKET=staging-test-results \
  S3_PREFIX=Staging_Tests_2024 \
  DATE=2024-staging-run-001
```

### Available Variables to Override

| Variable              | Default                         | Example Override                 | Description                         |
| --------------------- | ------------------------------- | -------------------------------- | ----------------------------------- |
| ENV_DIR               | env_files                       | `ENV_DIR=./config`               | Directory to scan for env files     |
| ENV_FILES             | Auto-discovered from ENV_DIR    | `ENV_FILES=".env.staging"`       | Specific env files to load          |
| COMPOSE_PROFILES      | tools,oracle-dev,minio,...      | `COMPOSE_PROFILES=minimal`       | Docker Compose profiles to activate |
| DEFAULT_PROCESSES     | 5                               | `DEFAULT_PROCESSES=10`           | Number of parallel test processes   |
| ROBOT_DEFAULT_TIMEOUT | 30s                             | `ROBOT_DEFAULT_TIMEOUT=60s`      | Default timeout for Robot tests     |
| S3_BUCKET             | artifacts.slimdev.snaplogic     | `S3_BUCKET=my-bucket`            | S3 bucket for test results          |
| S3_PREFIX             | RF_CommonTests_Results          | `S3_PREFIX=Custom_Results`       | S3 path prefix for uploads          |
| DATE                  | $(shell date +'%Y-%m-%d-%H-%M') | `DATE=custom-date`               | Timestamp for test runs             |
| DOCKER_COMPOSE_FILE   | docker/docker-compose.yml       | `DOCKER_COMPOSE_FILE=custom.yml` | Docker Compose file location        |
| PROJECT_ROOT          | $(shell pwd)                    | `PROJECT_ROOT=/custom/path`      | Project root directory              |
| TEST_DIR              | test                            | `TEST_DIR=custom_tests`          | Test directory location             |
| ROBOT_OUTPUT_DIR      | robot_output                    | `ROBOT_OUTPUT_DIR=results`       | Robot Framework output directory    |

### Common Override Patterns

#### Minimal Testing Setup
```bash
make robot-run-tests \
  ENV_FILES=".env.minimal" \
  COMPOSE_PROFILES=tools \
  DEFAULT_PROCESSES=1
```

#### Full Integration Testing
```bash
make robot-run-tests \
  ENV_FILES=".env.integration .env.all-services" \
  COMPOSE_PROFILES=tools,kafka,oracle-dev,postgres-dev,mysql-dev \
  DEFAULT_PROCESSES=10 \
  ROBOT_DEFAULT_TIMEOUT=120s
```

#### CI/CD Pipeline Configuration
```bash
make robot-run-tests \
  ENV_FILES="${CI_ENV_FILES}" \
  COMPOSE_PROFILES="${CI_PROFILES}" \
  ROBOT_OUTPUT_DIR="${CI_PROJECT_DIR}/results" \
  S3_BUCKET="${CI_ARTIFACTS_BUCKET}" \
  S3_PREFIX="${CI_COMMIT_SHA}" \
  DATE="${CI_BUILD_NUMBER}"
```

#### Production Deployment
```bash
make deploy \
  ENV_FILES=".env.production .env.secrets" \
  COMPOSE_PROFILES=production \
  DOCKER_COMPOSE_FILE=docker/docker-compose.prod.yml
```

### Combining with Environment Variables

You can also export variables before running make:

```bash
# Export variables
export ENV_FILES=".env.custom"
export COMPOSE_PROFILES="minimal"
export DEFAULT_PROCESSES=3

# Run make (will use exported variables)
make robot-run-tests
```

### Precedence Order

Variables are evaluated in this order (highest to lowest priority):

1. **Command-line override**: `make test VAR=value`
2. **Environment variables**: `export VAR=value`
3. **Makefile defaults**: `VAR ?= default`

This flexibility allows you to customize every aspect of the build and test process without modifying the Makefiles.
