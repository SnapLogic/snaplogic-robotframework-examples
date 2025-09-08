# Using Different Environment Files for Different Stages

## Overview

You can use different `.env` files for different stages (development, staging, QA, production) by passing the `ENV_FILE` parameter to any make command. If no `ENV_FILE` is specified, the default `.env` file is used.

## How It Works

The `Makefile.common` contains:
```makefile
# The ?= operator means:
# - If ENV_FILE is already defined (either as an environment variable or passed via command line), keep that value
# - If ENV_FILE is not defined, set it to .env
ENV_FILE ?= .env
```

This allows you to override the environment file for ANY make command.

## Usage

### Basic Usage

```bash
# Uses default .env file
make robot-run-tests

# Use staging environment file
make robot-run-tests ENV_FILE=.env.staging

# Use production environment file
make robot-run-tests ENV_FILE=.env.production

# Use QA environment file
make robot-run-tests ENV_FILE=.env.qa
```

### With Additional Parameters

You can combine ENV_FILE with any other parameters:

```bash
# Run specific tests in staging environment
make robot-run-tests ENV_FILE=.env.staging TAGS="oracle,kafka"

# Start services with production config
make snaplogic-start-services ENV_FILE=.env.production

# Clean start with development environment
make clean-start ENV_FILE=.env.dev

# Launch groundplex with QA configuration
make launch-groundplex ENV_FILE=.env.qa
```

## Setting Up Environment Files

### 1. Create Environment-Specific Files

Create separate `.env` files for each environment:

```bash
# Copy from template
cp .env.example .env.dev
cp .env.example .env.staging
cp .env.example .env.qa
cp .env.example .env.production

# Or copy from existing .env
cp .env .env.staging
cp .env .env.production
```

### 2. Configure Each Environment

Edit each file with environment-specific values:

**.env.dev**
```env
SNAPLOGIC_ORG=mycompany-dev
SNAPLOGIC_POD_URL=https://dev.snaplogic.com
SNAPLOGIC_USERNAME=dev-user
SNAPLOGIC_PASSWORD=dev-password
COMPOSE_PROFILES=tools,oracle-dev,minio,postgres-dev
```

**.env.staging**
```env
SNAPLOGIC_ORG=mycompany-staging
SNAPLOGIC_POD_URL=https://staging.snaplogic.com
SNAPLOGIC_USERNAME=staging-user
SNAPLOGIC_PASSWORD=staging-password
COMPOSE_PROFILES=tools,postgres-dev,kafka
```

**.env.production**
```env
SNAPLOGIC_ORG=mycompany-prod
SNAPLOGIC_POD_URL=https://elastic.snaplogic.com
SNAPLOGIC_USERNAME=prod-user
SNAPLOGIC_PASSWORD=prod-password
COMPOSE_PROFILES=tools
```

## Examples

### Example 1: Running Tests in Different Environments

```bash
# Development testing
make robot-run-tests ENV_FILE=.env.dev

# Staging testing with specific tags
make robot-run-tests ENV_FILE=.env.staging TAGS="smoke"

# QA testing with all tags
make robot-run-tests ENV_FILE=.env.qa

# Production testing (be careful!)
make robot-run-tests ENV_FILE=.env.production TAGS="critical"
```

### Example 2: Managing Services per Environment

```bash
# Start development services
make snaplogic-start-services ENV_FILE=.env.dev

# Stop staging services
make snaplogic-stop ENV_FILE=.env.staging

# Check status with production config
make status ENV_FILE=.env.production
```

### Example 3: Database Operations

```bash
# Start Oracle in development
make oracle-start ENV_FILE=.env.dev

# Start PostgreSQL in staging
make postgres-start ENV_FILE=.env.staging
```

### Example 4: Complete Workflow

```bash
# Full test run in staging environment
make clean-start ENV_FILE=.env.staging
make launch-groundplex ENV_FILE=.env.staging
make robot-run-tests ENV_FILE=.env.staging TAGS="regression"
make upload-test-results ENV_FILE=.env.staging
make snaplogic-stop ENV_FILE=.env.staging
```

## Using Environment Variables

You can also set ENV_FILE as an environment variable:

```bash
# Set for current session
export ENV_FILE=.env.staging
make robot-run-tests
make snaplogic-start-services

# Or inline for a single command
ENV_FILE=.env.production make robot-run-tests
```

## CI/CD Integration

### GitHub Actions
```yaml
- name: Run Tests
  run: make robot-run-tests
  env:
    ENV_FILE: .env.staging
```

### Jenkins
```groovy
stage('Test Staging') {
    steps {
        sh 'make robot-run-tests ENV_FILE=.env.staging'
    }
}
```

### GitLab CI
```yaml
test:staging:
  script:
    - make robot-run-tests ENV_FILE=.env.staging
```

### Shell Script
```bash
#!/bin/bash
# Select environment based on branch
if [ "$GIT_BRANCH" = "main" ]; then
    ENV_FILE=.env.production
elif [ "$GIT_BRANCH" = "staging" ]; then
    ENV_FILE=.env.staging
else
    ENV_FILE=.env.dev
fi

make robot-run-tests ENV_FILE=$ENV_FILE
```

## Best Practices

1. **File Naming Convention**: Use clear, consistent names:
   - `.env` - Default/local development
   - `.env.dev` - Development environment
   - `.env.staging` - Staging environment
   - `.env.qa` - QA environment
   - `.env.production` - Production environment

2. **Security**:
   - Never commit `.env` files with real credentials to Git
   - Add `.env*` to `.gitignore` (except `.env.example`)
   - Use environment variables in CI/CD for sensitive data

3. **Documentation**:
   - Keep `.env.example` updated with all required variables
   - Document environment-specific requirements

4. **Validation**:
   - Always verify which environment file is being used
   - Test configuration before running critical operations

## Troubleshooting

### Check Which Environment File Is Being Used

The docker-compose command will show which env file is being used:
```bash
# This will show the actual docker-compose command with --env-file parameter
make snaplogic-start-services ENV_FILE=.env.staging
```

### Verify Environment File Exists

```bash
# List all env files
ls -la .env*

# Check specific file
cat .env.staging | grep SNAPLOGIC_ORG
```

### Debug Environment Variables

```bash
# See what would be used
make -n robot-run-tests ENV_FILE=.env.staging
```

## Summary

- **Default behavior**: Uses `.env` file if no ENV_FILE specified
- **Override method**: Pass `ENV_FILE=.env.<stage>` to any make command
- **Works everywhere**: The ENV_FILE parameter works with ALL make targets
- **Simple to use**: Just add `ENV_FILE=.env.staging` to your command

No additional setup or special targets needed - it just works!
