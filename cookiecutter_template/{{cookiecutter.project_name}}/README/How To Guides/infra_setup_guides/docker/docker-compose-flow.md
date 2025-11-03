# Docker Compose Architecture Flow

## Overview
This document explains how the Docker Compose setup works for the Robot Framework testing environment.

## Container Build Flow

```
┌─────────────────────┐
│ docker-compose.yml  │
│  (tools container)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  robot/Dockerfile   │ ──► Builds tools container
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  requirements.txt   │ ──► Installs all libraries
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│   Tools Container   │ ──► Ready for testing!
│  (All libs ready)   │
└─────────────────────┘
```

## Detailed Steps

### 1. Docker Compose Configuration (`docker-compose.yml`)
- Defines all service containers (tools, groundplex, databases)
- Specifies build context and Dockerfile location for the tools container
- Sets up networking between containers
- Manages environment variables from `.env` file

### 2. Dockerfile Build (`robot/Dockerfile`)
- Base image setup with Python
- System dependencies installation
- Working directory configuration
- Copies the requirements file
- Triggers pip install process

### 3. Requirements Installation (`requirements.txt`)
- **Robot Framework Libraries:**
  - `robotframework-pabot` - Parallel test execution
  - `snaplogic-common-robot` - SnapLogic API interactions
  
- **Database Connectors:**
  - `snowflake-connector-python` - Snowflake database
  - `pymysql` - MySQL database
  - `psycopg2-binary` - PostgreSQL database
  - `pymssql` - Microsoft SQL Server
  - `oracledb` - Oracle database
  - `ibm_db` - IBM DB2 database
  - `teradatasql` - Teradata database
  
- **Other Dependencies:**
  - `minio` - MinIO S3-compatible storage
  - `stomp.py` - STOMP protocol for JMS testing
  - `requests` - HTTP client for API calls

### 4. Tools Container Ready
Once the build process completes:
- All Robot Framework libraries are installed
- All database connectors are configured
- Container is ready to execute tests
- Shared volumes allow access to test files and results

## Usage

### Starting the Services
```bash
# Bring up the tools container and other services
make start-services

# Or using docker-compose directly
docker compose --env-file .env -f docker-compose.yml up -d tools
```

### Verifying Installation
```bash
# Check installed libraries
docker exec snaplogic-test-example-tools-container pip list

# Verify specific library
docker exec snaplogic-test-example-tools-container pip show snowflake-connector-python
```

### Running Tests
```bash
# Run tests using the tools container
make robot-run-tests TAGS="snowflake_demo"
```

## Benefits of This Architecture

1. **Consistency**: Everyone uses the exact same environment
2. **Isolation**: No conflicts with local Python installations
3. **Reproducibility**: Easy to recreate the environment anywhere
4. **Version Control**: All dependencies are tracked in requirements.txt
5. **Easy Updates**: Simply rebuild the container for updates
6. **No Local Setup**: Developers don't need to install anything locally except Docker

## Troubleshooting

### Rebuilding the Container
If you need to update dependencies or fix issues:
```bash
# Force rebuild without cache
make snaplogic-build-tools

# Or rebuild with updated requirements
make rebuild-tools
```

### Checking Container Status
```bash
# View running containers
docker ps | grep tools

# Check container logs
docker logs snaplogic-test-example-tools-container
```

## Related Files
- `/docker-compose.yml` - Main compose configuration
- `/robot/Dockerfile` - Tools container build instructions
- `/src/tools/requirements.txt` - Python dependencies
- `/Makefile` - Convenient commands for container management
