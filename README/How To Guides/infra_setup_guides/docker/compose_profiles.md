# Docker Compose Profiles Management

## Overview
Docker Compose profiles allow you to selectively start services based on your needs. This document explains how profiles are managed in this project.

## 🎯 Single Source of Truth

**COMPOSE_PROFILES is defined ONCE in `makefiles/Makefile.common`**

```makefile
# In makefiles/Makefile.common
COMPOSE_PROFILES ?= tools,oracle-dev,minio,postgres-dev,mysql-dev,sqlserver-dev,activemq,salesforce-mock-start
```

All other Makefiles include this common configuration:
```makefile
include makefiles/Makefile.common
```

## 📋 Available Profiles

| Profile | Services | Purpose |
|---------|----------|---------|
| `tools` | Testing tools container | Robot Framework execution environment |
| `oracle-dev` | Oracle database | Oracle DB for testing |
| `postgres-dev` | PostgreSQL database | PostgreSQL for testing |
| `mysql-dev` | MySQL database | MySQL for testing |
| `sqlserver-dev` | SQL Server | SQL Server for testing |
| `minio` | MinIO S3 emulator | S3-compatible storage testing |
| `kafka` | Kafka, Kafka UI, Setup | Message streaming platform |
| `activemq` | ActiveMQ JMS | JMS messaging testing |
| `salesforce-mock-start` | Salesforce mocks | Salesforce API testing |
| `gp` | Groundplex | SnapLogic Groundplex container |

## 🔧 How to Use Profiles

### 1. **Default Profile Set**
The default profiles are defined in `Makefile.common`:
```bash
# Uses default profiles
make start-services
```

### 2. **Override via Command Line**
```bash
# Start only specific services
make start-services COMPOSE_PROFILES=kafka,postgres-dev

# Start minimal setup
make start-services COMPOSE_PROFILES=tools

# Start everything for integration testing
make start-services COMPOSE_PROFILES=tools,oracle-dev,kafka,activemq,gp
```

### 3. **Override via Environment Variable**
```bash
# Set for entire session
export COMPOSE_PROFILES=kafka,postgres-dev
make start-services
make kafka-test

# Or inline
COMPOSE_PROFILES=kafka make kafka-start
```

### 4. **Override in .env File**
```bash
# In .env file
COMPOSE_PROFILES=tools,kafka,postgres-dev
```
**Note**: Command-line overrides take precedence over .env file.

## 🎭 Common Profile Combinations

### Development Testing
```bash
# Minimal setup for development
COMPOSE_PROFILES=tools make start-services
```

### Database Testing
```bash
# All databases
COMPOSE_PROFILES=tools,oracle-dev,postgres-dev,mysql-dev,sqlserver-dev make start-services

# Specific database
COMPOSE_PROFILES=tools,postgres-dev make start-services
```

### Integration Testing
```bash
# Full integration environment
COMPOSE_PROFILES=tools,oracle-dev,kafka,activemq,minio,salesforce-mock-start,gp make start-services
```

### Message Queue Testing
```bash
# Messaging services only
COMPOSE_PROFILES=tools,kafka,activemq make start-services
```

## 📝 Adding New Profiles

1. **Define in docker-compose.yml:**
```yaml
services:
  new-service:
    image: new-service:latest
    profiles:
      - new-profile  # Add profile here
```

2. **Update default in Makefile.common (if needed):**
```makefile
COMPOSE_PROFILES ?= tools,oracle-dev,minio,postgres-dev,mysql-dev,sqlserver-dev,activemq,salesforce-mock-start,new-profile
```

3. **Document in this file**

## ⚠️ Important Notes

1. **Profile Order Doesn't Matter**: Docker Compose handles dependencies automatically
2. **Missing Profiles Are Ignored**: If a profile doesn't exist, Docker Compose skips it
3. **Services Without Profiles**: Always start regardless of COMPOSE_PROFILES value
4. **Override Precedence**:
   - Command line > Environment variable > .env file > Makefile default

## 🔍 Checking Active Profiles

```bash
# See which profiles are currently set
make status

# Check what would be used
echo $COMPOSE_PROFILES

# See all services that would start
docker compose --env-file .env -f docker/docker-compose.yml --profile tools --profile kafka config --services
```

## 🛠️ Troubleshooting

### Services Not Starting
```bash
# Check if profile is included
echo $COMPOSE_PROFILES | grep -o 'kafka'

# Verify service has correct profile in docker-compose.yml
docker compose -f docker/docker-compose.yml config | grep -A5 "your-service:"
```

### Wrong Services Starting
```bash
# Clear any environment overrides
unset COMPOSE_PROFILES

# Use explicit profile list
make start-services COMPOSE_PROFILES=tools,kafka
```

### Profile Not Working
```bash
# Validate docker-compose.yml syntax
docker compose -f docker/docker-compose.yml config

# Check profile is properly defined
docker compose -f docker/docker-compose.yml --profile your-profile config --services
```

## 📚 Best Practices

1. **Keep Default Minimal**: Only include commonly used services in default
2. **Document Profile Purpose**: Clear naming and documentation
3. **Group Related Services**: Use same profile for related services
4. **Test Profile Combinations**: Ensure services work together
5. **Use Command-Line for Temporary Changes**: Don't modify Makefile.common for one-off tests

## Example Workflow

```bash
# 1. Check current setup
make status

# 2. Start with specific profiles for your task
make start-services COMPOSE_PROFILES=tools,postgres-dev,kafka

# 3. Run your tests
make robot-run-tests TAGS="database,messaging"

# 4. Clean up
make snaplogic-stop
```
