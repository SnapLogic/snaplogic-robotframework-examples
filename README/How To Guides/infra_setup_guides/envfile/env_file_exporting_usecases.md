# Complete Guide to Using Environment Files (.env)

## Table of Contents
- [Overview](#overview)
- [How It Works](#how-it-works)
- [Method 1: Command Line Parameters](#method-1-command-line-parameters)
- [Method 2: Environment Variables](#method-2-environment-variables)
- [Method 3: Shell Scripts](#method-3-shell-scripts)
- [Method 4: Shell Configuration Files](#method-4-shell-configuration-files)
- [Method 5: Directory-based Auto-loading (direnv)](#method-5-directory-based-auto-loading-direnv)
- [Method 6: Command Aliases](#method-6-command-aliases)
- [Overriding Other Variables](#overriding-other-variables)
- [Best Practices](#best-practices)
- [Quick Reference](#quick-reference)

## Overview

The SnapLogic Robot Framework test suite supports using different `.env` files for different environments (development, staging, QA, production). This guide covers all possible ways to specify which environment file to use.

### Default Behavior
- If no `ENV_FILE` is specified → uses `.env`
- If `ENV_FILE` is specified → uses that file
- Works with ALL make commands automatically

## How It Works

In `Makefile.common`:
```makefile
# The ?= operator means:
# - If ENV_FILE is already defined, keep that value
# - If ENV_FILE is not defined, set it to .env
ENV_FILE ?= .env
```

## Method 1: Command Line Parameters

### Basic Usage
Pass `ENV_FILE` as a parameter to any make command:

```bash
# Uses default .env
make robot-run-tests

# Use specific environment files
make robot-run-tests ENV_FILE=.env.staging
make robot-run-tests ENV_FILE=.env.production
make robot-run-tests ENV_FILE=.env.qa
```

### With Additional Parameters
Combine `ENV_FILE` with other parameters:

```bash
# Run specific tests in staging
make robot-run-tests ENV_FILE=.env.staging TAGS="oracle,kafka"

# Start services with custom profiles
make snaplogic-start-services ENV_FILE=.env.qa COMPOSE_PROFILES=tools,postgres-dev

# Clean start with custom timeout
make clean-start ENV_FILE=.env.dev ROBOT_DEFAULT_TIMEOUT=60s
```

### All Service Commands
```bash
# Starting services
make snaplogic-start-services ENV_FILE=.env.staging
make oracle-start ENV_FILE=.env.qa
make kafka-start ENV_FILE=.env.dev
make postgres-start ENV_FILE=.env.production

# Stopping services
make snaplogic-stop ENV_FILE=.env.staging
make oracle-stop ENV_FILE=.env.qa

# Status checks
make status ENV_FILE=.env.production
make groundplex-status ENV_FILE=.env.staging
```

## Method 2: Environment Variables

### Set for Current Shell Session
Export the variable once, use for all commands:

```bash
# Set for all subsequent commands
export ENV_FILE=.env.staging

# Now all commands use .env.staging automatically
make robot-run-tests
make snaplogic-start-services
make clean-start
make upload-test-results

# Switch to different environment
export ENV_FILE=.env.qa
make robot-run-tests  # Now uses .env.qa

# Check current setting
echo $ENV_FILE

# Unset to go back to default
unset ENV_FILE
make robot-run-tests  # Back to using .env
```

### Set for Single Command
```bash
# Only affects this one command
ENV_FILE=.env.production make robot-run-tests

# Next command uses default again
make snaplogic-status  # Uses .env
```

### Set in Terminal Profile
For persistent configuration across sessions:

```bash
# Add to ~/.bashrc or ~/.bash_profile (for Bash)
echo 'export ENV_FILE=.env.staging' >> ~/.bashrc
source ~/.bashrc

# Add to ~/.zshrc (for Zsh/Mac)
echo 'export ENV_FILE=.env.staging' >> ~/.zshrc
source ~/.zshrc
```

## Method 3: Shell Scripts

### Create Environment-Specific Wrapper Scripts

**run-staging.sh:**
```bash
#!/bin/bash
# Wrapper for staging environment
export ENV_FILE=.env.staging
echo "🎭 Running in STAGING environment"
make "$@"
```

**run-qa.sh:**
```bash
#!/bin/bash
# Wrapper for QA environment
export ENV_FILE=.env.qa
echo "🧪 Running in QA environment"
make "$@"
```

**run-prod.sh:**
```bash
#!/bin/bash
# Wrapper for production environment
export ENV_FILE=.env.production
echo "⚠️  Running in PRODUCTION environment"
read -p "Are you sure? [y/N]: " confirm
if [ "$confirm" = "y" ]; then
    make "$@"
else
    echo "Aborted."
fi
```

**Usage:**
```bash
# Make scripts executable
chmod +x run-*.sh

# Use the scripts
./run-staging.sh robot-run-tests
./run-qa.sh snaplogic-start-services
./run-prod.sh clean-start
```

### Create a Smart Environment Selector Script

**run-env.sh:**
```bash
#!/bin/bash
# Smart environment selector

if [ -z "$1" ]; then
    echo "Usage: ./run-env.sh <environment> <make-target> [args...]"
    echo "Environments: dev, staging, qa, production"
    exit 1
fi

ENV=$1
shift

case $ENV in
    dev)
        export ENV_FILE=.env.dev
        ;;
    staging)
        export ENV_FILE=.env.staging
        ;;
    qa)
        export ENV_FILE=.env.qa
        ;;
    production)
        export ENV_FILE=.env.production
        echo "⚠️  WARNING: Production environment!"
        ;;
    *)
        echo "Unknown environment: $ENV"
        exit 1
        ;;
esac

echo "🚀 Running in $ENV environment (using $ENV_FILE)"
make "$@"
```

**Usage:**
```bash
./run-env.sh staging robot-run-tests
./run-env.sh qa snaplogic-start-services COMPOSE_PROFILES=minimal
./run-env.sh production status
```

## Method 4: Shell Configuration Files

### Project-Specific Configuration

Create a `.env.config` file in your project:
```bash
# .env.config
ENV_FILE=.env.staging
```

Then source it when needed:
```bash
source .env.config
make robot-run-tests  # Uses .env.staging
```

### Auto-load on Directory Entry

Add to your shell configuration to auto-load when entering the project:

**~/.bashrc or ~/.zshrc:**
```bash
# Auto-load environment config when entering project directory
cd() {
    builtin cd "$@"
    if [ -f .env.config ]; then
        source .env.config
        echo "📋 Loaded environment config: ENV_FILE=$ENV_FILE"
    fi
}
```

## Method 5: Directory-based Auto-loading (direnv)

### Install and Setup direnv

```bash
# Install direnv
brew install direnv  # macOS
apt-get install direnv  # Ubuntu/Debian

# Add to shell (bash)
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# Add to shell (zsh)
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
```

### Create .envrc File

**.envrc:**
```bash
# Automatically set environment when entering directory
export ENV_FILE=.env.staging
export COMPOSE_PROFILES=tools,postgres-dev,kafka

echo "📋 Environment configured:"
echo "   ENV_FILE=$ENV_FILE"
echo "   COMPOSE_PROFILES=$COMPOSE_PROFILES"
```

### Activate
```bash
# Allow direnv for this directory
direnv allow

# Now whenever you cd into this directory:
cd /path/to/project
# Environment is automatically set!
```

## Method 6: Command Aliases

### Create Convenient Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Environment-specific make commands
alias make-dev='ENV_FILE=.env.dev make'
alias make-staging='ENV_FILE=.env.staging make'
alias make-qa='ENV_FILE=.env.qa make'
alias make-prod='ENV_FILE=.env.production make'

# Specific command aliases
alias test-dev='ENV_FILE=.env.dev make robot-run-tests'
alias test-staging='ENV_FILE=.env.staging make robot-run-tests'
alias test-qa='ENV_FILE=.env.qa make robot-run-tests'
alias test-prod='ENV_FILE=.env.production make robot-run-tests'

# Service management aliases
alias start-dev='ENV_FILE=.env.dev make snaplogic-start-services'
alias start-staging='ENV_FILE=.env.staging make snaplogic-start-services'
alias stop-all='make snaplogic-stop'

# Quick status checks
alias status-dev='ENV_FILE=.env.dev make status'
alias status-staging='ENV_FILE=.env.staging make status'
alias status-qa='ENV_FILE=.env.qa make status'
```

**Usage:**
```bash
# Reload shell configuration
source ~/.bashrc  # or source ~/.zshrc

# Use the aliases
make-staging robot-run-tests
test-qa
start-dev
status-staging
```

## Overriding Other Variables

You can override ALL variables from `Makefile.common`:

### Override Multiple Variables
```bash
# Complete custom configuration
make robot-run-tests \
  ENV_FILE=.env.staging \
  COMPOSE_PROFILES=tools,kafka \
  DEFAULT_PROCESSES=8 \
  ROBOT_DEFAULT_TIMEOUT=45s \
  ROBOT_OUTPUT_DIR=staging_results \
  S3_BUCKET=staging-test-results \
  S3_PREFIX=Staging_Tests_2024 \
  DATE=2024-staging-run-001
```

### Available Variables to Override

| Variable | Default | Example Override |
|----------|---------|------------------|
| ENV_FILE | .env | `ENV_FILE=.env.staging` |
| COMPOSE_PROFILES | tools,oracle-dev,minio,... | `COMPOSE_PROFILES=minimal` |
| DEFAULT_PROCESSES | 5 | `DEFAULT_PROCESSES=10` |
| ROBOT_DEFAULT_TIMEOUT | 30s | `ROBOT_DEFAULT_TIMEOUT=60s` |
| S3_BUCKET | artifacts.slimdev.snaplogic | `S3_BUCKET=my-bucket` |
| S3_PREFIX | RF_CommonTests_Results | `S3_PREFIX=Custom_Results` |
| DATE | $(shell date +'%Y-%m-%d-%H-%M') | `DATE=custom-date` |
| DOCKER_COMPOSE_FILE | docker/docker-compose.yml | `DOCKER_COMPOSE_FILE=custom.yml` |
| PROJECT_ROOT | $(shell pwd) | `PROJECT_ROOT=/custom/path` |
| TEST_DIR | test | `TEST_DIR=custom_tests` |
| ROBOT_OUTPUT_DIR | robot_output | `ROBOT_OUTPUT_DIR=results` |

## Best Practices

### 1. Environment File Organization
```
project/
├── .env                 # Default/local development
├── .env.example         # Template with all variables
├── .env.dev            # Development
├── .env.staging        # Staging
├── .env.qa             # QA
├── .env.production     # Production
└── .env.local          # Personal overrides (git-ignored)
```

### 2. Git Configuration
**.gitignore:**
```
# Ignore all .env files except example
.env
.env.*
!.env.example

# Ignore personal configuration
.env.config
.envrc
run-*.sh
```

### 3. Team Workflows

**For Development Teams:**
```bash
# Each developer creates their own local config
cp .env.example .env.local
export ENV_FILE=.env.local

# Shared environments use standard names
make robot-run-tests ENV_FILE=.env.staging  # Test in staging
make robot-run-tests ENV_FILE=.env.qa       # Test in QA
```

**For CI/CD:**
```yaml
# GitHub Actions
env:
  ENV_FILE: .env.${{ github.event.inputs.environment }}

# Jenkins
environment {
    ENV_FILE = ".env.${params.ENVIRONMENT}"
}
```

### 4. Safety Measures

**Production Safety Script:**
```bash
#!/bin/bash
# safe-prod.sh - Wrapper with confirmations

export ENV_FILE=.env.production

echo "⚠️  PRODUCTION ENVIRONMENT SELECTED"
echo "ENV_FILE: $ENV_FILE"
echo "Target: $@"
echo ""
read -p "Type 'PRODUCTION' to confirm: " confirm

if [ "$confirm" = "PRODUCTION" ]; then
    make "$@"
else
    echo "Aborted."
    exit 1
fi
```

## Quick Reference

### Most Common Usage Patterns

```bash
# 1. Quick test in different environment (one-time)
make robot-run-tests ENV_FILE=.env.staging

# 2. Work in specific environment for a session
export ENV_FILE=.env.qa
make robot-run-tests
make snaplogic-start-services
make status

# 3. Permanent setup for a project
echo 'export ENV_FILE=.env.dev' >> .env.config
source .env.config

# 4. Using aliases for convenience
alias test-staging='ENV_FILE=.env.staging make robot-run-tests'
test-staging

# 5. Override multiple settings
make robot-run-tests \
  ENV_FILE=.env.qa \
  TAGS="smoke" \
  DEFAULT_PROCESSES=3
```

### Environment Switching Workflow

```bash
# Monday - Development
export ENV_FILE=.env.dev
make clean-start
make robot-run-tests

# Tuesday - Staging Tests
export ENV_FILE=.env.staging
make clean-start
make robot-run-tests TAGS="regression"

# Wednesday - QA Validation
export ENV_FILE=.env.qa
make robot-run-tests TAGS="smoke"

# Thursday - Production Checks
ENV_FILE=.env.production make status

# Friday - Back to default
unset ENV_FILE
make robot-run-tests  # Uses .env
```

### Checking Current Configuration

```bash
# Check which env file is set
echo $ENV_FILE

# Verify file exists
ls -la $ENV_FILE

# Preview what will be used
make -n robot-run-tests | grep env-file

# Check specific values in env file
grep SNAPLOGIC_ORG $ENV_FILE
```

## Troubleshooting

### Issue: Wrong environment being used
```bash
# Check current setting
echo "Current ENV_FILE: $ENV_FILE"

# Verify in make command
make -n snaplogic-start-services | grep "env-file"
```

### Issue: Environment file not found
```bash
# List available env files
ls -la .env*

# Check file exists
test -f .env.staging && echo "exists" || echo "not found"
```

### Issue: Variable not being overridden
```bash
# Command line has highest priority
unset ENV_FILE  # Clear environment variable
make robot-run-tests ENV_FILE=.env.staging  # This takes precedence
```

## Summary

- **Simplest**: Pass `ENV_FILE=.env.staging` to any make command
- **Most Convenient**: Export ENV_FILE for your shell session
- **Most Automated**: Use direnv for directory-based switching
- **Most Flexible**: Combine multiple variable overrides
- **Safest for Production**: Use wrapper scripts with confirmations

Choose the method that best fits your workflow and team practices!
