# Docker Compose Guide for SnapLogic Testing

## Table of Contents

1. [What is Docker Compose?](#what-is-docker-compose)
2. [Docker Compose Architecture in Our Project](#docker-compose-architecture-in-our-project)
3. [Understanding docker-compose.yml Structure](#understanding-docker-composeyml-structure)
4. [Service Profiles and Multi-File Setup](#service-profiles-and-multi-file-setup)
5. [Integration with Makefile](#integration-with-makefile)
6. [Common Docker Compose Commands](#common-docker-compose-commands)
7. [Troubleshooting Guide](#troubleshooting-guide)
8. [Best Practices](#best-practices)
9. [Quick Start Guide](#quick-start-guide)

## What is Docker Compose?

Docker Compose is a tool for defining and running multi-container Docker applications. It uses YAML files to configure application services and performs the creation and start-up process of all the containers with a single command.

### Key Benefits for Testing

- **Reproducibility** - Same environment across all machines
- **Isolation** - Each test run gets a clean environment
- **Speed** - Quick setup and teardown of complex environments
- **Multiple Environments** - Easy switching between dev/test/prod configs

### Docker Compose vs Docker

| Docker                           | Docker Compose                    |
| -------------------------------- | --------------------------------- |
| Manages single containers        | Orchestrates multiple containers  |
| Uses docker run commands         | Uses docker-compose.yml files     |
| Manual networking setup          | Automatic network creation        |
| Complex for multi-container apps | Simple multi-container management |

## Docker Compose Architecture in Our Project

Our SnapLogic test automation framework uses a modular Docker Compose architecture:

### Project Structure
```
├── docker-compose.yml          # Main orchestration file
├── docker-compose.oracle.yml   # Oracle database service
├── docker-compose.postgres.yml # PostgreSQL database service
├── docker-compose.s3emulator.yml    # MinIO S3-compatible storage
├── docker-compose.groundplex.yml # SnapLogic Groundplex
└── Makefile                    # Automation commands
```

### Service Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Network                     │
│                                                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │    Tools    │  │   Oracle    │  │  PostgreSQL │         │
│  │  Container  │  │  Database   │  │   Database  │         │
│  │             │  │             │  │             │         │
│  │ Robot Tests │  │  Port:1521  │  │  Port:5432  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                 │                 │                 │
│         └─────────────────┼─────────────────┘                │
│                           │                                   │
│  ┌─────────────┐  ┌──────┴──────┐                          │
│  │    MinIO    │  │ Groundplex  │                          │
│  │ S3 Storage  │  │  SnapLogic  │                          │
│  │             │  │   Runtime   │                          │
│  │ Port:9000/1 │  │             │                          │
│  └─────────────┘  └─────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

## Understanding docker-compose.yml Structure

### Main Compose File (docker-compose.yml)

```yaml
# docker-compose.yml - Main orchestration file
include:
  - docker-compose.oracle.yml      # Include Oracle service definition
  - docker-compose.groundplex.yml  # Include Groundplex service
  - docker-compose.s3emulator.yml       # Include MinIO service
  - docker-compose.postgres.yml    # Include PostgreSQL service

services:
  tools:                           # Robot Framework test runner
    build:
      context: src/tools           # Build context path
      dockerfile: ../../robot.Dockerfile
    container_name: snaplogic-test-example-tools-container
    image: snaplogic-test-example:latest
    env_file:
      - .env                       # Load environment variables
    volumes:
      - ./src:/app/src            # Mount source code
      - ./test:/app/test          # Mount test files
      - ./.env:/app/.env          # Mount environment file
      - ./setup_env.sh:/app/setup_env.sh
    command: [ "sh", "-c", "/app/setup_env.sh && tail -f /dev/null" ]
    profiles: [ tools ]            # Service profile
```

### Key Components Explained

#### 1. Include Directive

```yaml
include:
  - docker-compose.oracle.yml
  - docker-compose.groundplex.yml
```

- Modularizes service definitions
- Keeps configurations organized
- Allows selective service inclusion

#### 2. Service Definition

```yaml
services:
  service_name:
    image: image:tag       # Docker image
    container_name: name   # Container name
    ports:                 # Port mapping
      - "host:container"
    environment:           # Environment variables
      VAR: value
    volumes:              # Volume mounts
      - host:container
    profiles: [profile]   # Service profile
```

#### 3. Build Configuration

```yaml
build:
  context: ./path         # Build context
  dockerfile: Dockerfile  # Dockerfile location
```

#### 4. Volume Mounting

```yaml
volumes:
  - ./local/path:/container/path:ro    # Read-only
  - ./data:/data:rw                    # Read-write
  - named-volume:/data                 # Named volume
```

## Service Profiles and Multi-File Setup

### Understanding Profiles

Profiles allow you to selectively start services based on your testing needs:

```yaml
# docker-compose.oracle.yml
services:
  oracle-db:
    image: container-registry.oracle.com/database/free:23.7.0.0-lite
    container_name: oracle-db
    ports:
      - "1521:1521"
    environment:
      ORACLE_PWD: Oracle123
    volumes:
      - oracle_data:/opt/oracle/oradata
    healthcheck:
      test: [ "CMD", "bash", "-c", "echo 'select 1 from dual;' | sqlplus -s system/Oracle123@localhost/FREEPDB1" ]
      interval: 10s
      timeout: 10s
      retries: 10
    profiles: [ dev, oracle-dev ]    # Multiple profiles

volumes:
  oracle_data:                       # Named volume for data persistence
```

### Profile Usage Examples

```bash
# Start only tools container
docker compose --profile tools up

# Start Oracle and tools
docker compose --profile oracle-dev --profile tools up

# Start multiple services
COMPOSE_PROFILES=gp,oracle-dev docker compose up
```

### Service Organization

| File                          | Services             | Profiles          | Purpose                  |
| ----------------------------- | -------------------- | ----------------- | ------------------------ |
| docker-compose.yml            | tools                | tools             | Test execution container |
| docker-compose.oracle.yml     | oracle-db            | dev, oracle-dev   | Oracle database          |
| docker-compose.postgres.yml   | postgres-db          | dev, postgres-dev | PostgreSQL database      |
| docker-compose.s3emulator.yml | minio                | dev, minio-dev    | S3-compatible storage    |
| docker-compose.groundplex.yml | snaplogic-groundplex | gp                | SnapLogic runtime        |

## Integration with Makefile

The Makefile provides a user-friendly interface to Docker Compose commands, adding automation and workflow management.

### How Makefile Uses Docker Compose

#### 1. Environment Validation

```makefile
check-env:
	@if [ -f ".env" ]; then \
		echo "✅ Found .env file at: .env"; \
	else \
		echo "❌ Error: .env file not found"; \
		exit 1; \
	fi
```

#### 2. Service Management

```makefile
# Start services with profiles
start-services:
	@echo "Starting containers using profiles: $(COMPOSE_PROFILES)..."
	COMPOSE_PROFILES=$(COMPOSE_PROFILES) docker compose up -d
	@sleep 60
	$(MAKE) groundplex-status
```

#### 3. Build Process

```makefile
snaplogic-build-tools: snaplogic-stop
	@echo "Building image..."
	docker compose build --no-cache tools
```

#### 4. Test Execution

```makefile
robot-run-tests: check-env
	@echo "🔧 Starting Robot Framework tests..."
	docker compose exec -w /app/test tools robot \
		-G $(DATE) \
		--timestampoutputs \
		--variable PROJECT_SPACE_SETUP:$(PROJECT_SPACE_SETUP_VAL) \
		--include $(TAGS) \
		--outputdir robot_output suite/
```

### Makefile Workflow Examples

#### Complete Test Workflow

```makefile
robot-run-all-tests: check-env
	# Phase 1: Infrastructure setup
	$(MAKE) robot-run-tests TAGS="createplex" PROJECT_SPACE_SETUP=True
	
	# Phase 2: Start services
	$(MAKE) start-services
	
	# Phase 3: Run tests
	$(MAKE) robot-run-tests TAGS="$(TAGS)" PROJECT_SPACE_SETUP=False
```

### Key Makefile Commands

| Command                      | Description             | Docker Compose Usage                        |
| ---------------------------- | ----------------------- | ------------------------------------------- |
| `make snaplogic-build-tools` | Build test tools image  | `docker compose build --no-cache tools`     |
| `make start-services`        | Start selected services | `COMPOSE_PROFILES=x,y docker compose up -d` |
| `make robot-run-tests`       | Execute Robot tests     | `docker compose exec tools robot ...`       |
| `make snaplogic-stop`        | Stop all containers     | `docker compose down --remove-orphans`      |
| `make oracle-start`          | Start Oracle DB         | `docker compose --profile oracle-dev up -d` |
| `make groundplex-status`     | Check Groundplex health | `docker exec snaplogic-groundplex ...`      |

## Common Docker Compose Commands

### Basic Commands

```bash
# Start services in background
docker compose up -d

# Start with specific profiles
docker compose --profile oracle-dev --profile tools up -d

# View running containers
docker compose ps

# View logs
docker compose logs -f service_name

# Stop services
docker compose down

# Stop and remove volumes
docker compose down -v
```

### Advanced Commands

```bash
# Rebuild images
docker compose build --no-cache

# Execute command in running container
docker compose exec tools bash

# Run one-off command
docker compose run --rm tools robot --version

# Scale services
docker compose up -d --scale tools=3

# View resource usage
docker compose stats

# Validate compose files
docker compose config

# Pull latest images
docker compose pull
```

### Working with Profiles

```bash
# List available profiles
docker compose config --profiles

# Start multiple profiles
COMPOSE_PROFILES=oracle-dev,minio-dev docker compose up -d

# Override profiles via command line
docker compose --profile tools --profile oracle-dev up
```

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Port Conflicts

**Error**: `Bind for 0.0.0.0:1521 failed: port is already allocated`

**Solution 1**: Find and stop conflicting service
```bash
lsof -i :1521
docker compose down
```

**Solution 2**: Change port in compose file
```yaml
ports:
  - "1522:1521"  # Use different host port
```

#### 2. Container Name Conflicts

**Error**: `Conflict. The container name "/oracle-db" is already in use`

**Solution**:
```bash
docker container rm oracle-db
# Or
docker compose down --remove-orphans
```

#### 3. Volume Permission Issues

**Error**: `Permission denied`

**Solution**: Check volume ownership
```bash
docker compose exec tools ls -la /app/test

# Fix permissions
docker compose exec tools chmod -R 755 /app/test
```

#### 4. Service Dependencies

Add explicit dependencies:
```yaml
services:
  tools:
    depends_on:
      oracle-db:
        condition: service_healthy
```

#### 5. Environment Variable Issues

```bash
# Debug environment variables
docker compose config

# Check resolved values
docker compose exec tools env | grep MY_VAR
```

### Health Check Debugging

```bash
# Check service health
docker compose ps

# View health check logs
docker inspect oracle-db | jq '.[0].State.Health'

# Manual health check
docker compose exec oracle-db /healthcheck.sh
```

## Best Practices

### 1. Use Profiles for Environment Management

```yaml
profiles:
  - dev      # Development environment
  - test     # Test environment
  - ci       # CI/CD environment
```

### 2. Implement Health Checks

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 3. Use Named Volumes for Data Persistence

```yaml
volumes:
  oracle_data:    # Named volume
    driver: local
```

### 4. Environment Variable Management

```yaml
# Use .env file
env_file:
  - .env

# Provide defaults
environment:
  PORT: ${PORT:-8080}
```

### 5. Network Isolation

```yaml
networks:
  test-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.28.0.0/16
```

### 6. Resource Limits

```yaml
services:
  tools:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          memory: 2G
```

### 7. Logging Configuration

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## Makefile and Docker Compose Integration Flow

The updated integration flow reflects the current multi-phase testing approach with improved error handling and conditional project setup:

```
User Command                           Makefile Workflow                    Docker Compose Actions
──────────────────────────────────────────────────────────────────────────────────────────────────────
make robot-run-all-tests             ─┬─► check-env ──────────────────────► (validates .env file)
  TAGS="oracle"                       │
  PROJECT_SPACE_SETUP=True            │
                                      │
                                      ├─► [Phase 1] Conditional Setup ──────► 
                                      │   ├─ IF PROJECT_SPACE_SETUP=True:
                                      │   │   ├─► robot-run-tests ──────────► docker compose exec tools robot
                                      │   │   │   TAGS="createplex"               --include createplex
                                      │   │   │   PROJECT_SPACE_SETUP=True
                                      │   │   │
                                      │   │   └─► Error Recovery Logic ─────► 
                                      │   │       ├─ Check for "active nodes" error
                                      │   │       ├─► stop-groundplex ──────► docker compose --profile gp down
                                      │   │       ├─ Wait 60s for deregistration
                                      │   │       └─► Retry createplex tests
                                      │   │
                                      │   └─ ELSE (PROJECT_SPACE_SETUP≠True):
                                      │       └─► robot-run-tests ──────────► docker compose exec tools robot
                                      │           TAGS="verify_project_space_exists"  --include verify_project_space_exists
                                      │
                                      ├─► [Phase 2] Groundplex Launch ──────► 
                                      │   └─► launch-groundplex ─────────────► docker compose --profile gp up -d
                                      │       └─► groundplex-status ─────────► docker exec snaplogic-groundplex jcc.sh status
                                      │           (20 attempts, 10s intervals)
                                      │
                                      └─► [Phase 3] User Tests ─────────────► 
                                          └─► robot-run-tests ─────────────► docker compose exec tools robot
                                              TAGS="oracle" (user-defined)       --include oracle
                                              PROJECT_SPACE_SETUP=False
```

### Key Workflow Improvements

#### 1. **Intelligent Error Recovery**
```makefile
# Enhanced error handling with active node detection
robot-run-all-tests:
    $(MAKE) robot-run-tests TAGS="createplex" || { \
        if grep -q "cannot be deleted while it contains active nodes" robot_output/log-*.html; then \
            $(MAKE) stop-groundplex; \
            sleep 60; \
            $(MAKE) robot-run-tests TAGS="createplex" || exit 1; \
        fi; \
    }
```

#### 2. **Conditional Project Setup**
```makefile
# Dynamic workflow based on PROJECT_SPACE_SETUP parameter
PROJECT_SPACE_SETUP_ACTUAL=${PROJECT_SPACE_SETUP:-False}; \
if [ "$PROJECT_SPACE_SETUP_ACTUAL" = "True" ]; then \
    # Full setup path
else \
    # Verification-only path
fi
```

#### 3. **Robust Service Health Checking**
```makefile
# Enhanced Groundplex status checking with detailed logging
groundplex-status:
    attempt=1; \
    while [ $attempt -le 20 ]; do \
        if docker exec snaplogic-groundplex jcc.sh status; then \
            echo "✅ JCC is running."; exit 0; \
        fi; \
        sleep 10; attempt=$((attempt + 1)); \
    done
```

### Updated Command Reference

| Command                             | Current Implementation                   | Docker Compose Usage                                   |
| ----------------------------------- | ---------------------------------------- | ------------------------------------------------------ |
| `make robot-run-all-tests`          | Multi-phase workflow with error recovery | Multiple profile orchestration                         |
| `make createplex-launch-groundplex` | Combined Plex creation and launch        | `docker compose exec` + `--profile gp up`              |
| `make launch-groundplex`            | Groundplex launch with health checks     | `docker compose --profile gp up -d`                    |
| `make groundplex-status`            | 20-attempt health checking with logging  | `docker exec snaplogic-groundplex jcc.sh status`       |
| `make stop-groundplex`              | Graceful JCC shutdown with retries       | JCC stop + `docker compose --profile gp down`          |
| `make start-services`               | Profile-based service orchestration      | `COMPOSE_PROFILES=tools,oracle-dev,minio,postgres-dev` |
| `make snaplogic-start-services`     | Full rebuild and start workflow          | `build --no-cache` + profile startup                   |

### Environment and Profile Management

#### Default Profile Configuration
```makefile
# Current default profiles
COMPOSE_PROFILES ?= tools,oracle-dev,minio,postgres-dev

# Usage in service startup
start-services:
    COMPOSE_PROFILES=$(COMPOSE_PROFILES) docker compose up -d
    sleep 30  # Service stabilization wait
```

#### Profile Override Examples
```bash
# Override default profiles
make robot-run-all-tests COMPOSE_PROFILES="tools,oracle-dev"

# Use different database
make robot-run-all-tests COMPOSE_PROFILES="tools,postgres-dev,minio"
```

### Error Handling and Recovery

The current implementation includes sophisticated error handling:

1. **Active Node Detection**: Automatically detects when project space deletion fails due to active Groundplex nodes
2. **Graceful Recovery**: Stops Groundplex, waits for deregistration, and retries
3. **Health Check Loops**: Robust polling for service readiness with detailed logging
4. **Container State Validation**: Checks both container status and internal service status

### Service Lifecycle Management

```
Service Startup Flow:
────────────────────
snaplogic-stop ──► snaplogic-build-tools ──► start-services ──► health-checks
     │                      │                      │                │
     ├─ Clean containers    ├─ Rebuild tools       ├─ Launch        ├─ Validate
     ├─ Remove networks     ├─ No-cache build      ├─ profiles      ├─ readiness
     └─ Prune volumes       └─ Fresh image         └─ Wait 30s      └─ Log status
```

## Quick Start Guide

### 1. Basic Test Run

```bash

# Run with project space setup (first time setup)
make robot-run-all-tests TAGS="oracle" PROJECT_SPACE_SETUP=True

# Run Oracle tests with out the need of Project Space SetUp (Default value for PROJECT_SPACE_SETUP is False)
make robot-run-all-tests TAGS="oracle" 


```

### 2. Custom Profile Test Run

```bash
# Run Oracle tests with specific services
make robot-run-all-tests TAGS="oracle" COMPOSE_PROFILES="tools,oracle-dev,minio-dev"

# Run PostgreSQL tests with specific profiles
make robot-run-all-tests TAGS="postgres" COMPOSE_PROFILES="tools,postgres-dev"

# Run MinIO tests with custom setup
make robot-run-all-tests TAGS="minio" COMPOSE_PROFILES="tools,minio-dev" PROJECT_SPACE_SETUP=True
```

### 3. Individual Service Management

```bash
# Start Oracle only
make oracle-start

# Start MinIO
make start-s3-emulator

# Check Groundplex status
make groundplex-status
```

### 4. Debugging Workflow

```bash
# View running services
docker compose ps

# Check logs
docker compose logs -f tools

# Access container
docker compose exec tools bash
```

## Summary

Docker Compose in our SnapLogic test automation framework provides:

- **Modular Architecture** - Separate files for each service
- **Profile-Based Deployment** - Flexible service selection
- **Makefile Integration** - Simplified command interface
- **Health Monitoring** - Automated service readiness checks
- **Environment Management** - Consistent configuration across environments

The combination of Docker Compose and Makefile creates a powerful, maintainable testing infrastructure that scales with your needs.

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Compose Networking](https://docs.docker.com/compose/networking/)
- [Environment Variables in Compose](https://docs.docker.com/compose/environment-variables/)

---

## 📚 Explore More Documentation

💡 **Need help finding other guides?** Check out our **[📖 Complete Documentation Reference](../../reference.md)** for a comprehensive overview of all available tutorials, how-to guides, and quick start paths. It's your one-stop navigation hub for the entire SnapLogic Test Framework documentation!

---
*Last Updated: January 2025*